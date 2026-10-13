# probe_warp_kernel.R -- #67: with the pipeline pinned, is the residual terra-vs-gdalwarp value
# difference GDAL's version or the warp settings? Run after measure_pin.R.
# Usage: Rscript planning/active/probe_warp_kernel.R <dir holding measure_morr/>
suppressMessages(devtools::load_all(quiet = TRUE))
S <- commandArgs(TRUE)[1]
clip_tif <- file.path(S, "measure_morr/clip_new.tif")
ref <- terra::rast(file.path(S, "measure_morr/warp_sf_pin.tif"))
e <- as.vector(terra::ext(ref))
pl <- dem_pipeline_nad83(sf::st_crs(3979), sf::st_crs(3005))
cmp <- function(lab, a, b) {
  a <- terra::values(a, mat = FALSE); b <- terra::values(b, mat = FALSE)
  ok <- !is.na(a) & !is.na(b); d <- abs(a[ok] - b[ok])
  cat(sprintf("%-40s differ %d of %d  median %.4f  p99 %.4f  max %.4f\n", lab, sum(d > 0), sum(ok), median(d), quantile(d, .99), max(d)))
}
cmp("sf default vs sf -ct pinned (bilinear)", terra::rast(file.path(S, "measure_morr/warp_sf.tif")), ref)
for (m in c("near", "bilinear")) {
  f <- file.path(S, paste0("k_", m, ".tif")); unlink(f)
  sf::gdal_utils("warp", clip_tif, f, options = c("-t_srs", "EPSG:3005", "-te", e[["xmin"]], e[["ymin"]], e[["xmax"]], e[["ymax"]],
    "-tr", 30, 30, "-r", m, "-ot", "Float64", "-wt", "Float64", "-ct", pl, "-et", "0"))
  t <- terra::project(terra::rast(clip_tif), terra::rast(ref), method = m, pipeline = pl, by_util = TRUE, warpOpts = c("-et", "0"))
  t2 <- terra::project(terra::rast(clip_tif), terra::rast(ref), method = m, pipeline = pl)
  cmp(paste("GDAL3.13 by_util -et0 vs 3.8.5 -et0,", m), t, terra::rast(f))
  cmp(paste("GDAL3.13 default vs 3.8.5 -et0,", m), t2, terra::rast(f))
}

# ---- settings: terra's warper uses an exact transformer and scale 1 ----
ref <- terra::rast(file.path(S, "measure_morr/warp_sf_pin.tif"))
e <- as.vector(terra::ext(ref))
pl <- dem_pipeline_nad83(sf::st_crs(3979), sf::st_crs(3005))
cmp <- function(lab, a, b) {
  a <- terra::values(a, mat = FALSE); b <- terra::values(b, mat = FALSE)
  ok <- !is.na(a) & !is.na(b); d <- abs(a[ok] - b[ok])
  cat(sprintf("%-46s differ %d of %d  median %.6f  max %.6f\n", lab, sum(d > 1e-9), sum(ok), median(d), max(d)))
}
t2 <- terra::project(terra::rast(clip_tif), terra::rast(ref), method = "bilinear", pipeline = pl)
for (wo in list(c(), c("-wo", "XSCALE=1", "-wo", "YSCALE=1"), c("-wo", "XSCALE=1", "-wo", "YSCALE=1", "-et", "0"))) {
  f <- tempfile(fileext = ".tif")
  sf::gdal_utils("warp", clip_tif, f, options = c("-t_srs", "EPSG:3005", "-te", e[["xmin"]], e[["ymin"]], e[["xmax"]], e[["ymax"]],
    "-tr", 30, 30, "-r", "bilinear", "-ot", "Float64", "-wt", "Float64", "-ct", pl, wo))
  cmp(paste("terra(3.13) vs gdalwarp 3.8.5", paste(wo, collapse = " ")), t2, terra::rast(f))
}
