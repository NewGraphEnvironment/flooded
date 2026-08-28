# Shared fixtures — fl_valley_confine() is ~1.4 s on the bundled tile, so build
# the delineation once and reuse it across tests.
attr_fixture <- local({
  cache <- NULL
  function() {
    if (is.null(cache)) {
      dem <- terra::rast(testdata_path("dem.tif"))
      streams <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
      precip_r <- fl_stream_rasterize(streams, dem, field = "map_upstream")
      valleys <- fl_valley_confine(dem, streams,
                                   field = "upstream_area_ha", precip = precip_r)
      cache <<- list(dem = dem, streams = streams, valleys = valleys)
    }
    cache
  }
})

# Rasterize an attribution result back onto the valley grid so cell sets can be
# compared exactly. Polygons come from cells, so their edges fall on cell edges
# and centre-based rasterization recovers the original cells.
cells_of <- function(x, template) {
  r <- terra::rasterize(terra::vect(x), template, field = 1L, background = 0L)
  v <- as.vector(terra::values(r)) == 1L
  v[is.na(v)] <- FALSE
  v
}

valley_cells <- function(valleys) {
  v <- as.vector(terra::values(valleys)) == 1L
  v[is.na(v)] <- FALSE
  v
}

test_that("fl_valley_attribute returns one sf row per group, keyed by the group column", {
  f <- attr_fixture()

  out <- fl_valley_attribute(f$valleys, f$streams, group = "gnis_name", dem = f$dem)

  expect_s3_class(out, "sf")
  expect_true("gnis_name" %in% names(out))
  expect_setequal(out$gnis_name, unique(f$streams$gnis_name))
  expect_equal(sf::st_crs(out), sf::st_crs(f$valleys))
  expect_true(all(sf::st_is_valid(out)))
})

test_that("every valley cell is attributed to at least one group", {
  f <- attr_fixture()

  out <- fl_valley_attribute(f$valleys, f$streams, group = "gnis_name", dem = f$dem)

  covered <- rep(FALSE, terra::ncell(f$valleys))
  for (i in seq_len(nrow(out))) covered <- covered | cells_of(out[i, ], f$valleys)

  expect_gt(sum(valley_cells(f$valleys)), 0)
  expect_equal(sum(valley_cells(f$valleys) & !covered), 0)
})

test_that("attribution invents no ground outside the delineation", {
  f <- attr_fixture()

  out <- fl_valley_attribute(f$valleys, f$streams, group = "gnis_name", dem = f$dem)

  for (i in seq_len(nrow(out))) {
    expect_equal(sum(cells_of(out[i, ], f$valleys) & !valley_cells(f$valleys)), 0)
  }
})

test_that("overlap at confluences is preserved, not resolved to one watercourse", {
  f <- attr_fixture()

  out <- fl_valley_attribute(f$valleys, f$streams, group = "gnis_name", dem = f$dem)

  n_per_group <- vapply(seq_len(nrow(out)),
                        function(i) sum(cells_of(out[i, ], f$valleys)), integer(1))
  union_cells <- rep(FALSE, terra::ncell(f$valleys))
  for (i in seq_len(nrow(out))) union_cells <- union_cells | cells_of(out[i, ], f$valleys)

  # Shared ground means the parts sum to more than the whole.
  expect_gt(sum(n_per_group), sum(union_cells))
})

test_that("a single constant group reproduces the whole delineation", {
  f <- attr_fixture()
  streams <- f$streams
  streams$one <- "all"

  out <- fl_valley_attribute(f$valleys, streams, group = "one", dem = f$dem)

  expect_equal(nrow(out), 1L)
  expect_equal(cells_of(out, f$valleys), valley_cells(f$valleys))
})

