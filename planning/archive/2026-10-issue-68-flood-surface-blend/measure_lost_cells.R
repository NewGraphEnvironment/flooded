# flooded#68 Phase 1: do the floodplain cells lost between the coho network (arm 5) and all FWA
# streams (arm 1) sit next to the added streams, and which criterion drops them?
#
# Reads floodplains#110's probe outputs on m1 (read-only; writes only to OUT) and the local fwapg.
# usage: Rscript planning/active/measure_lost_cells.R <out_dir>
suppressMessages({library(sf); library(terra); library(DBI); library(RPostgres)})
pkgload::load_all(".", quiet = TRUE)   # source tree, not the installed flooded
terra::terraOptions(threads = 12, progress = 0)

OUT   <- commandArgs(trailingOnly = TRUE)[1]
PROBE <- path.expand("~/Projects/repo/floodplains/data/morr/probe_whole_fwa")
LCC   <- path.expand("~/Projects/repo/floodplains/scripts/floodplain_lcc")
stopifnot(!is.na(OUT), dir.exists(OUT), !startsWith(normalizePath(OUT), normalizePath(PROBE)))
source(file.path(LCC, "fp_whole_fwa.R"))

# co_ff04 (config/morr/flood_scenarios.csv)
sc <- list(flood_factor = 4, slope_threshold = 9, max_width = 2000, cost_threshold = 2500)

dem <- rast(file.path(PROBE, "dem_common.tif"))
fp1 <- rast(file.path(PROBE, "arm1_floodplain.tif"))
fp5 <- rast(file.path(PROBE, "arm5_floodplain.tif"))
stopifnot(compareGeom(dem, fp1, stopOnError = FALSE), compareGeom(dem, fp5, stopOnError = FALSE))
is1 <- function(r) !is.na(r) & r == 1

conn <- dbConnect(Postgres())
all <- fp_wf_read_network(conn, "fresh", "MORR", "co")
dbDisconnect(conn)
k1 <- fp_wf_keep(all, 1L, 3L); k5 <- fp_wf_keep(all, 5L, 3L)
stopifnot(all(k1[k5]))
s1 <- all[k1, ]; s5 <- all[k5, ]; added <- all[k1 & !k5, ]
cat(sprintf("segments: arm1 %d, arm5 %d, added %d\n", nrow(s1), nrow(s5), nrow(added)))

cell_ha <- prod(res(dem)) / 1e4
lost   <- is1(fp5) & !is1(fp1)
n_lost <- global(lost, "sum")[[1]]; n_fp5 <- global(is1(fp5), "sum")[[1]]
cat(sprintf("arm5 floodplain %d cells (%.0f ha); lost in arm1 %d cells (%.1f ha, %.2f%%)\n",
            n_fp5, n_fp5 * cell_ha, n_lost, n_lost * cell_ha, 100 * n_lost / n_fp5))

# --- distance to the nearest added stream ------------------------------------------------------
add_r <- rasterize(vect(added), dem, field = 1, touches = TRUE)
d_add <- distance(add_r)
dl <- values(d_add)[which(values(lost) == 1)]
df <- values(d_add)[which(values(is1(fp5)) == 1)]
q <- c(0.1, 0.25, 0.5, 0.75, 0.9)
cat("distance to nearest added stream (m), quantiles", paste(q, collapse = "/"), "\n")
cat("  lost cells:      ", round(quantile(dl, q)), "\n")
cat("  all arm5 fp:     ", round(quantile(df, q)), "\n")
for (t in c(60, 120, 250, 500, 1000)) {
  cat(sprintf("  share within %4d m: lost %.1f%%  all arm5 fp %.1f%%\n", t,
              100 * mean(dl <= t), 100 * mean(df <= t)))
}

# --- which criterion drops them -----------------------------------------------------------------
# Slope is the same for both arms; distance and cost only loosen as seeds are added. So a lost cell
# was dropped either by the flood mask or by cleanup. Recompute the flood mask for both arms.
slope <- tan(terrain(dem, "slope", unit = "degrees") * pi / 180) * 100
flood_mask <- function(s, tag) {
  r <- fl_stream_rasterize(s, dem, field = "upstream_area_ha")
  p <- fl_stream_rasterize(s, dem, field = "map_upstream")
  t0 <- Sys.time()
  f <- fl_flood_model(dem, r, flood_factor = sc$flood_factor, precip = p, max_width = sc$max_width)
  m <- ifel(!is.na(r), 1L, f[["flooded"]]); m <- ifel(is.na(m), 0L, m)
  cat(sprintf("  flood model %s: %.1f s\n", tag, as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  writeRaster(c(m, f[["flood_surface"]], f[["flood_depth"]]),
              file.path(OUT, sprintf("flood_%s.tif", tag)), overwrite = TRUE)
  list(mask = m, depth = f[["flood_depth"]], stream = r)
}
f1 <- flood_mask(s1, "arm1"); f5 <- flood_mask(s5, "arm5")
m_slope <- fl_mask(slope, threshold = sc$slope_threshold, operator = "<=")
m_cost1 <- fl_mask(fl_cost_distance(slope, f1$stream), threshold = sc$cost_threshold, operator = "<")
pre1 <- m_slope * fl_mask_distance(f1$stream, sc$max_width / 2) * m_cost1 * f1$mask

lv <- which(values(lost) == 1)
fl1 <- values(f1$mask)[lv]; fl5 <- values(f5$mask)[lv]; p1 <- values(pre1)[lv]
cat(sprintf("lost cells flooded in arm5 mask: %.1f%%; flooded in arm1 mask: %.1f%%\n",
            100 * mean(fl5 == 1, na.rm = TRUE), 100 * mean(fl1 == 1, na.rm = TRUE)))
cat(sprintf("lost cells: arm1 flood mask dropped them %.1f%% | arm1 pre-cleanup mask kept them %.1f%%\n",
            100 * mean(fl1 == 0 & fl5 == 1, na.rm = TRUE), 100 * mean(p1 == 1, na.rm = TRUE)))

# Whole-grid flood-mask monotonicity: cells flooded with the coho seeds and not with all seeds
fm_lost <- (f5$mask == 1) & (f1$mask == 0)
n_fm <- global(fm_lost, "sum", na.rm = TRUE)[[1]]
cat(sprintf("flood mask cells wet with arm5 seeds, dry with arm1 seeds: %d (%.1f ha)\n", n_fm, n_fm * cell_ha))
dm <- values(d_add)[which(values(fm_lost) == 1)]
cat("  their distance to nearest added stream (m):", round(quantile(dm, q)), "\n")

# Depth drop on lost cells: how far the arm1 waterline sits below the arm5 one
d5 <- values(f5$depth)[lv]; d1 <- values(f1$depth)[lv]
cat("arm5 flood depth on lost cells (m):", round(quantile(d5, q, na.rm = TRUE), 2), "\n")
writeRaster(lost * 1L, file.path(OUT, "lost_arm5_not_arm1.tif"), overwrite = TRUE)
