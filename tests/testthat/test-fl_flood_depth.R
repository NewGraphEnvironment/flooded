test_that("fl_flood_depth returns zero at stream cells", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  stream_r <- fl_stream_rasterize(streams_sf, dem, field = "channel_width")

  surface <- fl_flood_surface(dem, stream_r)
  depth <- fl_flood_depth(dem, surface, streams = stream_r)

  expect_s4_class(depth, "SpatRaster")
  expect_equal(names(depth), "flood_depth")

  # Stream cells should be 0
  stream_cells <- which(!is.na(terra::values(stream_r)))
  expect_true(all(terra::values(depth)[stream_cells] == 0))
})

test_that("fl_flood_depth has positive values near streams", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  stream_r <- fl_stream_rasterize(streams_sf, dem, field = "channel_width")

  surface <- fl_flood_surface(dem, stream_r)
  depth <- fl_flood_depth(dem, surface, streams = stream_r)

  vals <- terra::values(depth, na.rm = TRUE)
  # Should have some flooded cells (depth > 0)
  expect_true(sum(vals > 0) > 0)
  # All non-NA values should be >= 0
  expect_true(all(vals >= 0))
})

test_that("fl_flood_depth corridor narrows with smaller max_width", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  stream_r <- fl_stream_rasterize(streams_sf, dem, field = "channel_width")

  surface <- fl_flood_surface(dem, stream_r)
  wide <- fl_flood_depth(dem, surface, max_width = 2000, streams = stream_r)
  narrow <- fl_flood_depth(dem, surface, max_width = 200, streams = stream_r)

  n_wide <- sum(!is.na(terra::values(wide)))
  n_narrow <- sum(!is.na(terra::values(narrow)))
  expect_true(n_wide > n_narrow)
})

test_that("fl_flood_depth errors on mismatched grids", {
  r1 <- terra::rast(nrows = 5, ncols = 5, vals = 100,
                    xmin = 0, xmax = 5, ymin = 0, ymax = 5)
  r2 <- terra::rast(nrows = 10, ncols = 10, vals = 110,
                    xmin = 0, xmax = 5, ymin = 0, ymax = 5)
  expect_error(fl_flood_depth(r1, r2), "same extent")
})
