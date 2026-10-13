test_that("fl_patch_conn keeps connected patches and drops disconnected", {
  # 10x10, 10m cells
  # Patch A at top-left, Patch B at bottom-right
  # Anchor overlaps Patch A only
  vals <- matrix(0L, 10, 10)
  vals[2:3, 2:3] <- 1L  # Patch A
  vals[8:9, 8:9] <- 1L  # Patch B

  r <- terra::rast(vals, extent = terra::ext(0, 100, 0, 100), crs = "EPSG:3005")

  anchor_vals <- matrix(NA_real_, 10, 10)
  anchor_vals[2, 2] <- 1  # overlaps Patch A

  anchor <- terra::rast(anchor_vals, extent = terra::ext(0, 100, 0, 100),
                        crs = "EPSG:3005")

  out <- fl_patch_conn(r, anchor)

  # Patch A kept
  expect_equal(out[2, 2][1, 1], 1L)
  expect_equal(out[3, 3][1, 1], 1L)
  # Patch B removed
  expect_equal(out[8, 8][1, 1], 0L)
})

test_that("fl_patch_conn returns all zeros when no anchor overlap", {
  vals <- matrix(0L, 5, 5)
  vals[1:2, 1:2] <- 1L

  r <- terra::rast(vals, extent = terra::ext(0, 50, 0, 50), crs = "EPSG:3005")

  anchor_vals <- matrix(NA_real_, 5, 5)
  anchor_vals[5, 5] <- 1  # no overlap with patch

  anchor <- terra::rast(anchor_vals, extent = terra::ext(0, 50, 0, 50),
                        crs = "EPSG:3005")

  out <- fl_patch_conn(r, anchor)
  expect_equal(sum(terra::values(out)), 0L)
})

test_that("fl_patch_conn works with real test data", {
  dem <- terra::rast(testdata_path("dem.tif"))
  slope <- terra::rast(testdata_path("slope.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  stream_r <- fl_stream_rasterize(streams_sf, dem, field = "channel_width")
  gentle <- fl_mask(slope, threshold = 9, operator = "<=")

  connected <- fl_patch_conn(gentle, stream_r)

  vals <- terra::values(connected)
  # Should have some connected cells
  expect_true(sum(vals == 1L, na.rm = TRUE) > 0)
  # Should be fewer than or equal to original gentle cells
  expect_lte(sum(vals == 1L, na.rm = TRUE),
             sum(terra::values(gentle) == 1L, na.rm = TRUE))
})

test_that("fl_patch_conn errors on mismatched grids", {
  r1 <- terra::rast(nrows = 5, ncols = 5, vals = 1,
                    xmin = 0, xmax = 5, ymin = 0, ymax = 5)
  r2 <- terra::rast(nrows = 10, ncols = 10, vals = 1,
                    xmin = 0, xmax = 5, ymin = 0, ymax = 5)

  expect_error(fl_patch_conn(r1, r2), "same extent")
})

# --- NA input cells (#65) ---------------------------------------------------
# The connected path used to set NA to 0; the no-anchor path (x * 0L) kept it.
na_conn_grid <- function() {
  vals <- matrix(0L, 10, 10)
  vals[2:3, 2:3] <- 1L  # Patch A
  vals[8:9, 8:9] <- 1L  # Patch B
  vals[5:6, 5:6] <- NA  # NA block clear of both patches
  vals[7, 8] <- NA      # NA touching Patch B
  vals
}

na_conn_anchor <- function(row, col) {
  anchor_vals <- matrix(NA_real_, 10, 10)
  anchor_vals[row, col] <- 1
  terra::rast(anchor_vals, extent = terra::ext(0, 100, 0, 100), crs = "EPSG:3005")
}

test_that("fl_patch_conn keeps NA cells NA on the connected path (#65)", {
  vals <- na_conn_grid()
  r <- terra::rast(vals, extent = terra::ext(0, 100, 0, 100), crs = "EPSG:3005")

  out <- fl_patch_conn(r, na_conn_anchor(2, 2))

  expected <- vals
  expected[8:9, 8:9] <- 0L
  # terra::rast(matrix) fills by row, so compare against the row-major vector.
  expect_equal(terra::values(out)[, 1], as.vector(t(expected)))
})

test_that("fl_patch_conn keeps NA cells NA when no patch touches an anchor (#65)", {
  vals <- na_conn_grid()
  r <- terra::rast(vals, extent = terra::ext(0, 100, 0, 100), crs = "EPSG:3005")

  out <- fl_patch_conn(r, na_conn_anchor(5, 1))

  expected <- vals
  expected[!is.na(expected)] <- 0L
  expect_equal(terra::values(out)[, 1], as.vector(t(expected)))
})

test_that("fl_patch_conn keeps the slope.tif NA border ring NA (#65)", {
  dem <- terra::rast(testdata_path("dem.tif"))
  slope <- terra::rast(testdata_path("slope.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  stream_r <- fl_stream_rasterize(streams_sf, dem, field = "upstream_area_ha")
  gentle <- fl_mask(slope, threshold = 9, operator = "<=")
  na_in <- which(is.na(terra::values(gentle)[, 1]))
  # Fixture reaches the case: the ring is there to be zeroed.
  expect_equal(length(na_in), 2892L)

  connected <- fl_patch_conn(gentle, stream_r)

  expect_identical(which(is.na(terra::values(connected)[, 1])), na_in)
})
