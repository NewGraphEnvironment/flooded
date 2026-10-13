# measure_grid.R -- #67's two open questions, on the MORR coho network.
#
#   (a) On one identical target grid, do the projected cell values differ between
#       the GDAL/PROJ stacks terra and sf link?
#   (b) What does the fixed 30 m grid do to the delineation, compared with the
#       grid GDAL chose before #67? A middle arm at the old cell size (30.4306 m)
#       on an aligned grid separates origin from resolution.
#
# Usage (from the package root):
#   Rscript planning/archive/2026-10-issue-67-fl-dem-aoi-grid/measure_grid.R <out_dir>
# Inputs: floodplains' data/morr/aquatic_network.gpkg (streams_co3, waterbodies_co3),
# buffer 2000 m, target CRS = the streams' CRS, co_ff04 parameters from
# floodplains config/morr/flood_scenarios.csv. Reads MRDEM-30 over /vsicurl/.

suppressMessages(pkgload::load_all(".", quiet = TRUE))
sf::sf_use_s2(FALSE)

args <- commandArgs(TRUE)
out_dir <- if (length(args)) args[1] else stop("pass an output directory")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
log <- function(...) {
  msg <- paste0(format(Sys.time(), "%H:%M:%SZ", tz = "UTC"), " ", ...)
  cat(msg, "\n")
  cat(msg, "\n", file = file.path(out_dir, "measure_grid.log"), append = TRUE)
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
stopifnot(nrow(sc) == 1L)

src <- paste0("/vsicurl/https://canelevation-dem.s3.ca-central-1.amazonaws.com/",
              "mrdem-30/mrdem-30-dtm.tif")
buf <- 2000
tcrs <- sf::st_crs(streams)

# ---- Toolchain ----------------------------------------------------------------
tg <- terra::gdal(lib = "all")
sv <- sf::sf_extSoftVersion()
log("terra ", as.character(utils::packageVersion("terra")),
    " links GDAL ", tg[["gdal"]], " PROJ ", tg[["proj"]])
log("sf ", as.character(utils::packageVersion("sf")),
    " links GDAL ", sv[["GDAL"]], " PROJ ", sv[["PROJ"]],
    "; sf_proj_network() = ", sf::sf_proj_network())
log("flooded ", as.character(utils::packageVersion("flooded")),
    " (load_all, git ", system("git rev-parse --short HEAD", intern = TRUE), ")")
log("streams_co3: ", nrow(streams), " segments; waterbodies_co3: ", nrow(waterbodies))

r <- terra::rast(src)
r_crs <- sf::st_crs(terra::crs(r))
pipes <- sf::sf_proj_pipelines(r_crs, tcrs)
log("PROJ pipeline sf would use 3979 -> ", tcrs$epsg, ": ", pipes$description[1],
    " (accuracy ", pipes$accuracy[1], " m)")

# ---- DEMs ---------------------------------------------------------------------
aoi_buf <- sf::st_buffer(streams, buf)
aoi_buf_in_r <- sf::st_transform(aoi_buf, r_crs)

# OLD: fl_dem_aoi() before #67 -- crop, then let GDAL choose the grid
clip_old <- terra::crop(r, terra::vect(aoi_buf_in_r), snap = "out")
dem_old <- terra::project(clip_old, tcrs$wkt)

# NEW: fl_dem_aoi() on this branch (30 m), and the middle arm at the old cell size
dem_30 <- fl_dem_aoi(streams, buffer = buf, target_crs = tcrs)
res_old <- terra::res(dem_old)[1]
dem_mid <- fl_dem_aoi(streams, buffer = buf, target_crs = tcrs, res = res_old)

bs <- sf::st_bbox(aoi_buf_in_r)
pad <- 2 * max(terra::res(r))
clip_new <- terra::crop(r, terra::ext(bs[["xmin"]] - pad, bs[["xmax"]] + pad,
                                      bs[["ymin"]] - pad, bs[["ymax"]] + pad), snap = "out")
log(sprintf("source cells read: old crop %d, new crop %d (x%.4f)",
            terra::ncell(clip_old), terra::ncell(clip_new),
            terra::ncell(clip_new) / terra::ncell(clip_old)))

grid_line <- function(lab, d) {
  e <- as.vector(terra::ext(d))
  na <- terra::global(is.na(d), "sum")[[1]]
  log(sprintf("%-6s res %.9f  xmin %.6f  ymin %.6f  ncell %d  NA %d (%.1f%%)",
              lab, terra::res(d)[1], e[["xmin"]], e[["ymin"]], terra::ncell(d), na,
              100 * na / terra::ncell(d)))
}
grid_line("old", dem_old)
grid_line("mid", dem_mid)
grid_line("new30", dem_30)

# ---- (a) Values on one identical grid, three warp paths ------------------------
clip_tif <- file.path(out_dir, "clip_new.tif")
terra::writeRaster(clip_new, clip_tif, overwrite = TRUE, datatype = "FLT4S")
clip_disk <- terra::rast(clip_tif)
tmpl <- terra::rast(dem_30)

v_terra <- terra::values(terra::project(clip_disk, tmpl, method = "bilinear"), mat = FALSE)
v_util <- terra::values(
  terra::project(clip_disk, tmpl, method = "bilinear", by_util = TRUE), mat = FALSE
)
e <- as.vector(terra::ext(tmpl))
warp_tif <- file.path(out_dir, "warp_sf.tif")
unlink(warp_tif)
sf::gdal_utils(
  "warp", clip_tif, warp_tif,
  options = c("-t_srs", paste0("EPSG:", tcrs$epsg),
              "-te", e[["xmin"]], e[["ymin"]], e[["xmax"]], e[["ymax"]],
              "-tr", terra::res(tmpl)[1], terra::res(tmpl)[2],
              "-r", "bilinear", "-ot", "Float64", "-wt", "Float64", "-overwrite")
)
v_sf <- terra::values(terra::rast(warp_tif), mat = FALSE)
log("sf warp extent equals template: ", isTRUE(all(as.vector(terra::ext(terra::rast(warp_tif))) == e)))
v_fl <- terra::values(dem_30, mat = FALSE)

f32 <- function(x) {
  ok <- !is.na(x)
  x[ok] <- readBin(writeBin(x[ok], raw(), size = 4), "double", size = 4, n = sum(ok))
  x
}
compare <- function(lab, a, b) {
  na_diff <- sum(is.na(a) != is.na(b))
  both <- !is.na(a) & !is.na(b)
  d <- abs(a[both] - b[both])
  n32 <- sum(f32(a[both]) != f32(b[both]))
  log(sprintf("(a) %-28s cells %d  NA-mismatch %d  differ exactly %d  differ as Float32 %d  max |diff| %.6g m",
              lab, sum(both), na_diff, sum(d > 0), n32, if (length(d)) max(d) else NA))
}
compare("fl_dem_aoi vs terra default", v_fl, v_terra)
compare("terra default vs by_util", v_terra, v_util)
compare("terra by_util vs sf gdalwarp", v_util, v_sf)
compare("terra default vs sf gdalwarp", v_terra, v_sf)

# ---- (b) Delineation on each grid ----------------------------------------------
vca <- function(dem) {
  precip <- fl_stream_rasterize(streams, dem, field = "map_upstream")
  fl_valley_confine(
    dem, streams,
    area_field = "upstream_area_ha",
    slope = NULL,
    slope_threshold = sc$slope_threshold,
    max_width = sc$max_width,
    cost_threshold = sc$cost_threshold,
    flood_factor = sc$flood_factor,
    precip = precip,
    waterbodies = waterbodies,
    size_threshold = sc$size_threshold,
    hole_threshold = sc$hole_threshold
  )
}
polys <- list()
ha <- c()
for (lab in c("old", "mid", "new30")) {
  dem <- switch(lab, old = dem_old, mid = dem_mid, new30 = dem_30)
  t0 <- proc.time()
  v <- vca(dem)
  tt <- proc.time() - t0
  n <- terra::global(v == 1, "sum", na.rm = TRUE)[[1]]
  ha[lab] <- n * prod(terra::res(v)) / 1e4
  terra::writeRaster(v, file.path(out_dir, paste0("valleys_", lab, ".tif")),
                     overwrite = TRUE, datatype = "INT1U")
  polys[[lab]] <- terra::as.polygons(terra::classify(v, cbind(0, NA)), dissolve = TRUE)
  log(sprintf("(b) %-6s valley cells %d  %.1f ha  (cpu %.0f s, elapsed %.0f s, load %s)",
              lab, n, ha[lab], tt[["user.self"]] + tt[["sys.self"]], tt[["elapsed"]],
              paste(system("sysctl -n vm.loadavg", intern = TRUE), collapse = "")))
}
for (pair in list(c("old", "mid"), c("mid", "new30"), c("old", "new30"))) {
  a <- polys[[pair[1]]]
  b <- polys[[pair[2]]]
  both_ha <- sum(terra::expanse(terra::intersect(a, b), unit = "ha", transform = FALSE))
  log(sprintf("(b) %s -> %s: %.1f -> %.1f ha (%+.2f%%); shared %.1f ha, %s-only %.1f ha, %s-only %.1f ha",
              pair[1], pair[2], ha[pair[1]], ha[pair[2]],
              100 * (ha[pair[2]] / ha[pair[1]] - 1), both_ha,
              pair[1], ha[pair[1]] - both_ha, pair[2], ha[pair[2]] - both_ha))
}
log("done")
