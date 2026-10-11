# bench_attribution.R — time and profile fl_valley_attribute() at watershed scale (#72)
#
# Inputs are floodplains' cached probe outputs (floodplains#104 / #110): the common DEM, each arm's
# co_ff04 floodplain and its network. Arm 2 (order >= 2) networks come from extract_arm2.R.
#
# Datasets:
#   bundled   flooded's test tile, by gnis_name, delineated here (fl_valley_confine() is not
#             touched by #72), at the defaults and at a binding cost_threshold = 300
#   morr_co   MORR coho network (arm 5), 340 blue lines
#   morr_a2   MORR order >= 2 (arm 2), 1,711 blue lines
#   bulk_co   BULK coho network (arm 5), 428 blue lines
#   bulk_a2   BULK order >= 2 (arm 2), 2,550 blue lines
#
# Modes:
#   e2e      time fl_valley_attribute(complete = TRUE) from <tree>, then (untimed) write each
#            group's cells as a (group, cell) table, so two trees compare per group, per cell.
#   rprof    Rprof over one whole fl_valley_attribute(complete = TRUE) call: where the time goes,
#            by function, including the outer loop.
#   steps    a timed replica of fl_group_cells() and fl_cells_poly(), step by step, on the 50
#            largest groups by crop and a random 100 of the rest. The replica's cells are checked
#            against the real fl_group_cells() for every group it times.
#
# usage: Rscript bench_attribution.R <floodplains checkout> <flooded tree> <dataset> <mode> <out prefix> [workers]

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 5L || !args[4] %in% c("e2e", "rprof", "steps")) {
  stop("usage: bench_attribution.R <floodplains> <tree> <dataset> <e2e|rprof|steps> <out prefix> [workers]",
       call. = FALSE)
}
fp <- args[1]; tree <- args[2]; dataset <- args[3]; mode <- args[4]; out <- args[5]
workers <- if (length(args) >= 6L) as.integer(args[6]) else NA_integer_

suppressMessages(pkgload::load_all(tree, quiet = TRUE))
terra::terraOptions(threads = 12, progress = 0)   # the probe's setting
secs <- function(t0) round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 2)

# --- inputs ---------------------------------------------------------------------------------------
cost_threshold <- 2500
if (startsWith(dataset, "bundled")) {
  dem <- terra::rast(system.file("testdata/dem.tif", package = "flooded"))
  streams <- sf::st_read(system.file("testdata/streams.gpkg", package = "flooded"), quiet = TRUE)
  precip_r <- fl_stream_rasterize(streams, dem, field = "map_upstream")
  valleys <- fl_valley_confine(dem, streams, area_field = "upstream_area_ha", precip = precip_r)
  group <- "gnis_name"
  if (dataset == "bundled_300") cost_threshold <- 300 else stopifnot(dataset == "bundled")
} else {
  area <- substr(dataset, 1, 4); arm <- c(co = 5L, a2 = 2L)[[substr(dataset, 6, 7)]]
  d <- file.path(fp, "data", area, "probe_whole_fwa")
  dem <- terra::rast(file.path(d, "dem_common.tif"))
  valleys <- terra::rast(file.path(d, paste0("arm", arm, "_floodplain.tif")))
  streams <- if (arm == 5L) {
    sf::st_read(file.path(fp, "data", area, "aquatic_network.gpkg"), layer = "streams_co3", quiet = TRUE)
  } else {
    sf::st_read(file.path(d, "arm2_streams.gpkg"), layer = "streams", quiet = TRUE)
  }
  # The bench hard-codes the co_ff04 thresholds (max_width 2000, cost 2500, margin = max_width).
  sc <- utils::read.csv(file.path(fp, "config", area, "flood_scenarios.csv"))
  sc <- sc[sc$scenario_id == "co_ff04", ]
  stopifnot(nrow(sc) == 1L, sc$max_width == 2000, sc$cost_threshold == cost_threshold)
  rec <- jsonlite::read_json(file.path(d, paste0("arm", arm, "_timing.json")))
  stopifnot(nrow(streams) == rec$n_segments, length(unique(streams$blue_line_key)) == rec$n_blk,
            sum(terra::values(valleys, mat = FALSE) == 1, na.rm = TRUE) == rec$valley_cells)
  group <- "blue_line_key"
  # Production (floodplains 02) attributes the in-memory raster fl_valley_confine() returns; the
  # cached tif is LZW in one-row strips, so reading crops from it would time decompression instead.
  valleys <- terra::toMemory(valleys)
}

