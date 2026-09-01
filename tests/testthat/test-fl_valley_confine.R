test_that("fl_valley_confine returns binary SpatRaster", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  valleys <- fl_valley_confine(dem, streams_sf, area_field = "upstream_area_ha")

  expect_s4_class(valleys, "SpatRaster")
  expect_equal(names(valleys), "valley")

  vals <- terra::values(valleys, na.rm = TRUE)
  expect_true(all(vals %in% c(0L, 1L)))
})

test_that("fl_valley_confine identifies valley cells", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  valleys <- fl_valley_confine(dem, streams_sf, area_field = "upstream_area_ha")

  n_valley <- sum(terra::values(valleys) == 1L, na.rm = TRUE)
  n_total <- terra::ncell(valleys)

  # Should have some valley cells

  expect_true(n_valley > 0)
  # Valley should be a fraction of total area (not everything)
  expect_true(n_valley / n_total < 0.5)
})

test_that("fl_valley_confine accepts pre-rasterized streams", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  stream_r <- fl_stream_rasterize(streams_sf, dem, field = "upstream_area_ha")
  valleys <- fl_valley_confine(dem, stream_r)

  expect_s4_class(valleys, "SpatRaster")
  expect_true(sum(terra::values(valleys) == 1L, na.rm = TRUE) > 0)
})

test_that("fl_valley_confine accepts pre-computed slope", {
  dem <- terra::rast(testdata_path("dem.tif"))
  slope <- terra::rast(testdata_path("slope.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  valleys <- fl_valley_confine(dem, streams_sf, area_field = "upstream_area_ha", slope = slope)

  expect_s4_class(valleys, "SpatRaster")
  expect_true(sum(terra::values(valleys) == 1L, na.rm = TRUE) > 0)
})

test_that("fl_valley_confine shrinks with stricter thresholds", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  lax <- fl_valley_confine(dem, streams_sf, area_field = "upstream_area_ha",
                           slope_threshold = 15, cost_threshold = 5000)
  strict <- fl_valley_confine(dem, streams_sf, area_field = "upstream_area_ha",
                              slope_threshold = 5, cost_threshold = 1000)

  n_lax <- sum(terra::values(lax) == 1L, na.rm = TRUE)
  n_strict <- sum(terra::values(strict) == 1L, na.rm = TRUE)
  expect_true(n_lax >= n_strict)
})

# --- waterbodies and channel_buffer tests ---

test_that("channel_buffer auto-detects from streams$channel_width", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  # Default: auto-detect (streams has channel_width → buffer on)
  v_default <- fl_valley_confine(dem, streams_sf, area_field = "upstream_area_ha")
  # Explicit off

  v_no_buf <- fl_valley_confine(dem, streams_sf, area_field = "upstream_area_ha", channel_buffer = FALSE)

  n_default <- sum(terra::values(v_default) == 1L, na.rm = TRUE)
  n_no_buf <- sum(terra::values(v_no_buf) == 1L, na.rm = TRUE)

  # Buffer should add cells, not remove
  expect_true(n_default >= n_no_buf)
  # Buffer adds at least some cells (streams have width 4-31m on a 10m grid)
  expect_true(n_default > n_no_buf)
})

test_that("channel_buffer FALSE with rasterized streams is backwards compatible", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  stream_r <- fl_stream_rasterize(streams_sf, dem, field = "upstream_area_ha")

  # Pre-rasterized streams: no sf object → channel_buffer auto = FALSE
  v_raster <- fl_valley_confine(dem, stream_r)
  # Explicit FALSE on sf streams
  v_sf_nobuf <- fl_valley_confine(dem, streams_sf, area_field = "upstream_area_ha", channel_buffer = FALSE)

  n_raster <- sum(terra::values(v_raster) == 1L, na.rm = TRUE)
  n_sf_nobuf <- sum(terra::values(v_sf_nobuf) == 1L, na.rm = TRUE)

  # Both VCA-only: should be identical
  expect_equal(n_raster, n_sf_nobuf)
})

test_that("channel_buffer TRUE warns when no channel_width column", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  # Remove channel_width column
  streams_no_cw <- streams_sf[, setdiff(names(streams_sf), "channel_width")]

  expect_warning(
    fl_valley_confine(dem, streams_no_cw, area_field = "upstream_area_ha",
                      channel_buffer = TRUE),
    "channel_width"
  )
})

test_that("waterbodies adds cells, never removes", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  waterbodies <- sf::st_read(testdata_path("waterbodies.gpkg"), quiet = TRUE)

  v_no_wb <- fl_valley_confine(dem, streams_sf, area_field = "upstream_area_ha", channel_buffer = FALSE)
  v_wb <- fl_valley_confine(dem, streams_sf, area_field = "upstream_area_ha", channel_buffer = FALSE,
                            waterbodies = waterbodies)

  n_no_wb <- sum(terra::values(v_no_wb) == 1L, na.rm = TRUE)
  n_wb <- sum(terra::values(v_wb) == 1L, na.rm = TRUE)

  expect_true(n_wb >= n_no_wb)
  # Waterbodies should add at least some cells (16 features in test data)
  expect_true(n_wb > n_no_wb)
})

