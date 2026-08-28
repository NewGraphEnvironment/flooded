test_that("fl_cost_distance returns SpatRaster with zero at stream cells", {
  dem <- terra::rast(testdata_path("dem.tif"))
  slope <- terra::rast(testdata_path("slope.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  stream_r <- fl_stream_rasterize(streams_sf, dem, field = "channel_width")
  cd <- fl_cost_distance(slope, stream_r)

  expect_s4_class(cd, "SpatRaster")
  expect_equal(dim(cd), dim(slope))
  expect_equal(names(cd), "cost_distance")

  # Stream cells should have cost 0
  stream_mask <- !is.na(terra::values(stream_r))
  cd_vals <- terra::values(cd)
  expect_true(all(cd_vals[stream_mask] == 0, na.rm = TRUE))
})

test_that("fl_cost_distance increases away from streams", {
  dem <- terra::rast(testdata_path("dem.tif"))
  slope <- terra::rast(testdata_path("slope.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  stream_r <- fl_stream_rasterize(streams_sf, dem, field = "channel_width")
  cd <- fl_cost_distance(slope, stream_r)

  cd_vals <- terra::values(cd)
  # Non-stream, non-NA cells should have positive cost
  stream_mask <- !is.na(terra::values(stream_r))
  non_stream <- !stream_mask & !is.na(cd_vals)
  expect_true(all(cd_vals[non_stream] > 0))
})

test_that("fl_cost_distance works on small synthetic raster", {
  # 5x5 grid, stream in middle column, flat slope = 1 everywhere
  friction <- terra::rast(nrows = 5, ncols = 5, vals = rep(1, 25),
                          xmin = 0, xmax = 50, ymin = 0, ymax = 50,
                          crs = "EPSG:3005")
  stream_vals <- rep(NA, 25)
  stream_vals[c(3, 8, 13, 18, 23)] <- 10  # middle column

  streams <- terra::rast(nrows = 5, ncols = 5, vals = stream_vals,
                         xmin = 0, xmax = 50, ymin = 0, ymax = 50,
                         crs = "EPSG:3005")

  cd <- fl_cost_distance(friction, streams)

  vals <- terra::values(cd)
  # Middle column (cells 3,8,13,18,23) should be 0
  expect_true(all(vals[c(3, 8, 13, 18, 23)] == 0))
  # Adjacent columns should have lower cost than edge columns
  expect_true(all(vals[c(2, 7, 12, 17, 22)] < vals[c(1, 6, 11, 16, 21)]))
})

test_that("fl_cost_distance errors on mismatched grids", {
  r1 <- terra::rast(nrows = 5, ncols = 5, vals = 1,
                    xmin = 0, xmax = 5, ymin = 0, ymax = 5)
  r2 <- terra::rast(nrows = 10, ncols = 10, vals = 1,
                    xmin = 0, xmax = 5, ymin = 0, ymax = 5)

  expect_error(fl_cost_distance(r1, r2), "same extent")
})

# --- Zero-friction cells must not seed (#41) -------------------------------
#
# The bundled tile cannot reach this failure mode: slope.tif has no cell equal
# to zero (min 1.42e-14), and neither does slope derived from dem.tif. These
# fixtures are synthetic for that reason, not for convenience.

# 50x50 at 10 m, friction 10% everywhere, one stream cell at [45, 45].
# `flat` adds a 6x6 patch of exactly-zero friction at rows/cols 10-15, far from
# the stream — the shape a hydro-flattened lake or a void-filled plateau takes.
zero_friction_grid <- function(flat = TRUE) {
  friction <- terra::rast(nrows = 50, ncols = 50, vals = 10,
                          xmin = 0, xmax = 500, ymin = 0, ymax = 500,
                          crs = "EPSG:3005")
  if (flat) friction[10:15, 10:15] <- 0
  streams <- terra::rast(friction)
  terra::values(streams) <- NA
  streams[45, 45] <- 1
  list(friction = friction, streams = streams)
}

test_that("only stream cells are cost-distance seeds", {
  g <- zero_friction_grid()

  # Premise: the fixture must actually contain exact-zero friction, or the
  # assertion below passes for nothing.
  expect_gt(sum(terra::values(g$friction, mat = FALSE) == 0, na.rm = TRUE), 0)

  cd <- fl_cost_distance(g$friction, g$streams)

  zero_cells <- which(terra::values(cd, mat = FALSE) == 0)
  seed_cells <- which(!is.na(terra::values(g$streams, mat = FALSE)))
  expect_equal(zero_cells, seed_cells)
})

test_that("a flat patch is not a cost sink", {
  g <- zero_friction_grid()
  cd <- fl_cost_distance(g$friction, g$streams)

  # Under the bug the patch centre reads 0 — cheaper than ground adjacent to
  # the stream itself, which is the tell.
  expect_gt(cd[12, 12][[1]], cd[45, 44][[1]])
})

test_that("flooring makes flat ground cheap to cross, not a barrier", {
  # The opposite over-correction — flooring to 1, or to the median friction —
  # would satisfy every assertion above while making flat ground expensive.
  # A path through genuinely flat ground must still cost less than an
  # equal-length path over sloped ground.
  flat <- zero_friction_grid(flat = TRUE)
  ctrl <- zero_friction_grid(flat = FALSE)

  through_flat <- fl_cost_distance(flat$friction, flat$streams)[12, 12][[1]]
  over_slope <- fl_cost_distance(ctrl$friction, ctrl$streams)[12, 12][[1]]

  expect_lt(through_flat, over_slope)
})

test_that("negative friction still errors", {
  # terra rejects a negative cost surface. Flooring `<= 0` rather than `== 0`
  # would silently disable that guard and turn meaningless input into
  # plausible-looking output.
  friction <- terra::rast(nrows = 20, ncols = 20, vals = 10,
                          xmin = 0, xmax = 200, ymin = 0, ymax = 200,
                          crs = "EPSG:3005")
  friction[5, 5] <- -3
  streams <- terra::rast(friction)
  terra::values(streams) <- NA
  streams[18, 18] <- 1

  expect_error(fl_cost_distance(friction, streams), "negative friction")
})

test_that("integer-typed friction survives the floor", {
  # An integer raster must promote to float, or the floor rounds back to zero
  # and the fix silently does nothing.
  friction <- terra::rast(nrows = 20, ncols = 20,
                          xmin = 0, xmax = 200, ymin = 0, ymax = 200,
                          crs = "EPSG:3005")
  terra::values(friction) <- rep(10L, 400)
  friction[5:8, 5:8] <- 0L

  tf <- tempfile(fileext = ".tif")
  on.exit(unlink(tf), add = TRUE)
  terra::writeRaster(friction, tf, datatype = "INT2S", overwrite = TRUE)
  friction <- terra::rast(tf)
  expect_equal(terra::datatype(friction), "INT2S")

  streams <- terra::rast(friction)
  terra::values(streams) <- NA
  streams[18, 18] <- 1

  cd <- fl_cost_distance(friction, streams)
  expect_equal(sum(terra::values(cd, mat = FALSE) == 0, na.rm = TRUE), 1L)
})

test_that("NA friction remains an impassable barrier", {
  friction <- terra::rast(nrows = 20, ncols = 20, vals = 10,
                          xmin = 0, xmax = 200, ymin = 0, ymax = 200,
                          crs = "EPSG:3005")
  friction[, 10] <- NA  # a wall the full height of the grid
  streams <- terra::rast(friction)
  terra::values(streams) <- NA
  streams[1, 1] <- 1

  cd <- fl_cost_distance(friction, streams)

  expect_true(is.na(cd[10, 15][[1]]))   # sealed off behind the wall
  expect_true(is.na(cd[10, 10][[1]]))   # the wall itself
  expect_false(is.na(cd[10, 5][[1]]))   # same side as the stream
})

test_that("the fix cannot move any bundled-data result", {
  slope <- terra::rast(testdata_path("slope.tif"))
  dem <- terra::rast(testdata_path("dem.tif"))

  # Premise, asserted here so a future test-data swap fails on this line —
  # naming the real cause — rather than somewhere downstream. Every
  # bundled-data baseline in this suite rests on it.
  expect_equal(sum(terra::values(slope, mat = FALSE) == 0, na.rm = TRUE), 0L)

  # The slope = NULL path in fl_valley_confine() derives slope rather than
  # reading it, so it needs the premise checked too.
  slope_deg <- terra::terrain(dem, "slope", unit = "degrees")
  derived <- tan(slope_deg * pi / 180) * 100
  expect_equal(sum(terra::values(derived, mat = FALSE) == 0, na.rm = TRUE), 0L)

  # Cost is the only route by which this change reaches fl_valley_confine() or
  # fl_valley_attribute(), so equality here covers both.
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  stream_r <- fl_stream_rasterize(streams_sf, dem, field = "channel_width")

  unfloored <- terra::costDist(terra::ifel(!is.na(stream_r), 0, slope), target = 0)
  expect_equal(
    as.vector(terra::values(fl_cost_distance(slope, stream_r))),
    as.vector(terra::values(unfloored))
  )
})
