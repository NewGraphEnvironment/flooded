# Pre-compute heavy data for the WSG floodplain showcase vignette.
#
# Generic — runs for any BC watershed group. Set `wsg` below.
#
# Generates (under inst/vignette-data/, namespaced by WSG code):
#   <wsg>_aoi.gpkg          watershed group boundary (sf POLYGON)
#   <wsg>_streams.gpkg      stream network, order 4+ (sf LINESTRING)
#   <wsg>_dem.tif           MRDEM-30 clip cropped to streams + 2 km buffer
#   <wsg>_valleys.tif       fl_valley_confine() binary output (1=valley)
#   <wsg>_floodplain.gpkg   floodplain polygon from fl_valley_poly()
#
# Run interactively when the upstream sources change. The vignette reads
# these via system.file(...) and renders without touching the network or
# database.
#
# Prerequisites:
#   - SSH tunnel to fwapg PostgreSQL up; PG_*_SHARE env vars set
#     (defaults of fresh::frs_db_conn())
#   - Outbound HTTPS to s3.ca-central-1.amazonaws.com for MRDEM /vsicurl/
#   - Run from the package root so devtools::load_all() picks up the dev
#     version of fl_dem_aoi() (not whatever's installed)

# ---- params -------------------------------------------------------------

wsg <- "PARS"   # any 4-letter BC watershed group code

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
out <- function(name) file.path(out_dir, paste0(stub, "_", name))

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
sf::st_write(aoi, out("aoi.gpkg"), delete_dsn = TRUE, quiet = TRUE)
message(sprintf("  area: %.0f km²", aoi$area_ha[1] / 100))

# ---- 2. Streams (order 4+) ----------------------------------------------

message("Fetching ", wsg, " streams (order 4+) ...")
# bcfishpass.streams_vw carries channel_width, upstream_area_ha, map_upstream —
# the attrs fl_valley_confine() / fl_flood_model() need. The bare FWA table
# (whse_basemapping.fwa_stream_networks_sp) doesn't have them.
streams <- fresh::frs_stream_fetch(
  conn,
  watershed_group_code = wsg,
  stream_order_min = 4,
  table = "bcfishpass.streams_vw",
  cols = c(
    "segmented_stream_id", "blue_line_key", "waterbody_key",
    "downstream_route_measure", "upstream_area_ha", "map_upstream",
    "channel_width", "gnis_name", "stream_order", "gradient",
    "watershed_group_code", "geom"
  )
)
# fwapg streams carry XYZM (route measures live in M). GEOS-backed
# operations downstream (st_buffer in fl_valley_confine's channel_buffer
# step) reject XYZM. Drop here so the rest of the script doesn't have to.
streams <- sf::st_zm(streams)
sf::st_write(streams, out("streams.gpkg"), delete_dsn = TRUE, quiet = TRUE)
message(sprintf("  %d segments", nrow(streams)))

DBI::dbDisconnect(conn)

# ---- 3. MRDEM-30 clip via fl_dem_aoi() ----------------------------------

# Pass streams as the AOI so the crop is tight along the stream corridor —
# the memory-efficient pattern for big WSGs with sparse stream coverage.
message("Fetching MRDEM-30 clip (heaviest network step; ranges ~50-100 MB) ...")
dem <- fl_dem_aoi(streams, buffer = 2000)
# INT2S (Int16) for the cache: rounds to whole metres, which is fine for
# 30 m MRDEM and for the VCA pipeline, and shrinks the file ~5x vs FLT4S.
terra::writeRaster(
  terra::as.int(dem), out("dem.tif"),
  overwrite = TRUE,
  datatype = "INT2S",
  gdal = c("COMPRESS=DEFLATE", "PREDICTOR=2", "TILED=YES")
)
message(sprintf("  %d x %d cells (%.1f Mcells)",
                ncol(dem), nrow(dem),
                ncol(dem) * nrow(dem) / 1e6))

# ---- 4. Run flooded VCA pipeline ----------------------------------------

message("Running fl_valley_confine() ...")
terra::terraOptions(threads = max(1L, parallel::detectCores() - 2L))

valleys <- fl_valley_confine(
  dem = dem,
  streams = streams,
  field = "upstream_area_ha",
  precip = fl_stream_rasterize(streams, dem, field = "map_upstream")
)
terra::writeRaster(
  valleys, out("valleys.tif"),
  overwrite = TRUE,
  datatype = "INT1U",
  gdal = c("COMPRESS=DEFLATE", "TILED=YES")
)

# ---- 5. Polygonize ------------------------------------------------------

message("Polygonizing valleys ...")
floodplain <- fl_valley_poly(valleys)
sf::st_write(floodplain, out("floodplain.gpkg"),
             delete_dsn = TRUE, quiet = TRUE)

# ---- 6. Report cache size -----------------------------------------------

cache_files <- list.files(out_dir, pattern = paste0("^", stub, "_"),
                          full.names = TRUE)
cache_sizes <- file.info(cache_files)$size
total_mb <- sum(cache_sizes) / 1024^2
message(sprintf("Cache for %s total: %.1f MB across %d files",
                wsg, total_mb, length(cache_files)))
for (i in seq_along(cache_files)) {
  message(sprintf("  %-40s %.2f MB", basename(cache_files[i]),
                  cache_sizes[i] / 1024^2))
}
if (total_mb > 15) {
  warning(sprintf("Cache exceeds 15 MB target (%.1f MB)", total_mb),
          call. = FALSE)
}
