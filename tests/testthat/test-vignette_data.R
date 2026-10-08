# vignettes/stac-dem.Rmd compares live 10 m runs against lidar results cached
# by data-raw/stac_dem_vignette_data.R. The cache records the 10 m cell counts
# the same code produced when it was built; if fl_valley_confine() changes,
# the live counts move and the cached lidar results no longer compare
# like-for-like. Fail here so the drift is seen at test time, not only on the
# rendered page.

stac_vca <- function(dem, streams, slope) {
  fl_valley_confine(
    dem, streams,
    area_field = "upstream_area_ha",
    slope = slope,
    slope_threshold = 9,
    max_width = 2000,
    cost_threshold = 2500,
    flood_factor = 6,
    precip = fl_stream_rasterize(streams, dem, field = "map_upstream")
  )
}

test_that("stac-dem cached lidar results match the current fl_valley_confine()", {
  meta <- readRDS(system.file("vignette-data", "stac_meta.rds",
                              package = "flooded", mustWork = TRUE))
  regen <- "Re-run data-raw/stac_dem_vignette_data.R (needs the STAC endpoint)."

  dem <- terra::rast(testdata_path("dem.tif"))
  slope <- terra::rast(testdata_path("slope.tif"))
  streams <- sf::st_read(testdata_path("streams.gpkg"), quiet = TRUE)

  n_10m <- sum(terra::values(stac_vca(dem, streams, slope)) == 1, na.rm = TRUE)
  expect_equal(n_10m, meta$n_10m, info = regen)

  site_ext <- terra::ext(976560, 980060, 1055808, 1059808)
  streams_site <- suppressWarnings(sf::st_crop(streams, sf::st_as_sfc(sf::st_bbox(
    c(xmin = 976560, ymin = 1055808, xmax = 980060, ymax = 1059808),
    crs = sf::st_crs(streams)
  ))))
  valleys_site <- stac_vca(terra::crop(dem, site_ext), streams_site,
                           terra::crop(slope, site_ext))
  n_site_10m <- sum(terra::values(valleys_site) == 1, na.rm = TRUE)
  expect_equal(n_site_10m, meta$n_site_10m, info = regen)
})

test_that("stac-dem cached rasters sit on the grids the vignette compares them to", {
  dem <- terra::rast(testdata_path("dem.tif"))
  site_ext <- terra::ext(976560, 980060, 1055808, 1059808)
  v5 <- terra::rast(system.file("vignette-data", "stac_valleys_5m.tif",
                                package = "flooded", mustWork = TRUE))
  v1 <- terra::rast(system.file("vignette-data", "stac_valleys_1m_site.tif",
                                package = "flooded", mustWork = TRUE))

  expect_true(terra::compareGeom(v5, dem, stopOnError = FALSE))
  expect_true(terra::compareGeom(v1, terra::crop(dem, site_ext), stopOnError = FALSE))
  expect_true(all(terra::values(v5, na.rm = TRUE) %in% c(0, 1)))
  expect_true(all(terra::values(v1, na.rm = TRUE) %in% c(0, 1)))
})

test_that("stac-dem cached lidar rasters carry the lidar gap as NA (#63)", {
  # The 10 m guard above cannot see #63: the bundled DEM has no NA. Before the
  # fix the 2019 lidar gap (22% of the tile, ~8% of the site) was cached as 0
  # outside the channel buffer; with it those cells are NA. Pin the exact counts
  # from the rebuild at 1ea1ae5: a partial regression can leave some NA (when
  # fl_patch_rm() returns early, #65), so "any NA" would not catch it.
  v5 <- terra::rast(system.file("vignette-data", "stac_valleys_5m.tif",
                                package = "flooded", mustWork = TRUE))
  v1 <- terra::rast(system.file("vignette-data", "stac_valleys_1m_site.tif",
                                package = "flooded", mustWork = TRUE))
  expect_equal(terra::global(is.na(v5), "sum")[[1]], 115385)
  expect_equal(terra::global(is.na(v1), "sum")[[1]], 11020)
})
