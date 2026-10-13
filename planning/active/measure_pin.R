# measure_pin.R -- #67, after pinning: on MORR, does the pinned no-shift pipeline make
# the two GDAL/PROJ stacks agree? terra (GDAL 3.13.0 / PROJ 9.8.1) via fl_dem_aoi()
# against sf's gdalwarp (GDAL 3.8.5 / PROJ 9.5.1) given the same pipeline with -ct,
# on the identical 30 m grid. Then delineates both (co_ff04).
# Usage: Rscript planning/active/measure_pin.R <measure_grid out_dir>
suppressMessages(pkgload::load_all(".", quiet = TRUE))
sf::sf_use_s2(FALSE)
out_dir <- commandArgs(TRUE)[1]
log <- function(...) {
  msg <- paste0(format(Sys.time(), "%H:%M:%SZ", tz = "UTC"), " ", ...)
  cat(msg, "\n"); cat(msg, "\n", file = file.path(out_dir, "measure_grid.log"), append = TRUE)
}
fp <- path.expand("~/Projects/repo/floodplains")
gpkg <- file.path(fp, "data/morr/aquatic_network.gpkg")
streams <- sf::st_zm(sf::st_read(gpkg, layer = "streams_co3", quiet = TRUE), drop = TRUE)
for (col in c("upstream_area_ha", "map_upstream", "channel_width", "stream_order")) {
  if (col %in% names(streams)) streams[[col]] <- as.numeric(streams[[col]])
}
waterbodies <- sf::st_zm(sf::st_read(gpkg, layer = "waterbodies_co3", quiet = TRUE), drop = TRUE)
sc <- utils::read.csv(file.path(fp, "config/morr/flood_scenarios.csv"))
sc <- sc[sc$scenario_id == "co_ff04", ]

dem_pin <- fl_dem_aoi(streams, buffer = 2000, target_crs = sf::st_crs(streams))
log("pinned (default): git ", system("git rev-parse --short HEAD", intern = TRUE),
    " res ", terra::res(dem_pin)[1], " ext ", paste(as.vector(terra::ext(dem_pin)), collapse = ", "))
pl <- dem_pipeline_nad83(sf::st_crs(3979), sf::st_crs(streams))
log("pipeline: ", pl)

clip_tif <- file.path(out_dir, "clip_new.tif")
e <- as.vector(terra::ext(dem_pin))
warp <- function(extra, f) {
  unlink(f)
  sf::gdal_utils("warp", clip_tif, f, options = c(
    "-t_srs", paste0("EPSG:", sf::st_crs(streams)$epsg),
    "-te", e[["xmin"]], e[["ymin"]], e[["xmax"]], e[["ymax"]], "-tr", 30, 30,
    "-r", "bilinear", "-ot", "Float64", "-wt", "Float64", extra))
  terra::rast(f)
}
sf_pin <- warp(c("-ct", pl), file.path(out_dir, "warp_sf_pin.tif"))
sf_pin_et0 <- warp(c("-ct", pl, "-et", "0"), file.path(out_dir, "warp_sf_pin_et0.tif"))
terra_util <- terra::project(terra::rast(clip_tif), terra::rast(dem_pin), method = "bilinear",
                             pipeline = pl, by_util = TRUE)
cmp <- function(lab, a, b) {
  a <- terra::values(a, mat = FALSE); b <- terra::values(b, mat = FALSE)
  ok <- !is.na(a) & !is.na(b); d <- abs(a[ok] - b[ok])
  log(sprintf("(d) %-34s cells %d NA-mismatch %d differ %d  median %.4f  p99 %.4f  max %.4f m",
              lab, sum(ok), sum(is.na(a) != is.na(b)), sum(d > 0), stats::median(d),
              stats::quantile(d, .99), max(d)))
}
cmp("terra pinned vs sf -ct pinned", dem_pin, sf_pin)
cmp("terra pinned vs terra by_util", dem_pin, terra_util)
cmp("terra by_util vs sf -ct pinned", terra_util, sf_pin)
cmp("terra pinned vs sf -ct -et 0", dem_pin, sf_pin_et0)

vca <- function(dem) {
  fl_valley_confine(
    dem, streams, area_field = "upstream_area_ha", slope = NULL,
    slope_threshold = sc$slope_threshold, max_width = sc$max_width,
    cost_threshold = sc$cost_threshold, flood_factor = sc$flood_factor,
    precip = fl_stream_rasterize(streams, dem, field = "map_upstream"),
    waterbodies = waterbodies, size_threshold = sc$size_threshold,
    hole_threshold = sc$hole_threshold
  )
}
ref <- vca(dem_pin)
n_ref <- terra::global(ref == 1, "sum", na.rm = TRUE)[[1]]
log(sprintf("(d) terra pinned: %.1f ha", n_ref * 0.09))
for (lab in c("sf_pin", "sf_pin_et0", "terra_util")) {
  v <- vca(get(lab))
  n <- terra::global(v == 1, "sum", na.rm = TRUE)[[1]]
  both <- terra::global((v == 1) & (ref == 1), "sum", na.rm = TRUE)[[1]]
  log(sprintf("(d) terra pinned vs %-11s %.1f -> %.1f ha (%+.2f%%); terra-only %.1f ha, other-only %.1f ha",
              lab, n_ref * 0.09, n * 0.09, 100 * (n / n_ref - 1), (n_ref - both) * 0.09, (n - both) * 0.09))
}
log("done (d)")
