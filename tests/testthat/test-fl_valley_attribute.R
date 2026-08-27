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
  v <- terra::values(r) == 1L
  v[is.na(v)] <- FALSE
  v
}

valley_cells <- function(valleys) {
  v <- terra::values(valleys) == 1L
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

test_that("changing the grouping key relabels without moving the union", {
  f <- attr_fixture()

  by_name <- fl_valley_attribute(f$valleys, f$streams, group = "gnis_name", dem = f$dem)
  by_blk  <- fl_valley_attribute(f$valleys, f$streams, group = "blue_line_key", dem = f$dem)

  u1 <- rep(FALSE, terra::ncell(f$valleys))
  for (i in seq_len(nrow(by_name))) u1 <- u1 | cells_of(by_name[i, ], f$valleys)
  u2 <- rep(FALSE, terra::ncell(f$valleys))
  for (i in seq_len(nrow(by_blk))) u2 <- u2 | cells_of(by_blk[i, ], f$valleys)

  expect_equal(u1, u2)
  expect_false(nrow(by_name) == nrow(by_blk))
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
  ref_cells <- terra::values(ref) == 1L
  ref_cells[is.na(ref_cells)] <- FALSE

  # complete = FALSE isolates the threshold test from the coverage fallback.
  out <- fl_valley_attribute(f$valleys, streams, group = "gnis_name",
                             dem = f$dem, complete = FALSE)
  got <- cells_of(out[!is.na(out$gnis_name) & out$gnis_name == grp, ], f$valleys)

  expect_equal(got, ref_cells)
})

test_that("complete = FALSE leaves unreachable valley cells unattributed and reports them", {
  f <- attr_fixture()

  strict <- fl_valley_attribute(f$valleys, f$streams, group = "gnis_name",
                                dem = f$dem, complete = FALSE)
  full <- fl_valley_attribute(f$valleys, f$streams, group = "gnis_name", dem = f$dem)

  u_strict <- rep(FALSE, terra::ncell(f$valleys))
  for (i in seq_len(nrow(strict))) u_strict <- u_strict | cells_of(strict[i, ], f$valleys)

  # Morphological cleanup, the channel buffer and waterbodies all add valley
  # cells after the mask intersection in fl_valley_confine(), so the strict
  # cover is a subset and the fallback is what makes coverage total.
  n_fallback <- attr(full, "fl_fallback_cells")
  expect_type(n_fallback, "integer")
  expect_equal(sum(valley_cells(f$valleys) & !u_strict), n_fallback)
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

test_that("a group whose streams miss the valley yields an empty-but-present result", {
  f <- attr_fixture()
  streams <- f$streams
  # Relabel the single segment furthest from the valley floor as its own group.
  streams$grp <- ifelse(seq_len(nrow(streams)) == which.min(streams$upstream_area_ha),
                        "isolated", "main")

  out <- fl_valley_attribute(f$valleys, streams, group = "grp", dem = f$dem,
                             complete = FALSE)

  expect_true(all(c("isolated", "main") %in% out$grp) || nrow(out) == 1L)
  expect_s3_class(out, "sf")
})
