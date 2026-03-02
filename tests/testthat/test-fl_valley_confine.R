test_that("fl_valley_confine returns binary SpatRaster", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  valleys <- fl_valley_confine(dem, streams_sf)

  expect_s4_class(valleys, "SpatRaster")
  expect_equal(names(valleys), "valley")

  vals <- terra::values(valleys, na.rm = TRUE)
  expect_true(all(vals %in% c(0L, 1L)))
})

test_that("fl_valley_confine identifies valley cells", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  valleys <- fl_valley_confine(dem, streams_sf)

  n_valley <- sum(terra::values(valleys) == 1L, na.rm = TRUE)
  n_total <- terra::ncell(valleys)

  # Should have some valley cells

  expect_true(n_valley > 0)
  # Valley should be a fraction of total area (not everything)
  expect_true(n_valley / n_total < 0.5)
})

test_that("fl_valley_confine accepts pre-rasterized streams", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  stream_r <- fl_stream_rasterize(streams_sf, dem, field = "channel_width")
  valleys <- fl_valley_confine(dem, stream_r)

  expect_s4_class(valleys, "SpatRaster")
  expect_true(sum(terra::values(valleys) == 1L, na.rm = TRUE) > 0)
})

test_that("fl_valley_confine accepts pre-computed slope", {
  dem <- terra::rast(testdata_path("dem.tif"))
  slope <- terra::rast(testdata_path("slope.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  valleys <- fl_valley_confine(dem, streams_sf, slope = slope)

  expect_s4_class(valleys, "SpatRaster")
  expect_true(sum(terra::values(valleys) == 1L, na.rm = TRUE) > 0)
})

test_that("fl_valley_confine shrinks with stricter thresholds", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  lax <- fl_valley_confine(dem, streams_sf,
                           slope_threshold = 15, cost_threshold = 5000)
  strict <- fl_valley_confine(dem, streams_sf,
                              slope_threshold = 5, cost_threshold = 1000)

  n_lax <- sum(terra::values(lax) == 1L, na.rm = TRUE)
  n_strict <- sum(terra::values(strict) == 1L, na.rm = TRUE)
  expect_true(n_lax >= n_strict)
})
