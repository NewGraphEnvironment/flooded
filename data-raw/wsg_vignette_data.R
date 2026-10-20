# Pre-compute heavy data for the WSG floodplain showcase vignette.
#
# Generic — runs for any BC watershed group that link has modelled. Set
# `wsg` and `species` below.
#
# Generates (under inst/vignette-data/, namespaced by WSG code):
#   <wsg>.gpkg              multi-layer GeoPackage with the sf layers:
#                             aoi, streams, waterbodies, floodplain,
#                             railways, roads, reserves, parks,
#                             named_streams
#   <wsg>_dem.tif           MRDEM-30 clip cropped to streams + 2 km buffer
#   <wsg>_valleys.tif       fl_valley_confine() binary output (1=valley)
#   <wsg>_meta.rds          the link run the streams came from, and where the
#                           context layers came from
#
# Bundling the sf layers into a single multi-layer gpkg matches how QGIS
# expects a per-WSG project bundle and keeps the cache to three files per
# WSG. Rasters stay separate (terra writes COG/GeoTIFF, not into gpkg).
#
# Streams come from the tables link builds with its `default` config
# (schema `fresh_default`): geometry, channel width, access, habitat and
# mapping code for `species`, from the run recorded in fresh_default.log.
# Filtering to `access IN (1, 2)` (1 = modelled, 2 = observed) and
# `stream_order >= min_order` gives "accessible habitat order 3+". Upstream
# area and mean annual precipitation upstream (ClimateBC) are joined from
# fwapg's own tables, the joins fresh::frs_col_join() documents.
#
# Waterbodies (lakes + wetlands) are picked up via `waterbody_key`
# linkage from the filtered stream list — only those physically anchored
# to the network are included. They feed `fl_valley_confine(waterbodies =)`
# so the final valley raster fills lake / wetland cells the gradient and
# cost-distance masks would otherwise carve donut holes around.
#
# To swap species: change `species` to any code link models for the WSG
# (e.g. "co" for coho, "st" for steelhead) — same column shape (`access`,
# `spawning`, `rearing`, `mapping_code`).
#
# Context layers (railways, roads, reserves, parks) are not in fwapg; they
# come from the shared database behind the PG_*_SHARE variables. When that
# database cannot be reached, the layers are carried over unchanged from
# the existing <wsg>.gpkg (they do not depend on the streams), and
# <wsg>_meta.rds records that they were.
#
# Prerequisites:
#   - the PostgreSQL database link persists to (fwapg with `fresh_default`),
#     reached by fresh::frs_db_conn() through the standard PG* variables,
#     with `wsg` modelled into `fresh_default` by link, in the run named by
#     `run_id` below. `fresh_default` holds one provincial run at a time and
#     the next one overwrites it, so the script stops if the run there is not
#     this one; update `run_id` deliberately when rebuilding from a newer run.
#   - for fresh context layers: the shared database (PG_*_SHARE variables)
#   - Outbound HTTPS to s3.ca-central-1.amazonaws.com for MRDEM /vsicurl/
#   - Run from package root so devtools::load_all() finds dev fl_dem_aoi()

# ---- params -------------------------------------------------------------

wsg <- "PARS"                       # any 4-letter BC watershed group code
species <- "bt"                     # link species code (bull trout)
min_order <- 3                      # minimum stream order to keep
run_id <- "cypherjob2-20261017T034533.534-1b8d39"   # fresh_default.log, PARS
recompute_id <- "m1-20261017T092007.555-1b04b0"   # fresh_default.log_recompute, PARS
# inst/NOTICE.md names these runs and their link version: change them together.

# ---- env ----------------------------------------------------------------

Sys.setenv(
  GDAL_HTTP_MAX_RETRY = "3",
  GDAL_HTTP_RETRY_DELAY = "2",
  VSI_CACHE = "TRUE"
)

devtools::load_all(quiet = TRUE)
library(fresh)
library(sf)
library(terra)

out_dir <- file.path("inst", "vignette-data")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

