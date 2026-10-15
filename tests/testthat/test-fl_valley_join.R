# Synthetic fixtures: a 10 x 10 grid of 10 m cells, groups claiming rectangles
# whose edges fall on cell edges, and hand-placed segments. The bundled tile
# cannot pin these rules: on it 49 of 50 segments carry the same habitat flags.

jn_grid <- function(valley = 1L) {
  r <- terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 100,
                   ymin = 0, ymax = 100, crs = "EPSG:3005")
  terra::values(r) <- valley
  r
}

# One attributed row per element of `rects`, each c(xmin, xmax, ymin, ymax).
jn_attr <- function(rects, keys, group = "grp") {
  geoms <- lapply(rects, function(b) {
    sf::st_polygon(list(rbind(c(b[1], b[3]), c(b[2], b[3]), c(b[2], b[4]),
                              c(b[1], b[4]), c(b[1], b[3]))))
  })
  x <- list(valley = rep(1L, length(rects)))
  x[[group]] <- keys
  x$geometry <- sf::st_sfc(geoms, crs = 3005)
  sf::st_sf(x, sf_column_name = "geometry")
}

# One segment per row of `d` (columns grp, x0, y0, x1, y1, plus flag columns).
jn_segs <- function(d, group = "grp") {
  geoms <- lapply(seq_len(nrow(d)), function(i) {
    sf::st_linestring(rbind(c(d$x0[i], d$y0[i]), c(d$x1[i], d$y1[i])))
  })
  out <- d[, setdiff(names(d), c("x0", "y0", "x1", "y1")), drop = FALSE]
  names(out)[names(out) == "grp"] <- group
  out$geometry <- sf::st_sfc(geoms, crs = 3005)
  sf::st_sf(out, sf_column_name = "geometry")
}

# Value of `col` at the cell whose centre is (x, y).
jn_at <- function(tab, r, x, y, col) {
  tab[[col]][match(terra::cellFromXY(r, cbind(x, y)), tab$cell)]
}

# A claims x 0-60, B claims x 40-100; A's segment runs up x = 5 (FALSE), B's up
# x = 95 (TRUE). Cells centred at x = 45 and 55 are shared.
jn_two <- function() {
  r <- jn_grid()
  a <- jn_attr(list(c(0, 60, 0, 100), c(40, 100, 0, 100)), c("A", "B"))
  s <- jn_segs(data.frame(grp = c("A", "B"), x0 = c(5, 95), y0 = 0,
                          x1 = c(5, 95), y1 = 100, flag = c(FALSE, TRUE)))
  list(r = r, a = a, s = s)
}

test_that("fl_valley_join returns nearest and any tables, one row per valley cell", {
  f <- jn_two()

  out <- fl_valley_join(f$r, f$a, f$s, group = "grp")

  expect_named(out, c("nearest", "any", "check", "ties", "no_segments"))
  expect_named(out$nearest, c("cell", "grp", "dist", "flag"))
  expect_named(out$any, c("cell", "flag"))
  expect_equal(out$nearest$cell, seq_len(100))
  expect_equal(out$any$cell, seq_len(100))
  expect_equal(out$check,
               c(valley_cells = 100L, attributed_cells = 100L, missing = 0L, extra = 0L))
  expect_type(out$nearest$flag, "logical")
})

test_that("shared cells: nearest takes one owner, any takes every claimer", {
  f <- jn_two()

  out <- fl_valley_join(f$r, f$a, f$s, group = "grp")

  # x = 45: A's segment 40 m away, B's 50 m away. A owns it; B still says TRUE.
  expect_equal(jn_at(out$nearest, f$r, 45, 55, "grp"), "A")
  expect_equal(jn_at(out$nearest, f$r, 45, 55, "dist"), 40)
  expect_false(jn_at(out$nearest, f$r, 45, 55, "flag"))
  expect_true(jn_at(out$any, f$r, 45, 55, "flag"))
  # x = 55: B nearer, so both resolutions say TRUE.
  expect_equal(jn_at(out$nearest, f$r, 55, 55, "grp"), "B")
  expect_true(jn_at(out$nearest, f$r, 55, 55, "flag"))
  # Unshared cells agree.
  expect_false(jn_at(out$any, f$r, 15, 55, "flag"))
  expect_true(jn_at(out$any, f$r, 85, 55, "flag"))

  # Areas: nearest partitions the valley, any is a superset of it.
  expect_equal(sum(out$nearest$flag), 50)
  expect_equal(sum(out$any$flag), 60)
  expect_true(all(out$any$flag[out$nearest$flag]))
})