test_that("waterbodies + channel_buffer is additive", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  waterbodies <- sf::st_read(testdata_path("waterbodies.gpkg"), quiet = TRUE)

  v_base <- fl_valley_confine(dem, streams_sf, area_field = "upstream_area_ha", channel_buffer = FALSE)
  v_buf <- fl_valley_confine(dem, streams_sf, area_field = "upstream_area_ha")
  v_wb <- fl_valley_confine(dem, streams_sf, area_field = "upstream_area_ha", channel_buffer = FALSE,
                            waterbodies = waterbodies)
  v_both <- fl_valley_confine(dem, streams_sf, area_field = "upstream_area_ha", waterbodies = waterbodies)

  n_base <- sum(terra::values(v_base) == 1L, na.rm = TRUE)
  n_buf <- sum(terra::values(v_buf) == 1L, na.rm = TRUE)
  n_wb <- sum(terra::values(v_wb) == 1L, na.rm = TRUE)
  n_both <- sum(terra::values(v_both) == 1L, na.rm = TRUE)

  # Monotonic: base <= buf, base <= wb, both >= buf, both >= wb
  expect_true(n_buf >= n_base)
  expect_true(n_wb >= n_base)
  expect_true(n_both >= n_buf)
  expect_true(n_both >= n_wb)
})

test_that("empty waterbodies sf is a no-op", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  waterbodies <- sf::st_read(testdata_path("waterbodies.gpkg"), quiet = TRUE)

  empty_wb <- waterbodies[0, ]

  v_no_wb <- fl_valley_confine(dem, streams_sf, area_field = "upstream_area_ha", channel_buffer = FALSE)
  v_empty <- fl_valley_confine(dem, streams_sf, area_field = "upstream_area_ha", channel_buffer = FALSE,
                               waterbodies = empty_wb)

  n_no_wb <- sum(terra::values(v_no_wb) == 1L, na.rm = TRUE)
  n_empty <- sum(terra::values(v_empty) == 1L, na.rm = TRUE)

  expect_equal(n_no_wb, n_empty)
})

test_that("waterbodies must be sf", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  expect_error(
    fl_valley_confine(dem, streams_sf, area_field = "upstream_area_ha", waterbodies = "not_sf"),
    # Anchor on the argument, not on "sf": the required-`area_field` message and
    # the `streams` type error both contain "sf" too, so a bare "sf" here would
    # pass for the wrong reason if area_field were ever dropped from this call.
    "waterbodies"
  )
})

test_that("output is still binary with features added", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  waterbodies <- sf::st_read(testdata_path("waterbodies.gpkg"), quiet = TRUE)

  valleys <- fl_valley_confine(dem, streams_sf, area_field = "upstream_area_ha", waterbodies = waterbodies)

  vals <- terra::values(valleys, na.rm = TRUE)
  expect_true(all(vals %in% c(0L, 1L)))
  expect_equal(names(valleys), "valley")
})

# --- area_field contract (#47) ---
#
# `area_field` is the drainage-area term of the Hall bankfull regression, in
# hectares. It has no default: channel width and upstream area are both plain
# positive numerics, so a wrong column produces a smaller floodplain with no
# error. `field` is the deprecated spelling, kept for one release.

# fl_valley_confine() is ~1.4 s on the bundled tile — build the reference
# delineation once and compare the alias paths against it.
af_fixture <- local({
  cache <- NULL
  function() {
    if (is.null(cache)) {
      dem <- terra::rast(testdata_path("dem.tif"))
      streams <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
      ref <- fl_valley_confine(dem, streams, area_field = "upstream_area_ha")
      cache <<- list(dem = dem, streams = streams, ref = ref)
    }
    cache
  }
})

test_that("area_field is required when streams is sf", {
  f <- af_fixture()

  expect_error(fl_valley_confine(f$dem, f$streams), "area_field")
  # The message must name the quantity and its units, not just the argument —
  # the whole defect is that a plausible number is accepted for the wrong one.
  err <- tryCatch(fl_valley_confine(f$dem, f$streams), error = function(e) conditionMessage(e))
  expect_match(err, "hectare")
})

