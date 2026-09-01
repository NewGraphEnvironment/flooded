# Pre-compute heavy data for the WSG floodplain showcase vignette.
#
# Generic — runs for any BC watershed group. Set `wsg` and `species_view`
# below.
#
# Generates (under inst/vignette-data/, namespaced by WSG code):
#   <wsg>.gpkg              multi-layer GeoPackage with the sf layers:
#                             aoi, streams, waterbodies, floodplain,
#                             railways, roads, reserves, parks,
#                             named_streams
#   <wsg>_dem.tif           MRDEM-30 clip cropped to streams + 2 km buffer
#   <wsg>_valleys.tif       fl_valley_confine() binary output (1=valley)
#
# Bundling the sf layers into a single multi-layer gpkg matches how QGIS
# expects a per-WSG project bundle and keeps the cache to three files per
# WSG. Rasters stay separate (terra writes COG/GeoTIFF, not into gpkg).
#
# Streams come from `bcfishpass.streams_bt_vw` (bull trout accessible
# network — every row has `access IN (1, 2)` by construction). Filtering
# to `access IN (1, 2) AND stream_order >= min_order` plus the
# `watershed_group_code` filter gives "best accessible habitat order 3+"
# without needing a working-table classification pipeline.
#
# Waterbodies (lakes + wetlands) are picked up via `waterbody_key`
# linkage from the filtered stream list — only those physically anchored
# to the network are included. They feed `fl_valley_confine(waterbodies =)`
# so the final valley raster fills lake / wetland cells the gradient and
# cost-distance masks would otherwise carve donut holes around.
#
# To swap species: change `species_view` to e.g. `"streams_co_vw"` for
# coho or `"streams_st_vw"` for steelhead — same column shape (`access`,
# `spawning`, `rearing`).
#
# Prerequisites:
#   - SSH tunnel to fwapg PostgreSQL up; PG_*_SHARE env vars set
#     (defaults of fresh::frs_db_conn())
#   - Outbound HTTPS to s3.ca-central-1.amazonaws.com for MRDEM /vsicurl/
#   - Run from package root so devtools::load_all() finds dev fl_dem_aoi()

# ---- params -------------------------------------------------------------

wsg <- "PARS"                       # any 4-letter BC watershed group code
species_view <- "streams_bt_vw"     # bcfishpass species-accessible view
min_order <- 3                      # minimum stream order to keep

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

# Single multi-layer GeoPackage for all sf layers. Wipe at the start of
# each run so we never carry stale layers across re-runs.
gpkg <- file.path(out_dir, paste0(stub, ".gpkg"))
if (file.exists(gpkg)) file.remove(gpkg)

write_layer <- function(x, layer) {
  sf::st_write(x, gpkg, layer = layer, delete_layer = TRUE,
               append = TRUE, quiet = TRUE)
}

# ---- 1. WSG boundary ----------------------------------------------------

message("Fetching ", wsg, " watershed group boundary ...")
conn <- fresh::frs_db_conn()
on.exit(try(DBI::dbDisconnect(conn), silent = TRUE), add = TRUE)

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

message(sprintf("Fetching %s accessible order %d+ streams from bcfishpass.%s ...",
                wsg, min_order, species_view))
streams <- sf::st_read(
  conn,
  query = sprintf("
    SELECT segmented_stream_id, linear_feature_id, blue_line_key,
           waterbody_key, downstream_route_measure, upstream_area_ha,
           map_upstream, channel_width, gnis_name, stream_order,
           gradient, mapping_code, access, spawning, rearing,
           dam_dnstr_ind, watershed_group_code, geom
    FROM bcfishpass.%s
    WHERE watershed_group_code = '%s'
      AND access IN (1, 2)
      AND stream_order >= %d", species_view, wsg, min_order),
  quiet = TRUE
)
streams <- sf::st_zm(streams)
write_layer(streams, "streams")
message(sprintf("  %d segments (assessed: %d, modelled: %d)",
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
# the source carries one.

fetch_layer <- function(query_sql, layer_name, label) {
  layer <- try(sf::st_read(conn, query = query_sql, quiet = TRUE),
               silent = TRUE)
  if (inherits(layer, "try-error") || nrow(layer) == 0L) {
    message(sprintf("  %s: 0 features (skipping)", label))
    return(invisible(NULL))
  }
  layer <- sf::st_zm(layer)
  write_layer(layer, layer_name)
  message(sprintf("  %s: %d features", label, nrow(layer)))
}

aoi_wkt <- sf::st_as_text(sf::st_geometry(aoi))
intersect_clause <- function(geom_col = "geom") {
  sprintf("ST_Intersects(%s, ST_GeomFromText('%s', 3005))", geom_col, aoi_wkt)
}

message("Fetching context layers (railways, roads, reserves, parks) ...")

fetch_layer(
  sprintf("SELECT track_name, geom FROM whse_basemapping.gba_railway_tracks_sp
           WHERE %s", intersect_clause()),
  "railways", "railways")

fetch_layer(
  sprintf("SELECT transport_line_id, structured_name_1, transport_line_type_code,
                  highway_route_1, geom
           FROM whse_basemapping.transport_line
           WHERE %s", intersect_clause()),
  "roads", "roads")

fetch_layer(
  sprintf("SELECT english_name, band_name, geom
           FROM whse_admin_boundaries.adm_indian_reserves_bands_sp
           WHERE %s", intersect_clause()),
  "reserves", "First Nations reserves")

fetch_layer(
  sprintf("SELECT protected_lands_name, protected_lands_designation, geom
           FROM whse_tantalis.ta_park_ecores_pa_svw
           WHERE %s", intersect_clause()),
  "parks", "parks / protected")

# Named streams come pre-filtered by watershed_group_code — no spatial join.
fetch_layer(
  sprintf("SELECT gnis_name, blue_line_key, stream_order, geom
           FROM whse_basemapping.fwa_named_streams
           WHERE watershed_group_code = '%s'", wsg),
  "named_streams", "named streams")

# Cache the bcfishpass model version + date so the vignette can stamp
# data provenance without needing a DB connection at render time.
message("Caching bcfishpass version stamp ...")
bp_log <- DBI::dbGetQuery(conn, "
  SELECT model_version, date_completed
  FROM bcfishpass.log
  WHERE model_type = 'LINEAR'
  ORDER BY date_completed DESC LIMIT 1")
saveRDS(
  list(bcfishpass_version = bp_log$model_version,
       bcfishpass_date    = format(bp_log$date_completed, "%Y-%m-%d")),
  file.path(out_dir, paste0(stub, "_meta.rds"))
)

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
