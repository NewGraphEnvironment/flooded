test_that("fl_mask_distance returns binary mask within threshold", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  stream_r <- fl_stream_rasterize(streams_sf, dem, field = "channel_width")
  m <- fl_mask_distance(stream_r, threshold = 1000)

  expect_s4_class(m, "SpatRaster")
  expect_equal(dim(m), dim(dem))
  expect_equal(names(m), "mask")

  vals <- terra::values(m, na.rm = TRUE)
  expect_true(all(vals %in% c(0L, 1L)))
})

test_that("fl_mask_distance includes stream cells", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  stream_r <- fl_stream_rasterize(streams_sf, dem, field = "channel_width")
  m <- fl_mask_distance(stream_r, threshold = 100)

  # Every stream cell should be within the mask
  stream_cells <- !is.na(terra::values(stream_r))
  mask_vals <- terra::values(m)
  expect_true(all(mask_vals[stream_cells] == 1L))
})

test_that("fl_mask_distance corridor narrows with smaller threshold", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  stream_r <- fl_stream_rasterize(streams_sf, dem, field = "channel_width")
  wide <- fl_mask_distance(stream_r, threshold = 1000)
  narrow <- fl_mask_distance(stream_r, threshold = 200)

  n_wide <- sum(terra::values(wide, na.rm = TRUE))
  n_narrow <- sum(terra::values(narrow, na.rm = TRUE))
  expect_true(n_wide > n_narrow)
  expect_true(n_narrow > 0)
})

test_that("fl_mask_distance on synthetic raster gives expected result", {
  # 5x5, 10m cells, feature in centre
  r <- terra::rast(nrows = 5, ncols = 5, vals = NA,
                   xmin = 0, xmax = 50, ymin = 0, ymax = 50,
                   crs = "EPSG:3005")
  r[3, 3] <- 1  # centre cell

  m <- fl_mask_distance(r, threshold = 15)

  # Centre + 4 cardinal neighbours should be within 10m
  # Diagonal neighbours at ~14.1m should also be within 15m
  vals <- terra::values(m)
  expect_equal(vals[13], 1L)  # centre
  # At least the 4 cardinal neighbours
  expect_true(sum(vals == 1L, na.rm = TRUE) >= 5)
})

test_that("fl_mask_distance errors on invalid inputs", {
  expect_error(fl_mask_distance("not_raster", 100))

  r <- terra::rast(nrows = 2, ncols = 2, vals = 1,
                   xmin = 0, xmax = 2, ymin = 0, ymax = 2)
  expect_error(fl_mask_distance(r, -10))
  expect_error(fl_mask_distance(r, "ten"))
})
