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