test_that("a coarser grouping is exactly the union of its finer members", {
  # gnis_name and blue_line_key are a bijection on this tile (5 groups each), so
  # comparing them proves nothing. Build a genuine two-level coarsening instead.
  f <- attr_fixture()
  streams <- f$streams
  fine <- ifelse(is.na(streams$gnis_name), "unnamed", streams$gnis_name)
  streams$fine <- fine
  streams$coarse <- ifelse(fine %in% c("Bulkley River", "unnamed"), "A", "B")

  by_fine <- fl_valley_attribute(f$valleys, streams, group = "fine", dem = f$dem)
  by_coarse <- fl_valley_attribute(f$valleys, streams, group = "coarse", dem = f$dem)

  expect_equal(nrow(by_fine), 5L)
  expect_equal(nrow(by_coarse), 2L)

  for (cg in c("A", "B")) {
    members <- unique(streams$fine[streams$coarse == cg])
    u_fine <- rep(FALSE, terra::ncell(f$valleys))
    for (m in members) {
      u_fine <- u_fine | cells_of(by_fine[by_fine$fine == m, ], f$valleys)
    }
    expect_equal(cells_of(by_coarse[by_coarse$coarse == cg, ], f$valleys), u_fine)
  }
})

test_that("coverage still holds when the cost threshold is binding", {
  # At package defaults the criteria are not binding on this tile, so a coverage
  # test there can pass for the wrong reason. Squeeze cost_threshold until
  # morphological cleanup can push cells past it.
  f <- attr_fixture()

  out <- fl_valley_attribute(f$valleys, f$streams, group = "gnis_name",
                             dem = f$dem, cost_threshold = 300)

  covered <- rep(FALSE, terra::ncell(f$valleys))
  for (i in seq_len(nrow(out))) covered <- covered | cells_of(out[i, ], f$valleys)

  expect_gt(attr(out, "fl_fallback_cells"), 0)
  expect_equal(sum(valley_cells(f$valleys) & !covered), 0)
})

test_that("group counts and overlap are anchored, not merely non-zero", {
  f <- attr_fixture()

  out <- fl_valley_attribute(f$valleys, f$streams, group = "gnis_name", dem = f$dem)

  expect_equal(nrow(out), 5L)

  per_group <- vapply(seq_len(nrow(out)),
                      function(i) sum(cells_of(out[i, ], f$valleys)), integer(1))
  expect_true(all(per_group > 0))

  # Measured 2.45x on this tile; assert a band so the test fails if overlap
  # collapses to a partition or explodes.
  ratio <- sum(per_group) / sum(valley_cells(f$valleys))
  expect_gt(ratio, 1.5)
  expect_lt(ratio, 3.5)
})

test_that("corridor cropping does not change the answer", {
  # Oracle: compute one group's membership on the full grid with no cropping,
  # using the same exported primitives the function is built from.
  f <- attr_fixture()
  streams <- f$streams
  grp <- "Cesford Creek"

  sub <- streams[!is.na(streams$gnis_name) & streams$gnis_name == grp, ]
  sub$seed <- 1
  slope_deg <- terra::terrain(f$dem, "slope", unit = "degrees")
  slope <- tan(slope_deg * pi / 180) * 100
  seeds <- fl_stream_rasterize(sub, f$dem, field = "seed")
  ref <- f$valleys *
    fl_mask_distance(seeds, threshold = 2000 / 2) *
    fl_mask(fl_cost_distance(slope, seeds), threshold = 2500, operator = "<")
  ref_cells <- as.vector(terra::values(ref)) == 1L
  ref_cells[is.na(ref_cells)] <- FALSE

  # complete = FALSE isolates the threshold test from the coverage fallback.
  out <- fl_valley_attribute(f$valleys, streams, group = "gnis_name",
                             dem = f$dem, complete = FALSE)
  got <- cells_of(out[!is.na(out$gnis_name) & out$gnis_name == grp, ], f$valleys)

  expect_equal(got, ref_cells)
})

