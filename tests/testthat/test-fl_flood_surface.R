test_that("fl_flood_surface returns NA at non-stream cells", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  stream_r <- fl_stream_rasterize(streams_sf, dem, field = "channel_width")

  surface <- fl_flood_surface(dem, stream_r)

  expect_s4_class(surface, "SpatRaster")
  expect_equal(names(surface), "flood_surface")

  # Non-stream cells should be NA
  stream_cells <- !is.na(terra::values(stream_r))
  surface_vals <- terra::values(surface)
  expect_true(all(is.na(surface_vals[!stream_cells])))
  # Stream cells should have values
  expect_true(all(!is.na(surface_vals[stream_cells])))
})

test_that("fl_flood_surface exceeds DEM at stream cells", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  stream_r <- fl_stream_rasterize(streams_sf, dem, field = "channel_width")

  surface <- fl_flood_surface(dem, stream_r)

  stream_cells <- which(!is.na(terra::values(stream_r)))
  dem_at_streams <- terra::values(dem)[stream_cells]
  surface_at_streams <- terra::values(surface)[stream_cells]

  # Flood surface should be above DEM (flood_factor > 0)
  expect_true(all(surface_at_streams > dem_at_streams))
})

test_that("fl_flood_surface increases with flood_factor", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  stream_r <- fl_stream_rasterize(streams_sf, dem, field = "channel_width")

  s3 <- fl_flood_surface(dem, stream_r, flood_factor = 3)
  s9 <- fl_flood_surface(dem, stream_r, flood_factor = 9)

  stream_cells <- which(!is.na(terra::values(stream_r)))
  expect_true(all(terra::values(s9)[stream_cells] > terra::values(s3)[stream_cells]))
})

test_that("fl_flood_surface works on synthetic data", {
  # Flat DEM at 100m, stream with area = 1000ha
  dem <- terra::rast(nrows = 5, ncols = 5, vals = 100,
                     xmin = 0, xmax = 50, ymin = 0, ymax = 50, crs = "EPSG:3005")
  stream_vals <- rep(NA, 25)
  stream_vals[13] <- 1000  # centre cell, 1000ha
  streams <- terra::rast(nrows = 5, ncols = 5, vals = stream_vals,
                         xmin = 0, xmax = 50, ymin = 0, ymax = 50, crs = "EPSG:3005")

  surface <- fl_flood_surface(dem, streams, flood_factor = 6, precip = 1)

  # Only centre cell should have a value
  expect_equal(sum(!is.na(terra::values(surface))), 1L)
  # Should be > 100 (DEM + some flood depth)
  expect_true(terra::values(surface)[13] > 100)
})

test_that("fl_flood_surface errors on mismatched grids", {
  r1 <- terra::rast(nrows = 5, ncols = 5, vals = 100,
                    xmin = 0, xmax = 5, ymin = 0, ymax = 5)
  r2 <- terra::rast(nrows = 10, ncols = 10, vals = 1,
                    xmin = 0, xmax = 5, ymin = 0, ymax = 5)
  expect_error(fl_flood_surface(r1, r2), "same extent")
})
