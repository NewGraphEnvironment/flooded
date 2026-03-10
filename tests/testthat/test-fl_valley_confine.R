test_that("fl_valley_confine returns binary SpatRaster", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  valleys <- fl_valley_confine(dem, streams_sf)

  expect_s4_class(valleys, "SpatRaster")
  expect_equal(names(valleys), "valley")

  vals <- terra::values(valleys, na.rm = TRUE)
  expect_true(all(vals %in% c(0L, 1L)))
})

test_that("fl_valley_confine identifies valley cells", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  valleys <- fl_valley_confine(dem, streams_sf)

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

  stream_r <- fl_stream_rasterize(streams_sf, dem, field = "channel_width")
  valleys <- fl_valley_confine(dem, stream_r)

  expect_s4_class(valleys, "SpatRaster")
  expect_true(sum(terra::values(valleys) == 1L, na.rm = TRUE) > 0)
})

test_that("fl_valley_confine accepts pre-computed slope", {
  dem <- terra::rast(testdata_path("dem.tif"))
  slope <- terra::rast(testdata_path("slope.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  valleys <- fl_valley_confine(dem, streams_sf, slope = slope)

  expect_s4_class(valleys, "SpatRaster")
  expect_true(sum(terra::values(valleys) == 1L, na.rm = TRUE) > 0)
})

test_that("fl_valley_confine shrinks with stricter thresholds", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  lax <- fl_valley_confine(dem, streams_sf,
                           slope_threshold = 15, cost_threshold = 5000)
  strict <- fl_valley_confine(dem, streams_sf,
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
  v_default <- fl_valley_confine(dem, streams_sf)
  # Explicit off

  v_no_buf <- fl_valley_confine(dem, streams_sf, channel_buffer = FALSE)

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

  stream_r <- fl_stream_rasterize(streams_sf, dem, field = "channel_width")

  # Pre-rasterized streams: no sf object → channel_buffer auto = FALSE
  v_raster <- fl_valley_confine(dem, stream_r)
  # Explicit FALSE on sf streams
  v_sf_nobuf <- fl_valley_confine(dem, streams_sf, channel_buffer = FALSE)

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
    fl_valley_confine(dem, streams_no_cw, field = "upstream_area_ha",
                      channel_buffer = TRUE),
    "channel_width"
  )
})

test_that("waterbodies adds cells, never removes", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  waterbodies <- sf::st_read(testdata_path("waterbodies.gpkg"), quiet = TRUE)

  v_no_wb <- fl_valley_confine(dem, streams_sf, channel_buffer = FALSE)
  v_wb <- fl_valley_confine(dem, streams_sf, channel_buffer = FALSE,
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

  v_base <- fl_valley_confine(dem, streams_sf, channel_buffer = FALSE)
  v_buf <- fl_valley_confine(dem, streams_sf)
  v_wb <- fl_valley_confine(dem, streams_sf, channel_buffer = FALSE,
                            waterbodies = waterbodies)
  v_both <- fl_valley_confine(dem, streams_sf, waterbodies = waterbodies)

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

  v_no_wb <- fl_valley_confine(dem, streams_sf, channel_buffer = FALSE)
  v_empty <- fl_valley_confine(dem, streams_sf, channel_buffer = FALSE,
                               waterbodies = empty_wb)

  n_no_wb <- sum(terra::values(v_no_wb) == 1L, na.rm = TRUE)
  n_empty <- sum(terra::values(v_empty) == 1L, na.rm = TRUE)

  expect_equal(n_no_wb, n_empty)
})

test_that("waterbodies must be sf", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  expect_error(
    fl_valley_confine(dem, streams_sf, waterbodies = "not_sf"),
    "sf"
  )
})

test_that("output is still binary with features added", {
  dem <- terra::rast(testdata_path("dem.tif"))
  streams_sf <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)
  waterbodies <- sf::st_read(testdata_path("waterbodies.gpkg"), quiet = TRUE)

  valleys <- fl_valley_confine(dem, streams_sf, waterbodies = waterbodies)

  vals <- terra::values(valleys, na.rm = TRUE)
  expect_true(all(vals %in% c(0L, 1L)))
  expect_equal(names(valleys), "valley")
})
