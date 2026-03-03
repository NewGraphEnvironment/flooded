test_that("fl_valley_poly returns sf polygons from binary raster", {
  slope <- terra::rast(system.file("testdata/slope.tif", package = "flooded"))
  gentle <- fl_mask(slope, threshold = 9, operator = "<=")

  poly <- fl_valley_poly(gentle)

  expect_s3_class(poly, "sf")
  expect_true(all(sf::st_is_valid(poly)))
  expect_true("valley" %in% names(poly))
  expect_true(all(poly$valley == 1))
  expect_true(all(sf::st_geometry_type(poly) %in% c("POLYGON", "MULTIPOLYGON")))
})

test_that("fl_valley_poly with dissolve = FALSE returns separate patches", {
  slope <- terra::rast(system.file("testdata/slope.tif", package = "flooded"))
  gentle <- fl_mask(slope, threshold = 9, operator = "<=")

  poly_dissolved <- fl_valley_poly(gentle, dissolve = TRUE)
  poly_patches <- fl_valley_poly(gentle, dissolve = FALSE)

  expect_s3_class(poly_patches, "sf")
  # Undissolved should have >= as many features as dissolved
  expect_gte(nrow(poly_patches), nrow(poly_dissolved))
})

test_that("fl_valley_poly preserves CRS", {
  slope <- terra::rast(system.file("testdata/slope.tif", package = "flooded"))
  gentle <- fl_mask(slope, threshold = 9, operator = "<=")

  poly <- fl_valley_poly(gentle)
  expect_equal(
    sf::st_crs(poly)$epsg,
    as.integer(terra::crs(slope, describe = TRUE)$code)
  )
})

test_that("fl_valley_poly returns empty sf for all-zero raster", {
  r <- terra::rast(nrows = 10, ncols = 10, vals = 0L)
  poly <- fl_valley_poly(r)
  expect_s3_class(poly, "sf")
  expect_equal(nrow(poly), 0L)
})