test_that("a cell takes its own group's NEAREST segment, not any segment on the group", {
  # A by-key join reads all of A as TRUE because A carries a TRUE segment.
  r <- jn_grid()
  a <- jn_attr(list(c(0, 100, 0, 100)), "A")
  s <- jn_segs(data.frame(grp = "A", x0 = 5, y0 = c(0, 50), x1 = 5, y1 = c(50, 100),
                          flag = c(FALSE, TRUE)))

  out <- fl_valley_join(r, a, s, group = "grp")

  expect_false(jn_at(out$nearest, r, 55, 15, "flag"))
  expect_true(jn_at(out$nearest, r, 55, 85, "flag"))
  expect_equal(sum(out$nearest$flag), 50)
  expect_equal(sum(out$any$flag), 50)
})

test_that("only claiming groups compete: a nearer segment on an unclaiming group is ignored", {
  # C's TRUE segment runs through the middle of A's ground, but C claims nothing.
  r <- jn_grid()
  a <- jn_attr(list(c(0, 100, 0, 100)), "A")
  s <- jn_segs(data.frame(grp = c("A", "C"), x0 = c(5, 55), y0 = 0, x1 = c(5, 55),
                          y1 = 100, flag = c(FALSE, TRUE)))

  out <- fl_valley_join(r, a, s, group = "grp")

  expect_false(any(out$nearest$flag))
  expect_false(any(out$any$flag))
  expect_true(all(out$nearest$grp == "A"))
})

test_that("an equidistant shared cell goes to the lowest group key, and is counted", {
  # A up x = 5, B up x = 85: cells centred at x = 45 are 40 m from both.
  r <- jn_grid()
  a <- jn_attr(list(c(0, 60, 0, 100), c(40, 100, 0, 100)), c("B", "A"))
  s <- jn_segs(data.frame(grp = c("B", "A"), x0 = c(5, 85), y0 = 0, x1 = c(5, 85),
                          y1 = 100, flag = c(FALSE, TRUE)))

  expect_message(out <- fl_valley_join(r, a, s, group = "grp"), "tie")

  # Key "A" is the segment at x = 85, so the tie goes to it.
  expect_equal(jn_at(out$nearest, r, 45, 55, "grp"), "A")
  expect_true(jn_at(out$nearest, r, 45, 55, "flag"))
  expect_equal(out$ties, 10L)
})

test_that("ties order numeric keys numerically and put an NA key last", {
  r <- jn_grid()
  rects <- list(c(0, 60, 0, 100), c(40, 100, 0, 100))
  segs <- data.frame(x0 = c(5, 85), y0 = 0, x1 = c(5, 85), y1 = 100,
                     flag = c(FALSE, TRUE))

  # 10 sorts below 9 as text; numerically 9 wins.
  a <- jn_attr(rects, c(10, 9), group = "blk")
  s <- jn_segs(cbind(grp = c(10, 9), segs), group = "blk")
  out <- suppressMessages(fl_valley_join(r, a, s, group = "blk"))
  expect_equal(jn_at(out$nearest, r, 45, 55, "blk"), 9)

  a <- jn_attr(rects, c(NA, 9), group = "blk")
  s <- jn_segs(cbind(grp = c(NA, 9), segs), group = "blk")
  out <- suppressMessages(fl_valley_join(r, a, s, group = "blk"))
  expect_equal(jn_at(out$nearest, r, 45, 55, "blk"), 9)
  # The NA group still owns its own ground through its NA-keyed segment.
  expect_true(is.na(jn_at(out$nearest, r, 15, 55, "blk")))
  expect_false(jn_at(out$nearest, r, 15, 55, "flag"))
})

