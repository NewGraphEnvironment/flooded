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

# A source in EPSG:3979 (NAD83(CSRS), MRDEM's CRS) whose value is its own x
# coordinate. Bilinear sampling of a linear field is exact, so each output cell
# holds the 3979 x of its centre under whatever operation projected it.
x_field_3979 <- function(aoi, buffer, res = 10, crs = 3979) {
  bb <- sf::st_bbox(sf::st_transform(sf::st_buffer(aoi, buffer + 500), crs))
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
      y <- real(x, crs, ...)
      pipeline <- list(...)$pipeline
      if (inherits(y, "sfc") && (is.null(pipeline) || !nzchar(pipeline)) &&
            !isTRUE(sf::st_is_longlat(y))) {
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
# grid differently. Found by searching d = 0:29 against 0.7.0 (#78);
# `wgs84_source` are offsets where the grid itself moves, which the first fix
# left unpinned when the source -> target pair had no pin. The offsets are
# specific to the mock's +1.3 m: the real PROJ 9.5.1 / 9.8.1 split here is
# about (+0.7, -1.05) m. The fixture's origin comes from a plain transform on
# purpose, so origin and plain window move together on any PROJ.
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

snapped_ext <- function(x, res) {
  bb <- sf::st_bbox(x)
  c(floor(bb[c("xmin", "ymin")] / res), ceiling(bb[c("xmax", "ymax")] / res))
}

test_that("the mock shifts an unpinned transform, so the offsets reach a cell boundary (#78)", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  r <- terra::rast(x_field_3979(aoi, 100, res = 30))
  crop_ext <- function(a) {
    as.vector(terra::ext(terra::crop(r, terra::ext(sf::st_bbox(a)[c(1, 3, 2, 4)]), snap = "out")))
  }
  # What 0.7.0 read: the plain transform, unmocked against mocked
  for (d in c(window_offsets$reproject, window_offsets$crop)) {
    buf <- sf::st_buffer(shift_east(aoi, d), 100)
    expect_false(identical(crop_ext(sf::st_transform(buf, 3979)),
                           crop_ext(with_sf_datum_shift(sf::st_transform(buf, 3979)))),
                 info = paste("offset", d))
  }
  # For a CSRS AOI, the grid edge snaps differently or the window crops differently
  moved <- function(buf, to, res) {
    !identical(snapped_ext(sf::st_transform(buf, to), res),
               snapped_ext(with_sf_datum_shift(sf::st_transform(buf, to)), res))
  }
  r_res <- terra::res(r)[1]
  for (d in window_offsets$third) {
    buf <- sf::st_buffer(to_csrs_utm(shift_east(aoi, d)), 100)
    window_moved <- !identical(crop_ext(sf::st_transform(buf, 3979)),
                               crop_ext(with_sf_datum_shift(sf::st_transform(buf, 3979))))
    expect_true(moved(buf, 3005, r_res) || window_moved, info = paste("offset", d))
  }
  r_wgs <- terra::rast(x_field_3979(aoi, 100, res = 30, crs = 32610))
  for (d in window_offsets$wgs84_source) {
    buf <- sf::st_buffer(to_csrs_utm(shift_east(aoi, d)), 100)
    expect_true(moved(buf, 3005, terra::res(r_wgs)[1]), info = paste("offset", d))
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

  for (d in window_offsets$reproject) {
    a <- shift_east(aoi, d)
    expect_same_dem(fl_dem_aoi(a, source = src, buffer = 100),
                    with_sf_datum_shift(fl_dem_aoi(a, source = src, buffer = 100)))
  }
})

test_that("fl_dem_aoi crops on the source grid the same whichever PROJ sf links (#78)", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  src <- x_field_3979(aoi, 100, res = 30)

  for (d in window_offsets$crop) {
    a <- shift_east(aoi, d)
    expect_same_dem(fl_dem_aoi(a, source = src, buffer = 100, target_crs = 3979),
                    with_sf_datum_shift(fl_dem_aoi(a, source = src, buffer = 100, target_crs = 3979)))
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
    buf <- sf::st_buffer(shift_east(aoi, d), 100)
    win <- sf::st_bbox(suppressWarnings(
      sf::st_transform(buf, sf::st_crs(3979)$wkt, pipeline = given, reverse = TRUE)
    ))
    bb <- sf::st_bbox(buf)
    res <- terra::res(r)[1]  # terra fits the fixture's 30 m to its extent
    pad <- 2 * max(terra::res(r))
    tmpl <- terra::rast(
      terra::ext(floor(bb[["xmin"]] / res) * res, ceiling(bb[["xmax"]] / res) * res,
                 floor(bb[["ymin"]] / res) * res, ceiling(bb[["ymax"]] / res) * res),
      resolution = res, crs = sf::st_crs(3005)$wkt
    )
    expected <- terra::project(
      terra::crop(r, terra::ext(win[["xmin"]] - pad, win[["xmax"]] + pad,
                                win[["ymin"]] - pad, win[["ymax"]] + pad), snap = "out"),
      tmpl, method = "bilinear", pipeline = given
    )
    a <- shift_east(aoi, d)
    expect_same_dem(fl_dem_aoi(a, source = src, buffer = 100, pipeline = given), expected)
    expect_same_dem(fl_dem_aoi(a, source = src, buffer = 100, pipeline = given),
                    with_sf_datum_shift(fl_dem_aoi(a, source = src, buffer = 100, pipeline = given)))
  }
})

test_that("fl_dem_aoi stops clearly when a supplied pipeline cannot be inverted (#78)", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  src <- x_field_3979(aoi, 100, res = 30)
  # urm5 has no inverse
  no_inverse <- paste(flooded:::dem_pipeline_nad83(sf::st_crs(3979), sf::st_crs(3005)),
                      "+step +proj=urm5 +n=0.9 +alpha=2 +q=4")
  expect_error(fl_dem_aoi(aoi, source = src, buffer = 100, pipeline = no_inverse),
               "could not be inverted")

  # Degrees out, but sf feeds the inverse lat/lon in authority order
  to_degrees <- paste(
    "+proj=pipeline +step +inv +proj=lcc +lat_0=49 +lon_0=-95 +lat_1=49 +lat_2=77",
    "+x_0=0 +y_0=0 +ellps=GRS80 +step +proj=unitconvert +xy_in=rad +xy_out=deg"
  )
  aoi_ll <- sf::st_transform(aoi, 4269)
  expect_error(
    fl_dem_aoi(aoi_ll, source = src, buffer = 100, res = 3e-4, pipeline = to_degrees),
    "could not be inverted"
  )
})

