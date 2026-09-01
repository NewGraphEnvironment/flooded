test_that("fl_flood_surface returns NA at non-stream cells", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  stream_r <- fl_stream_rasterize(streams_sf, dem, field = "channel_width")

  surface <- fl_flood_surface(dem, stream_r)

  expect_s4_class(surface, "SpatRaster")
  expect_equal(names(surface), "flood_surface")

  # Non-stream cells should be NA
  stream_cells <- !is.na(terra::values(stream_r))
  surface_vals <- terra::values(surface)
  expect_true(all(is.na(surface_vals[!stream_cells])))
  # Stream cells should have values
  expect_true(all(!is.na(surface_vals[stream_cells])))
})

test_that("fl_flood_surface exceeds DEM at stream cells", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  stream_r <- fl_stream_rasterize(streams_sf, dem, field = "channel_width")

  surface <- fl_flood_surface(dem, stream_r)

  stream_cells <- which(!is.na(terra::values(stream_r)))
  dem_at_streams <- terra::values(dem)[stream_cells]
  surface_at_streams <- terra::values(surface)[stream_cells]

  # Flood surface should be above DEM (flood_factor > 0)
  expect_true(all(surface_at_streams > dem_at_streams))
})

test_that("fl_flood_surface increases with flood_factor", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  stream_r <- fl_stream_rasterize(streams_sf, dem, field = "channel_width")

  s3 <- fl_flood_surface(dem, stream_r, flood_factor = 3)
  s9 <- fl_flood_surface(dem, stream_r, flood_factor = 9)

  stream_cells <- which(!is.na(terra::values(stream_r)))
  expect_true(all(terra::values(s9)[stream_cells] > terra::values(s3)[stream_cells]))
})

test_that("fl_flood_surface works on synthetic data", {
  # Flat DEM at 100m, stream with area = 1000ha
  dem <- terra::rast(nrows = 5, ncols = 5, vals = 100,
                     xmin = 0, xmax = 50, ymin = 0, ymax = 50, crs = "EPSG:3005")
  stream_vals <- rep(NA, 25)
  stream_vals[13] <- 1000  # centre cell, 1000ha
  streams <- terra::rast(nrows = 5, ncols = 5, vals = stream_vals,
                         xmin = 0, xmax = 50, ymin = 0, ymax = 50, crs = "EPSG:3005")

  # precip = NULL drops the term. A literal 1 would mean one millimetre.
  surface <- fl_flood_surface(dem, streams, flood_factor = 6, precip = NULL)

  # Only centre cell should have a value
  expect_equal(sum(!is.na(terra::values(surface))), 1L)
  # Should be > 100 (DEM + some flood depth)
  expect_true(terra::values(surface)[13] > 100)
})

test_that("fl_flood_surface errors on mismatched grids", {
  r1 <- terra::rast(nrows = 5, ncols = 5, vals = 100,
                    xmin = 0, xmax = 5, ymin = 0, ymax = 5)
  r2 <- terra::rast(nrows = 10, ncols = 10, vals = 1,
                    xmin = 0, xmax = 5, ymin = 0, ymax = 5)
  expect_error(fl_flood_surface(r1, r2), "same extent")
})

# --- Units guard ------------------------------------------------------------
#
# Hall et al. (2007) and Nagel et al. (2014) both specify the bankfull
# regression as taking drainage area in km2 and mean annual precipitation in
# cm/yr. Callers supply hectares and millimetres, so the conversion happens
# inside fl_flood_surface(). See flooded#49.
#
# The expected values below are hard literals computed from the published
# equation on km2 / cm. They are deliberately NOT computed from Nagel's
# combined form h_bf = 0.054 * A^0.170 * P^0.215, which is an algebraic
# identity of the two-step form:
#
#   0.145 * 0.196^0.607 = 0.05393 ~ 0.054
#   0.280 * 0.607       = 0.16996 ~ 0.170
#   0.355 * 0.607       = 0.21549 ~ 0.215
#
# Being an identity, it agrees with the two-step form in ANY units and so
# cannot detect a units defect. A literal is the only oracle that can.

# One-cell fixture on a zero DEM, so the flood surface IS the flood depth.
units_fixture <- function(area_ha, precip_mm = NULL) {
  mk <- function(vals) {
    terra::rast(nrows = 3, ncols = 3, vals = vals,
                xmin = 0, xmax = 30, ymin = 0, ymax = 30, crs = "EPSG:3005")
  }
  stream_vals <- rep(NA_real_, 9)
  stream_vals[5] <- area_ha
  out <- list(dem = mk(0), streams = mk(stream_vals))
  if (!is.null(precip_mm)) {
    precip_vals <- rep(NA_real_, 9)
    precip_vals[5] <- precip_mm
    out$precip <- mk(precip_vals)
  }
  out
}

test_that("fl_flood_surface converts hectares and mm to km2 and cm/yr", {
  # A = 10,000 ha = 100 km2 ; P = 500 mm = 50 cm ; flood_factor = 1
  #   W = 0.196 * 100^0.280 * 50^0.355 = 2.8535824338 m
  #   D = 0.145 * W^0.607              = 0.2740248754 m
  # Feeding ha and mm straight in gives 0.9844530049 m — 3.5926x too deep.
  f <- units_fixture(area_ha = 10000)

  surface <- fl_flood_surface(f$dem, f$streams,
                              flood_factor = 1, precip = 500)

  expect_equal(terra::values(surface)[5], 0.2740248754, tolerance = 1e-8)
})

test_that("fl_flood_surface treats a precip raster the same as a scalar", {
  f <- units_fixture(area_ha = 10000, precip_mm = 500)

  scalar_surface <- fl_flood_surface(f$dem, f$streams,
                                     flood_factor = 1, precip = 500)
  raster_surface <- fl_flood_surface(f$dem, f$streams,
                                     flood_factor = 1, precip = f$precip)

  expect_equal(terra::values(raster_surface)[5],
               terra::values(scalar_surface)[5], tolerance = 1e-8)
  expect_equal(terra::values(raster_surface)[5], 0.2740248754,
               tolerance = 1e-8)
})

test_that("fl_flood_surface drops the precipitation term when precip is NULL", {
  # With the term omitted the multiplier is exactly 1, so
  #   D = 0.145 * (0.196 * 100^0.280)^0.607 = 0.1179471463 m
  # A default of `precip = 1` cannot express this once the input is read as
  # millimetres: 1 mm is 0.1 cm/yr, scaling width by 0.4416 and depth by
  # 0.6089 — shallower than omitting the term, not equal to it.
  f <- units_fixture(area_ha = 10000)

  surface <- fl_flood_surface(f$dem, f$streams, flood_factor = 1,
                              precip = NULL)

  expect_equal(terra::values(surface)[5], 0.1179471463, tolerance = 1e-8)
  expect_equal(terra::values(surface)[5],
               terra::values(fl_flood_surface(f$dem, f$streams,
                                              flood_factor = 1))[5],
               tolerance = 1e-8)
})

test_that("fl_flood_surface scales linearly with flood_factor", {
  f <- units_fixture(area_ha = 10000)

  s1 <- fl_flood_surface(f$dem, f$streams, flood_factor = 1, precip = 500)
  s6 <- fl_flood_surface(f$dem, f$streams, flood_factor = 6, precip = 500)

  expect_equal(terra::values(s6)[5], 6 * terra::values(s1)[5],
               tolerance = 1e-8)
  expect_equal(terra::values(s6)[5], 6 * 0.2740248754, tolerance = 1e-8)
})