test_that("a claiming group with no segments is reported, owns no shared ground, leaves its own unknown", {
  # A claims x 0-60 and has no segments; B claims x 40-100.
  r <- jn_grid()
  a <- jn_attr(list(c(0, 60, 0, 100), c(40, 100, 0, 100)), c("A", "B"))
  s <- jn_segs(data.frame(grp = "B", x0 = 95, y0 = 0, x1 = 95, y1 = 100, flag = FALSE))

  expect_message(out <- fl_valley_join(r, a, s, group = "grp"), "no segments")

  expect_equal(out$no_segments, "A")
  # Shared cell: B owns it even though A sorts first.
  expect_equal(jn_at(out$nearest, r, 45, 55, "grp"), "B")
  expect_false(jn_at(out$nearest, r, 45, 55, "flag"))
  expect_false(jn_at(out$any, r, 45, 55, "flag"))
  # A's own ground: owner A, no distance, flags unknown under both resolutions.
  expect_equal(jn_at(out$nearest, r, 15, 55, "grp"), "A")
  expect_equal(jn_at(out$nearest, r, 15, 55, "dist"), Inf)
  expect_true(is.na(jn_at(out$nearest, r, 15, 55, "flag")))
  expect_true(is.na(jn_at(out$any, r, 15, 55, "flag")))
  expect_equal(out$ties, 0L)
})

test_that("a valley cell no group claims gets no row and is reported as missing", {
  r <- jn_grid()
  a <- jn_attr(list(c(0, 100, 10, 100)), "A")   # leaves the bottom row unclaimed
  s <- jn_segs(data.frame(grp = "A", x0 = 5, y0 = 0, x1 = 5, y1 = 100, flag = TRUE))

  expect_warning(out <- fl_valley_join(r, a, s, group = "grp"), "10 valley cells")

  expect_equal(out$check[["missing"]], 10L)
  expect_equal(out$check[["extra"]], 0L)
  expect_equal(nrow(out$nearest), 90L)
  expect_equal(nrow(out$any), 90L)
  expect_false(any(terra::cellFromXY(r, cbind(5:9 * 10 + 5, 5)) %in% out$nearest$cell))
})

test_that("a claimed cell outside the valley is reported as extra and dropped", {
  v <- rep(1L, 100)
  v[1:10] <- 0L          # top row is not valley
  v[11] <- NA_integer_   # and one no-data cell
  r <- jn_grid(v)
  a <- jn_attr(list(c(0, 100, 0, 100)), "A")
  s <- jn_segs(data.frame(grp = "A", x0 = 5, y0 = 0, x1 = 5, y1 = 100, flag = TRUE))

  expect_warning(out <- fl_valley_join(r, a, s, group = "grp"), "outside the valley")

  expect_equal(out$check,
               c(valley_cells = 89L, attributed_cells = 100L, missing = 0L, extra = 11L))
  expect_equal(out$nearest$cell, 12:100)
})

test_that("NA flags propagate: nearest copies them, any yields NA only without a TRUE", {
  r <- jn_grid()
  a <- jn_attr(list(c(0, 60, 0, 100), c(40, 100, 0, 100)), c("A", "B"))
  s <- jn_segs(data.frame(grp = c("A", "B"), x0 = c(5, 95), y0 = 0, x1 = c(5, 95),
                          y1 = 100, f1 = c(NA, TRUE), f2 = c(NA, FALSE)))

  out <- fl_valley_join(r, a, s, group = "grp")

  expect_true(is.na(jn_at(out$nearest, r, 45, 55, "f1")))
  expect_true(jn_at(out$any, r, 45, 55, "f1"))
  expect_true(is.na(jn_at(out$any, r, 45, 55, "f2")))
  expect_false(jn_at(out$any, r, 85, 55, "f2"))
})

