test_that("fl_flood_trim removes cells matching exclusion mask", {
  x <- terra::rast(nrows = 3, ncols = 3,
                   vals = c(1, 1, 1, 0, 1, 0, 0, 0, 1),
                   xmin = 0, xmax = 3, ymin = 0, ymax = 3)
  mask <- terra::rast(nrows = 3, ncols = 3,
                      vals = c(0, 0, 1, 0, 0, 0, 0, 0, 1),
                      xmin = 0, xmax = 3, ymin = 0, ymax = 3)

  out <- fl_flood_trim(x, mask)

  # Original had 5 ones; mask removes 2 (cells 3 and 9)
  expect_equal(sum(terra::values(out)), 3L)
})

test_that("fl_flood_trim works with multiple masks", {
  x <- terra::rast(nrows = 3, ncols = 3, vals = rep(1, 9),
                   xmin = 0, xmax = 3, ymin = 0, ymax = 3)
  m1 <- terra::rast(nrows = 3, ncols = 3,
                    vals = c(1, 0, 0, 0, 0, 0, 0, 0, 0),
                    xmin = 0, xmax = 3, ymin = 0, ymax = 3)
  m2 <- terra::rast(nrows = 3, ncols = 3,
                    vals = c(0, 0, 0, 0, 0, 0, 0, 0, 1),
                    xmin = 0, xmax = 3, ymin = 0, ymax = 3)

  out <- fl_flood_trim(x, m1, m2)
  expect_equal(sum(terra::values(out)), 7L)
})
