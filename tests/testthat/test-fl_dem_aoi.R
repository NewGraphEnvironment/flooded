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

  result <- fl_dem_aoi(aoi_4326, source = testdata_path("dem.tif"), buffer = 100, res = 1e-4)

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
    target_crs = 4326,
    res = 1e-4
  )

  expect_s4_class(result, "SpatRaster")
  expect_equal(sf::st_crs(terra::crs(result))$epsg, 4326L)
  expect_equal(terra::res(result), c(1e-4, 1e-4))
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

# Expected grid for a reprojection, computed here rather than by fl_dem_aoi():
# the buffered AOI's bbox in the target CRS, snapped outward to multiples of res.
expected_ext <- function(aoi, buffer, crs, res) {
  bb <- sf::st_bbox(sf::st_transform(sf::st_buffer(aoi, buffer), crs))
  c(
    xmin = floor(bb[["xmin"]] / res) * res, xmax = ceiling(bb[["xmax"]] / res) * res,
    ymin = floor(bb[["ymin"]] / res) * res, ymax = ceiling(bb[["ymax"]] / res) * res
  )
}

test_that("fl_dem_aoi reprojects onto the source cell size, aligned to multiples of it (#67)", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  # Before #67 GDAL chose this grid: 10.0124 m, origin off any multiple of 10
  result <- fl_dem_aoi(aoi, source = testdata_path("dem.tif"), buffer = 100, target_crs = 3157)

  expect_identical(terra::res(result), c(10, 10))
  expect_equal(as.vector(terra::ext(result)), expected_ext(aoi, 100, 3157, 10), tolerance = 0)
})

test_that("fl_dem_aoi aligns the grid when the AOI is already in target_crs (#67)", {
  # The floodplains shape: streams in the target CRS, DEM in another
  aoi <- sf::st_transform(sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE), 3157)

  result <- fl_dem_aoi(aoi, source = testdata_path("dem.tif"), buffer = 100)

  expect_identical(terra::res(result), c(10, 10))
  expect_equal(as.vector(terra::ext(result)), expected_ext(aoi, 100, 3157, 10), tolerance = 0)
})

test_that("fl_dem_aoi resamples onto an aligned grid in the source CRS when res differs (#67)", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  result <- fl_dem_aoi(aoi, source = testdata_path("dem.tif"), buffer = 100, res = 30)

  expect_identical(terra::res(result), c(30, 30))
  expect_equal(as.vector(terra::ext(result)), expected_ext(aoi, 100, 3005, 30), tolerance = 0)
})

test_that("fl_dem_aoi honours an explicit res and aligns every edge to it (#67)", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  result <- fl_dem_aoi(
    aoi, source = testdata_path("dem.tif"), buffer = 100, target_crs = 3157, res = 30
  )

  expect_identical(terra::res(result), c(30, 30))
  e <- as.vector(terra::ext(result))
  expect_identical(unname(e %% 30), rep(0, 4))
  expect_equal(e, expected_ext(aoi, 100, 3157, 30), tolerance = 0)
})

test_that("fl_dem_aoi has data in every cell of the buffered AOI (#67)", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  # The AOI + 100 m sits ~900 m inside dem.tif. Grid corners beyond the area
  # read may be NA; no cell inside the buffered AOI may be.
  result <- fl_dem_aoi(aoi, source = testdata_path("dem.tif"), buffer = 100, target_crs = 3157)
  in_aoi <- !is.na(terra::rasterize(
    terra::vect(sf::st_transform(sf::st_buffer(aoi, 100), 3157)), result, touches = FALSE
  ))

  expect_gt(terra::global(in_aoi, "sum")[[1]], 0)
  expect_identical(terra::global(is.na(result) & in_aoi, "sum")[[1]], 0)
})

test_that("fl_dem_aoi in the source CRS crops on the source grid, unchanged", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  r <- terra::rast(testdata_path("dem.tif"))

  result <- fl_dem_aoi(aoi, source = testdata_path("dem.tif"), buffer = 100)
  expected <- terra::crop(r, terra::vect(sf::st_buffer(aoi, 100)), snap = "out")

  expect_true(terra::compareGeom(result, expected, stopOnError = FALSE))
  expect_identical(as.vector(terra::ext(result)), as.vector(terra::ext(expected)))
  expect_identical(terra::values(result), terra::values(expected))
})

test_that("fl_dem_aoi asks for res in degrees for a geographic target (#67)", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  expect_error(
    fl_dem_aoi(aoi, source = testdata_path("dem.tif"), buffer = 100, target_crs = 4326),
    "res = 0\\.0[0-9]+ degrees"
  )
})

test_that("fl_dem_aoi rejects an invalid res", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  dem <- testdata_path("dem.tif")

  expect_error(fl_dem_aoi(aoi, source = dem, target_crs = 3157, res = "30"), "`res` must be")
  expect_error(fl_dem_aoi(aoi, source = dem, target_crs = 3157, res = c(30, 30)), "`res` must be")
  expect_error(fl_dem_aoi(aoi, source = dem, target_crs = 3157, res = 0), "`res` must be")
  expect_error(fl_dem_aoi(aoi, source = dem, target_crs = 3157, res = NA_real_), "`res` must be")
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
  # MRDEM's 30 m cells, on a grid aligned to multiples of 30 (#67)
  expect_identical(terra::res(result), c(30, 30))
  expect_identical(unname(as.vector(terra::ext(result)) %% 30), rep(0, 4))
})
