test_that("fl_dem_aoi crops local file to buffered AOI", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  result <- fl_dem_aoi(aoi, source = testdata_path("dem.tif"), buffer = 100)

  expect_s4_class(result, "SpatRaster")
  expect_true(terra::ncell(result) > 0)

  # Result extent must cover the buffered AOI
  aoi_buf_ext <- terra::ext(terra::vect(sf::st_buffer(aoi, 100)))
  res_ext <- terra::ext(result)
  expect_true(res_ext$xmin <= aoi_buf_ext$xmin)
  expect_true(res_ext$xmax >= aoi_buf_ext$xmax)
  expect_true(res_ext$ymin <= aoi_buf_ext$ymin)
  expect_true(res_ext$ymax >= aoi_buf_ext$ymax)
})

test_that("fl_dem_aoi handles AOI/source CRS mismatch", {
  aoi_3005 <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  aoi_4326 <- sf::st_transform(aoi_3005, 4326)

  result <- fl_dem_aoi(aoi_4326, source = testdata_path("dem.tif"), buffer = 100, res = 1e-4)

  expect_s4_class(result, "SpatRaster")
  expect_true(terra::ncell(result) > 0)
  # target_crs defaulted to aoi_4326's CRS (EPSG:4326)
  expect_equal(sf::st_crs(terra::crs(result))$epsg, 4326L)
})

test_that("fl_dem_aoi target_crs override reprojects after crop", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  result <- fl_dem_aoi(
    aoi,
    source = testdata_path("dem.tif"),
    buffer = 100,
    target_crs = 4326,
    res = 1e-4
  )

  expect_s4_class(result, "SpatRaster")
  expect_equal(sf::st_crs(terra::crs(result))$epsg, 4326L)
  expect_equal(terra::res(result), c(1e-4, 1e-4))
})

test_that("fl_dem_aoi larger buffer yields equal-or-larger extent", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  small <- fl_dem_aoi(aoi, source = testdata_path("dem.tif"), buffer = 100)
  big <- fl_dem_aoi(aoi, source = testdata_path("dem.tif"), buffer = 500)

  expect_true(terra::ncell(big) >= terra::ncell(small))
})

test_that("fl_dem_aoi accepts polygon AOI", {
  waterbodies <- sf::st_read(testdata_path("waterbodies.gpkg"), quiet = TRUE)

  result <- fl_dem_aoi(
    waterbodies,
    source = testdata_path("dem.tif"),
    buffer = 100
  )

  expect_s4_class(result, "SpatRaster")
  expect_true(terra::ncell(result) > 0)
})

# Expected grid for a reprojection, computed here rather than by fl_dem_aoi():
# the buffered AOI's bbox in the target CRS, snapped outward to multiples of res.
expected_ext <- function(aoi, buffer, crs, res) {
  bb <- sf::st_bbox(sf::st_transform(sf::st_buffer(aoi, buffer), crs))
  c(
    xmin = floor(bb[["xmin"]] / res) * res, xmax = ceiling(bb[["xmax"]] / res) * res,
    ymin = floor(bb[["ymin"]] / res) * res, ymax = ceiling(bb[["ymax"]] / res) * res
  )
}

test_that("fl_dem_aoi reprojects onto the source cell size, aligned to multiples of it (#67)", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  # Before #67 GDAL chose this grid: 10.0124 m, origin off any multiple of 10
  result <- fl_dem_aoi(aoi, source = testdata_path("dem.tif"), buffer = 100, target_crs = 3157)

  expect_identical(terra::res(result), c(10, 10))
  expect_equal(as.vector(terra::ext(result)), expected_ext(aoi, 100, 3157, 10), tolerance = 0)
})

test_that("fl_dem_aoi aligns the grid when the AOI is already in target_crs (#67)", {
  # The floodplains shape: streams in the target CRS, DEM in another
  aoi <- sf::st_transform(sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE), 3157)

  result <- fl_dem_aoi(aoi, source = testdata_path("dem.tif"), buffer = 100)

  expect_identical(terra::res(result), c(10, 10))
  expect_equal(as.vector(terra::ext(result)), expected_ext(aoi, 100, 3157, 10), tolerance = 0)
})

