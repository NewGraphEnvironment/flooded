test_that("fl_flood_depth returns zero at stream cells", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  stream_r <- fl_stream_rasterize(streams_sf, dem, field = "channel_width")

  surface <- fl_flood_surface(dem, stream_r)
  depth <- fl_flood_depth(dem, surface, streams = stream_r)

  expect_s4_class(depth, "SpatRaster")
  expect_equal(names(depth), "flood_depth")

  # Stream cells should be 0
  stream_cells <- which(!is.na(terra::values(stream_r)))
  expect_true(all(terra::values(depth)[stream_cells] == 0))
})

test_that("fl_flood_depth has positive values near streams", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  stream_r <- fl_stream_rasterize(streams_sf, dem, field = "channel_width")

  surface <- fl_flood_surface(dem, stream_r)
  depth <- fl_flood_depth(dem, surface, streams = stream_r)

  vals <- terra::values(depth, na.rm = TRUE)
  # Should have some flooded cells (depth > 0)
  expect_true(sum(vals > 0) > 0)
  # All non-NA values should be >= 0
  expect_true(all(vals >= 0))
})

test_that("fl_flood_depth corridor narrows with smaller max_width", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  stream_r <- fl_stream_rasterize(streams_sf, dem, field = "channel_width")

  surface <- fl_flood_surface(dem, stream_r)
  wide <- fl_flood_depth(dem, surface, max_width = 2000, streams = stream_r)
  narrow <- fl_flood_depth(dem, surface, max_width = 200, streams = stream_r)

  n_wide <- sum(!is.na(terra::values(wide)))
  n_narrow <- sum(!is.na(terra::values(narrow)))
  expect_true(n_wide > n_narrow)
})

test_that("fl_flood_depth errors on mismatched grids", {
  r1 <- terra::rast(nrows = 5, ncols = 5, vals = 100,
                    xmin = 0, xmax = 5, ymin = 0, ymax = 5)
  r2 <- terra::rast(nrows = 10, ncols = 10, vals = 110,
                    xmin = 0, xmax = 5, ymin = 0, ymax = 5)
  expect_error(fl_flood_depth(r1, r2), "same extent")
})

# --- Pooled default is unchanged (#68) ----------------------------------------------

test_that("the default method keeps the pooled interpolation's output", {
  # Pinned on main before #68 (6498d49) and re-pinned unchanged in round 2.
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  stream_r <- fl_stream_rasterize(streams_sf, dem, field = "upstream_area_ha")
  precip_r <- fl_stream_rasterize(streams_sf, dem, field = "map_upstream")
  surface <- fl_flood_surface(dem, stream_r, flood_factor = 6, precip = precip_r)

  d <- terra::values(fl_flood_depth(dem, surface, streams = stream_r), mat = FALSE)
  expect_equal(sum(!is.na(d)), 32178L)
  expect_equal(sum(d > 0, na.rm = TRUE), 30571L)
  expect_equal(sum(d, na.rm = TRUE), 65162.334854, tolerance = 1e-10)
  # ... and naming it explicitly is the same call.
  p <- terra::values(fl_flood_depth(dem, surface, streams = stream_r, method = "pooled"),
                     mat = FALSE)
  expect_identical(p, d)
})

test_that("fl_flood_depth validates method", {
  r <- terra::rast(nrows = 5, ncols = 5, vals = 100, xmin = 0, xmax = 5, ymin = 0, ymax = 5)
  expect_error(fl_flood_depth(r, r, method = "idw"), "pooled")
})

test_that("method = 'drainage' names whitebox when it is unavailable", {
  local_mocked_bindings(fl_has_whitebox = function() FALSE)
  r <- terra::rast(nrows = 5, ncols = 5, vals = 100, xmin = 0, xmax = 5, ymin = 0, ymax = 5)
  expect_error(fl_flood_depth(r, r, method = "drainage"), "whitebox")
})

