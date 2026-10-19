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
#   <wsg>_dem.tif           MRDEM-30 clip cropped to streams + 2 km buffer,
#                           truncated to whole metres (the model runs on the
#                           unrounded values)
#   <wsg>_valleys.tif       fl_valley_confine() binary output (1=valley)
#   <wsg>_meta.rds          the link run, where the context layers came from,
#                           the arguments and floodplain cells at each flood
#                           factor, a digest of the rows of every query whose
#                           rows are written to the gpkg, the MRDEM-30 ETag,
#                           the md5 of every file written, and the software
#                           (release, commit, concept DOI) the build rests on
#
# tests/testthat/test-vignette_data.R fails when a written file, an fwapg query
# or the MRDEM-30 file no longer matches what is recorded here, so the article
# cannot go on quoting a superseded run. Context layers read from the shared
# database are digested but not checked. Run this from a committed tree: the commit it
# records is the article's citation of flooded.
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
flood_factor <- 4                   # written as <wsg>_valleys.tif
flood_factors_also <- c(2, 6, 7)    # areas only, for the article's flood-level passage
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

# git output, or NA when git fails
git_out <- function(args) {
  x <- suppressWarnings(system2("git", args, stdout = TRUE))
  if (!is.null(attr(x, "status"))) NA_character_ else x
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
  # The previous meta describes the previous gpkg only when both are the
  # committed copies of one commit; otherwise record no origin.
  clean <- identical(git_out(c("status", "--porcelain", "--", gpkg_final, meta_path)), character(0))
  commit <- git_out(c("log", "-1", shQuote("--format=%h %cs"), "--", gpkg_final))
  same <- identical(commit, git_out(c("log", "-1", shQuote("--format=%h %cs"), "--", meta_path)))
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

# The software this build is: flooded's commit, and whether the code the run
# loads differs from it. Checked before anything is written.
flooded_sha <- git_out(c("rev-parse", "HEAD"))
flooded_dirty <- length(git_out(c("status", "--porcelain", "--", "R", "DESCRIPTION", "inst/extdata",
                                  "data-raw/wsg_vignette_data.R"))) > 0L
flooded_tag <- git_out(c("describe", "--tags", "--abbrev=0", "--match", shQuote("v[0-9]*.[0-9]*.[0-9]*"), "HEAD"))
if (is.na(flooded_sha)) stop("Not in flooded's git checkout; run from the package root.", call. = FALSE)
if (flooded_dirty) message("NOTE: R/, DESCRIPTION, inst/extdata or this script differ from ", substr(flooded_sha, 1, 7),
                           "; meta records the build as dirty.")

# Every query whose rows end up in the bundle is recorded with a digest of
# those rows, computed by Postgres, so a later test can ask whether the
# database still holds the same thing.
sources <- data.frame(name = character(), db = character(), sql = character(), digest = character())
digest_sql <- function(sql) {
  sprintf("SELECT md5(string_agg(md5(t::text), '' ORDER BY md5(t::text))) AS d FROM (%s) t", sql)
}
# Rows and digest come from one snapshot. `sql_record` is what meta keeps,
# when the SQL itself is too long to be worth storing.
read_source <- function(con, name, db, sql, sql_record = sql) {
  DBI::dbBegin(con)
  ok <- FALSE
  on.exit(if (!ok) DBI::dbRollback(con))
  DBI::dbExecute(con, "SET TRANSACTION ISOLATION LEVEL REPEATABLE READ")
  x <- sf::st_read(con, query = sql, quiet = TRUE)
  d <- DBI::dbGetQuery(con, digest_sql(sql))$d
  DBI::dbCommit(con)
  ok <- TRUE
  sources[nrow(sources) + 1L, ] <<- list(name, db, sql_record, if (is.na(d)) "empty" else d)
  x
}

# JSON from a web API, with the HTTP status checked
get_json <- function(url) {
  h <- curl::new_handle(useragent = "flooded data-raw (https://github.com/NewGraphEnvironment/flooded)")
  r <- curl::curl_fetch_memory(url, handle = h)
  if (r$status_code != 200L) stop("HTTP ", r$status_code, " from ", url, call. = FALSE)
  jsonlite::fromJSON(rawToChar(r$content), simplifyVector = FALSE)
}

# ---- 1. WSG boundary ----------------------------------------------------

conn <- fresh::frs_db_conn()

if (is.na(DBI::dbGetQuery(conn, "SELECT to_regclass('fresh_default.log') AS t")$t)) {
  stop("Database '", DBI::dbGetQuery(conn, "SELECT current_database()")[[1]],
       "' has no fresh_default schema; point the PG* variables at the database link ",
       "persists to.", call. = FALSE)
}
run <- DBI::dbGetQuery(conn, sprintf(
  "SELECT run_id, run_uid, run_label, date_end, config_name, config_hash, link_version, fresh_sha,
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
  "SELECT recompute_id, date_start, date_end, link_version, link_sha, link_dirty
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

aoi <- read_source(conn, "aoi", "fwapg", sprintf(
  "SELECT watershed_group_code, watershed_group_name, area_ha, geom
     FROM whse_basemapping.fwa_watershed_groups_poly
     WHERE watershed_group_code = '%s'", wsg))
write_layer(aoi, "aoi")
message(sprintf("  area: %.0f km²", aoi$area_ha[1] / 100))

# ---- 2. Streams: accessible, order 3+ -----------------------------------

message(sprintf("Fetching %s order %d+ streams accessible to %s from fresh_default ...",
                wsg, min_order, toupper(species)))
streams <- read_source(conn, "streams", "fwapg", sprintf("
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
    ORDER BY s.blue_line_key, s.downstream_route_measure", species, wsg, min_order))
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
  lakes <- read_source(conn, "lakes", "fwapg", sprintf(
    "SELECT waterbody_key, geom FROM whse_basemapping.fwa_lakes_poly
      WHERE waterbody_key IN (%s)", keys_sql))
  wetlands <- read_source(conn, "wetlands", "fwapg", sprintf(
    "SELECT waterbody_key, geom FROM whse_basemapping.fwa_wetlands_poly
      WHERE waterbody_key IN (%s)", keys_sql))
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
    try(read_source(conn_ctx, nm, "share", sprintf(context_sql[[nm]], intersect_clause()),
                    sql_record = sprintf(context_sql[[nm]], "<intersects the aoi layer's geometry>")),
        silent = TRUE)
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
named_streams <- read_source(conn, "named_streams", "fwapg", sprintf(
  "SELECT gnis_name, blue_line_key, stream_order, geom
     FROM whse_basemapping.fwa_named_streams
    WHERE watershed_group_code = '%s'", wsg))
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

# ---- 4b. Software the build rests on, and how to cite it ------------------

# Each package is cited by its last release at or before the build, its concept
# DOI where Zenodo archives one, and the commit the build used. link's and
# fresh's versions are the ones the link run recorded; the GitHub compare API
# confirms that each version's tag is at or before the commits, and the next tag
# is not. flooded's is the last local version tag before HEAD. fwapg is an
# external tool, cited by the commit link's run recorded.
tag_at_or_before <- function(repo, tag, sha) {
  st <- get_json(sprintf("https://api.github.com/repos/%s/compare/%s...%s", repo, tag, sha))$status
  st %in% c("ahead", "identical")
}
repo_tags <- function(repo) {
  out <- character()
  for (page in 1:50) {
    x <- get_json(sprintf("https://api.github.com/repos/%s/tags?per_page=100&page=%d", repo, page))
    if (length(x) == 0L) return(grep("^v[0-9]+\\.[0-9]+\\.[0-9]+$", out, value = TRUE))
    out <- c(out, vapply(x, function(t) t$name, character(1)))
  }
  stop("more than 5,000 tags in ", repo, call. = FALSE)
}
last_release <- function(repo, version, shas) {
  tag <- paste0("v", version)
  tags <- repo_tags(repo)
  later <- tags[package_version(sub("^v", "", tags)) > package_version(version)]
  next_tag <- if (length(later)) later[order(package_version(sub("^v", "", later)))][1] else NA
  for (sha in shas) {
    if (!tag_at_or_before(repo, tag, sha)) stop(repo, " ", tag, " is not at or before ", sha, call. = FALSE)
    if (!is.na(next_tag) && tag_at_or_before(repo, next_tag, sha)) {
      stop(repo, " ", next_tag, " is also at or before ", sha, ", so ", tag, " is not its last release",
           call. = FALSE)
    }
  }
  tag
}
link_tag <- last_release("NewGraphEnvironment/link", run$link_version, c(run$link_sha, rc$link_sha))
fresh_tag <- last_release("NewGraphEnvironment/fresh", run$fresh_version, run$fresh_sha)
software <- data.frame(
  package = c("flooded", "link", "fresh", "fwapg"),
  url = c("https://www.newgraphenvironment.com/flooded/", "https://www.newgraphenvironment.com/link/",
          "https://www.newgraphenvironment.com/fresh/", "https://smnorris.github.io/fwapg/"),
  release = c(flooded_tag, link_tag, fresh_tag, NA),
  # commits link at: github.com/<repo>/commit/<commit>
  repo = c("NewGraphEnvironment/flooded", "NewGraphEnvironment/link", "NewGraphEnvironment/fresh",
           "NewGraphEnvironment/fwapg"),
  commit = c(flooded_sha, run$link_sha, run$fresh_sha, run$fwapg_sha),
  # link's access and mapping codes come from its recompute, at a later commit
  commit_also = c(NA, rc$link_sha, NA, NA),
  version = c(as.character(utils::packageVersion("flooded")), run$link_version, run$fresh_version, NA),
  dirty = c(flooded_dirty, run$link_dirty, NA, NA),
  dirty_also = c(NA, rc$link_dirty, NA, NA)
)

# Concept DOIs. Zenodo registers each release's DOI with DataCite, and a
# version record's IsVersionOf relation names its concept DOI.
doi_url <- paste0("https://api.datacite.org/dois?query=%22New%20Graph%20Environment%22%20OR%20",
                  "NewGraphEnvironment&client-id=cern.zenodo&page%5Bsize%5D=500")
recs <- get_json(doi_url)$data
concept_of <- function(pkg) {
  hit <- Filter(function(r) {
    t <- r$attributes$titles
    length(t) > 0L && grepl(sprintf("^(NewGraphEnvironment/)?%s:", pkg), t[[1]]$title)
  }, recs)
  rel <- unlist(lapply(hit, function(r) {
    vapply(Filter(function(x) identical(x$relationType, "IsVersionOf"), r$attributes$relatedIdentifiers),
           function(x) x$relatedIdentifier, character(1))
  }))
  unique(rel)
}
# the earliest release each concept DOI holds a version of
first_archived <- function(pkg) {
  v <- unlist(lapply(recs, function(r) {
    t <- r$attributes$titles
    if (length(t) > 0L && grepl(sprintf("^(NewGraphEnvironment/)?%s:", pkg), t[[1]]$title)) r$attributes$version
  }))
  v <- grep("^v?[0-9]+\\.[0-9]+\\.[0-9]+$", v, value = TRUE)
  paste0("v", min(package_version(sub("^v", "", v))))
}
software$concept_doi <- NA_character_
software$doi_from <- NA_character_
for (pkg in c("flooded", "link")) {
  d <- concept_of(pkg)
  if (length(d) != 1L) stop("DataCite gives ", length(d), " concept DOIs for ", pkg, call. = FALSE)
  software$concept_doi[software$package == pkg] <- d
  software$doi_from[software$package == pkg] <- first_archived(pkg)
}
dois <- list(source = doi_url, retrieved = format(Sys.Date()))

# ---- 5. MRDEM-30 clip via fl_dem_aoi() ----------------------------------

message("Fetching MRDEM-30 clip (heaviest network step) ...")
# fl_dem_aoi()'s default source; its ETag changes whenever the file does
dem_url <- "https://canelevation-dem.s3.ca-central-1.amazonaws.com/mrdem-30/mrdem-30-dtm.tif"
hd <- curl::curl_fetch_memory(dem_url, handle = curl::new_handle(nobody = TRUE))
if (hd$status_code != 200L) stop("HTTP ", hd$status_code, " from ", dem_url, call. = FALSE)
hdr <- curl::parse_headers_list(hd$headers)
dem_source <- list(url = dem_url, etag = hdr[["etag"]], last_modified = hdr[["last-modified"]])
dem <- fl_dem_aoi(streams, source = paste0("/vsicurl/", dem_url), buffer = 2000)
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

# Every criterion at its package default (fl_params()), except the flood
# factor. Recorded so the article states the values the run used.
p <- fl_params()
vca_args <- stats::setNames(as.list(p$default), p$parameter)
vca_args$flood_factor <- flood_factor
precip <- fl_stream_rasterize(streams, dem, field = "map_upstream")
run_vca <- function(ff) {
  do.call(fl_valley_confine, c(list(dem = dem, streams = streams, area_field = "upstream_area_ha",
                                    precip = precip, waterbodies = waterbodies),
                               utils::modifyList(vca_args, list(flood_factor = ff))))
}
# Floodplain inside the watershed group boundary, measured as the article
# measures it: valley cells after cropping and masking to the boundary.
in_aoi_cells <- function(v) {
  v <- terra::mask(terra::crop(v, terra::vect(aoi)), terra::vect(aoi))
  as.integer(sum(terra::values(v) == 1L, na.rm = TRUE))
}
vca_seconds <- system.time(valleys <- run_vca(flood_factor))[["elapsed"]]
fp_cells <- stats::setNames(in_aoi_cells(valleys), flood_factor)
for (ff in flood_factors_also) {
  message("  and at flood factor ", ff, " (area only) ...")
  fp_cells[[as.character(ff)]] <- in_aoi_cells(run_vca(ff))
}
fp_cells <- fp_cells[order(as.numeric(names(fp_cells)))]
fp_area_ha <- fp_cells * prod(terra::res(valleys)) / 1e4
message("  floodplain inside ", wsg, " (ha) by flood factor: ",
        paste(names(fp_area_ha), round(fp_area_ha, 1), sep = " = ", collapse = ", "))
cpu <- tryCatch(system2("sysctl", c("-n", "machdep.cpu.brand_string"), stdout = TRUE),
                error = function(e) NA_character_, warning = function(w) NA_character_)
if (length(cpu) != 1L || is.na(cpu)) cpu <- unname(Sys.info()[["machine"]])
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

# What the article states, and what the test checks the bundle against.
written <- c(gpkg, out("dem.tif"), out("valleys.tif"))
meta <- c(meta, list(
  vca_args = vca_args,                 # flood_factor plus every other criterion at its default
  fp_cells = fp_cells,                 # floodplain cells inside the boundary, by flood factor
  fp_area_ha = fp_area_ha,             # the same, in hectares
  vca_seconds = unname(vca_seconds),   # fl_valley_confine() at flood_factor, one run
  vca_threads = terra::terraOptions(print = FALSE)$threads,
  cpu = cpu,
  sources = sources,                   # every query whose rows reach the gpkg: SQL and a digest of its rows
  dem_source = dem_source,
  md5_files = stats::setNames(unname(tools::md5sum(written)), basename(written)),
  software = software,
  dois = dois,
  built = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
))
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