test_that("fl_dem_aoi resamples onto an aligned grid in the source CRS when res differs (#67)", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  result <- fl_dem_aoi(aoi, source = testdata_path("dem.tif"), buffer = 100, res = 30)

  expect_identical(terra::res(result), c(30, 30))
  expect_equal(as.vector(terra::ext(result)), expected_ext(aoi, 100, 3005, 30), tolerance = 0)
})

test_that("fl_dem_aoi honours an explicit res and aligns every edge to it (#67)", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  result <- fl_dem_aoi(
    aoi, source = testdata_path("dem.tif"), buffer = 100, target_crs = 3157, res = 30
  )

  expect_identical(terra::res(result), c(30, 30))
  e <- as.vector(terra::ext(result))
  expect_identical(unname(e %% 30), rep(0, 4))
  expect_equal(e, expected_ext(aoi, 100, 3157, 30), tolerance = 0)
})

test_that("fl_dem_aoi has data in every cell of the buffered AOI (#67)", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  # The AOI + 100 m sits ~900 m inside dem.tif. Grid corners beyond the area
  # read may be NA; no cell inside the buffered AOI may be.
  result <- fl_dem_aoi(aoi, source = testdata_path("dem.tif"), buffer = 100, target_crs = 3157)
  in_aoi <- !is.na(terra::rasterize(
    terra::vect(sf::st_transform(sf::st_buffer(aoi, 100), 3157)), result, touches = FALSE
  ))

  expect_gt(terra::global(in_aoi, "sum")[[1]], 0)
  expect_identical(terra::global(is.na(result) & in_aoi, "sum")[[1]], 0)
})

test_that("fl_dem_aoi in the source CRS crops on the source grid, unchanged", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  r <- terra::rast(testdata_path("dem.tif"))

  result <- fl_dem_aoi(aoi, source = testdata_path("dem.tif"), buffer = 100)
  expected <- terra::crop(r, terra::vect(sf::st_buffer(aoi, 100)), snap = "out")

  expect_true(terra::compareGeom(result, expected, stopOnError = FALSE))
  expect_identical(as.vector(terra::ext(result)), as.vector(terra::ext(expected)))
  expect_identical(terra::values(result), terra::values(expected))
})

test_that("fl_dem_aoi asks for res in degrees for a geographic target (#67)", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  expect_error(
    fl_dem_aoi(aoi, source = testdata_path("dem.tif"), buffer = 100, target_crs = 4326),
    "res = 0\\.0[0-9]+ degrees"
  )
})

test_that("fl_dem_aoi rejects an invalid res", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  dem <- testdata_path("dem.tif")

  expect_error(fl_dem_aoi(aoi, source = dem, target_crs = 3157, res = "30"), "`res` must be")
  expect_error(fl_dem_aoi(aoi, source = dem, target_crs = 3157, res = c(30, 30)), "`res` must be")
  expect_error(fl_dem_aoi(aoi, source = dem, target_crs = 3157, res = 0), "`res` must be")
  expect_error(fl_dem_aoi(aoi, source = dem, target_crs = 3157, res = NA_real_), "`res` must be")
})

# Transform shift-free where flooded pins the pair, else as sf's PROJ does.
# Fixtures, the mock and expected values all measure from this position, which
# every PROJ agrees on, so the tests mean the same thing on any toolchain.
pin_transform <- function(x, to, transform = sf::st_transform) {
  to <- sf::st_crs(to)
  pin <- flooded:::dem_pipeline_nad83(sf::st_crs(x), to)
  if (!nzchar(pin)) return(transform(x, to))
  suppressWarnings(transform(x, to$wkt, pipeline = pin))
}

# A source in EPSG:3979 (NAD83(CSRS), MRDEM's CRS) whose value is its own x
# coordinate. Bilinear sampling of a linear field is exact, so each output cell
# holds the 3979 x of its centre under whatever operation projected it.
x_field_3979 <- function(aoi, buffer, res = 10, crs = 3979) {
  bb <- sf::st_bbox(pin_transform(sf::st_buffer(aoi, buffer + 500), crs))
  r <- terra::rast(terra::ext(bb[["xmin"]], bb[["xmax"]], bb[["ymin"]], bb[["ymax"]]),
                   resolution = res, crs = paste0("EPSG:", crs))
  r <- terra::init(r, "x")
  f <- tempfile(fileext = ".tif")
  terra::writeRaster(r, f, datatype = "FLT8S")
  f
}

