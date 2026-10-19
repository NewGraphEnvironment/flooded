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
  # from the rebuild at 1ea1ae5: a partial regression can leave some NA (before
  # #65, fl_patch_rm() kept NA on its early return), so "any NA" would not catch it.
  v5 <- terra::rast(system.file("vignette-data", "stac_valleys_5m.tif",
                                package = "flooded", mustWork = TRUE))
  v1 <- terra::rast(system.file("vignette-data", "stac_valleys_1m_site.tif",
                                package = "flooded", mustWork = TRUE))
  expect_equal(terra::global(is.na(v5), "sum")[[1]], 115385)
  expect_equal(terra::global(is.na(v1), "sum")[[1]], 11020)
})

# vignettes/pars-floodplain.Rmd quotes data-raw/wsg_vignette_data.R's bundle. These fail when the
# bundle, or a source it was built from, is no longer what pars_meta.rds records, so the article
# cannot go on quoting a run that has been superseded. The database and DEM checks need the
# sources, so they run on a machine that has them and skip elsewhere.

pars_meta <- function() {
  readRDS(system.file("vignette-data", "pars_meta.rds", package = "flooded", mustWork = TRUE))
}
regen_pars <- "Re-run data-raw/wsg_vignette_data.R from a committed tree."

test_that("the Parsnip bundle is the one its meta describes", {
  meta <- pars_meta()
  expect_setequal(names(meta$md5_files), c("pars.gpkg", "pars_dem.tif", "pars_valleys.tif"))
  for (f in names(meta$md5_files)) {
    p <- system.file("vignette-data", f, package = "flooded", mustWork = TRUE)
    expect_identical(unname(tools::md5sum(p)), meta$md5_files[[f]], info = paste(f, "changed.", regen_pars))
  }
})

test_that("the Parsnip floodplain in meta is the valley grid's, inside the boundary", {
  meta <- pars_meta()
  aoi <- sf::st_read(system.file("vignette-data", "pars.gpkg", package = "flooded"), layer = "aoi", quiet = TRUE)
  v <- terra::rast(system.file("vignette-data", "pars_valleys.tif", package = "flooded"))
  v <- terra::mask(terra::crop(v, terra::vect(aoi)), terra::vect(aoi))
  ff <- as.character(meta$vca_args$flood_factor)
  expect_identical(meta$fp_cells[[ff]], as.integer(sum(terra::values(v) == 1L, na.rm = TRUE)))
  expect_identical(meta$fp_area_ha, meta$fp_cells * prod(terra::res(v)) / 1e4)
})

test_that("every database source of the Parsnip bundle is unchanged since it was built", {
  skip_on_cran()
  skip_on_ci()
  skip_if_not_installed("DBI")
  skip_if_not_installed("fresh")
  meta <- pars_meta()
  digest <- function(conn, sql) {
    d <- DBI::dbGetQuery(conn, sprintf(
      "SELECT md5(string_agg(md5(t::text), '' ORDER BY md5(t::text))) AS d FROM (%s) t", sql))$d
    if (is.na(d)) "empty" else d
  }
  old <- Sys.getenv("PGCONNECT_TIMEOUT", NA)
  Sys.setenv(PGCONNECT_TIMEOUT = "5")
  on.exit(if (is.na(old)) Sys.unsetenv("PGCONNECT_TIMEOUT") else Sys.setenv(PGCONNECT_TIMEOUT = old))
  conn <- tryCatch(fresh::frs_db_conn(), error = function(e) NULL)
  skip_if(is.null(conn), "the database the Parsnip bundle was built from is not reachable")
  on.exit(DBI::dbDisconnect(conn), add = TRUE)
  skip_if(is.na(DBI::dbGetQuery(conn, "SELECT to_regclass('fresh_default.log') AS t")$t),
          "the reachable database has no fresh_default schema")
  # fwapg sources only: the map's context layers come from a second database
  # (PG_*_SHARE) and are drawn, never quoted
  src <- meta$sources[meta$sources$db == "fwapg", ]
  expect_gt(nrow(src), 0)
  for (i in seq_len(nrow(src))) {
    expect_identical(digest(conn, src$sql[i]), src$digest[i],
                     info = paste(src$name[i], "has moved in the database.", regen_pars))
  }
})

test_that("the Parsnip DEM's source is unchanged since it was built", {
  skip_on_cran()
  skip_on_ci()
  meta <- pars_meta()
  h <- tryCatch(curlGetHeaders(meta$dem_source$url), error = function(e) NULL)
  skip_if(is.null(h) || attr(h, "status") != 200L, "MRDEM-30 is not reachable")
  etag <- sub("^etag:\\s*", "", trimws(grep("^etag:", h, ignore.case = TRUE, value = TRUE)), ignore.case = TRUE)
  expect_identical(etag, meta$dem_source$etag, info = paste("MRDEM-30 has changed.", regen_pars))
})
