# Phase 1 gate (#68 round 2): does a conditioned D8 path reach a stream?
#
# For each of today's valley cells (bundled tile, upstream_area_ha + precip, ff6), follow the
# D8 path and ask whether any cell on it lies within one cell (3x3) of a stream cell.
# Raw terra flowdir is the baseline (29% in plan-mode probe); whitebox breach and fill are the
# candidates. Gate: >= 90%.
#
# Run: Rscript planning/active/measure_drainage_reach.R > planning/active/measure_drainage_reach.log 2>&1

pkgload::load_all(quiet = TRUE)
dem <- terra::rast(system.file("testdata/dem.tif", package = "flooded"))
st <- sf::st_read(system.file("testdata/streams.gpkg", package = "flooded"), quiet = TRUE)
sr <- fl_stream_rasterize(st, dem, field = "upstream_area_ha")
pr <- fl_stream_rasterize(st, dem, field = "map_upstream")
vc <- terra::values(fl_valley_confine(dem, st, area_field = "upstream_area_ha",
                                      precip = pr), mat = FALSE)
near_st <- terra::values(terra::focal(!is.na(sr), 3, "max", na.rm = TRUE), mat = FALSE) == 1

nr <- terra::nrow(dem); nc <- terra::ncol(dem); cell <- seq_len(terra::ncell(dem))
rc <- terra::rowColFromCell(dem, cell)
# ESRI D8 codes -> row/col offsets
dr <- c(`1` = 0, `2` = 1, `4` = 1, `8` = 1, `16` = 0, `32` = -1, `64` = -1, `128` = -1)
dc <- c(`1` = 1, `2` = 1, `4` = 0, `8` = -1, `16` = -1, `32` = -1, `64` = 0, `128` = 1)

reach <- function(code) {
  key <- as.character(code)
  ok <- key %in% names(dr)
  r2 <- rc[, 1] + ifelse(ok, dr[key], NA)
  c2 <- rc[, 2] + ifelse(ok, dc[key], NA)
  nxt <- ifelse(!is.na(r2) & r2 >= 1 & r2 <= nr & c2 >= 1 & c2 <= nc, (r2 - 1) * nc + c2, NA)
  nxt[is.na(nxt)] <- cell[is.na(nxt)]
  h <- near_st
  i <- 0
  repeat {
    i <- i + 1
    h2 <- h | h[nxt]; n2 <- nxt[nxt]
    if (identical(n2, nxt) && identical(h2, h)) break
    h <- h2; nxt <- n2
    if (i > 40) break
  }
  terminal_self <- nxt[nxt] == nxt
  c(pits = sum(!ok), iters = i, cyclic = mean(!terminal_self),
    all = mean(h), valley = mean(h[vc == 1], na.rm = TRUE))
}

wd <- tempfile("wbt"); dir.create(wd)
f_dem <- file.path(wd, "dem.tif"); terra::writeRaster(dem, f_dem)
pntr <- function(cond) {
  f_p <- file.path(wd, "pntr.tif")
  whitebox::wbt_d8_pointer(cond, f_p, esri_pntr = TRUE, verbose_mode = FALSE)
  terra::values(terra::rast(f_p), mat = FALSE)
}

cat("valley cells:", sum(vc == 1, na.rm = TRUE), "\n\n")
cat("raw terra flowdir:\n"); print(round(reach(terra::values(terra::terrain(dem, "flowdir"), mat = FALSE)), 3))
cat("raw whitebox d8 (no conditioning):\n"); print(round(reach(pntr(f_dem)), 3))

for (d in c(10, 50, 200)) {
  t0 <- Sys.time()
  f_b <- file.path(wd, sprintf("breach_%d.tif", d))
  whitebox::wbt_breach_depressions_least_cost(f_dem, f_b, dist = d, fill = TRUE, verbose_mode = FALSE)
  r <- reach(pntr(f_b))
  cat(sprintf("breach least-cost dist=%d (+fill): %.1f s\n", d, as.numeric(Sys.time() - t0, units = "secs")))
  print(round(r, 3))
}
t0 <- Sys.time()
f_f <- file.path(wd, "fill.tif")
whitebox::wbt_fill_depressions(f_dem, f_f, fix_flats = TRUE, verbose_mode = FALSE)
r <- reach(pntr(f_f))
cat(sprintf("fill depressions (fix_flats): %.1f s\n", as.numeric(Sys.time() - t0, units = "secs")))
print(round(r, 3))