# The shift-free NAD83(CSRS) -> NAD83 operation, written out here rather than
# taken from fl_dem_aoi()'s builder: inverse BC Albers, then Canada Atlas
# Lambert, both on GRS80, with no datum step between them.
pipeline_3005_to_3979 <- paste(
  "+proj=pipeline",
  "+step +inv +proj=aea +lat_0=45 +lon_0=-126 +lat_1=50 +lat_2=58.5 +x_0=1000000 +y_0=0 +ellps=GRS80",
  "+step +proj=lcc +lat_0=49 +lon_0=-95 +lat_1=49 +lat_2=77 +x_0=0 +y_0=0 +ellps=GRS80"
)

cell_x_3979 <- function(r) {
  xy <- terra::xyFromCell(r, which(!is.na(terra::values(r, mat = FALSE))))
  pts <- sf::st_sfc(sf::st_multipoint(xy), crs = 3005)
  suppressWarnings(
    sf::st_coordinates(sf::st_transform(pts, sf::st_crs(3979)$wkt, pipeline = pipeline_3005_to_3979))[, "X"]
  )
}

test_that("fl_dem_aoi projects NAD83(CSRS) to NAD83 with no datum shift, whatever PROJ prefers (#67)", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  src <- x_field_3979(aoi, 100)

  result <- fl_dem_aoi(aoi, source = src, buffer = 100)
  v <- terra::values(result, mat = FALSE)
  v <- v[!is.na(v)]

  d <- abs(v - cell_x_3979(result))

  expect_gt(length(v), 1000)
  # A datum step moves these ~0.7 m here (PROJ 9.8.1 routes via WGS 84). The
  # residual is Float32 rounding of the warp output (0.125 m steps at x ~ -1.9e6;
  # median 3 cm, p99 6 cm); edge cells, where bilinear
  # sampling meets the rim of the source, are left out by the quantile.
  expect_lt(stats::median(d), 0.1)
  expect_lt(stats::quantile(d, 0.99)[[1]], 0.2)
})

test_that("fl_dem_aoi pipeline = \"\" hands the operation to PROJ; a string is used as given (#67)", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  src <- x_field_3979(aoi, 100)

  pinned <- fl_dem_aoi(aoi, source = src, buffer = 100)
  # The pinned pipeline plus a 50 m shift: a string that differs from the pin
  shifted <- paste(flooded:::dem_pipeline_nad83(sf::st_crs(3979), sf::st_crs(3005)),
                   "+step +proj=affine +xoff=50")
  given <- fl_dem_aoi(aoi, source = src, buffer = 100, pipeline = shifted)
  proj <- fl_dem_aoi(aoi, source = src, buffer = 100, pipeline = "")
  r <- terra::rast(src)
  expected_proj <- terra::project(
    terra::crop(r, terra::ext(terra::vect(sf::st_transform(sf::st_buffer(aoi, 100), 3979))) + 20,
                snap = "out"),
    terra::rast(pinned), method = "bilinear"
  )

  d_given <- abs(terra::values(given, mat = FALSE) - terra::values(pinned, mat = FALSE))
  expect_gt(stats::median(d_given, na.rm = TRUE), 10)
  expect_equal(terra::values(proj), terra::values(expected_proj), tolerance = 1e-9)
})

# Stand-in for an sf whose PROJ picks a datum step: every sf::st_transform()
# without a pipeline lands 1.3 m (#67's PROJ 9.5.1 vs 9.8.1 gap) further east
# and north. Calls given a pipeline pass through. Only sfc results are moved,
# because st_transform.sf() reaches this mock again for its geometry column.
mock_sf_datum_shift <- function(env = parent.frame()) {
  real <- sf::st_transform
  testthat::local_mocked_bindings(
    st_transform = function(x, crs, ...) {
      pipeline <- list(...)$pipeline
      if (!inherits(x, "sfc") || !(is.null(pipeline) || !nzchar(pipeline))) {
        return(real(x, crs, ...))
      }
      # From the shift-free position, not wherever this machine's sf puts it,
      # so the simulated step is the same 1.3 m on any PROJ
      y <- pin_transform(x, crs, real)
      if (!isTRUE(sf::st_is_longlat(y))) {
        y <- sf::st_sfc(y + c(1.3, 1.3), crs = sf::st_crs(y))
      }
      y
    },
    .package = "sf", .env = env
  )
}

with_sf_datum_shift <- function(expr) {
  mock_sf_datum_shift()
  expr
}

