test_that("fl_flood_model returns 3-layer SpatRaster", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  stream_r <- fl_stream_rasterize(streams_sf, dem, field = "channel_width")

  result <- fl_flood_model(dem, stream_r)

  expect_s4_class(result, "SpatRaster")
  expect_equal(terra::nlyr(result), 3L)
  expect_equal(names(result), c("flood_surface", "flood_depth", "flooded"))
})

test_that("fl_flood_model flooded layer is binary", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  stream_r <- fl_stream_rasterize(streams_sf, dem, field = "channel_width")

  result <- fl_flood_model(dem, stream_r)
  flooded <- result[["flooded"]]

  vals <- terra::values(flooded, na.rm = TRUE)
  expect_true(all(vals %in% c(0L, 1L)))
  expect_true(sum(vals == 1L) > 0)
})
