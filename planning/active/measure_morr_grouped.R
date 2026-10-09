# flooded#68 Phases 4-5: MORR arm 1 and arm 5 delineated pooled (group_field = NULL) and per
# watercourse (blue_line_key), same code, same grid, same co_ff04 parameters as floodplains#110.
# Times the grouped run and measures (a) floodplain lost when seeds are added, (b) ground the
# grouped surface adds over the pooled one and where it sits.
#
# Read-only on floodplains data; writes only to OUT. usage: Rscript <this> <out_dir>
suppressMessages({library(sf); library(terra); library(DBI); library(RPostgres)})
pkgload::load_all(".", quiet = TRUE)
terra::terraOptions(threads = 12, progress = 0)

OUT   <- commandArgs(trailingOnly = TRUE)[1]
PROBE <- path.expand("~/Projects/repo/floodplains/data/morr/probe_whole_fwa")
LCC   <- path.expand("~/Projects/repo/floodplains/scripts/floodplain_lcc")
stopifnot(!is.na(OUT), dir.exists(OUT), !startsWith(normalizePath(OUT), normalizePath(PROBE)))
source(file.path(LCC, "fp_whole_fwa.R"))
sc <- list(flood_factor = 4, slope_threshold = 9, max_width = 2000, cost_threshold = 2500,
           size_threshold = 5000, hole_threshold = 2500)

dem <- rast(file.path(PROBE, "dem_common.tif"))
cell_ha <- prod(res(dem)) / 1e4
conn <- dbConnect(Postgres())
all <- fp_wf_read_network(conn, "fresh", "MORR", "co")
arms <- list(arm1 = all[fp_wf_keep(all, 1L, 3L), ], arm5 = all[fp_wf_keep(all, 5L, 3L), ])
wbs <- lapply(arms, function(s) fp_wf_read_waterbodies(conn, s))
dbDisconnect(conn)

run <- function(arm, group_field) {
  s <- arms[[arm]]
  p <- fl_stream_rasterize(s, dem, field = "map_upstream")
  t0 <- Sys.time()
  v <- fl_valley_confine(dem, s, area_field = "upstream_area_ha", slope = NULL,
                         slope_threshold = sc$slope_threshold, max_width = sc$max_width,
                         cost_threshold = sc$cost_threshold, flood_factor = sc$flood_factor,
                         precip = p, waterbodies = wbs[[arm]],
                         size_threshold = sc$size_threshold, hole_threshold = sc$hole_threshold,
                         group_field = group_field)
  secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  tag <- paste0(arm, if (is.null(group_field)) "_pooled" else "_grouped")
  cat(sprintf("%-14s %6.1f s  %d valley cells (%.0f ha)  [%d segments, %d blue lines]\n", tag, secs,
              global(v == 1, "sum", na.rm = TRUE)[[1]],
              global(v == 1, "sum", na.rm = TRUE)[[1]] * cell_ha, nrow(s),
              length(unique(s$blue_line_key))))
  writeRaster(v, file.path(OUT, paste0(tag, ".tif")), overwrite = TRUE)
  v
}
is1 <- function(r) !is.na(r) & r == 1
n <- function(r) global(r, "sum", na.rm = TRUE)[[1]]

v <- list(arm1_pooled = run("arm1", NULL), arm5_pooled = run("arm5", NULL),
          arm1_grouped = run("arm1", "blue_line_key"), arm5_grouped = run("arm5", "blue_line_key"))

# Sanity: the pooled run on this code reproduces the probe's published rasters
for (k in c(1, 5)) {
  old <- rast(file.path(PROBE, sprintf("arm%d_floodplain.tif", k)))
  d <- n(xor(is1(old), is1(v[[sprintf("arm%d_pooled", k)]])))
  cat(sprintf("arm%d pooled vs probe raster: %d cells differ\n", k, d))
}

for (m in c("pooled", "grouped")) {
  a1 <- is1(v[[paste0("arm1_", m)]]); a5 <- is1(v[[paste0("arm5_", m)]])
  lost <- a5 & !a1
  cat(sprintf("%-7s arm5 %d cells; arm5 not in arm1: %d cells (%.1f ha, %.2f%%)\n", m, n(a5), n(lost),
              n(lost) * cell_ha, 100 * n(lost) / n(a5)))
  writeRaster(lost * 1L, file.path(OUT, paste0("lost_", m, ".tif")), overwrite = TRUE)
}

# Ground the grouped surface adds (and any it removes) relative to the pooled one, per arm
for (arm in c("arm1", "arm5")) {
  p <- is1(v[[paste0(arm, "_pooled")]]); g <- is1(v[[paste0(arm, "_grouped")]])
  gain <- g & !p; loss <- p & !g
  cat(sprintf("%s grouped vs pooled: +%d cells (%.1f ha, +%.2f%%), -%d cells (%.1f ha)\n", arm,
              n(gain), n(gain) * cell_ha, 100 * n(gain) / n(p), n(loss), n(loss) * cell_ha))
  # Where the gain sits: distance to the arm's own nearest stream
  sr <- rasterize(vect(arms[[arm]]), dem, field = 1, touches = TRUE)
  dg <- values(distance(sr))[which(values(gain) == 1)]
  cat("  gain distance to nearest stream (m), q10/25/50/75/90:",
      round(quantile(dg, c(0.1, 0.25, 0.5, 0.75, 0.9))), "\n")
  writeRaster(gain * 1L, file.path(OUT, paste0("gain_", arm, ".tif")), overwrite = TRUE)
}