test_that("cols selects attribute columns; NULL takes every logical column", {
  f <- jn_two()
  f$s$other <- !f$s$flag
  f$s$label <- c("x", "y")

  out <- fl_valley_join(f$r, f$a, f$s, group = "grp")
  expect_named(out$nearest, c("cell", "grp", "dist", "flag", "other"))

  out <- fl_valley_join(f$r, f$a, f$s, group = "grp", cols = "other")
  expect_named(out$any, c("cell", "other"))
  expect_true(jn_at(out$nearest, f$r, 45, 55, "other"))
})

test_that("inputs are validated", {
  f <- jn_two()
  f$s$label <- c("x", "y")

  expect_error(fl_valley_join(f$r, f$a, f$s, group = "nope"), "not found in `attributed`")
  s2 <- f$s
  names(s2)[names(s2) == "grp"] <- "other"
  expect_error(fl_valley_join(f$r, f$a, s2, group = "grp"), "not found in `segments`")
  expect_error(fl_valley_join(f$r, f$a, f$s, group = "grp", cols = "missing_col"),
               "missing_col")
  expect_error(fl_valley_join(f$r, f$a, f$s, group = "grp", cols = "label"), "logical")
  expect_error(fl_valley_join(f$r, f$a, f$s[, "grp"], group = "grp"), "No logical")
  s3 <- f$s
  s3$dist <- TRUE
  expect_error(fl_valley_join(f$r, f$a, s3, group = "grp", cols = "dist"), "dist")
  expect_error(fl_valley_join(f$r, sf::st_transform(f$a, 4326), f$s, group = "grp"),
               "CRS")
  expect_error(fl_valley_join(f$r, f$a, f$s, group = "cell"), "taken")
  r_ll <- terra::rast(nrows = 10, ncols = 10, xmin = -127, xmax = -126, ymin = 54,
                      ymax = 55, crs = "EPSG:4326", vals = 1L)
  expect_error(fl_valley_join(r_ll, sf::st_transform(f$a, 4326), f$s, group = "grp"),
               "projected")
})

test_that("segments in another CRS are transformed, and empty geometries skipped", {
  f <- jn_two()
  ref <- fl_valley_join(f$r, f$a, f$s, group = "grp")

  s <- sf::st_transform(f$s, 26909)
  out <- fl_valley_join(f$r, f$a, s, group = "grp")
  expect_equal(out$nearest[, c("cell", "grp", "flag")], ref$nearest[, c("cell", "grp", "flag")])
  expect_equal(out$nearest$dist, ref$nearest$dist, tolerance = 1e-6)

  s <- rbind(f$s, sf::st_sf(grp = "A", flag = TRUE,
                            geometry = sf::st_sfc(sf::st_linestring(), crs = 3005)))
  expect_equal(fl_valley_join(f$r, f$a, s, group = "grp"), ref)
})

test_that("keys that match no segment at all are flagged as a likely type mismatch", {
  f <- jn_two()
  f$s$grp <- c("a", "b")

  expect_warning(suppressMessages(fl_valley_join(f$r, f$a, f$s, group = "grp")),
                 "No segment")
})

test_that("on the bundled tile the join partitions the valley and nests nearest inside any", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  precip_r <- fl_stream_rasterize(streams, dem, field = "map_upstream")
  valleys <- fl_valley_confine(dem, streams,
                               area_field = "upstream_area_ha", precip = precip_r)
  attributed <- suppressMessages(
    fl_valley_attribute(valleys, streams, group = "blue_line_key", dem = dem)
  )
  streams$big <- streams$stream_order >= 6
  streams$wide <- !is.na(streams$channel_width) & streams$channel_width > 20

  out <- suppressMessages(fl_valley_join(valleys, attributed, streams, group = "blue_line_key"))

  vc <- which(terra::values(valleys, mat = FALSE) == 1L)
  expect_equal(unname(out$check[c("missing", "extra")]), c(0L, 0L))
  expect_equal(out$nearest$cell, vc)
  expect_equal(out$any$cell, vc)
  expect_named(out$nearest, c("cell", "blue_line_key", "dist", "big", "wide"))
  expect_length(out$no_segments, 0)
  for (col in c("big", "wide")) {
    expect_gt(sum(out$nearest[[col]]), 0)
    expect_lt(sum(out$nearest[[col]]), length(vc))
    expect_true(all(out$any[[col]][out$nearest[[col]]]))
  }
})