# Section checkpoints inside the one timed call, so its parts sum to its total. Tracers are placed at
# the top-level statements of fl_valley_attribute() that open each section, found by their text so
# the same bench runs on main and on the branch.
marks <- data.frame(label = character(0), t = numeric(0), cpu = numeric(0))
.ck <- function(label) {
  pt <- proc.time()
  marks[nrow(marks) + 1L, ] <<- list(label, as.numeric(Sys.time()), pt[["user.self"]] + pt[["sys.self"]])
}
sections <- c(slope = "^if \\(is.null\\(slope\\)\\)", crs = "^if \\(sf::st_crs\\(streams\\)",
              valley_cells = "^valley_cells <-", groups = "^cells_by_group <-",
              covered = "^covered <-", fallback = "^n_assigned <-", empty_check = "^empty_grp <-",
              polygonize = "^parts <- list\\(\\)", rbind = "^out <- fl_check_out\\((do.call|fl_rbind_pairwise)")
ns <- asNamespace("flooded")
stmts <- vapply(as.list(body(get("fl_valley_attribute", envir = ns)))[-1],
                function(e) paste(deparse(e, width.cutoff = 500L)[1], collapse = ""), character(1))
at <- vapply(sections, function(rx) {
  i <- grep(rx, stmts)
  if (length(i) != 1L) stop("section marker not found once: ", rx, call. = FALSE)
  i + 1L   # body(f)[[1]] is `{`
}, integer(1))
# One trace() call: a second would replace the first. Statements run in order, so the n-th
# checkpoint reached is section n.
ck_n <- 0L
.ck_next <- function() { ck_n <<- ck_n + 1L; .ck(names(at)[ck_n]) }
suppressMessages(trace("fl_valley_attribute", tracer = quote(.GlobalEnv$.ck_next()), at = unname(at),
                       where = ns, print = FALSE))
fva <- get("fl_valley_attribute", envir = ns)

warns <- character(0)
attribute <- function(...) {
  extra <- if (is.na(workers)) list() else list(workers = workers)
  withCallingHandlers(
    do.call(fva, c(list(valleys, streams, group = group, dem = dem,
                                        max_width = 2000, cost_threshold = cost_threshold), extra,
                                   list(...))),
    warning = function(w) { warns <<- c(warns, substr(conditionMessage(w), 1, 200))
                            invokeRestart("muffleWarning") },
    message = function(m) invokeRestart("muffleMessage"))
}

meta <- list(
  dataset = dataset, mode = mode, workers = workers,
  tree_sha = system2("git", c("-C", tree, "rev-parse", "--short", "HEAD"), stdout = TRUE),
  tree_dirty = length(system2("git", c("-C", tree, "status", "--porcelain", "--", "R"), stdout = TRUE)) > 0L,
  flooded = as.character(desc::desc_get_version(tree)),
  terra = as.character(packageVersion("terra")), sf = as.character(packageVersion("sf")),
  terra_gdal = terra::gdal(), geos = unname(sf::sf_extSoftVersion()[["GEOS"]]), threads = 12L,
  host = Sys.info()[["nodename"]], valleys_in_memory = terra::inMemory(valleys),
  # Other jobs share this machine and wall time moves with them; CPU time (cpu_s) and the load
  # average at start and end say whether a run was contended.
  load_start = system2("sysctl", c("-n", "vm.loadavg"), stdout = TRUE), ncell = terra::ncell(valleys),
  n_groups = length(unique(streams[[group]])), started_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)
)
load_end <- function() system2("sysctl", c("-n", "vm.loadavg"), stdout = TRUE)
write_json <- function(x, path) jsonlite::write_json(x, path, auto_unbox = TRUE, pretty = TRUE, digits = NA)

