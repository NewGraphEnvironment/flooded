# Phase 4 (#68 round 2): MORR, the floodplains#110 probe DEM (~30 m, watershed-clipped).
#   - arm 5 (coho network) pooled vs drainage at ff2/4/6: bounded change, ff gaps
#   - arm 1 (all FWA) vs arm 5 under drainage at ff4: flood-mask and valley loss
#     (pooled: 451.9 ha valley loss, 1,256.5 ha flood-mask loss)
#   - path reach on the corridor, and timing
# Read-only on floodplains data; the network comes from the local fwapg (PG* in ~/.Renviron).
# Run: Rscript planning/active/measure_morr.R > planning/active/measure_morr.log 2>&1
suppressMessages({library(sf); library(terra); library(DBI); library(RPostgres)})
pkgload::load_all(".", quiet = TRUE)
terra::terraOptions(threads = 12, progress = 0)
PROBE <- path.expand("~/Projects/repo/floodplains/data/morr/probe_whole_fwa")
source(path.expand("~/Projects/repo/floodplains/scripts/floodplain_lcc/fp_whole_fwa.R"))
dem <- rast(file.path(PROBE, "dem_common.tif"))
conn <- dbConnect(Postgres()); all <- fp_wf_read_network(conn, "fresh", "MORR", "co"); dbDisconnect(conn)
s1 <- all[fp_wf_keep(all, 1L, 3L), ]; s5 <- all[fp_wf_keep(all, 5L, 3L), ]
cell_ha <- prod(res(dem)) / 1e4
cat(sprintf("dem %d x %d (%.2f m); arm1 %d, arm5 %d segments\n", nrow(dem), ncol(dem), res(dem)[1], nrow(s1), nrow(s5)))

# One route for every run on this DEM (the DEM alone decides it).
t0 <- Sys.time(); route <- fl_flow_route(dem)
cat(sprintf("flow route (WhiteboxTools, 1 thread): %.0f s\n", as.numeric(Sys.time() - t0, units = "secs")))
ns <- asNamespace("flooded"); unlockBinding("fl_flow_route", ns)
assign("fl_flow_route", function(dem, breach_dist = 50L) route, ns)

ha <- function(v) sum(!is.na(v) & v == 1) * cell_ha
run <- function(s, ff, m) {
  p <- fl_stream_rasterize(s, dem, field = "map_upstream")
  t0 <- Sys.time()
  v <- values(fl_valley_confine(dem, s, area_field = "upstream_area_ha", precip = p,
                                flood_factor = ff, flood_method = m), mat = FALSE)
  attr(v, "secs") <- as.numeric(Sys.time() - t0, units = "secs")
  v
}
flood_mask <- function(s, m) {
  r <- fl_stream_rasterize(s, dem, field = "upstream_area_ha")
  p <- fl_stream_rasterize(s, dem, field = "map_upstream")
  f <- fl_flood_model(dem, r, flood_factor = 4, precip = p, method = m)[["flooded"]]
  f <- ifel(!is.na(r), 1L, f); values(ifel(is.na(f), 0L, f), mat = FALSE)
}

cat("\n== arm 5, pooled vs drainage\n")
v5 <- list()
for (ff in c(2, 4, 6)) for (m in c("pooled", "drainage")) {
  v <- run(s5, ff, m); v5[[paste(m, ff)]] <- v
  cat(sprintf("%-8s ff%d  %9.0f ha  (%.0f s)\n", m, ff, ha(v), attr(v, "secs")))
}
for (ff in c(2, 4, 6)) {
  p <- v5[[paste("pooled", ff)]]; d <- v5[[paste("drainage", ff)]]
  cat(sprintf("ff%d: drainage %+.1f%% | lost %.0f ha, gained %.0f ha\n", ff, 100 * (ha(d) / ha(p) - 1),
              sum(p %in% 1 & !d %in% 1) * cell_ha, sum(d %in% 1 & !p %in% 1) * cell_ha))
}
for (m in c("pooled", "drainage")) {
  h <- sapply(c(2, 4, 6), function(ff) ha(v5[[paste(m, ff)]]))
  cat(sprintf("%-8s gaps: ff4/ff2 %+.1f%%, ff6/ff4 %+.1f%%\n", m, 100 * (h[2] / h[1] - 1), 100 * (h[3] / h[2] - 1)))
}

cat("\n== arm 1 vs arm 5 at ff4, drainage\n")
v1 <- run(s1, 4, "drainage")
lost <- v5[["drainage 4"]] %in% 1 & !v1 %in% 1
cat(sprintf("arm1 %.0f ha, arm5 %.0f ha; valley lost adding streams: %d cells (%.1f ha)  [pooled: 451.9 ha]\n",
            ha(v1), ha(v5[["drainage 4"]]), sum(lost), sum(lost) * cell_ha))
fm5 <- flood_mask(s5, "drainage"); fm1 <- flood_mask(s1, "drainage")
cat(sprintf("flood-mask cells wet with arm5, dry with arm1: %d  [pooled: 13,569]\n", sum(fm5 == 1 & fm1 == 0)))

cat("\n== reach\n")
sr5 <- fl_stream_rasterize(s5, dem, field = "upstream_area_ha")
surf <- fl_flood_surface(dem, sr5, flood_factor = 4)
own <- fl_path_max(route[["next"]], fl_drainage_level(surf, dem, route))
dist <- values(distance(ifel(!is.na(sr5), 1, NA)), mat = FALSE)
corr <- dist <= 1000 & !is.na(values(dem, mat = FALSE))
cat(sprintf("arm5 corridor cells owned: %.1f%%; arm5 pooled-valley cells owned: %.1f%%\n",
            100 * mean(!is.na(own[corr])), 100 * mean(!is.na(own[v5[["pooled 4"]] %in% 1]))))
