#!/usr/bin/env Rscript
#
# testdata.R
#
# Generate test fixtures for the flooded package. The outputs are committed to
# inst/testdata/ so this script does NOT need to be run by package users.
#
# Crops a ~6km section of Neexdzii Kwah (Bulkley River) near Topley, BC from
# the BULK watershed group DEM used by bcfishpass lateral habitat modelling.
# Stream network comes from data-raw/network_extract.R (see that file for
# how the streams were queried from bcfishpass).
#
# Prerequisites:
#   - bcfishpass BULK DEM at the path below (from lateral habitat pipeline)
#   - Stream network geojson from airbc repo
#   - R packages: terra, sf, here
#
# Output:
#   inst/testdata/dem.tif      — 10m DEM cropped to stream extent + 1km buffer
#   inst/testdata/slope.tif    — percent slope derived from cropped DEM
#   inst/testdata/streams.gpkg — stream network in BC Albers (EPSG:3005)

library(terra)
library(sf)

# --- Source paths ---
bulk_dem_path <- "~/Projects/repo/bcfishpass/model/habitat_lateral/data/temp/BULK/dem.tif"
streams_path <- "~/Projects/repo/airbc/data/network/network_bulk_richfield_cesford.geojson"
out_dir <- here::here("inst", "testdata")

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# --- Read and reproject streams to BC Albers ---
message("Reading streams...")
streams <- sf::st_read(streams_path, quiet = TRUE)
streams <- sf::st_transform(streams, 3005)
message("  ", nrow(streams), " segments in BC Albers")

# --- Crop DEM to stream extent + 1km buffer ---
message("Reading BULK DEM...")
dem_full <- terra::rast(bulk_dem_path)

stream_bbox <- sf::st_bbox(streams)
buffer_m <- 1000
crop_extent <- terra::ext(
  stream_bbox["xmin"] - buffer_m,
  stream_bbox["xmax"] + buffer_m,
  stream_bbox["ymin"] - buffer_m,
  stream_bbox["ymax"] + buffer_m
)

message("Cropping DEM to stream extent + 1km buffer...")
dem <- terra::crop(dem_full, crop_extent)
message("  ", ncol(dem), " x ", nrow(dem), " pixels (",
        round(ncol(dem) * nrow(dem) / 1e3, 1), "k cells)")

# --- Derive slope ---
message("Deriving slope (percent)...")
slope <- terra::terrain(dem, "slope", unit = "degrees")
# Convert to percent: tan(degrees * pi/180) * 100
slope <- tan(slope * pi / 180) * 100

# --- Write outputs ---
message("Writing outputs to ", out_dir, "...")
terra::writeRaster(dem, file.path(out_dir, "dem.tif"), overwrite = TRUE)
terra::writeRaster(slope, file.path(out_dir, "slope.tif"), overwrite = TRUE)
sf::st_write(streams, file.path(out_dir, "streams.gpkg"),
             delete_dsn = TRUE, quiet = TRUE)

# --- Summary ---
message("\nTest data summary:")
message("  DEM:     ", file.path(out_dir, "dem.tif"), " (",
        round(file.size(file.path(out_dir, "dem.tif")) / 1e6, 1), " MB)")
message("  Slope:   ", file.path(out_dir, "slope.tif"), " (",
        round(file.size(file.path(out_dir, "slope.tif")) / 1e6, 1), " MB)")
message("  Streams: ", file.path(out_dir, "streams.gpkg"), " (",
        round(file.size(file.path(out_dir, "streams.gpkg")) / 1e3, 1), " KB)")
message("  Extent:  ", paste(round(as.vector(terra::ext(dem))), collapse = ", "),
        " (EPSG:3005)")
