# bench_fallback.R — time fl_valley_attribute()'s coverage fallback on MORR arm 5 (#71)
#
# Inputs are floodplains' cached probe outputs for MORR (floodplains#110): the coho network
# (`aquatic_network.gpkg`, layer `streams_co3`, 4,877 segments, 340 blue lines), arm 5's floodplain
# at co_ff04 and the common DEM. The probe recorded fallback_cells = 14170 and 339 rows for this
# attribution (`probe_whole_fwa/arm5_timing.json`), which this script asserts it reproduces.
#
# Modes:
#   e2e     time fl_valley_attribute(group = "blue_line_key", complete = TRUE) from <tree>
#           and write per-group cell counts, so two trees can be compared.
#   helper  on <tree> (which must define fl_nearest_group()), time the old full-grid
#           terra::distance() pass and the new helper on the same uncovered cells, and check
#           that every cell they assign differently is a tie.
#
# usage: Rscript bench_fallback.R <floodplains/data/morr> <flooded source tree> <e2e|helper> <out prefix>

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 4L || !args[3] %in% c("e2e", "helper")) {
  stop("usage: bench_fallback.R <data/morr dir> <source tree> <e2e|helper> <out prefix>", call. = FALSE)
}
dir_morr <- args[1]; tree <- args[2]; mode <- args[3]; out <- args[4]

suppressMessages(pkgload::load_all(tree, quiet = TRUE))
terra::terraOptions(threads = 12, progress = 0)   # the probe's setting
secs <- function(t0) round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1)

dem <- terra::rast(file.path(dir_morr, "probe_whole_fwa", "dem_common.tif"))
valleys <- terra::rast(file.path(dir_morr, "probe_whole_fwa", "arm5_floodplain.tif"))
streams <- sf::st_read(file.path(dir_morr, "aquatic_network.gpkg"), layer = "streams_co3", quiet = TRUE)
vv <- terra::values(valleys, mat = FALSE)
stopifnot(nrow(streams) == 4877L, length(unique(streams$blue_line_key)) == 340L,
          sum(vv == 1, na.rm = TRUE) == 385021L)

# Warnings are recorded, not printed: the probe saw exactly one (group 360652838 has no valley cells).
warns <- character(0)
quiet_attr <- function(...) {
  withCallingHandlers(fl_valley_attribute(...),
                      warning = function(w) {
                        warns <<- c(warns, conditionMessage(w))
                        invokeRestart("muffleWarning")
                      })
}

meta <- list(
  mode = mode,
  tree_sha = system2("git", c("-C", tree, "rev-parse", "--short", "HEAD"), stdout = TRUE),
  flooded = as.character(desc::desc_get_version(tree)),
  terra = as.character(packageVersion("terra")), sf = as.character(packageVersion("sf")),
  terra_gdal = terra::gdal(), geos = unname(sf::sf_extSoftVersion()[["GEOS"]]), threads = 12L,
  host = Sys.info()[["nodename"]], started_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)
)

if (mode == "e2e") {
  t0 <- Sys.time()
  x <- quiet_attr(valleys, streams, group = "blue_line_key", dem = dem,
                  max_width = 2000, cost_threshold = 2500)
  t_attr <- secs(t0)
  cell_area <- prod(terra::res(valleys))
  counts <- data.frame(blue_line_key = x$blue_line_key,
                       cells = round(as.numeric(sf::st_area(x)) / cell_area))
  utils::write.csv(counts, paste0(out, "_counts.csv"), row.names = FALSE)
  res <- c(meta, list(t_attr_s = t_attr, rows = nrow(x),
                      fallback_cells = attr(x, "fl_fallback_cells"),
                      warnings = length(warns), first_warning = warns[1]))
  jsonlite::write_json(res, paste0(out, ".json"), auto_unbox = TRUE, pretty = TRUE)
  print(res[c("tree_sha", "t_attr_s", "rows", "fallback_cells")])
  stopifnot(res$rows == 339L, res$fallback_cells == 14170L, length(warns) == 1L,
            grepl("360652838", warns[1]))
}

if (mode == "helper") {
  # Uncovered cells: valley cells that no group reaches within the thresholds. Polygons are
  # built from cells, so rasterizing them by centre recovers exactly the covered set.
  t0 <- Sys.time()
  strict <- quiet_attr(valleys, streams, group = "blue_line_key", dem = dem,
                       max_width = 2000, cost_threshold = 2500, complete = FALSE)
  t_strict <- secs(t0)
  cov <- terra::rasterize(terra::vect(strict), valleys, field = 1L, background = 0L)
  uncovered <- which(vv == 1 & terra::values(cov, mat = FALSE) == 0)
  stopifnot(length(uncovered) == 14170L)

  # idx_r exactly as fl_valley_attribute() builds it.
  keys <- streams$blue_line_key
  levels_grp <- sort(unique(keys))
  idx_streams <- streams
  idx_streams$fl_group_idx <- match(keys, levels_grp)
  t0 <- Sys.time()
  idx_r <- fl_stream_rasterize(idx_streams, valleys, field = "fl_group_idx")
  t_rasterize <- secs(t0)

  t0 <- Sys.time()
  nearest <- terra::distance(idx_r, target = NA, values = TRUE)
  a_old <- terra::values(nearest, mat = FALSE)[uncovered]
  t_old <- secs(t0)

  t0 <- Sys.time()
  a_new <- fl_nearest_group(idx_r, uncovered)
  t_new <- secs(t0)

  # A differing cell is a tie when its distance to the nearest burned cell of each of the two
  # groups is the same.
  iv <- terra::values(idx_r, mat = FALSE)
  burned <- which(!is.na(iv))
  bxy <- terra::xyFromCell(idx_r, burned)
  d_to <- function(cell, g) {
    p <- terra::xyFromCell(idx_r, cell)
    b <- bxy[iv[burned] == g, , drop = FALSE]
    min(sqrt((b[, 1] - p[1])^2 + (b[, 2] - p[2])^2))
  }
  diff <- which(a_old != a_new | is.na(a_old) != is.na(a_new))
  gap <- vapply(diff, function(k) abs(d_to(uncovered[k], a_old[k]) - d_to(uncovered[k], a_new[k])),
                numeric(1))

  res <- c(meta, list(t_strict_s = t_strict, uncovered = length(uncovered),
                      burned_cells = length(burned), t_rasterize_s = t_rasterize,
                      t_old_distance_s = t_old, t_new_nearest_s = t_new,
                      cells_differing = length(diff),
                      max_distance_gap_m = if (length(gap)) max(gap) else 0))
  jsonlite::write_json(res, paste0(out, ".json"), auto_unbox = TRUE, pretty = TRUE, digits = NA)
  print(res[-(1:8)])
}