test_that("waterbody cells beyond every group's thresholds are still covered", {
  # fl_valley_confine() ORs waterbody polygons into the output with no spatial
  # filter (fl_valley_confine.R:213-220), so a lake can sit outside every
  # group's distance and cost thresholds. The coverage fallback is what keeps
  # those cells attributed.
  f <- attr_fixture()
  wb <- sf::st_read(testdata_path("waterbodies.gpkg"), quiet = TRUE)
  precip_r <- fl_stream_rasterize(f$streams, f$dem, field = "map_upstream")
  valleys_wb <- fl_valley_confine(f$dem, f$streams, field = "upstream_area_ha",
                                  precip = precip_r, waterbodies = wb)

  strict <- fl_valley_attribute(valleys_wb, f$streams, group = "gnis_name",
                                dem = f$dem, complete = FALSE)
  full <- fl_valley_attribute(valleys_wb, f$streams, group = "gnis_name",
                              dem = f$dem)

  u_strict <- rep(FALSE, terra::ncell(valleys_wb))
  for (i in seq_len(nrow(strict))) u_strict <- u_strict | cells_of(strict[i, ], valleys_wb)
  u_full <- rep(FALSE, terra::ncell(valleys_wb))
  for (i in seq_len(nrow(full))) u_full <- u_full | cells_of(full[i, ], valleys_wb)

  n_fallback <- attr(full, "fl_fallback_cells")
  expect_type(n_fallback, "integer")

  # The fallback must actually fire here, or the rest of this test is vacuous.
  expect_gt(n_fallback, 0)
  expect_equal(sum(valley_cells(valleys_wb) & !u_strict), n_fallback)
  expect_equal(sum(valley_cells(valleys_wb) & !u_full), 0)
})

test_that("NA group values form their own group and stay covered", {
  f <- attr_fixture()
  expect_true(any(is.na(f$streams$gnis_name)))

  out <- fl_valley_attribute(f$valleys, f$streams, group = "gnis_name", dem = f$dem)

  expect_equal(sum(is.na(out$gnis_name)), 1L)
  expect_gt(sum(cells_of(out[is.na(out$gnis_name), ], f$valleys)), 0)
})

test_that("fl_valley_attribute does not mutate its inputs", {
  f <- attr_fixture()
  before <- terra::values(f$valleys)

  fl_valley_attribute(f$valleys, f$streams, group = "gnis_name", dem = f$dem)

  expect_equal(terra::values(f$valleys), before)
})

test_that("fl_valley_attribute rejects bad input", {
  f <- attr_fixture()

  expect_error(
    fl_valley_attribute(f$valleys, f$streams, group = "not_a_column", dem = f$dem),
    "not_a_column"
  )
  expect_error(
    fl_valley_attribute(f$valleys, sf::st_drop_geometry(f$streams),
                        group = "gnis_name", dem = f$dem),
    "sf"
  )
  expect_error(
    fl_valley_attribute(f$valleys, f$streams, group = c("gnis_name", "blue_line_key"),
                        dem = f$dem),
    "length"
  )
  expect_error(
    fl_valley_attribute(f$valleys, f$streams, group = "gnis_name"),
    "slope|dem"
  )

  shifted <- terra::shift(f$dem, dx = 100000)
  expect_error(
    fl_valley_attribute(f$valleys, f$streams, group = "gnis_name", dem = shifted),
    "extent|resolution|CRS"
  )
})

test_that("a group whose streams fall outside the raster is named, not silently dropped", {
  f <- attr_fixture()
  far <- f$streams[1, ]
  sf::st_geometry(far) <- sf::st_geometry(far) + c(5e5, 5e5)
  sf::st_crs(far) <- sf::st_crs(f$streams)
  far$gnis_name <- "Elsewhere River"
  combined <- rbind(f$streams, far)

  expect_warning(
    out <- fl_valley_attribute(f$valleys, combined, group = "gnis_name", dem = f$dem),
    "Elsewhere River"
  )
  # Dropped rather than returned as an empty row — but never silently.
  expect_false("Elsewhere River" %in% out$gnis_name)
})

test_that("a delineation with no valley cells returns a usable empty sf", {
  # The zero-parts branch is easy to build wrong: renaming an sf column by
  # position detaches the geometry column and every accessor then errors.
  f <- attr_fixture()
  empty_valleys <- f$valleys * 0L

  out <- suppressWarnings(
    fl_valley_attribute(empty_valleys, f$streams, group = "gnis_name", dem = f$dem)
  )

  expect_s3_class(out, "sf")
  expect_equal(nrow(out), 0L)
  expect_true("gnis_name" %in% names(out))
  expect_equal(attr(out, "sf_column"), "geometry")
  expect_silent(sf::st_geometry(out))
  expect_equal(sf::st_crs(out), sf::st_crs(f$valleys))
  expect_output(print(out))
})