stub <- tolower(wsg)
out <- function(name) file.path(out_dir, paste0(stub, "_", name))   # rasters

# Single multi-layer GeoPackage for all sf layers. It is built from scratch
# in a temporary file and moved into place only after the last layer is
# written (section 6), so a run that stops part-way leaves the previous
# <wsg>.gpkg, and the context layers it holds, untouched.
gpkg_final <- file.path(out_dir, paste0(stub, ".gpkg"))
meta_path <- file.path(out_dir, paste0(stub, "_meta.rds"))
gpkg <- tempfile(paste0(stub, "_"), fileext = ".gpkg")
context_names <- c("railways", "roads", "reserves", "parks")

# Value for one layer from a previous meta field: named per layer, or a single
# value that applied to every layer (the format before per-layer records).
prev_value <- function(x, nm) {
  if (is.null(x) || length(x) == 0L) return(NA_character_)
  if (!is.null(names(x))) return(if (nm %in% names(x)) unname(x[[nm]]) else NA_character_)
  if (length(x) == 1L) unname(x) else NA_character_
}

# Previous context layers, in case the shared database cannot be reached
# (section 4), and where each was last fetched from the database: inherited
# from the previous meta when that run carried it too (NA stays NA), else the
# commit of the previous gpkg, when the working gpkg and meta are both that
# commit's.
carried <- list()
carried_from <- character()
prev_layers <- character()
if (file.exists(gpkg_final)) {
  prev_layers <- sf::st_layers(gpkg_final)$name
  git1 <- function(args) {
    x <- suppressWarnings(system2("git", args, stdout = TRUE))
    if (!is.null(attr(x, "status"))) NA_character_ else x
  }
  # The previous meta describes the previous gpkg only when both are the
  # committed copies of one commit; otherwise record no origin.
  clean <- identical(git1(c("status", "--porcelain", "--", gpkg_final, meta_path)), character(0))
  commit <- git1(c("log", "-1", shQuote("--format=%h %cs"), "--", gpkg_final))
  same <- identical(commit, git1(c("log", "-1", shQuote("--format=%h %cs"), "--", meta_path)))
  if (!clean || !same || length(commit) != 1L) commit <- NA_character_
  pm <- if (!is.na(commit) && file.exists(meta_path)) readRDS(meta_path) else list()
  for (nm in intersect(context_names, sf::st_layers(gpkg_final)$name)) {
    carried[[nm]] <- sf::st_read(gpkg_final, layer = nm, quiet = TRUE)
    carried_from[[nm]] <- if (identical(prev_value(pm$context_source, nm), "carried")) {
      prev_value(pm$context_carried_from, nm)
    } else {
      commit
    }
  }
}

write_layer <- function(x, layer) {
  sf::st_write(x, gpkg, layer = layer, delete_layer = TRUE,
               append = TRUE, quiet = TRUE)
}

# ---- 1. WSG boundary ----------------------------------------------------

conn <- fresh::frs_db_conn()