shift_east <- function(x, d) {
  g <- sf::st_geometry(x) + c(d, 0)
  sf::st_crs(g) <- sf::st_crs(x)
  sf::st_geometry(x) <- g
  x
}

expect_same_dem <- function(a, b) {
  testthat::expect_identical(as.vector(terra::ext(a)), as.vector(terra::ext(b)))
  testthat::expect_identical(terra::values(a), terra::values(b))
}

# The streams moved east by d metres put an edge of the buffered AOI within
# 1.3 m of a cell boundary of x_field_3979(aoi, 100, res = 30), so under
# mock_sf_datum_shift() 0.7.0 reads or crops a different column or row, or (for
# `third` and `wgs84_source`, with the AOI in NAD83(CSRS) / UTM 10N) snaps the
# grid differently. Found by searching d = 0:29 against 0.7.0 (#78), on an sf
# whose PROJ (9.5.1) applies no datum step for these pairs;
# `wgs84_source` are offsets where the grid itself moves, which the first fix
# left unpinned when the source -> target pair had no pin. The offsets are
# specific to the mock's +1.3 m: the real PROJ 9.5.1 / 9.8.1 split here is
# about (+0.7, -1.05) m. The fixture origin, the mock and every expected value
# are measured from the shift-free position (pin_transform()), so the offsets
# reach the same boundaries whichever PROJ sf links (#78 round 4).
window_offsets <- list(
  reproject = c(12, 21), crop = c(12, 22), third = c(8, 18), wgs84_source = c(1, 18)
)

# NAD83(CSRS) / UTM 10N, the CSRS flavour of AOI that PROJ versions disagree on
# going into BC Albers. Converted shift-free so the AOI itself is fixed.
to_csrs_utm <- function(x) {
  suppressWarnings(sf::st_transform(
    x, sf::st_crs(3157)$wkt,
    pipeline = flooded:::dem_pipeline_nad83(sf::st_crs(3005), sf::st_crs(3157))
  ))
}

# Where a third-CRS AOI's grid belongs, worked out here: the buffered AOI's
# bbox carried into the target shift-free, snapped outward to multiples of res
pinned_grid_ext <- function(aoi, buffer, to, res) {
  buf <- sf::st_buffer(aoi, buffer)
  bb <- sf::st_bbox(suppressWarnings(sf::st_transform(
    buf, sf::st_crs(to)$wkt,
    pipeline = flooded:::dem_pipeline_nad83(sf::st_crs(aoi), sf::st_crs(to))
  )))
  c(floor(bb[["xmin"]] / res) * res, ceiling(bb[["xmax"]] / res) * res,
    floor(bb[["ymin"]] / res) * res, ceiling(bb[["ymax"]] / res) * res)
}

# What fl_dem_aoi() should return for an AOI in 3005 and the 3979 fixture,
# built here from a stated read-window operation (shift-free by default):
# the crop on the source grid for target 3979, else the warp onto the aligned
# grid in 3005
expected_window_dem <- function(aoi, r, buffer, target,
                                window = flooded:::dem_pipeline_nad83(sf::st_crs(3005), sf::st_crs(3979)),
                                reverse = FALSE,
                                warp = flooded:::dem_pipeline_nad83(sf::st_crs(3979), sf::st_crs(3005))) {
  buf <- sf::st_buffer(aoi, buffer)
  win <- suppressWarnings(
    sf::st_transform(buf, sf::st_crs(3979)$wkt, pipeline = window, reverse = reverse)
  )
  if (target == 3979) return(terra::crop(r, terra::vect(win), snap = "out"))
  wb <- sf::st_bbox(win)
  bb <- sf::st_bbox(buf)
  res <- terra::res(r)[1]  # terra fits the fixture's 30 m to its extent
  pad <- 2 * max(terra::res(r))
  tmpl <- terra::rast(
    terra::ext(floor(bb[["xmin"]] / res) * res, ceiling(bb[["xmax"]] / res) * res,
               floor(bb[["ymin"]] / res) * res, ceiling(bb[["ymax"]] / res) * res),
    resolution = res, crs = sf::st_crs(3005)$wkt
  )
  terra::project(
    terra::crop(r, terra::ext(wb[["xmin"]] - pad, wb[["xmax"]] + pad,
                              wb[["ymin"]] - pad, wb[["ymax"]] + pad), snap = "out"),
    tmpl, method = "bilinear", pipeline = warp
  )
}