test_that("area_field is not required when streams is already rasterized", {
  f <- af_fixture()

  # The SpatRaster branch never reaches fl_stream_rasterize(), so area_field is
  # irrelevant there and must not be demanded.
  stream_r <- fl_stream_rasterize(f$streams, f$dem, field = "upstream_area_ha")
  valleys <- fl_valley_confine(f$dem, stream_r)

  expect_s4_class(valleys, "SpatRaster")
  expect_true(sum(terra::values(valleys) == 1L, na.rm = TRUE) > 0)
  # ... and an area layer must not trip the wrong-column warning below.
  expect_no_warning(fl_valley_confine(f$dem, stream_r))
})

test_that("a raster named channel_width warns", {
  f <- af_fixture()

  # The residual #47 hazard: the sf branch is closed, but a raster burned from
  # the rasterizer's own default carries the same wrong quantity one call
  # earlier. The layer name is the tell — fl_stream_rasterize() names its output
  # after the column it burned.
  #
  # The guard names "channel_width" literally, and this asserts the coincidence
  # that makes the default dangerous. If the line below fails,
  # fl_stream_rasterize()'s default has moved: fix this fixture, NOT the guard —
  # keying the guard to the default would invert it, warning on a correct area
  # raster and going silent on the defect.
  expect_equal(formals(fl_stream_rasterize)$field, "channel_width")

  default_r <- fl_stream_rasterize(f$streams, f$dem, field = "channel_width")

  expect_equal(names(default_r), "channel_width")
  expect_warning(fl_valley_confine(f$dem, default_r), "not upstream contributing")
})

test_that("deprecated field= warns and forwards to area_field", {
  f <- af_fixture()

  expect_warning(
    v_dep <- fl_valley_confine(f$dem, f$streams, field = "upstream_area_ha"),
    "area_field"
  )
  # Forwarding must be exact, not merely similar in extent.
  expect_equal(terra::values(v_dep), terra::values(f$ref))
})

test_that("area_field wins when both spellings are supplied", {
  f <- af_fixture()

  expect_warning(
    v_both <- fl_valley_confine(f$dem, f$streams,
                                area_field = "upstream_area_ha",
                                field = "channel_width"),
    "area_field"
  )
  expect_equal(terra::values(v_both), terra::values(f$ref))
})

test_that("area_field is the third positional argument", {
  f <- af_fixture()

  v_pos <- fl_valley_confine(f$dem, f$streams, "upstream_area_ha")

  expect_equal(terra::values(v_pos), terra::values(f$ref))
})

test_that("channel width and upstream area are not interchangeable", {
  f <- af_fixture()

  # Why area_field can have no default: both columns are positive numerics, and
  # the smaller one silently returns a smaller floodplain. channel_width is
  # 4.1-31.3 against upstream_area_ha 1,928.8-110,337.4.
  #
  # channel_buffer = FALSE on both sides. With the buffer on, the channel is
  # ORed back in after cleanup regardless of what the flood model returned, so
  # `n_cw > 0` would hold even for an all-zero flood mask, and the shared
  # buffered cells compress the gap being measured.
  #
  # The inequality is measured on this tile, not derived: the flood *surface* is
  # monotonic in area, but the cell count is not a monotone function of it —
  # closing, hole fill, patch removal and the modal filter all sit in between.
  v_cw <- fl_valley_confine(f$dem, f$streams, area_field = "channel_width",
                            channel_buffer = FALSE)
  v_area <- fl_valley_confine(f$dem, f$streams, area_field = "upstream_area_ha",
                              channel_buffer = FALSE)

  n_cw <- sum(terra::values(v_cw) == 1L, na.rm = TRUE)
  n_area <- sum(terra::values(v_area) == 1L, na.rm = TRUE)

  expect_gt(n_cw, 0)
  expect_lt(n_cw, n_area)

  # Stronger than the counts, and the claim NEWS makes: the wrong column does not
  # merely map less, it maps a strict subset — it never finds ground the right
  # column misses.
  cw <- as.vector(terra::values(v_cw)) == 1L
  ar <- as.vector(terra::values(v_area)) == 1L
  cw[is.na(cw)] <- FALSE
  ar[is.na(ar)] <- FALSE
  expect_equal(sum(cw & !ar), 0L)
})

test_that("the area_field path is silent", {
  f <- af_fixture()

  # Negative control for the deprecation warning: without this, an
  # implementation that warns unconditionally passes every test above, because
  # an uncaught warning does not fail a testthat 3e test.
  expect_no_warning(fl_valley_confine(f$dem, f$streams, area_field = "upstream_area_ha"))
})

test_that("area_field must be a single column name", {
  f <- af_fixture()

  # Without an explicit check these fall through to fl_stream_rasterize(), whose
  # message names `field` — the argument the caller did not use.
  expect_error(fl_valley_confine(f$dem, f$streams, area_field = NULL), "area_field")
  expect_error(fl_valley_confine(f$dem, f$streams, area_field = 3), "area_field")
  expect_error(fl_valley_confine(f$dem, f$streams,
                                 area_field = c("upstream_area_ha", "channel_width")),
               "area_field")
})
