test_that("fl_flood_assemble unions two binary rasters", {
  r1 <- terra::rast(nrows = 3, ncols = 3,
                    vals = c(1, 0, 0, 0, 1, 0, 0, 0, 0),
                    xmin = 0, xmax = 3, ymin = 0, ymax = 3)
  r2 <- terra::rast(nrows = 3, ncols = 3,
                    vals = c(0, 0, 1, 0, 0, 0, 0, 1, 0),
                    xmin = 0, xmax = 3, ymin = 0, ymax = 3)

  out <- fl_flood_assemble(r1, r2)

  expect_equal(sum(terra::values(out)), 4L)
  expect_equal(names(out), "assembled")
})

test_that("fl_flood_assemble works with multi-layer input", {
  r1 <- terra::rast(nrows = 3, ncols = 3,
                    vals = c(1, 0, 0, 0, 1, 0, 0, 0, 0),
                    xmin = 0, xmax = 3, ymin = 0, ymax = 3)
  r2 <- terra::rast(nrows = 3, ncols = 3,
                    vals = c(0, 0, 1, 0, 0, 0, 0, 1, 0),
                    xmin = 0, xmax = 3, ymin = 0, ymax = 3)

  stk <- c(r1, r2)
  out <- fl_flood_assemble(stk)
  expect_equal(sum(terra::values(out)), 4L)
})
