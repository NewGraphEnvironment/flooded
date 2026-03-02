test_that("fl_mask returns binary SpatRaster with correct dimensions", {
  slope <- terra::rast(testdata_path("slope.tif"))

  m <- fl_mask(slope, threshold = 9, operator = "<=")

  expect_s4_class(m, "SpatRaster")
  expect_equal(dim(m), dim(slope))
  expect_equal(names(m), "mask")

  vals <- terra::values(m, na.rm = TRUE)
  expect_true(all(vals %in% c(0L, 1L)))
})

test_that("fl_mask threshold produces expected proportions", {
  slope <- terra::rast(testdata_path("slope.tif"))

  gentle <- fl_mask(slope, threshold = 9, operator = "<=")
  steep <- fl_mask(slope, threshold = 9, operator = ">")

  n_gentle <- sum(terra::values(gentle, na.rm = TRUE) == 1L)
  n_steep <- sum(terra::values(steep, na.rm = TRUE) == 1L)
  n_valid <- sum(!is.na(terra::values(slope)))

  # gentle + steep should account for all valid cells
  expect_equal(n_gentle + n_steep, n_valid)
  # Both should have some cells (test area has mix of valley and hillside)
  expect_true(n_gentle > 0)
  expect_true(n_steep > 0)
})

test_that("fl_mask operators work correctly on known values", {
  r <- terra::rast(nrows = 3, ncols = 3, vals = 1:9,
                   xmin = 0, xmax = 3, ymin = 0, ymax = 3)

  expect_equal(sum(terra::values(fl_mask(r, 5, "<="))), 5L)
  expect_equal(sum(terra::values(fl_mask(r, 5, "<"))),  4L)
  expect_equal(sum(terra::values(fl_mask(r, 5, ">="))), 5L)
  expect_equal(sum(terra::values(fl_mask(r, 5, ">"))),  4L)
  expect_equal(sum(terra::values(fl_mask(r, 5, "=="))), 1L)
  expect_equal(sum(terra::values(fl_mask(r, 5, "!="))), 8L)
})

test_that("fl_mask preserves NA cells", {
  r <- terra::rast(nrows = 3, ncols = 3, vals = c(1:8, NA),
                   xmin = 0, xmax = 3, ymin = 0, ymax = 3)

  m <- fl_mask(r, 5, "<=")

  expect_true(is.na(terra::values(m)[9]))
  expect_equal(sum(terra::values(m, na.rm = TRUE)), 5L)
})

test_that("fl_mask errors on invalid operator", {
  r <- terra::rast(nrows = 2, ncols = 2, vals = 1:4,
                   xmin = 0, xmax = 2, ymin = 0, ymax = 2)

  expect_error(fl_mask(r, 2, "~"), "operator")
})

test_that("fl_mask errors on wrong input types", {
  expect_error(fl_mask("not_raster", 5))
  r <- terra::rast(nrows = 2, ncols = 2, vals = 1:4,
                   xmin = 0, xmax = 2, ymin = 0, ymax = 2)
  expect_error(fl_mask(r, "five"))
})
