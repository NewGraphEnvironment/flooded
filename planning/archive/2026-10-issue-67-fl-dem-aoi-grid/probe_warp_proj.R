S <- commandArgs(TRUE)[1]
clip_tif <- file.path(S, "measure_morr/clip_new.tif")
ref <- terra::rast(file.path(S, "measure_morr/warp_sf.tif"))
e <- as.vector(terra::ext(ref))
warp <- function(extra, f) {
  unlink(f)
  sf::gdal_utils("warp", clip_tif, f, options = c("-t_srs", "EPSG:3005",
    "-te", e[["xmin"]], e[["ymin"]], e[["xmax"]], e[["ymax"]], "-tr", 30, 30,
    "-r", "bilinear", "-ot", "Float64", "-wt", "Float64", extra))
  terra::values(terra::rast(f), mat = FALSE)
}
v_sf <- terra::values(ref, mat = FALSE)
v_sf_et0 <- warp(c("-et", "0"), file.path(S, "w_et0.tif"))
tmpl <- terra::rast(ref)
v_t <- terra::values(terra::project(terra::rast(clip_tif), tmpl, method = "bilinear"), mat = FALSE)
cmp <- function(lab, a, b) { ok <- !is.na(a) & !is.na(b); d <- abs(a[ok] - b[ok])
  cat(sprintf("%-34s differ %d of %d  max %.4f  p99 %.4f  median %.5f\n", lab, sum(d > 1e-9), sum(ok), max(d), quantile(d, .99), median(d))) }
cmp("sf default vs sf -et 0", v_sf, v_sf_et0)
cmp("terra default vs sf -et 0", v_t, v_sf_et0)
# datum operation: one point through each PROJ
p <- cbind(c(1100000, 1200000), c(1000000, 1100000))  # BC Albers
pt_sf <- sf::st_coordinates(sf::st_transform(sf::st_sfc(sf::st_multipoint(p), crs = 3005), 3979))[, 1:2]
pt_te <- terra::project(p, "EPSG:3005", "EPSG:3979")
cat("3005->3979 sf (PROJ 9.5.1) minus terra (PROJ 9.8.1), metres:\n"); print(pt_sf - pt_te)