# The per-group position join as first written in NewGraphEnvironment/floodplains
# (scripts/floodplain_lcc/fp_habitat_join.R, fp_hj_join_range()), generalised to
# any flag columns. Kept here as the reference fl_valley_join() must reproduce.
jn_reference <- function(valleys, attributed, segments, group, cols) {
  cb <- terra::cells(valleys, terra::vect(attributed))
  cells <- data.frame(key = attributed[[group]][cb[, "ID"]], cell = cb[, "cell"])
  out <- list()
  for (b in unique(cells$key)) {
    cc <- cells$cell[cells$key == b]
    idx <- which(segments[[group]] == b)
    pts <- sf::st_as_sf(as.data.frame(terra::xyFromCell(valleys, cc)),
                        coords = c("x", "y"), crs = sf::st_crs(segments))
    nn <- idx[sf::st_nearest_feature(pts, segments[idx, ])]
    d <- data.frame(cell = cc, key = b,
                    dist = as.numeric(sf::st_distance(pts, segments[nn, ], by_element = TRUE)))
    for (col in cols) d[[col]] <- segments[[col]][nn]
    out[[length(out) + 1]] <- d
  }
  o <- do.call(rbind, out)
  any_ <- data.frame(cell = sort(unique(o$cell)))
  for (col in cols) any_[[col]] <- as.logical(tapply(o[[col]], o$cell, any))
  o <- o[order(o$cell, o$dist, o$key), ]
  first <- !duplicated(o$cell)
  ties <- sum(!first & is.finite(o$dist) & o$dist == c(NA, o$dist[-nrow(o)]) &
                o$cell == c(NA, o$cell[-nrow(o)]) & c(FALSE, first[-length(first)]),
              na.rm = TRUE)
  near <- data.frame(cell = o$cell[first])
  for (col in cols) near[[col]] <- o[[col]][first]
  list(nearest = near, any = any_, ties = ties)
}

test_that("on the bundled tile fl_valley_join reproduces the reference join cell for cell", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  precip_r <- fl_stream_rasterize(streams, dem, field = "map_upstream")
  valleys <- fl_valley_confine(dem, streams,
                               area_field = "upstream_area_ha", precip = precip_r)
  attributed <- suppressMessages(
    fl_valley_attribute(valleys, streams, group = "blue_line_key", dem = dem)
  )
  streams$spawning <- streams$stream_order >= 6
  streams$rearing <- !is.na(streams$channel_width) & streams$channel_width > 20
  cols <- c("spawning", "rearing")

  ref <- jn_reference(valleys, attributed, streams, "blue_line_key", cols)
  out <- suppressMessages(fl_valley_join(valleys, attributed, streams,
                                         group = "blue_line_key", cols = cols))

  # The tile has ground claimed by several blue lines and exact ties, so both
  # resolutions and the tie rule are exercised.
  expect_gt(out$ties, 0)
  expect_gt(sum(duplicated(terra::cells(valleys, terra::vect(attributed))[, "cell"])), 0)
  expect_equal(out$ties, ref$ties)
  expect_equal(out$nearest$cell, ref$nearest$cell)
  expect_equal(out$any$cell, ref$any$cell)
  for (col in cols) {
    expect_identical(out$nearest[[col]], ref$nearest[[col]])
    expect_identical(out$any[[col]], ref$any[[col]])
  }
})