# --- e2e ------------------------------------------------------------------------------------------
if (mode == "e2e") {
  t0 <- Sys.time()
  pt0 <- proc.time()
  .ck("start")
  x <- attribute()
  .ck("end")
  t_attr <- secs(t0)
  pt <- proc.time() - pt0
  # Each section's time runs from its checkpoint to the next one reached.
  sec <- data.frame(section = head(marks$label, -1), wall_s = round(diff(marks$t), 2),
                    cpu_s = round(diff(marks$cpu), 2))
  utils::write.csv(sec, paste0(out, "_sections.csv"), row.names = FALSE)
  print(sec)
  # Polygons are unions of whole cells, so the cells whose centres they contain are exactly the
  # attributed cells.
  cc <- terra::cells(valleys, terra::vect(x))
  tab <- data.frame(group = x[[group]][cc[, "ID"]], cell = as.integer(cc[, "cell"]))
  tab <- tab[order(tab$group, tab$cell), ]
  saveRDS(tab, paste0(out, "_cells.rds"))
  res <- c(meta, list(t_attr_s = t_attr, cpu_s = pt[["user.self"]] + pt[["sys.self"]],
                      rows = nrow(x), fallback_cells = attr(x, "fl_fallback_cells"),
                      member_cells = nrow(tab), sections = sec$section, section_wall_s = sec$wall_s,
                      section_cpu_s = sec$cpu_s, warnings = length(warns), first_warning = warns[1]))
  res$load_end <- load_end()
  write_json(res, paste0(out, ".json"))
  print(unlist(res[c("dataset", "tree_sha", "workers", "t_attr_s", "cpu_s", "rows", "fallback_cells",
                     "member_cells", "load_start", "load_end")]))
}

# --- rprof ----------------------------------------------------------------------------------------
if (mode == "rprof") {
  f <- paste0(out, ".rprof")
  Rprof(f, interval = 0.02, memory.profiling = FALSE, gc.profiling = TRUE, event = "elapsed")
  t0 <- Sys.time()
  x <- attribute()
  t_attr <- secs(t0)
  Rprof(NULL)
  sp <- summaryRprof(f)
  tot <- sp$by.total
  top <- utils::head(tot[order(-tot$total.time), ], 60)
  utils::write.csv(top, paste0(out, "_by_total.csv"))
  utils::write.csv(utils::head(sp$by.self, 40), paste0(out, "_by_self.csv"))
  res <- c(meta, list(t_attr_s = t_attr, sampled_s = sp$sampling.time))
  res$load_end <- load_end()
  write_json(res, paste0(out, ".json"))
  print(unlist(res[c("dataset", "t_attr_s", "sampled_s")]))
  print(utils::head(top[, c("total.time", "total.pct", "self.time")], 40))
}

