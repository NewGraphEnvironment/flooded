#!/usr/bin/env Rscript
#
# network_extract.R
#
# Documents how inst/testdata/streams.gpkg and waterbodies.gpkg were created.
# The outputs are committed to the package so this script does NOT need to be
# run by package users.
#
# Extracts coho-accessible streams (order 4+) between two points on a mainstem
# using fresh::frs_network() with network subtraction, from the tables link
# builds with its `default` config (schema `fresh_default`). Lakes and wetlands
# are clipped to DEM extent.
#
# The order 4+ filter focuses on streams most relevant to restoration planning
# and higher-value salmon habitat. It also constrains the floodplain AOI for
# practical applications like orthophoto acquisition and review. All watershed
# tributaries contribute to floodplain health, but the vignette demonstrates
# the pipeline on the mainstem corridor where investment has the most impact.
#
# Sources:
#   - geometry, channel width, access, habitat, mapping code: link's
#     `fresh_default` tables, from the BULK run recorded in fresh_default.log
#   - upstream area and mean annual precipitation upstream (ClimateBC): fwapg's
#     fwa_watersheds_upstream_area and fwa_stream_networks_mean_annual_precip,
#     joined the way fresh::frs_col_join() documents
#   - lakes and wetlands: the Freshwater Atlas in fwapg
#
# Requires:
#   - the PostgreSQL database link persists to (fwapg with `fresh_default`),
#     reached by fresh::frs_db_conn() through the standard PG* variables
#   - BULK modelled into `fresh_default` by link, in the run named by `run_id`
#     below. `fresh_default` holds one provincial run at a time and the next
#     one overwrites it, so the script stops if the run there is not this one;
#     update `run_id` deliberately when rebuilding from a newer run.
#   - R packages: fresh, sf, terra, DBI

library(fresh)
library(sf)
library(terra)

# --- Boundary points on Bulkley mainstem ---
wsg <- "BULK"
blk <- 360873822
mouth_drm <- 216733
cutoff_drm <- 222000
run_id <- "cypherjob3-20261017T034609.698-65b431"   # fresh_default.log, BULK
recompute_id <- "m1-20261017T071424.051-24a90b"   # fresh_default.log_recompute, BULK
# inst/NOTICE.md names these runs and their link version: change them together.

# --- DEM extent for clipping ---
dem <- terra::rast(here::here("inst", "testdata", "dem.tif"))
dem_bbox <- sf::st_as_sfc(sf::st_bbox(dem))

conn <- frs_db_conn()