snapped_ext <- function(x, res) {
  bb <- sf::st_bbox(x)
  c(floor(bb[c("xmin", "ymin")] / res), ceiling(bb[c("xmax", "ymax")] / res))
}

test_that("the mock's 1.3 m step crosses a cell boundary at every offset (#78)", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  r <- terra::rast(x_field_3979(aoi, 100, res = 30))
  r_wgs <- terra::rast(x_field_3979(aoi, 100, res = 30, crs = 32610))
  crop_ext <- function(a) {
    as.vector(terra::ext(terra::crop(r, terra::ext(sf::st_bbox(a)[c(1, 3, 2, 4)]), snap = "out")))
  }
  # Shift-free against what an unpinned transform returns under the mock
  crop_moves <- function(buf) {
    !identical(crop_ext(pin_transform(buf, 3979)),
               crop_ext(with_sf_datum_shift(sf::st_transform(buf, 3979))))
  }
  grid_moves <- function(buf, res) {
    !identical(snapped_ext(pin_transform(buf, 3005), res),
               snapped_ext(with_sf_datum_shift(sf::st_transform(buf, 3005)), res))
  }
  for (d in c(window_offsets$reproject, window_offsets$crop)) {
    expect_true(crop_moves(sf::st_buffer(shift_east(aoi, d), 100)), info = paste("offset", d))
  }
  for (d in window_offsets$third) {
    buf <- sf::st_buffer(to_csrs_utm(shift_east(aoi, d)), 100)
    expect_true(grid_moves(buf, terra::res(r)[1]) || crop_moves(buf), info = paste("offset", d))
  }
  for (d in window_offsets$wgs84_source) {
    buf <- sf::st_buffer(to_csrs_utm(shift_east(aoi, d)), 100)
    expect_true(grid_moves(buf, terra::res(r_wgs)[1]), info = paste("offset", d))
  }
  # And it reaches sf::st_transform as flooded calls it
  buf <- sf::st_buffer(aoi, 100)
  expect_false(identical(
    sf::st_bbox(flooded:::dem_st_transform(buf, sf::st_crs(3979), "")),
    sf::st_bbox(with_sf_datum_shift(flooded:::dem_st_transform(buf, sf::st_crs(3979), "")))
  ))
})

test_that("fl_dem_aoi reads the same source window whichever PROJ sf links (#78)", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  src <- x_field_3979(aoi, 100, res = 30)

  r <- terra::rast(src)

  for (d in window_offsets$reproject) {
    a <- shift_east(aoi, d)
    # Where the window lands, not only that the mock leaves it alone
    expected <- expected_window_dem(a, r, 100, target = 3005)
    expect_same_dem(fl_dem_aoi(a, source = src, buffer = 100), expected)
    expect_same_dem(with_sf_datum_shift(fl_dem_aoi(a, source = src, buffer = 100)), expected)
  }
})

test_that("fl_dem_aoi crops on the source grid the same whichever PROJ sf links (#78)", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  src <- x_field_3979(aoi, 100, res = 30)

  r <- terra::rast(src)

  for (d in window_offsets$crop) {
    a <- shift_east(aoi, d)
    expected <- expected_window_dem(a, r, 100, target = 3979)
    expect_same_dem(fl_dem_aoi(a, source = src, buffer = 100, target_crs = 3979), expected)
    expect_same_dem(with_sf_datum_shift(fl_dem_aoi(a, source = src, buffer = 100, target_crs = 3979)),
                    expected)
  }
})

test_that("fl_dem_aoi inverts a supplied pipeline for the read window (#78)", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  src <- x_field_3979(aoi, 100, res = 30)
  r <- terra::rast(src)
  # Differs from the default pin by more than a cell, so a window from the pin
  # would sit one or two cells off this one
  given <- paste(flooded:::dem_pipeline_nad83(sf::st_crs(3979), sf::st_crs(3005)),
                 "+step +proj=affine +xoff=45 +yoff=45")

  for (d in window_offsets$reproject) {
    a <- shift_east(aoi, d)
    expected <- expected_window_dem(a, r, 100, target = 3005,
                                    window = given, reverse = TRUE, warp = given)
    expect_same_dem(fl_dem_aoi(a, source = src, buffer = 100, pipeline = given), expected)
    expect_same_dem(with_sf_datum_shift(fl_dem_aoi(a, source = src, buffer = 100, pipeline = given)),
                    expected)
  }
})