# --- steps ----------------------------------------------------------------------------------------
if (mode == "steps") {
  # Derived exactly as fl_valley_attribute() derives it.
  slope <- tan(terra::terrain(dem, "slope", unit = "degrees") * pi / 180) * 100
  keys <- streams[[group]]
  lev <- sort(unique(keys[!is.na(keys)]))
  res_xy <- terra::res(valleys)
  crop_cells <- vapply(lev, function(g) {
    bb <- sf::st_bbox(streams[!is.na(keys) & keys == g, ])
    ((bb[["xmax"]] - bb[["xmin"]] + 4000) / res_xy[1]) * ((bb[["ymax"]] - bb[["ymin"]] + 4000) / res_xy[2])
  }, numeric(1))
  set.seed(72)
  big <- order(-crop_cells)[seq_len(min(50L, length(lev)))]
  rest <- setdiff(seq_along(lev), big)
  # Small enough to time every group: then the step sums can be set against the e2e wall time.
  pick <- if (length(lev) <= 500L) seq_along(lev) else
    c(big, rest[sample.int(length(rest), min(100L, length(rest)))])

  tm <- function(expr) { t0 <- Sys.time(); force(expr); as.numeric(difftime(Sys.time(), t0, units = "secs")) }
  pt0 <- proc.time()
  rows <- lapply(pick, function(i) {
    g <- lev[i]
    t <- c()
    sg <- NULL
    t["subset"] <- tm(sg <- streams[!is.na(keys) & keys == g, ])
    sg0 <- sg
    sg <- sg[!sf::st_is_empty(sf::st_geometry(sg)), ]
    e <- NULL; slope_c <- NULL; valleys_c <- NULL; seeds <- NULL; dm <- NULL; cd <- NULL; cm <- NULL
    member <- NULL; lc <- NULL; cells <- NULL
    t["ext"] <- tm({
      e <- terra::ext(terra::vect(sf::st_geometry(sg)))
      e <- terra::intersect(terra::extend(e, 2000), terra::ext(valleys))
    })
    if (is.null(e)) return(NULL)
    t["crop_slope"] <- tm(slope_c <- terra::crop(slope, e, snap = "out"))
    t["crop_valleys"] <- tm(valleys_c <- terra::crop(valleys, e, snap = "out"))
    sg$fl_seed <- 1
    t["rasterize"] <- tm(seeds <- fl_stream_rasterize(sg, slope_c, field = "fl_seed"))
    t["seed_check"] <- tm(all(is.na(terra::values(seeds, mat = FALSE))))
    t["distance"] <- tm(dm <- fl_mask_distance(seeds, threshold = 1000))
    t["costdist"] <- tm(cd <- fl_cost_distance(slope_c, seeds))
    t["cost_mask"] <- tm(cm <- fl_mask(cd, threshold = cost_threshold, operator = "<"))
    t["multiply"] <- tm(member <- valleys_c * dm * cm)
    t["values"] <- tm(lc <- which(terra::values(member, mat = FALSE) == 1L))
    t["cell_xy"] <- tm(cells <- terra::cellFromXY(valleys, terra::xyFromCell(member, lc)))
    # The real helper runs after the replica, so the replica's crops are not timed on warm caches.
    real <- fl_group_cells(sg0, valleys, slope, 2000, cost_threshold, 2000)$cells
    stopifnot(identical(as.numeric(cells), as.numeric(real)))   # empty: integer(0) vs numeric(0)
    t["poly"] <- if (length(cells)) tm(fl_cells_poly(cells, valleys)) else 0
    data.frame(group = format(g), crop_cells = terra::ncell(slope_c), member_cells = length(cells),
               big = i %in% big, t(t))
  })
  pt <- proc.time() - pt0
  tab <- do.call(rbind, rows)
  utils::write.csv(tab, paste0(out, "_steps.csv"), row.names = FALSE)
  step_cols <- setdiff(names(tab), c("group", "crop_cells", "member_cells", "big"))
  agg <- rbind(big = colSums(tab[tab$big, step_cols]), sample = colSums(tab[!tab$big, step_cols]))
  print(round(agg, 2))
  cat("loop elapsed", pt[["elapsed"]], "cpu", pt[["user.self"]] + pt[["sys.self"]], "\n")
  res <- c(meta, list(loop_elapsed_s = pt[["elapsed"]], loop_cpu_s = pt[["user.self"]] + pt[["sys.self"]],
                      step_sum_s = sum(tab[, step_cols]),
                      n_big = sum(tab$big), n_sample = sum(!tab$big),
                      sample_crop_cells_mean = mean(tab$crop_cells[!tab$big]),
                      sample_s_mean = mean(rowSums(tab[!tab$big, step_cols]))))
  res$load_end <- load_end()
  write_json(res, paste0(out, ".json"))
}
