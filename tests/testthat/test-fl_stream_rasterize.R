test_that("fl_stream_rasterize returns SpatRaster matching template grid", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  r <- fl_stream_rasterize(streams, dem, field = "channel_width")

  expect_s4_class(r, "SpatRaster")
  expect_equal(dim(r), dim(dem))
  expect_equal(terra::crs(r), terra::crs(dem))
  expect_equal(as.vector(terra::ext(r)), as.vector(terra::ext(dem)))
  expect_equal(names(r), "channel_width")
})

test_that("fl_stream_rasterize burns correct values", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  r <- fl_stream_rasterize(streams, dem, field = "channel_width")

  vals <- terra::values(r, na.rm = TRUE)
  # Stream cells should have positive channel width values

  expect_true(all(vals > 0))
  # Values should fall within the range of the input field (float32 tolerance)
  expect_equal(min(vals), min(streams$channel_width), tolerance = 1e-5)
  expect_equal(max(vals), max(streams$channel_width), tolerance = 1e-5)
})

test_that("fl_stream_rasterize produces mostly NA (non-stream) cells", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  r <- fl_stream_rasterize(streams, dem, field = "channel_width")

  n_stream <- sum(!is.na(terra::values(r)))
  n_total <- terra::ncell(r)
  # Streams should be a small fraction of total cells

  expect_true(n_stream > 0)
  expect_true(n_stream / n_total < 0.05)
})

test_that("fl_stream_rasterize works with stream_order field", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  r <- fl_stream_rasterize(streams, dem, field = "stream_order")

  vals <- terra::values(r, na.rm = TRUE)
  expect_true(all(vals %in% unique(streams$stream_order)))
  expect_equal(names(r), "stream_order")
})

test_that("fl_stream_rasterize errors on missing field", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  expect_error(
    fl_stream_rasterize(streams, dem, field = "nonexistent"),
    "not found"
  )
})

test_that("fl_stream_rasterize errors on non-numeric field", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  expect_error(
    fl_stream_rasterize(streams, dem, field = "gnis_name"),
    "must be numeric"
  )
})

test_that("fl_stream_rasterize errors on wrong input types", {
  dem <- terra::rast(testdata_path("dem.tif"))

  expect_error(fl_stream_rasterize("not_sf", dem))
  expect_error(fl_stream_rasterize(data.frame(x = 1), dem))
})