test_that("fl_dem_aoi stops clearly when a supplied pipeline cannot be applied in reverse (#78)", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  src <- x_field_3979(aoi, 100, res = 30)
  lcc_3979 <- "+proj=lcc +lat_0=49 +lon_0=-95 +lat_1=49 +lat_2=77 +x_0=0 +y_0=0 +ellps=GRS80"
  # Valid forward, but urm5 has no inverse: the reverse returns NaN
  no_inverse <- paste("+proj=pipeline +step +inv", lcc_3979, "+step +proj=urm5 +n=0.9 +alpha=2 +q=4")
  expect_error(fl_dem_aoi(aoi, source = src, buffer = 100, pipeline = no_inverse),
               "could not be applied in reverse")

  # Not a valid pipeline at all (urm5 wants lon/lat, the pin ends in metres):
  # sf errors, and PROJ's own reason arrives as GDAL warnings
  invalid <- paste(flooded:::dem_pipeline_nad83(sf::st_crs(3979), sf::st_crs(3005)),
                   "+step +proj=urm5 +n=0.9 +alpha=2 +q=4")
  suppressWarnings(
    expect_error(fl_dem_aoi(aoi, source = src, buffer = 100, pipeline = invalid),
                 "could not be applied in reverse")
  )

  # Degrees out, but sf feeds the inverse lat/lon in authority order
  to_degrees <- paste(
    "+proj=pipeline +step +inv +proj=lcc +lat_0=49 +lon_0=-95 +lat_1=49 +lat_2=77",
    "+x_0=0 +y_0=0 +ellps=GRS80 +step +proj=unitconvert +xy_in=rad +xy_out=deg"
  )
  aoi_ll <- sf::st_transform(aoi, 4269)
  expect_error(
    fl_dem_aoi(aoi_ll, source = src, buffer = 100, res = 3e-4, pipeline = to_degrees),
    "could not be applied in reverse"
  )
})

test_that("fl_dem_aoi places the grid the same for an AOI in a third CRS, whichever PROJ sf links (#78)", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  src <- x_field_3979(aoi, 100, res = 30)

  # NAD83(CSRS) / UTM 10N: neither the source's CRS nor the target's
  res <- terra::res(terra::rast(src))[1]
  for (d in window_offsets$third) {
    a <- to_csrs_utm(shift_east(aoi, d))
    # Where it lands, not only that the mock leaves it alone: a wrong pipeline
    # gives the same misplaced, all-NA raster with and without the mock
    got <- fl_dem_aoi(a, source = src, buffer = 100, target_crs = 3005)
    expect_equal(unname(as.vector(terra::ext(got))), pinned_grid_ext(a, 100, 3005, res), tolerance = 0)
    expect_gt(terra::global(!is.na(got), "sum")[[1]], 0.5 * terra::ncell(got))
    expect_same_dem(with_sf_datum_shift(fl_dem_aoi(a, source = src, buffer = 100, target_crs = 3005)), got)
  }
})

test_that("fl_dem_aoi pins an AOI's grid when the source -> target pair has no pin (#78)", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  # WGS 84 / UTM 10N source: WGS 84 -> NAD83 is not pinned, CSRS AOI -> NAD83 is
  src <- x_field_3979(aoi, 100, res = 30, crs = 32610)

  # The read window (CSRS -> WGS 84) has no pin, so only the grid is compared
  res <- terra::res(terra::rast(src))[1]
  for (d in window_offsets$wgs84_source) {
    a <- to_csrs_utm(shift_east(aoi, d))
    got <- fl_dem_aoi(a, source = src, buffer = 100, target_crs = 3005)
    expect_equal(unname(as.vector(terra::ext(got))), pinned_grid_ext(a, 100, 3005, res), tolerance = 0)
    mocked <- with_sf_datum_shift(fl_dem_aoi(a, source = src, buffer = 100, target_crs = 3005))
    expect_equal(unname(as.vector(terra::ext(mocked))), pinned_grid_ext(a, 100, 3005, res), tolerance = 0)
  }
})

