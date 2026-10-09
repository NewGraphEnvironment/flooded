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

# --- Per-watercourse surfaces (#68) ----------------------------------------------
# A river down the middle of a valley and a small creek crossing the floor to meet
# it. The floor rises 0.2 m per cell away from the river, so the river's 4 m
# waterline reaches ~20 cells out, while the creek's own waterline is 0.1 m. A
# pooled interpolation blends the two and pulls the river's waterline down around
# the creek; a per-watercourse one keeps the higher.
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
  both <- build(c(river, creek), c(rep(4, length(river)), rep(0.1, length(creek))))
  river_only <- build(river, 4)
  groups <- terra::rast(dem)
  g <- rep(NA_real_, terra::ncell(dem))
  g[river] <- 1
  g[creek] <- 2
  terra::values(groups) <- g
  list(dem = dem, both = both, river_only = river_only, groups = groups,
       river = river, creek = creek)
}

test_that("the creek fixture reaches the pooled blend's failure", {
  # Without this the superset assertion below could pass for a fixture where the
  # creek never touches the river's waterline.
  f <- creek_fixture()
  alone <- fl_flood_depth(f$dem, f$river_only, max_width = 600)
  pooled <- fl_flood_depth(f$dem, f$both, max_width = 600)

  lost <- !is.na(terra::values(alone)) & is.na(terra::values(pooled))
  # 46 cells measured on the pooled IDW (6498d49).
  expect_gt(sum(lost), 20)
})

test_that("adding a creek never dries ground its river floods", {
  f <- creek_fixture()
  alone <- terra::values(fl_flood_depth(f$dem, f$river_only, max_width = 600), mat = FALSE)
  grouped <- terra::values(fl_flood_depth(f$dem, f$both, max_width = 600,
                                          groups = f$groups), mat = FALSE)

  expect_true(all(!is.na(grouped[!is.na(alone)])))
  # Depth, not only extent: away from the creek's own cells nothing is shallower.
  off_creek <- setdiff(which(!is.na(alone)), f$creek)
  expect_true(all(grouped[off_creek] >= alone[off_creek] - 1e-9))
})

test_that("groups as a list of cell indices matches the raster form", {
  f <- creek_fixture()
  from_raster <- fl_flood_depth(f$dem, f$both, max_width = 600, groups = f$groups)
  from_list <- fl_flood_depth(f$dem, f$both, max_width = 600,
                              groups = list(f$river, f$creek))

  expect_equal(terra::values(from_list), terra::values(from_raster))
})

test_that("a cell may belong to more than one watercourse in the list form", {
  # The confluence cell is the river's; listing it in the creek's group too must
  # only add to the creek's surface, never take ground away.
  f <- creek_fixture()
  mouth <- terra::cellFromRowCol(f$dem, 30, 40)
  shared <- fl_flood_depth(f$dem, f$both, max_width = 600,
                           groups = list(f$river, c(f$creek, mouth)))
  separate <- fl_flood_depth(f$dem, f$both, max_width = 600,
                             groups = list(f$river, f$creek))

  s <- terra::values(shared, mat = FALSE)
  p <- terra::values(separate, mat = FALSE)
  expect_true(all(!is.na(s[!is.na(p)])))
})

test_that("one group reproduces the pooled interpolation exactly", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  stream_r <- fl_stream_rasterize(streams_sf, dem, field = "upstream_area_ha")
  surface <- fl_flood_surface(dem, stream_r)

  pooled <- fl_flood_depth(dem, surface, streams = stream_r)
  one <- terra::ifel(is.na(stream_r), NA, 1)
  grouped <- fl_flood_depth(dem, surface, streams = stream_r, groups = one)

  expect_equal(terra::values(grouped), terra::values(pooled))
})

test_that("groups = NULL keeps the pooled interpolation's output", {
  # Pinned on main before #68 (6498d49): the opt-out path must not move.
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  stream_r <- fl_stream_rasterize(streams_sf, dem, field = "upstream_area_ha")
  precip_r <- fl_stream_rasterize(streams_sf, dem, field = "map_upstream")
  surface <- fl_flood_surface(dem, stream_r, flood_factor = 6, precip = precip_r)

  d <- terra::values(fl_flood_depth(dem, surface, streams = stream_r), mat = FALSE)
  expect_equal(sum(!is.na(d)), 32178L)
  expect_equal(sum(d > 0, na.rm = TRUE), 30571L)
  expect_equal(sum(d, na.rm = TRUE), 65162.334854, tolerance = 1e-10)
})

test_that("fl_flood_depth validates groups", {
  f <- creek_fixture()
  wrong_grid <- terra::rast(nrows = 10, ncols = 10, vals = 1,
                            xmin = 0, xmax = 800, ymin = 0, ymax = 600)
  expect_error(fl_flood_depth(f$dem, f$both, groups = wrong_grid), "same extent")
  expect_error(fl_flood_depth(f$dem, f$both, groups = list(c(1, terra::ncell(f$dem) + 1))),
               "cell")
  expect_error(fl_flood_depth(f$dem, f$both, groups = "blue_line_key"), "groups")
})