# --- The link run this reads ---
if (is.na(DBI::dbGetQuery(conn, "SELECT to_regclass('fresh_default.log') AS t")$t)) {
  stop("Database '", DBI::dbGetQuery(conn, "SELECT current_database()")[[1]],
       "' has no fresh_default schema; point the PG* variables at the database link ",
       "persists to.", call. = FALSE)
}
run <- DBI::dbGetQuery(conn, sprintf(
  "SELECT run_id, run_uid, run_label, date_end, config_name, link_version, link_sha,
          fresh_version, fwapg_sha
     FROM fresh_default.log
    WHERE watershed_group_code = %s
    ORDER BY date_end DESC LIMIT 1",
  DBI::dbQuoteLiteral(conn, wsg)
))
n_seg <- DBI::dbGetQuery(conn, sprintf(
  "SELECT count(*)::int AS n FROM fresh_default.streams_access WHERE watershed_group_code = %s",
  DBI::dbQuoteLiteral(conn, wsg)
))$n
if (nrow(run) == 0L || n_seg == 0L) {
  stop(wsg, " is not modelled in `fresh_default`; run link's default config for it first.",
       call. = FALSE)
}
if (!identical(run$run_id, run_id)) {
  stop("fresh_default holds ", wsg, " run ", run$run_id, ", not ", run_id,
       ". Update `run_id` if rebuilding from the newer run is intended.", call. = FALSE)
}
rc <- DBI::dbGetQuery(conn, sprintf(
  "SELECT recompute_id, date_end, link_version, link_sha
     FROM fresh_default.log_recompute
    WHERE watershed_group_code = %s
    ORDER BY date_start DESC LIMIT 1", DBI::dbQuoteLiteral(conn, wsg)))
if (!identical(rc$recompute_id, recompute_id) || anyNA(rc$date_end)) {
  stop("fresh_default's latest ", wsg, " recompute is ",
       if (nrow(rc)) paste0(rc$recompute_id, if (anyNA(rc$date_end)) " (unfinished)") else "none",
       ", not ", recompute_id, ". Access and mapping codes come from it: update ",
       "`recompute_id` if rebuilding from it is intended.", call. = FALSE)
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
message("fwapg tables read: ", paste(names(fwapg_state), unlist(fwapg_state), sep = " ", collapse = ", "))

# --- Network between the two points, plus waterbodies ---
# frs_clip() doesn't handle XYM/XYZM geometries yet so we clip manually
# after st_zm(). TODO: fix in fresh, then use clip param directly.
message("Querying order 4+ streams and waterbodies between drm ", mouth_drm,
        " and ", cutoff_drm, " on blk ", blk, "...")

results <- frs_network(
  conn,
  blue_line_key = blk,
  downstream_route_measure = mouth_drm,
  upstream_measure = cutoff_drm,
  tables = list(
    streams = list(
      table = "fresh_default.streams",
      cols = c("id_segment", "watershed_group_code", "geom"),
      wscode_col = "wscode_ltree",
      localcode_col = "localcode_ltree",
      extra_where = "stream_order >= 4"
    ),
    lakes = "whse_basemapping.fwa_lakes_poly",
    wetlands = "whse_basemapping.fwa_wetlands_poly"
  )
) |>
  lapply(sf::st_zm, drop = TRUE)

# --- Attributes by id_segment: link's model plus fwapg's upstream area and precipitation ---
ids <- results$streams$id_segment
attrs <- DBI::dbGetQuery(conn, sprintf(
  "SELECT s.id_segment, s.linear_feature_id, s.blue_line_key, s.waterbody_key,
          s.downstream_route_measure, ua.upstream_area_ha, p.map_upstream,
          s.gnis_name, s.stream_order, s.channel_width,
          mc.mapping_code_co AS mapping_code,
          a.access_co AS access, h.spawning, h.rearing, s.watershed_group_code
     FROM fresh_default.streams s
     JOIN fresh_default.streams_access a USING (id_segment, watershed_group_code)
     JOIN fresh_default.streams_habitat_co h USING (id_segment, watershed_group_code)
     LEFT JOIN fresh_default.streams_mapping_code mc USING (id_segment, watershed_group_code)
     LEFT JOIN whse_basemapping.fwa_streams_watersheds_lut l
       ON l.linear_feature_id = s.linear_feature_id
     LEFT JOIN whse_basemapping.fwa_watersheds_upstream_area ua
       ON ua.watershed_feature_id = l.watershed_feature_id
     LEFT JOIN whse_basemapping.fwa_stream_networks_mean_annual_precip p
       ON p.wscode_ltree = s.wscode_ltree AND p.localcode_ltree = s.localcode_ltree
    WHERE s.watershed_group_code = %s
      AND s.id_segment IN (%s)",
  DBI::dbQuoteLiteral(conn, wsg), paste(ids, collapse = ", ")
))
DBI::dbDisconnect(conn)
stopifnot(!anyDuplicated(attrs$id_segment), setequal(attrs$id_segment, ids))

# Coho-accessible (1 = modelled, 2 = observed), as link codes access.
streams <- merge(results$streams[, c("id_segment", "geom")], attrs, by = "id_segment")
streams <- streams[streams$access %in% c(1L, 2L), ]
streams <- streams[order(streams$blue_line_key, streams$downstream_route_measure),
                   c(names(attrs), "geom")]
sf::st_geometry(streams) <- "geom"

# Clip to DEM extent
results <- lapply(list(streams = streams, lakes = results$lakes, wetlands = results$wetlands),
                  function(x) if (inherits(x, "sf") && nrow(x) > 0L) frs_clip(x, dem_bbox) else x)

streams <- results$streams
lakes <- results$lakes
wetlands <- results$wetlands
rownames(streams) <- NULL

message("  Streams: ", nrow(streams), " segments")
message("  Orders: ", paste(sort(unique(streams$stream_order)), collapse = ", "))
message("  Lakes: ", nrow(lakes))
message("  Wetlands: ", nrow(wetlands))

# --- Write streams ---
out_path <- here::here("inst", "testdata", "streams.gpkg")
sf::st_write(streams, out_path, layer = "streams", delete_dsn = TRUE, quiet = TRUE)
message("Saved: ", out_path)

# --- Combine waterbodies ---
waterbodies <- rbind(
  lakes[, c("waterbody_key", "waterbody_type", "area_ha", "geom")],
  wetlands[, c("waterbody_key", "waterbody_type", "area_ha", "geom")]
)

wb_path <- here::here("inst", "testdata", "waterbodies.gpkg")
sf::st_write(waterbodies, wb_path, delete_dsn = TRUE, quiet = TRUE)
message("Saved: ", wb_path, " (", nrow(waterbodies), " features)")