# --- Drainage ownership (#68) --------------------------------------------------------
# A river down the middle of a valley (column 40) and a small creek crossing the floor
# toward it along row 30, stopping one cell short. The floor rises 0.2 m per cell away from the river and is flat
# down-valley, so every cell drains straight across to the river. The river's 4 m
# waterline reaches 20 cells out; the creek's own waterline is 0.1 m. Round 1 measured
# that a pooled interpolation loses 46 cells of the river's floodplain when the creek is
# added.
creek_fixture <- function() {
  dem <- terra::rast(nrows = 60, ncols = 80, xmin = 0, xmax = 800,
                     ymin = 0, ymax = 600, crs = "EPSG:3005")
  col <- terra::colFromCell(dem, seq_len(terra::ncell(dem)))
  terra::values(dem) <- 100 + 0.2 * abs(col - 40)
  z <- terra::values(dem, mat = FALSE)

  river <- terra::cellFromRowCol(dem, 1:60, 40)
  creek <- terra::cellFromRowCol(dem, 30, 5:38)
  build <- function(cells, depth) {
    s <- terra::rast(dem)
    v <- rep(NA_real_, terra::ncell(dem))
    v[cells] <- z[cells] + depth
    terra::values(s) <- v
    s
  }
  list(dem = dem, z = z, river = river, creek = creek,
       both = build(c(river, creek), c(rep(4, length(river)), rep(0.1, length(creek)))),
       river_only = build(river, 4))
}

test_that("the creek fixture reaches the pooled blend's failure", {
  # Without this, the monotone assertion below could pass on a fixture where the
  # creek never touches the river's waterline.
  f <- creek_fixture()
  alone <- fl_flood_depth(f$dem, f$river_only, max_width = 600)
  pooled <- fl_flood_depth(f$dem, f$both, max_width = 600)
  lost <- !is.na(terra::values(alone)) & is.na(terra::values(pooled))
  expect_gt(sum(lost), 20)
})

test_that("drainage: adding a creek never dries or shallows the river's floodplain", {
  skip_if_no_whitebox()
  f <- creek_fixture()
  alone <- terra::values(fl_flood_depth(f$dem, f$river_only, max_width = 600,
                                        method = "drainage"), mat = FALSE)
  both <- terra::values(fl_flood_depth(f$dem, f$both, max_width = 600,
                                       method = "drainage"), mat = FALSE)

  # Fixture reaches the case: the river alone floods ground on both sides.
  expect_gt(sum(alone > 0, na.rm = TRUE), 500)
  expect_true(all(!is.na(both[!is.na(alone)])))
  off_creek <- setdiff(which(!is.na(alone)), f$creek)
  expect_true(all(both[off_creek] >= alone[off_creek] - 1e-9))
})

test_that("drainage: a cell takes the highest waterline on its downstream path", {
  skip_if_no_whitebox()
  f <- creek_fixture()
  d <- fl_flood_depth(f$dem, f$both, max_width = 600, method = "drainage")
  at <- function(r, c) terra::values(d, mat = FALSE)[terra::cellFromRowCol(f$dem, r, c)]

  # A path cell's level is the lowest ground in its 3x3 window plus the deepest stream
  # depth in it. Row 10, column 30 (ground 102) drains east; at column 39 the window
  # holds the river (bed 100, depth 4), so its waterline is 104.
  expect_equal(at(10, 30), 2, tolerance = 1e-6)
  # Beside the creek the window's lowest ground is one cell toward the river, 0.2 m lower,
  # which is more than the creek's 0.1 m depth: row 29, column 20 (ground 104) gets the
  # river's 104 and is not flooded. This is the rule's stated low bias.
  expect_equal(at(29, 20), 0, tolerance = 1e-6)
  # Ground the river's 4 m cannot reach stays dry: column 15 is 105 m.
  expect_true(is.na(at(10, 15)))
  # Stream cells are 0, as in the pooled method.
  expect_true(all(terra::values(d, mat = FALSE)[c(f$river, f$creek)] == 0))
})