test_that("fl_dem_aoi places the grid the same for an AOI in a third CRS, whichever PROJ sf links (#78)", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  src <- x_field_3979(aoi, 100, res = 30)

  # NAD83(CSRS) / UTM 10N: neither the source's CRS nor the target's
  for (d in window_offsets$third) {
    a <- to_csrs_utm(shift_east(aoi, d))
    expect_same_dem(fl_dem_aoi(a, source = src, buffer = 100, target_crs = 3005),
                    with_sf_datum_shift(fl_dem_aoi(a, source = src, buffer = 100, target_crs = 3005)))
  }
})

test_that("fl_dem_aoi pins an AOI's grid when the source -> target pair has no pin (#78)", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  # WGS 84 / UTM 10N source: WGS 84 -> NAD83 is not pinned, CSRS AOI -> NAD83 is
  src <- x_field_3979(aoi, 100, res = 30, crs = 32610)

  # The read window (CSRS -> WGS 84) has no pin, so only the grid is compared
  for (d in window_offsets$wgs84_source) {
    a <- to_csrs_utm(shift_east(aoi, d))
    expect_identical(
      as.vector(terra::ext(fl_dem_aoi(a, source = src, buffer = 100, target_crs = 3005))),
      as.vector(terra::ext(with_sf_datum_shift(fl_dem_aoi(a, source = src, buffer = 100, target_crs = 3005))))
    )
  }
})

test_that("fl_dem_aoi pipeline = \"\" leaves the read window to sf's PROJ too (#78)", {
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  src <- x_field_3979(aoi, 100, res = 30)
  aoi <- shift_east(aoi, window_offsets$crop[1])

  plain <- fl_dem_aoi(aoi, source = src, buffer = 100, target_crs = 3979, pipeline = "")
  shifted <- with_sf_datum_shift(
    fl_dem_aoi(aoi, source = src, buffer = 100, target_crs = 3979, pipeline = "")
  )

  expect_false(identical(as.vector(terra::ext(plain)), as.vector(terra::ext(shifted))))

  # And on the reproject path
  aoi <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  a <- shift_east(aoi, window_offsets$reproject[1])
  plain <- fl_dem_aoi(a, source = src, buffer = 100, pipeline = "")
  shifted <- with_sf_datum_shift(fl_dem_aoi(a, source = src, buffer = 100, pipeline = ""))
  expect_false(identical(terra::values(plain), terra::values(shifted)))
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
