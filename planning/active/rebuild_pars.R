# rebuild_pars.R -- regenerate the DEM-dependent Parsnip vignette cache for #67.
#
# Steps 5-7 of data-raw/wsg_vignette_data.R only, from the cached pars.gpkg
# streams and waterbodies, so no DB is needed and nothing but the grid changes:
# pars_dem.tif, pars_valleys.tif (ff04) and the `floodplain` layer of pars.gpkg are
# rewritten. Every other layer and pars_meta.rds is checked unchanged.
# Also runs ff06 and ff07 (not cached) for the scenario-span figures in the prose.
#
# Usage (from the package root): Rscript planning/active/rebuild_pars.R <log_dir>

Sys.setenv(GDAL_HTTP_MAX_RETRY = "3", GDAL_HTTP_RETRY_DELAY = "2", VSI_CACHE = "TRUE")
suppressMessages(pkgload::load_all(".", quiet = TRUE))

args <- commandArgs(TRUE)
log_dir <- if (length(args)) args[1] else stop("pass a log directory")
dir.create(log_dir, showWarnings = FALSE, recursive = TRUE)
log <- function(...) {
  msg <- paste0(format(Sys.time(), "%H:%M:%SZ", tz = "UTC"), " ", ...)
  cat(msg, "\n")
  cat(msg, "\n", file = file.path(log_dir, "rebuild_pars.log"), append = TRUE)
}

out_dir <- file.path("inst", "vignette-data")
gpkg <- file.path(out_dir, "pars.gpkg")
out <- function(name) file.path(out_dir, paste0("pars_", name))

layer_md5 <- function() {
  lyr <- setdiff(sf::st_layers(gpkg)$name, "floodplain")
  vapply(lyr, function(l) {
    f <- tempfile(fileext = ".rds")
    saveRDS(sf::st_read(gpkg, layer = l, quiet = TRUE), f, version = 3)
    unname(tools::md5sum(f))
  }, character(1))
}
md5_before <- layer_md5()
meta_before <- unname(tools::md5sum(out("meta.rds")))

dem_prev <- terra::rast(out("dem.tif"))
log(sprintf("previous dem: res %.6f  ncell %d  non-NA %.1f%%", terra::res(dem_prev)[1],
            terra::ncell(dem_prev),
            100 * terra::global(!is.na(dem_prev), "sum")[[1]] / terra::ncell(dem_prev)))

streams <- sf::st_read(gpkg, layer = "streams", quiet = TRUE)
waterbodies <- sf::st_read(gpkg, layer = "waterbodies", quiet = TRUE)
log("streams ", nrow(streams), ", waterbodies ", nrow(waterbodies))

# ---- 5. DEM -------------------------------------------------------------------
dem <- fl_dem_aoi(streams, buffer = 2000)
e <- as.vector(terra::ext(dem))
log(sprintf("new dem: res %s  ext %s  ncell %d  non-NA %.1f%%",
            paste(terra::res(dem), collapse = " x "), paste(e, collapse = ", "),
            terra::ncell(dem),
            100 * terra::global(!is.na(dem), "sum")[[1]] / terra::ncell(dem)))
stopifnot(identical(terra::res(dem), c(30, 30)), all(e %% 30 == 0))
terra::writeRaster(
  terra::as.int(dem), out("dem.tif"),
  overwrite = TRUE, datatype = "INT2S",
  gdal = c("COMPRESS=DEFLATE", "PREDICTOR=2", "TILED=YES")
)

# ---- 6. VCA -------------------------------------------------------------------
terra::terraOptions(threads = max(1L, parallel::detectCores() - 2L))
precip <- fl_stream_rasterize(streams, dem, field = "map_upstream")
vca <- function(ff) {
  fl_valley_confine(
    dem = dem, streams = streams, area_field = "upstream_area_ha",
    precip = precip, waterbodies = waterbodies, flood_factor = ff
  )
}
ha <- c()
for (ff in c(4, 6, 7)) {
  t0 <- proc.time()
  v <- vca(ff)
  tt <- proc.time() - t0
  n <- terra::global(v == 1, "sum", na.rm = TRUE)[[1]]
  ha[as.character(ff)] <- n * prod(terra::res(v)) / 1e4
  log(sprintf("ff%02d: %d cells, %.1f ha (elapsed %.0f s, cpu %.0f s)", ff, n,
              ha[as.character(ff)], tt[["elapsed"]], tt[["user.self"]] + tt[["sys.self"]]))
  if (ff == 4) {
    terra::writeRaster(v, out("valleys.tif"), overwrite = TRUE, datatype = "INT1U",
                       gdal = c("COMPRESS=DEFLATE", "TILED=YES"))
    floodplain <- fl_valley_poly(v)
    sf::st_write(floodplain, gpkg, layer = "floodplain", delete_layer = TRUE,
                 append = TRUE, quiet = TRUE)
  }
}
log(sprintf("ff04 -> ff06 %+.1f%%, ff04 -> ff07 %+.1f%%",
            100 * (ha[["6"]] / ha[["4"]] - 1), 100 * (ha[["7"]] / ha[["4"]] - 1)))

# ---- checks -------------------------------------------------------------------
md5_after <- layer_md5()
log("non-floodplain layers unchanged: ", identical(md5_before, md5_after),
    " (", paste(names(md5_before), collapse = ", "), ")")
log("pars_meta.rds unchanged: ", identical(meta_before, unname(tools::md5sum(out("meta.rds")))))
log("done")