if (is.na(DBI::dbGetQuery(conn, "SELECT to_regclass('fresh_default.log') AS t")$t)) {
  stop("Database '", DBI::dbGetQuery(conn, "SELECT current_database()")[[1]],
       "' has no fresh_default schema; point the PG* variables at the database link ",
       "persists to.", call. = FALSE)
}
run <- DBI::dbGetQuery(conn, sprintf(
  "SELECT run_id, run_uid, run_label, date_end, config_name, config_hash, link_version,
          link_sha, link_dirty, fresh_version, fresh_dirty, crate_version, fwapg_sha
     FROM fresh_default.log
    WHERE watershed_group_code = '%s'
    ORDER BY date_end DESC LIMIT 1", wsg))
n_seg <- DBI::dbGetQuery(conn, sprintf(
  "SELECT count(*)::int AS n FROM fresh_default.streams_access WHERE watershed_group_code = '%s'",
  wsg))$n
if (nrow(run) == 0L || n_seg == 0L) {
  stop(wsg, " is not modelled in `fresh_default`; run link's default config for it first.",
       call. = FALSE)
}
if (!identical(run$run_id, run_id)) {
  stop("fresh_default holds ", wsg, " run ", run$run_id, ", not ", run_id,
       ". Update `run_id` if rebuilding from the newer run is intended.", call. = FALSE)
}
rc <- DBI::dbGetQuery(conn, sprintf(
  "SELECT recompute_id, date_start, date_end, link_version, link_sha
     FROM fresh_default.log_recompute
    WHERE watershed_group_code = '%s'
    ORDER BY date_start DESC LIMIT 1", wsg))
if (!identical(rc$recompute_id, recompute_id) || anyNA(rc$date_end) ||
    !isTRUE(rc$date_start > run$date_end)) {
  stop("fresh_default's latest ", wsg, " recompute is ",
       if (nrow(rc)) paste0(rc$recompute_id, if (anyNA(rc$date_end)) " (unfinished)") else "none",
       ", expected ", recompute_id, " started after run ", run$run_id, " ended. Access ",
       "and mapping codes come from it: update `recompute_id` if rebuilding from it ",
       "is intended.", call. = FALSE)
}
# Upstream area and precipitation are read live from fwapg tables that no link
# run pins and that carry no load stamp: record the state read.
fwapg_state <- DBI::dbGetQuery(conn, "
  SELECT (SELECT count(*) FROM whse_basemapping.fwa_streams_watersheds_lut) AS lut_rows,
         (SELECT count(*) FROM whse_basemapping.fwa_watersheds_upstream_area) AS upstream_area_rows,
         (SELECT count(*) FROM whse_basemapping.fwa_stream_networks_mean_annual_precip) AS precip_rows")
fwapg_state[] <- lapply(fwapg_state, as.numeric)
message("Reading link run ", run$run_id, " (", run$run_label, ", ", run$config_name,
        " config, link ", run$link_version, ", ", format(run$date_end, "%Y-%m-%d"),
        "), recomputed by ", rc$recompute_id, " (link ", substr(rc$link_sha, 1, 7), ")")

message("Fetching ", wsg, " watershed group boundary ...")

aoi <- sf::st_read(
  conn,
  query = sprintf(
    "SELECT watershed_group_code, watershed_group_name, area_ha, geom
     FROM whse_basemapping.fwa_watershed_groups_poly
     WHERE watershed_group_code = '%s'",
    wsg
  ),
  quiet = TRUE
)
write_layer(aoi, "aoi")
message(sprintf("  area: %.0f km²", aoi$area_ha[1] / 100))

# ---- 2. Streams: accessible, order 3+ -----------------------------------

message(sprintf("Fetching %s order %d+ streams accessible to %s from fresh_default ...",
                wsg, min_order, toupper(species)))
streams <- sf::st_read(
  conn,
  query = sprintf("
    SELECT s.id_segment, s.linear_feature_id, s.blue_line_key,
           s.waterbody_key, s.downstream_route_measure, ua.upstream_area_ha,
           p.map_upstream, s.channel_width, s.gnis_name, s.stream_order,
           s.gradient, mc.mapping_code_%1$s AS mapping_code,
           a.access_%1$s AS access, h.spawning, h.rearing,
           a.dam_dnstr_ind, s.watershed_group_code, s.geom
    FROM fresh_default.streams s
    JOIN fresh_default.streams_access a USING (id_segment, watershed_group_code)
    JOIN fresh_default.streams_habitat_%1$s h USING (id_segment, watershed_group_code)
    LEFT JOIN fresh_default.streams_mapping_code mc USING (id_segment, watershed_group_code)
    LEFT JOIN whse_basemapping.fwa_streams_watersheds_lut l
      ON l.linear_feature_id = s.linear_feature_id
    LEFT JOIN whse_basemapping.fwa_watersheds_upstream_area ua
      ON ua.watershed_feature_id = l.watershed_feature_id
    LEFT JOIN whse_basemapping.fwa_stream_networks_mean_annual_precip p
      ON p.wscode_ltree = s.wscode_ltree AND p.localcode_ltree = s.localcode_ltree
    WHERE s.watershed_group_code = '%2$s'
      AND a.access_%1$s IN (1, 2)
      AND s.stream_order >= %3$d
    ORDER BY s.blue_line_key, s.downstream_route_measure", species, wsg, min_order),
  quiet = TRUE
)
stopifnot(!anyDuplicated(streams$id_segment))
streams <- sf::st_zm(streams)
# link stores single-part MULTILINESTRINGs; write them as LINESTRING like the
# bundled test streams.
if (all(lengths(sf::st_geometry(streams)) == 1L)) {
  streams <- sf::st_cast(streams, "LINESTRING", warn = FALSE)
}
write_layer(streams, "streams")
message(sprintf("  %d segments (modelled: %d, observed: %d)",
                nrow(streams),
                sum(streams$access == 1L, na.rm = TRUE),
                sum(streams$access == 2L, na.rm = TRUE)))

# ---- 3. Waterbodies on the accessible network ---------------------------

wb_keys <- unique(streams$waterbody_key)
wb_keys <- wb_keys[!is.na(wb_keys) & wb_keys != 0]
message(sprintf("Fetching waterbodies on %d distinct waterbody_keys ...",
                length(wb_keys)))

if (length(wb_keys) > 0L) {
  keys_sql <- paste(wb_keys, collapse = ", ")
  lakes <- sf::st_read(
    conn,
    query = sprintf(
      "SELECT waterbody_key, geom FROM whse_basemapping.fwa_lakes_poly
       WHERE waterbody_key IN (%s)", keys_sql),
    quiet = TRUE
  )
  wetlands <- sf::st_read(
    conn,
    query = sprintf(
      "SELECT waterbody_key, geom FROM whse_basemapping.fwa_wetlands_poly
       WHERE waterbody_key IN (%s)", keys_sql),
    quiet = TRUE
  )
  lakes_min <- sf::st_sf(waterbody_type = rep("L", nrow(lakes)),
                         geom = sf::st_geometry(lakes))
  wetlands_min <- sf::st_sf(waterbody_type = rep("W", nrow(wetlands)),
                            geom = sf::st_geometry(wetlands))
  waterbodies <- rbind(lakes_min, wetlands_min)
  # Drop any non-polygon geoms (degenerate features in source data
  # occasionally come through as MULTILINESTRING and break terra::rasterize).
  keep <- sf::st_geometry_type(waterbodies) %in% c("POLYGON", "MULTIPOLYGON")
  if (any(!keep)) {
    message(sprintf("  dropping %d non-polygon waterbody geom(s)", sum(!keep)))
    waterbodies <- waterbodies[keep, ]
  }
  message(sprintf("  lakes: %d, wetlands: %d, total: %d",
                  nrow(lakes), nrow(wetlands), nrow(waterbodies)))
} else {
  waterbodies <- sf::st_sf(waterbody_type = character(0),
                           geom = sf::st_sfc(crs = sf::st_crs(streams)))
  message("  no waterbodies on streams")
}
waterbodies <- sf::st_zm(waterbodies)
write_layer(waterbodies, "waterbodies")

# ---- 4. Context layers (railways, roads, reserves, parks) --------------

# Spatial intersect with the WSG boundary. Each query becomes a layer in
# the multi-layer gpkg. Geometry-only attributes plus a name field where
# the source carries one. These tables are not in fwapg: read them from the
# shared database (PG_*_SHARE). A layer whose query fails (no connection, or a
# database without the table) is carried over from the previous gpkg, and
# `context_source` in <wsg>_meta.rds records, per layer, which it was.

aoi_wkt <- sf::st_as_text(sf::st_geometry(aoi))
intersect_clause <- function(geom_col = "geom") {
  sprintf("ST_Intersects(%s, ST_GeomFromText('%s', 3005))", geom_col, aoi_wkt)
}

context_sql <- c(
  railways = "SELECT track_name, geom FROM whse_basemapping.gba_railway_tracks_sp
              WHERE %s",
  roads = "SELECT transport_line_id, structured_name_1, transport_line_type_code,
                  highway_route_1, geom
           FROM whse_basemapping.transport_line
           WHERE %s",
  reserves = "SELECT english_name, band_name, geom
              FROM whse_admin_boundaries.adm_indian_reserves_bands_sp
              WHERE %s",
  parks = "SELECT protected_lands_name, protected_lands_designation, geom
           FROM whse_tantalis.ta_park_ecores_pa_svw
           WHERE %s"
)

# With every PG_*_SHARE variable empty, frs_db_conn() would fall through to
# the standard PG* database (fwapg), which has none of these tables.
e <- Sys.getenv
share <- c(dbname = e("PG_DB_SHARE"), host = e("PG_HOST_SHARE"),
           port = e("PG_PORT_SHARE"), user = e("PG_USER_SHARE"))
conn_ctx <- if (any(nzchar(share))) {
  try(do.call(fresh::frs_db_conn, c(as.list(share), password = e("PG_PASS_SHARE"))),
      silent = TRUE)
} else {
  structure("PG_*_SHARE variables are not set", class = "try-error")
}

message("Fetching context layers (railways, roads, reserves, parks) ...")
context_source <- character()
for (nm in context_names) {
  # A query error (not an empty result) is what sends a layer to the fallback.
  layer <- if (inherits(conn_ctx, "try-error")) conn_ctx else
    try(sf::st_read(conn_ctx, query = sprintf(context_sql[[nm]], intersect_clause()),
                    quiet = TRUE), silent = TRUE)
  if (!inherits(layer, "try-error")) {
    context_source[[nm]] <- "database"
    if (nrow(layer) == 0L) {
      message(sprintf("  %s: 0 features (skipping)", nm))
      next
    }
    write_layer(sf::st_zm(layer), nm)
    message(sprintf("  %s: %d features", nm, nrow(layer)))
  } else if (!is.null(carried[[nm]])) {
    context_source[[nm]] <- "carried"
    write_layer(carried[[nm]], nm)
    message(sprintf("  %s: %d features carried over from the previous %s (%s)",
                    nm, nrow(carried[[nm]]), gpkg_final, trimws(as.character(layer))))
  } else {
    stop("Could not fetch ", nm, " and the previous ", gpkg_final, " has no such layer ",
         "to carry over: ", trimws(as.character(layer)), call. = FALSE)
  }
}
if (!inherits(conn_ctx, "try-error")) DBI::dbDisconnect(conn_ctx)

# Named streams come pre-filtered by watershed_group_code — no spatial join.
named_streams <- sf::st_read(conn, query = sprintf(
  "SELECT gnis_name, blue_line_key, stream_order, geom
     FROM whse_basemapping.fwa_named_streams
    WHERE watershed_group_code = '%s'", wsg), quiet = TRUE)
if (nrow(named_streams) > 0L) write_layer(sf::st_zm(named_streams), "named_streams")
message(sprintf("  named streams: %d features", nrow(named_streams)))

# Cache the link run the streams came from, so the vignette can state the
# data's source without a DB connection at render time.
meta <- list(link_run_id     = run$run_id,
       link_run_uid    = run$run_uid,
       link_run_label  = run$run_label,
       link_config     = run$config_name,
       link_config_hash = run$config_hash,
       link_version    = run$link_version,
       link_sha        = run$link_sha,
       link_dirty      = run$link_dirty,
       link_run_date   = format(run$date_end, "%Y-%m-%d"),
       # access and mapping codes were rewritten by this recompute; spawning and
       # rearing are the modelling run's (link_sha)
       link_recompute_id  = rc$recompute_id,
       link_recompute_sha = rc$link_sha,
       link_recompute_date = format(rc$date_end, "%Y-%m-%d"),
       fresh_version   = run$fresh_version,
       fresh_dirty     = run$fresh_dirty,
       crate_version   = run$crate_version,
       fwapg_sha       = run$fwapg_sha,   # as recorded by the link run
       # row counts of the fwapg tables upstream area and precipitation were
       # joined from, when this script read them
       fwapg_read      = cbind(fwapg_state, read_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")),
       n_upstream_area_na = sum(is.na(streams$upstream_area_ha)),
       species         = toupper(species),
       # per context layer, "database": fetched from the shared database
       # (PG_*_SHARE) in this run; "carried": copied from the previous <wsg>.gpkg.
       # context_carried_from: per carried layer, the commit ("<sha> <date>")
       # whose gpkg last fetched it from the database, NA where unknown
       context_source  = context_source,
       context_carried_from = carried_from[names(context_source)[context_source == "carried"]])

DBI::dbDisconnect(conn)

# ---- 5. MRDEM-30 clip via fl_dem_aoi() ----------------------------------

message("Fetching MRDEM-30 clip (heaviest network step) ...")
dem <- fl_dem_aoi(streams, buffer = 2000)
terra::writeRaster(
  terra::as.int(dem), out("dem.tif"),
  overwrite = TRUE,
  datatype = "INT2S",
  gdal = c("COMPRESS=DEFLATE", "PREDICTOR=2", "TILED=YES")
)
message(sprintf("  %d x %d cells (%.1f Mcells)",
                ncol(dem), nrow(dem),
                ncol(dem) * nrow(dem) / 1e6))

# ---- 6. Run flooded VCA pipeline ----------------------------------------

message("Running fl_valley_confine() with waterbodies ...")
terra::terraOptions(threads = max(1L, parallel::detectCores() - 2L))

valleys <- fl_valley_confine(
  dem = dem,
  streams = streams,
  area_field = "upstream_area_ha",
  precip = fl_stream_rasterize(streams, dem, field = "map_upstream"),
  waterbodies = waterbodies,
  flood_factor = 4   # ff04 — functional floodplain (recurrent inundation)
)
terra::writeRaster(
  valleys, out("valleys.tif"),
  overwrite = TRUE,
  datatype = "INT1U",
  gdal = c("COMPRESS=DEFLATE", "TILED=YES")
)

message("Polygonizing valleys ...")
floodplain <- fl_valley_poly(valleys)
write_layer(floodplain, "floodplain")

# Replace the previous gpkg only if no layer it had has gone missing, then
# record the run. Copy beside the target first (the tempfile may be on another
# volume) and rename into place, so the target is never left half-written.
lost <- setdiff(prev_layers, sf::st_layers(gpkg)$name)
if (length(lost) > 0L) {
  # The tempfile goes when R exits; keep the new file outside the package
  # (the parent of the session tempdir outlives it) so nothing stray ships.
  kept <- file.path(dirname(tempdir()), paste0(stub, "_rejected.gpkg"))
  saved <- file.copy(gpkg, kept, overwrite = TRUE)
  stop("The new ", gpkg_final, " would lose layer(s) ", paste(lost, collapse = ", "),
       "; the previous file is unchanged",
       if (saved) paste0(" and the new one is at ", kept) else " and the new one could not be kept",
       call. = FALSE)
}
partial <- paste0(gpkg_final, ".partial")
if (!file.copy(gpkg, partial, overwrite = TRUE) || !file.rename(partial, gpkg_final)) {
  unlink(partial)
  stop("Could not move the new gpkg into place; ", gpkg_final, " is unchanged.", call. = FALSE)
}
unlink(gpkg)
gpkg <- gpkg_final
saveRDS(meta, meta_path)

# ---- 7. Report cache size -----------------------------------------------

cache_files <- c(gpkg, list.files(out_dir,
                                  pattern = paste0("^", stub, "_.*\\.tif$"),
                                  full.names = TRUE))
cache_sizes <- file.info(cache_files)$size
total_mb <- sum(cache_sizes) / 1024^2
message(sprintf("Cache for %s total: %.1f MB across %d files",
                wsg, total_mb, length(cache_files)))
for (i in seq_along(cache_files)) {
  message(sprintf("  %-40s %.2f MB", basename(cache_files[i]),
                  cache_sizes[i] / 1024^2))
}
message(sprintf("  gpkg layers: %s",
                paste(sf::st_layers(gpkg)$name, collapse = ", ")))
