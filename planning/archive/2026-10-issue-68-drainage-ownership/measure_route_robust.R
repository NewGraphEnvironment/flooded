# Phase 3 (#68 round 2): the replacement conditioning (least cost without its racy fill
# branch, then BreachDepressions) on the bundled tile, 30 sequential calls: panics,
# determinism, downhill invariant, pits left, and valley-cell reach (3x3) as in Phase 1.
# Run: Rscript planning/active/measure_route_robust.R > planning/active/measure_route_robust.log 2>&1
pkgload::load_all(quiet = TRUE)
dem <- terra::rast(system.file("testdata/dem.tif", package = "flooded"))
fails <- 0; ref <- NULL; differ <- 0; t <- numeric(0)
for (i in 1:30) {
  t0 <- Sys.time()
  r <- tryCatch(fl_flow_route(dem), error = function(e) { fails <<- fails + 1; NULL })
  t <- c(t, as.numeric(Sys.time() - t0, units = "secs"))
  if (is.null(r)) next
  if (is.null(ref)) ref <- r else if (!identical(r, ref)) differ <- differ + 1
}
cat(sprintf("30 calls: %d errors, %d differ from the first; median %.1f s\n", fails, differ, median(t)))
z <- ref$z; nxt <- ref[["next"]]
cat("downhill violations:", sum(z[nxt] > z, na.rm = TRUE), " fixed points (pits, edges, NA):", sum(nxt == seq_along(nxt)), "\n")
st <- sf::st_read(system.file("testdata/streams.gpkg", package = "flooded"), quiet = TRUE)
sr <- fl_stream_rasterize(st, dem, field = "upstream_area_ha")
pr <- fl_stream_rasterize(st, dem, field = "map_upstream")
vc <- terra::values(fl_valley_confine(dem, st, area_field = "upstream_area_ha", precip = pr), mat = FALSE)
near <- terra::values(terra::focal(!is.na(sr), 3, "max", na.rm = TRUE), mat = FALSE) == 1
h <- fl_path_max(nxt, ifelse(near, 1, NA))
cat(sprintf("pooled valley cells whose path meets a stream (3x3): %.1f%%  [least cost + fill: 79.1%%]\n",
            100 * mean(!is.na(h[vc == 1]))))
