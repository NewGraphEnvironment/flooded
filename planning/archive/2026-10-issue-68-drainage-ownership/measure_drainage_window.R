# Phase 1 gate follow-up (#68 round 2): why do conditioned D8 paths miss the streams?
# Breach (dist = 50, + fill) then ESRI D8. For valley cells whose path never comes within the
# window of a stream: where does the path end (grid edge vs interior pit), and how far is the
# closest approach to a stream? Then: share reached as a function of window radius.
#
# Run: Rscript planning/active/measure_drainage_window.R > planning/active/measure_drainage_window.log 2>&1
pkgload::load_all(quiet = TRUE)
dem <- terra::rast(system.file("testdata/dem.tif", package = "flooded"))
st <- sf::st_read(system.file("testdata/streams.gpkg", package = "flooded"), quiet = TRUE)
sr <- fl_stream_rasterize(st, dem, field = "upstream_area_ha")
pr <- fl_stream_rasterize(st, dem, field = "map_upstream")
vc <- terra::values(fl_valley_confine(dem, st, area_field = "upstream_area_ha", precip = pr), mat = FALSE)
dist <- terra::values(terra::distance(terra::ifel(!is.na(sr), 1, NA)), mat = FALSE)

nr <- terra::nrow(dem); nc <- terra::ncol(dem); cell <- seq_len(terra::ncell(dem))
rc <- terra::rowColFromCell(dem, cell)
dr <- c(`1` = 0, `2` = 1, `4` = 1, `8` = 1, `16` = 0, `32` = -1, `64` = -1, `128` = -1)
dc <- c(`1` = 1, `2` = 1, `4` = 0, `8` = -1, `16` = -1, `32` = -1, `64` = 0, `128` = 1)
wd <- tempfile("wbt"); dir.create(wd)
f_dem <- file.path(wd, "dem.tif"); terra::writeRaster(dem, f_dem)
f_b <- file.path(wd, "breach.tif"); f_p <- file.path(wd, "pntr.tif")
whitebox::wbt_breach_depressions_least_cost(f_dem, f_b, dist = 50, fill = TRUE, verbose_mode = FALSE)
whitebox::wbt_d8_pointer(f_b, f_p, esri_pntr = TRUE, verbose_mode = FALSE)
code <- terra::values(terra::rast(f_p), mat = FALSE)
key <- as.character(code); ok <- key %in% names(dr)
r2 <- rc[, 1] + ifelse(ok, dr[key], NA); c2 <- rc[, 2] + ifelse(ok, dc[key], NA)
nxt0 <- ifelse(!is.na(r2) & r2 >= 1 & r2 <= nr & c2 >= 1 & c2 <= nc, (r2 - 1) * nc + c2, NA)
nxt0[is.na(nxt0)] <- cell[is.na(nxt0)]

# path minimum of distance-to-stream, by pointer jumping
m <- dist; nxt <- nxt0
for (i in 1:40) { m2 <- pmin(m, m[nxt]); n2 <- nxt[nxt]; if (identical(n2, nxt) && identical(m2, m)) break; m <- m2; nxt <- n2 }
term <- nxt
edge <- rc[term, 1] %in% c(1, nr) | rc[term, 2] %in% c(1, nc)
v <- which(vc == 1)
cat("valley cells", length(v), "\n")
cat("closest approach of valley paths to a stream (m), quantiles:\n")
print(round(quantile(m[v], c(.5, .7, .8, .9, .95, .99, 1)), 1))
for (rad in c(10, 15, 30, 50, 100, 200)) cat(sprintf("reached within %4d m: %.3f\n", rad, mean(m[v] <= rad + 1e-6)))
miss <- v[m[v] > 15]
cat("\nmissed (> 15 m) valley cells:", length(miss), "; path ends at grid edge:", round(mean(edge[miss]), 3),
    "; own distance to stream median", round(median(dist[miss])), "m\n")
cat("cell size", terra::res(dem), "\n")