test_that("a group whose segments miss every cell centre warns instead of vanishing", {
  # fl_stream_rasterize() uses touches = FALSE, so a sub-cell segment burns
  # nothing. At k = 340 blue_line_keys this is near-certain, not hypothetical.
  f <- attr_fixture()
  streams <- f$streams

  # Put a 0.4 m segment at a cell CORNER, where no cell centre can be crossed.
  centre <- terra::xyFromCell(f$valleys, terra::ncell(f$valleys) %/% 2L)
  corner <- centre + terra::res(f$valleys) / 2
  coords <- rbind(corner + 0.1, corner + 0.5)

  tiny <- streams[1, ]
  sf::st_geometry(tiny) <- sf::st_sfc(sf::st_linestring(coords),
                                      crs = sf::st_crs(streams))
  tiny$gnis_name <- "Subpixel Creek"
  combined <- rbind(streams, tiny)

  expect_warning(
    fl_valley_attribute(f$valleys, combined, group = "gnis_name", dem = f$dem),
    "Subpixel Creek"
  )
})

test_that("a group named as omitted is genuinely absent from the output", {
  # The dropped-group warning must be raised AFTER the coverage fallback: a group
  # with zero threshold cells can still win uncovered cells as nearest-group, and
  # naming it "omitted" while returning it is worse than saying nothing.
  f <- attr_fixture()
  vals <- as.vector(terra::values(f$valleys))

  # A stream sitting on non-valley ground, close enough to the valley edge to be
  # the nearest group for some uncovered cells.
  valley_xy <- terra::xyFromCell(f$valleys, which(!is.na(vals) & vals == 1L)[1])
  non_valley <- which(!is.na(vals) & vals == 0L)
  nv_xy <- terra::xyFromCell(f$valleys, non_valley)
  d <- sqrt((nv_xy[, 1] - valley_xy[1])^2 + (nv_xy[, 2] - valley_xy[2])^2)
  seed_xy <- nv_xy[which.min(d), ]

  ghost <- f$streams[1, ]
  sf::st_geometry(ghost) <- sf::st_sfc(
    sf::st_linestring(rbind(seed_xy, seed_xy + c(20, 0))),
    crs = sf::st_crs(f$streams)
  )
  ghost$gnis_name <- "Ghost Creek"
  combined <- rbind(f$streams, ghost)

  # max_width = 10 makes the distance criterion bite, so most cells go to the
  # fallback and Ghost Creek can pick some up despite scoring zero on thresholds.
  warned <- character(0)
  out <- withCallingHandlers(
    fl_valley_attribute(f$valleys, combined, group = "gnis_name", dem = f$dem,
                        max_width = 10),
    warning = function(w) {
      warned <<- c(warned, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )

  groups <- as.character(stats::na.omit(unique(combined$gnis_name)))
  named <- groups[vapply(groups, function(g) any(grepl(g, warned, fixed = TRUE)),
                         logical(1))]

  # Ghost Creek scores zero on the thresholds but wins fallback cells, which is
  # the precondition for the bug this pins — assert it, or the test is vacuous.
  expect_true("Ghost Creek" %in% as.character(out$gnis_name))
  expect_equal(intersect(named, as.character(out$gnis_name)), character(0))
})

test_that("empty geometries do not abort the whole attribution", {
  # Routine after st_intersection() clipping; terra::ext() errors on them.
  f <- attr_fixture()
  broken <- f$streams[1, ]
  sf::st_geometry(broken) <- sf::st_sfc(sf::st_linestring(), crs = sf::st_crs(f$streams))
  broken$gnis_name <- "Empty Creek"
  combined <- rbind(f$streams, broken)

  expect_warning(
    out <- fl_valley_attribute(f$valleys, combined, group = "gnis_name", dem = f$dem),
    "Empty Creek"
  )
  expect_equal(nrow(out), 5L)
})

test_that("group = 'geometry' is rejected rather than clobbering the geometry column", {
  f <- attr_fixture()
  streams <- f$streams
  streams$geometry <- ifelse(is.na(streams$gnis_name), "unnamed", streams$gnis_name)

  expect_error(
    fl_valley_attribute(f$valleys, streams, group = "geometry", dem = f$dem),
    "geometry"
  )
})