test_that("fl_dem_aoi pipeline = \"\" leaves the read window to sf's PROJ too (#78)", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  src <- x_field_3979(aoi, 100, res = 30)
  r <- terra::rast(src)
  # What the mock makes sf's PROJ do: the pin plus 1.3 m
  stepped <- paste(flooded:::dem_pipeline_nad83(sf::st_crs(3005), sf::st_crs(3979)),
                   "+step +proj=affine +xoff=1.3 +yoff=1.3")

  a <- shift_east(aoi, window_offsets$crop[1])
  got <- with_sf_datum_shift(fl_dem_aoi(a, source = src, buffer = 100, target_crs = 3979, pipeline = ""))
  expect_same_dem(got, expected_window_dem(a, r, 100, target = 3979, window = stepped))
  expect_false(identical(as.vector(terra::ext(got)),
                         as.vector(terra::ext(expected_window_dem(a, r, 100, target = 3979)))))

  # And on the reproject path, where the warp is left to terra's PROJ too
  a <- shift_east(aoi, window_offsets$reproject[1])
  got <- with_sf_datum_shift(fl_dem_aoi(a, source = src, buffer = 100, pipeline = ""))
  expect_same_dem(got, expected_window_dem(a, r, 100, target = 3005, window = stepped, warp = ""))
  expect_false(identical(
    terra::values(got),
    terra::values(expected_window_dem(a, r, 100, target = 3005, warp = ""))
  ))
})

test_that("fl_dem_aoi leaves the operation to PROJ outside projected NAD83 pairs", {
  expect_identical(flooded:::dem_pipeline_nad83(sf::st_crs(3005), sf::st_crs(4326)), "")
  expect_identical(flooded:::dem_pipeline_nad83(sf::st_crs(4326), sf::st_crs(3005)), "")
  # Geographic NAD83: GDAL and sf disagree on axis order around a pipeline
  expect_identical(flooded:::dem_pipeline_nad83(sf::st_crs(3005), sf::st_crs(4269)), "")
  expect_identical(flooded:::dem_pipeline_nad83(sf::st_crs(4617), sf::st_crs(3005)), "")
  # Projected but northing first (NAD83(CSRS) / New Brunswick Stereographic)
  expect_identical(flooded:::dem_pipeline_nad83(sf::st_crs(3979), sf::st_crs(2953)), "")
  expect_identical(flooded:::dem_pipeline_nad83(sf::st_crs(2953), sf::st_crs(3005)), "")
  # "North American Datum of 1983 (CSRS) version 2" is a NAD83 realization too
  expect_match(flooded:::dem_pipeline_nad83(sf::st_crs(22209), sf::st_crs(3005)), "^\\+proj=pipeline")
  expect_match(flooded:::dem_pipeline_nad83(sf::st_crs(3979), sf::st_crs(3005)), "^\\+proj=pipeline")
  expect_false(grepl("helmert|cart|towgs84|datum",
                     flooded:::dem_pipeline_nad83(sf::st_crs(3979), sf::st_crs(3005))))
})

test_that("fl_dem_aoi returns data for a geographic NAD83 target (#67)", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  # A supplied pipeline here once gave an all-NA raster (axis order)
  result <- fl_dem_aoi(aoi, source = testdata_path("dem.tif"), buffer = 100, target_crs = 4269, res = 1e-4)

  expect_gt(terra::global(!is.na(result), "sum")[[1]], 0.5 * terra::ncell(result))
})

test_that("fl_dem_aoi returns data for a northing-first projected target (#67)", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  # A pinned pipeline here once gave an all-NA raster (EPSG:2953 is N, E)
  result <- fl_dem_aoi(aoi, source = testdata_path("dem.tif"), buffer = 100, target_crs = 2953)

  expect_gt(terra::global(!is.na(result), "sum")[[1]], 0.5 * terra::ncell(result))
})

test_that("fl_dem_aoi rejects an invalid pipeline", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  dem <- testdata_path("dem.tif")

  expect_error(fl_dem_aoi(aoi, source = dem, target_crs = 3157, pipeline = NA_character_), "`pipeline` must be")
  expect_error(fl_dem_aoi(aoi, source = dem, target_crs = 3157, pipeline = c("a", "b")), "`pipeline` must be")
})

test_that("fl_dem_aoi rejects non-sf aoi", {
  expect_error(
    fl_dem_aoi("not_sf", source = testdata_path("dem.tif")),
    "sf"
  )
})

