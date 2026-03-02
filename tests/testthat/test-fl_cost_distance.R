test_that("fl_cost_distance returns SpatRaster with zero at stream cells", {
  dem <- terra::rast(testdata_path("dem.tif"))
  slope <- terra::rast(testdata_path("slope.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  stream_r <- fl_stream_rasterize(streams_sf, dem, field = "channel_width")
  cd <- fl_cost_distance(slope, stream_r)

  expect_s4_class(cd, "SpatRaster")
  expect_equal(dim(cd), dim(slope))
  expect_equal(names(cd), "cost_distance")

  # Stream cells should have cost 0
  stream_mask <- !is.na(terra::values(stream_r))
  cd_vals <- terra::values(cd)
  expect_true(all(cd_vals[stream_mask] == 0, na.rm = TRUE))
})

test_that("fl_cost_distance increases away from streams", {
  dem <- terra::rast(testdata_path("dem.tif"))
  slope <- terra::rast(testdata_path("slope.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  stream_r <- fl_stream_rasterize(streams_sf, dem, field = "channel_width")
  cd <- fl_cost_distance(slope, stream_r)

  cd_vals <- terra::values(cd)
  # Non-stream, non-NA cells should have positive cost
  stream_mask <- !is.na(terra::values(stream_r))
  non_stream <- !stream_mask & !is.na(cd_vals)
  expect_true(all(cd_vals[non_stream] > 0))
})

test_that("fl_cost_distance works on small synthetic raster", {
  # 5x5 grid, stream in middle column, flat slope = 1 everywhere
  friction <- terra::rast(nrows = 5, ncols = 5, vals = rep(1, 25),
                          xmin = 0, xmax = 50, ymin = 0, ymax = 50,
                          crs = "EPSG:3005")
  stream_vals <- rep(NA, 25)
  stream_vals[c(3, 8, 13, 18, 23)] <- 10  # middle column

  streams <- terra::rast(nrows = 5, ncols = 5, vals = stream_vals,
                         xmin = 0, xmax = 50, ymin = 0, ymax = 50,
                         crs = "EPSG:3005")

  cd <- fl_cost_distance(friction, streams)

  vals <- terra::values(cd)
  # Middle column (cells 3,8,13,18,23) should be 0
  expect_true(all(vals[c(3, 8, 13, 18, 23)] == 0))
  # Adjacent columns should have lower cost than edge columns
  expect_true(all(vals[c(2, 7, 12, 17, 22)] < vals[c(1, 6, 11, 16, 21)]))
})

test_that("fl_cost_distance errors on mismatched grids", {
  r1 <- terra::rast(nrows = 5, ncols = 5, vals = 1,
                    xmin = 0, xmax = 5, ymin = 0, ymax = 5)
  r2 <- terra::rast(nrows = 10, ncols = 10, vals = 1,
                    xmin = 0, xmax = 5, ymin = 0, ymax = 5)

  expect_error(fl_cost_distance(r1, r2), "same extent")
})
