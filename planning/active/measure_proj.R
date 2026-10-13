# measure_proj.R -- #67 follow-on: with the grid fixed, how far does the delineation
# still move when the cell VALUES come from another GDAL/PROJ stack?
# Runs after measure_grid.R, on its outputs: the identical 30 m MORR grid warped by
# sf's gdalwarp (GDAL 3.8.5 / PROJ 9.5.1, default -et and -et 0) vs fl_dem_aoi()
# (terra, GDAL 3.13.0 / PROJ 9.8.1).
# Usage: Rscript planning/active/measure_proj.R <measure_grid out_dir> <dir with w_et0.tif>
suppressMessages(pkgload::load_all(".", quiet = TRUE))
sf::sf_use_s2(FALSE)
a <- commandArgs(TRUE)
log <- function(...) {
  msg <- paste0(format(Sys.time(), "%H:%M:%SZ", tz = "UTC"), " ", ...)
  cat(msg, "\n"); cat(msg, "\n", file = file.path(a[1], "measure_grid.log"), append = TRUE)
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
ref <- terra::rast(file.path(a[1], "valleys_new30.tif"))
n_ref <- terra::global(ref == 1, "sum", na.rm = TRUE)[[1]]
for (f in c(file.path(a[1], "warp_sf.tif"), file.path(a[2], "w_et0.tif"))) {
  v <- vca(terra::rast(f))
  stopifnot(terra::compareGeom(v, ref, stopOnError = FALSE))
  n <- terra::global(v == 1, "sum", na.rm = TRUE)[[1]]
  both <- terra::global((v == 1) & (ref == 1), "sum", na.rm = TRUE)[[1]]
  log(sprintf("(c) terra 30 m vs %-12s %.1f -> %.1f ha (%+.2f%%); shared %.1f ha, terra-only %.1f ha, sf-only %.1f ha",
              basename(f), n_ref * 0.09, n * 0.09, 100 * (n / n_ref - 1), both * 0.09,
              (n_ref - both) * 0.09, (n - both) * 0.09))
}
log("done (c)")