test_that("fl_dem_aoi fetches MRDEM-30 via /vsicurl/", {
  testthat::skip_on_cran()
  testthat::skip_if_offline()

  # Single-feature AOI keeps the range read tiny (~100s of KB)
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)[1, ]

  result <- fl_dem_aoi(aoi, buffer = 100)

  expect_s4_class(result, "SpatRaster")
  expect_true(terra::ncell(result) > 0)
  # Default target_crs is the input AOI's CRS
  expect_equal(sf::st_crs(terra::crs(result)), sf::st_crs(aoi))
  # MRDEM's 30 m cells, on a grid aligned to multiples of 30 (#67)
  expect_identical(terra::res(result), c(30, 30))
  expect_identical(unname(as.vector(terra::ext(result)) %% 30), rep(0, 4))
})

# dem.tif is UInt32 with nodata 4294967295. terra::project() of a file-backed
# copy leaves cells beyond the raster it projects at that nodata rounded to Float32
# (4294967296), which no longer matches the nodata, so it reads as data (#76).
# Any integer nodata Float32 cannot hold does the same. The same DEM
# stored as Float32 never takes that path, so it is the reference: the result
# must be identical, NA where the output reaches past the area read included.
dem_as <- function(datatype, ...) {
  f <- tempfile(fileext = ".tif")
  terra::writeRaster(terra::rast(testdata_path("dem.tif")), f, datatype = datatype, ...)
  f
}

test_that("fl_dem_aoi returns NA, not 2^32, beyond a whole-file UInt32 source (#76)", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  src <- testdata_path("dem.tif")
  expect_identical(terra::datatype(terra::rast(src)), "INT4U")

  # buffer = 2000 reaches past dem.tif, so the crop is the whole file
  result <- fl_dem_aoi(aoi, source = src, buffer = 2000, target_crs = 3157)

  expect_gt(terra::global(is.na(result), "sum")[[1]], 0)
  expect_lte(terra::global(result, "max", na.rm = TRUE)[[1]], 1062)
  expect_same_dem(
    result, fl_dem_aoi(aoi, source = dem_as("FLT4S"), buffer = 2000, target_crs = 3157)
  )
})

test_that("fl_dem_aoi returns NA beyond a UInt32 subset crop that terra writes to disk (#76)", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  old <- terra::terraOptions(print = FALSE)$todisk
  terra::terraOptions(todisk = TRUE)
  on.exit(terra::terraOptions(todisk = old), add = TRUE)

  # buffer = 100 is a real subset of dem.tif: in memory it was always NA, on
  # disk (a large AOI) it took the 2^32 path too
  result <- fl_dem_aoi(aoi, source = testdata_path("dem.tif"), buffer = 100, target_crs = 3157)

  expect_gt(terra::global(is.na(result), "sum")[[1]], 0)
  expect_same_dem(
    result, fl_dem_aoi(aoi, source = dem_as("FLT4S"), buffer = 100, target_crs = 3157)
  )
})

test_that("fl_dem_aoi returns NA beyond a UInt32 source resampled in its own CRS (#76)", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  expect_same_dem(
    fl_dem_aoi(aoi, source = testdata_path("dem.tif"), buffer = 2000, res = 30),
    fl_dem_aoi(aoi, source = dem_as("FLT4S"), buffer = 2000, res = 30)
  )
})

test_that("fl_dem_aoi returns NA beyond other integer sources whose nodata Float32 cannot hold (#76)", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  ref <- fl_dem_aoi(aoi, source = dem_as("FLT4S"), buffer = 2000, target_crs = 3157)

  for (src in c(dem_as("INT8U"), dem_as("INT4S", NAflag = 2147483647))) {
    expect_same_dem(fl_dem_aoi(aoi, source = src, buffer = 2000, target_crs = 3157), ref)
  }
})

test_that("fl_dem_aoi reprojects a multi-layer integer source layer by layer (#76)", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  r <- terra::rast(testdata_path("dem.tif"))
  src <- tempfile(fileext = ".tif")
  terra::writeRaster(c(r, r), src, datatype = "INT4U")
  ref <- fl_dem_aoi(aoi, source = dem_as("FLT4S"), buffer = 2000, target_crs = 3157)

  result <- fl_dem_aoi(aoi, source = src, buffer = 2000, target_crs = 3157)

  expect_equal(terra::nlyr(result), 2)
  expect_identical(terra::values(result)[, 1], terra::values(ref)[, 1])
  expect_identical(terra::values(result)[, 2], terra::values(ref)[, 1])
})
