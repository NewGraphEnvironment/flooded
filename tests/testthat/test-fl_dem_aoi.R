test_that("fl_dem_aoi crops local file to buffered AOI", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  result <- fl_dem_aoi(aoi, source = testdata_path("dem.tif"), buffer = 100)

  expect_s4_class(result, "SpatRaster")
  expect_true(terra::ncell(result) > 0)

  # Result extent must cover the buffered AOI
  aoi_buf_ext <- terra::ext(terra::vect(sf::st_buffer(aoi, 100)))
  res_ext <- terra::ext(result)
  expect_true(res_ext$xmin <= aoi_buf_ext$xmin)
  expect_true(res_ext$xmax >= aoi_buf_ext$xmax)
  expect_true(res_ext$ymin <= aoi_buf_ext$ymin)
  expect_true(res_ext$ymax >= aoi_buf_ext$ymax)
})

test_that("fl_dem_aoi handles AOI/source CRS mismatch", {
  aoi_3005 <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  aoi_4326 <- sf::st_transform(aoi_3005, 4326)

  result <- fl_dem_aoi(aoi_4326, source = testdata_path("dem.tif"), buffer = 100)

  expect_s4_class(result, "SpatRaster")
  expect_true(terra::ncell(result) > 0)
  # target_crs defaulted to aoi_4326's CRS (EPSG:4326)
  expect_equal(sf::st_crs(terra::crs(result))$epsg, 4326L)
})

test_that("fl_dem_aoi target_crs override reprojects after crop", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  result <- fl_dem_aoi(
    aoi,
    source = testdata_path("dem.tif"),
    buffer = 100,
    target_crs = 4326
  )

  expect_s4_class(result, "SpatRaster")
  expect_equal(sf::st_crs(terra::crs(result))$epsg, 4326L)
})

test_that("fl_dem_aoi larger buffer yields equal-or-larger extent", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  small <- fl_dem_aoi(aoi, source = testdata_path("dem.tif"), buffer = 100)
  big <- fl_dem_aoi(aoi, source = testdata_path("dem.tif"), buffer = 500)

  expect_true(terra::ncell(big) >= terra::ncell(small))
})

test_that("fl_dem_aoi accepts polygon AOI", {
  waterbodies <- sf::st_read(testdata_path("waterbodies.gpkg"), quiet = TRUE)

  result <- fl_dem_aoi(
    waterbodies,
    source = testdata_path("dem.tif"),
    buffer = 100
  )

  expect_s4_class(result, "SpatRaster")
  expect_true(terra::ncell(result) > 0)
})

test_that("fl_dem_aoi rejects non-sf aoi", {
  expect_error(
    fl_dem_aoi("not_sf", source = testdata_path("dem.tif")),
    "sf"
  )
})

test_that("fl_dem_aoi fetches MRDEM-30 via /vsicurl/", {
  testthat::skip_on_cran()
  testthat::skip_if_offline()

  # Single-feature AOI keeps the range read tiny (~100s of KB)
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)[1, ]

  result <- fl_dem_aoi(aoi, buffer = 100)

  expect_s4_class(result, "SpatRaster")
  expect_true(terra::ncell(result) > 0)
  # Default target_crs is the input AOI's CRS
  expect_equal(sf::st_crs(terra::crs(result)), sf::st_crs(aoi))
})
