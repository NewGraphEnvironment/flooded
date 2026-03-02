test_that("fl_patch_rm removes small patches and keeps large ones", {
  # 10x10 grid, 10m cells (100m² per cell)
  # Patch A: 6 cells = 600m², Patch B: 2 cells = 200m²
  vals <- matrix(0L, 10, 10)
  vals[2:3, 2:4] <- 1L  # 6-cell patch
  vals[7:8, 7] <- 1L    # 2-cell patch

  r <- terra::rast(vals, extent = terra::ext(0, 100, 0, 100), crs = "EPSG:3005")

  # Remove patches < 500m² — should drop the 2-cell patch
  out <- fl_patch_rm(r, min_area = 500)

  expect_s4_class(out, "SpatRaster")
  # Large patch still present (row 2, col 2)
  expect_equal(out[2, 2][1, 1], 1L)
  # Small patch removed (row 7, col 7)
  expect_equal(out[7, 7][1, 1], 0L)
})

test_that("fl_patch_rm keeps all patches when threshold is small", {
  vals <- matrix(0L, 5, 5)
  vals[1, 1] <- 1L
  vals[5, 5] <- 1L

  r <- terra::rast(vals, extent = terra::ext(0, 50, 0, 50), crs = "EPSG:3005")

  out <- fl_patch_rm(r, min_area = 1)
  expect_equal(sum(terra::values(out)), 2L)
})

test_that("fl_patch_rm removes all patches when threshold is huge", {
  vals <- matrix(0L, 5, 5)
  vals[1:2, 1:2] <- 1L  # 4 cells = 400m²

  r <- terra::rast(vals, extent = terra::ext(0, 50, 0, 50), crs = "EPSG:3005")

  out <- fl_patch_rm(r, min_area = 1e6)
  expect_equal(sum(terra::values(out)), 0L)
})

test_that("fl_patch_rm respects 4 vs 8 connectivity", {
  # Diagonal-only connection: connected under 8, separate under 4
  vals <- matrix(0L, 5, 5)
  vals[1, 1] <- 1L
  vals[2, 2] <- 1L  # diagonal from (1,1)
  vals[4:5, 4:5] <- 1L  # 4-cell block

  r <- terra::rast(vals, extent = terra::ext(0, 50, 0, 50), crs = "EPSG:3005")

  # With 4-connectivity: (1,1) and (2,2) are separate 1-cell patches (100m² each)
  out4 <- fl_patch_rm(r, min_area = 200, directions = 4L)
  expect_equal(out4[1, 1][1, 1], 0L)
  expect_equal(out4[2, 2][1, 1], 0L)

  # With 8-connectivity: (1,1) and (2,2) form a 2-cell patch (200m²)
  out8 <- fl_patch_rm(r, min_area = 200, directions = 8L)
  expect_equal(out8[1, 1][1, 1], 1L)
  expect_equal(out8[2, 2][1, 1], 1L)
})

test_that("fl_patch_rm errors on invalid inputs", {
  r <- terra::rast(nrows = 2, ncols = 2, vals = c(1, 0, 0, 1),
                   xmin = 0, xmax = 2, ymin = 0, ymax = 2)
  expect_error(fl_patch_rm(r, min_area = -1))
  expect_error(fl_patch_rm("not_raster", min_area = 100))
})