test_that("drainage: a cell whose path never nears a stream gets no waterline", {
  skip_if_no_whitebox()
  # One stream on the low side of a plane tilted west: ground east of it drains
  # through it. Ground west of it drains away from it and, beyond the stream's 3x3
  # window, is never flooded, however low (column 19 is in the window and floods).
  dem <- terra::rast(nrows = 20, ncols = 40, xmin = 0, xmax = 400,
                     ymin = 0, ymax = 200, crs = "EPSG:3005")
  col <- terra::colFromCell(dem, seq_len(terra::ncell(dem)))
  terra::values(dem) <- 100 + 0.1 * col
  s <- terra::rast(dem)
  v <- rep(NA_real_, terra::ncell(dem))
  st <- terra::cellFromRowCol(dem, 1:20, 20)
  v[st] <- terra::values(dem, mat = FALSE)[st] + 5
  terra::values(s) <- v

  d <- terra::values(fl_flood_depth(dem, s, max_width = 400, method = "drainage"), mat = FALSE)
  west <- terra::cellFromRowCol(dem, 10, 10)
  east <- terra::cellFromRowCol(dem, 10, 30)
  expect_true(is.na(d[west]))
  # Column 21's window holds the stream (bed 102, depth 5): 107 against ground 103.
  expect_equal(d[east], 107 - 103, tolerance = 1e-6)
})

test_that("drainage keeps NA DEM cells NA", {
  skip_if_no_whitebox()
  f <- creek_fixture()
  dem <- f$dem
  gap <- terra::cellFromRowCol(dem, 5:9, 30:34)
  dem[gap] <- NA
  d <- terra::values(fl_flood_depth(dem, terra::mask(f$both, dem), max_width = 600,
                                    method = "drainage"), mat = FALSE)
  expect_true(all(is.na(d[gap])))
  expect_gt(sum(d > 0, na.rm = TRUE), 0)
})

test_that("fl_path_max takes the max over each downstream path", {
  # 1 -> 2 -> 3 (end); 4 alone; 5 -> 1
  nxt <- c(2L, 3L, 3L, 4L, 1L)
  expect_equal(fl_path_max(nxt, c(NA, 5, 1, NA, 2)), c(5, 5, 1, NA, 5))
  # A 1,000-cell path, longer than nine doublings, still reaches its end.
  n <- 1000L
  expect_equal(fl_path_max(c(2:n, n), c(rep(NA, n - 1), 7))[1], 7)
})

test_that("fl_pointer_next decodes every ESRI D8 code", {
  # 3 x 3 grid, centre cell 5. ESRI: 1 E, 2 SE, 4 S, 8 SW, 16 W, 32 NW, 64 N, 128 NE,
  # row 1 at the top. A swapped direction would still give monotone output, so pin each.
  codes <- c(1, 2, 4, 8, 16, 32, 64, 128)
  expected <- c(6, 9, 8, 7, 4, 1, 2, 3)
  for (i in seq_along(codes)) {
    code <- rep(0, 9)
    code[5] <- codes[i]
    expect_equal(fl_pointer_next(code, 3L, 3L)[5], expected[i], info = paste("code", codes[i]))
  }
  # No outflow, NA and invalid codes point to themselves.
  expect_equal(fl_pointer_next(c(0, NA, 3, 0, 0, 0, 0, 0, 0), 3L, 3L)[1:3], 1:3)
  # Steps off each edge point to themselves.
  expect_equal(fl_pointer_next(rep(64, 9), 3L, 3L)[1:3], 1:3)   # north off the top
  expect_equal(fl_pointer_next(rep(4, 9), 3L, 3L)[7:9], 7:9)    # south off the bottom
  expect_equal(fl_pointer_next(rep(16, 9), 3L, 3L)[c(1, 4, 7)], c(1, 4, 7))  # west
  expect_equal(fl_pointer_next(rep(1, 9), 3L, 3L)[c(3, 6, 9)], c(3, 6, 9))   # east
})

test_that("fl_path_max reports which cell supplied the max", {
  nxt <- c(2L, 3L, 3L, 4L, 1L)
  r <- fl_path_max(nxt, c(NA, 5, 1, NA, 2), which = TRUE)
  expect_equal(r$max, c(5, 5, 1, NA, 5))
  expect_equal(r$from, c(2L, 2L, 3L, NA, 2L))
})

test_that("drainage: the conditioned D8 route only ever runs downhill", {
  skip_if_no_whitebox()
  dem <- terra::rast(testdata_path("dem.tif"))
  route <- fl_flow_route(dem)
  expect_length(route[["next"]], terra::ncell(dem))
  expect_true(all(route$z[route[["next"]]] <= route$z, na.rm = TRUE))
  # Deterministic: multi-threaded WhiteboxTools breaching was not (#68).
  expect_identical(fl_flow_route(dem), route)
})
