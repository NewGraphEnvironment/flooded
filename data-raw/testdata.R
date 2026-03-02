# Generate test fixtures for flooded package
#
# Crops a ~3-5km section of Neexdzii Kwah (Bulkley River) from the BULK
# watershed group DEM used by bcfishpass lateral habitat modelling.
#
# Prerequisites:
#   - bcfishpass repo at ~/Projects/repo/bcfishpass with BULK temp data
#   - terra, sf packages installed
#
# Run once manually; outputs are committed to inst/testdata/

library(terra)
library(sf)

# --- Configuration ---
bulk_dem_path <- "~/Projects/repo/bcfishpass/model/habitat_lateral/data/temp/BULK/dem.tif"
streams_path <- "~/Projects/repo/airbc/data/network_knockholt_ailport.geojson"
out_dir <- here::here("inst", "testdata")

# --- Define crop extent ---
# Pick a ~3-5km section of Neexdzii Kwah with valley floor, tributary, and walls
# TODO: define exact bounding box during implementation
# crop_extent <- terra::ext(xmin, xmax, ymin, ymax)  # BC Albers EPSG:3005

# --- Crop DEM ---
# dem_full <- terra::rast(bulk_dem_path)
# dem <- terra::crop(dem_full, crop_extent)
# terra::writeRaster(dem, file.path(out_dir, "dem.tif"), overwrite = TRUE)

# --- Derive slope ---
# slope <- terra::terrain(dem, "slope", unit = "percent")
# terra::writeRaster(slope, file.path(out_dir, "slope.tif"), overwrite = TRUE)

# --- Extract matching streams ---
# streams_full <- sf::st_read(streams_path)
# streams_full <- sf::st_transform(streams_full, terra::crs(dem))
# crop_bbox <- sf::st_as_sfc(sf::st_bbox(dem))
# streams <- sf::st_intersection(streams_full, crop_bbox)
# sf::st_write(streams, file.path(out_dir, "streams.gpkg"), delete_dsn = TRUE)
