# ab_join_compare.R -- A/B for flooded#83: floodplains' fp_hj_join_range() (origin/main 8db7165) vs
# flooded::fl_valley_join() on identical inputs, every species of the given areas.
# usage, from a floodplains checkout with the flooded under test first on .libPaths():
#   Rscript ab_join_compare.R <dir with fp_habitat_join_old.R> <floodplains root> <area> ...
# where fp_habitat_join_old.R is `git show 8db7165:scripts/floodplain_lcc/fp_habitat_join.R`.
suppressMessages({library(sf); library(terra); library(DBI); library(RPostgres)})
sf::sf_use_s2(FALSE)
terra::terraOptions(threads = 4, memfrac = 0.3, progress = 0)
`%||%` <- function(a, b) if (is.null(a)) b else a
args <- commandArgs(trailingOnly = TRUE); sp_dir <- args[1]; root <- args[2]; areas <- args[-(1:2)]
old <- new.env(); sys.source(file.path(sp_dir, "fp_habitat_join_old.R"), envir = old)
source(file.path(root, "scripts/floodplain_lcc/fp_region.R"))
cat("flooded", as.character(packageVersion("flooded")), find.package("flooded"), "\n")
out <- list()
for (area in areas) {
  cfg <- yaml::read_yaml(file.path(root, "config", area, "area.yml"))
  scen <- cfg$primary_scenario %||% paste0(cfg$species, "_ff04")
  dd <- file.path(root, "data", area)
  r <- rast(file.path(dd, paste0("floodplain_", scen, ".tif")))
  v <- st_read(file.path(dd, "floodplain.gpkg"), layer = paste0(scen, "_by_", cfg$attribute_by), quiet = TRUE)
  v[[cfg$attribute_by]] <- as.numeric(v[[cfg$attribute_by]])
  hl <- st_read(file.path(dd, "aquatic_network.gpkg"), layer = "habitat_link", quiet = TRUE)
  schema <- sub("^link:", "", unique(hl$model))
  con <- dbConnect(Postgres())
  seg <- st_zm(st_read(con, quiet = TRUE, query = sprintf("
    SELECT blue_line_key, downstream_route_measure AS drm, geom
      FROM %s.streams WHERE watershed_group_code = '%s'", schema, cfg$watershed_group)), drop = TRUE)
  dbDisconnect(con)
  for (k in c("blue_line_key", "drm")) seg[[k]] <- as.numeric(seg[[k]])
  seg_key <- sprintf("%.0f:%.3f", seg$blue_line_key, seg$drm)
  g <- old$fp_hj_grid_cells(r, v, cfg$attribute_by, st_crs(seg))
  for (sp in sort(unique(hl$species), method = "radix")) {
    h <- hl[hl$species == sp, ]
    hk <- sprintf("%.0f:%.3f", as.numeric(h$blue_line_key), as.numeric(h$downstream_route_measure))
    m <- match(seg_key, hk); hs <- seg[!is.na(m), ]
    hs$spawning <- !is.na(h$spawning[m[!is.na(m)]]) & as.logical(h$spawning[m[!is.na(m)]])
    hs$rearing  <- !is.na(h$rearing[m[!is.na(m)]])  & as.logical(h$rearing[m[!is.na(m)]])
    t0 <- Sys.time(); a <- old$fp_hj_join_range(g$cells, hs, r); t_old <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    t0 <- Sys.time(); b <- suppressMessages(flooded::fl_valley_join(r, v, hs, group = cfg$attribute_by,
                                                                   cols = c("spawning", "rearing")))
    t_new <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    same <- function(x, y) isTRUE(all.equal(as.numeric(x$cell), as.numeric(y$cell))) &&
      identical(x$spawning, y$spawning) && identical(x$rearing, y$rearing)
    out[[paste(area, sp)]] <- data.frame(area = area, species = sp, cells = nrow(b$nearest),
      nearest_identical = same(a$nearest, b$nearest), any_identical = same(a$any, b$any),
      ties_old = attr(a$nearest, "ties"), ties_new = b$ties,
      noseg_old = attr(a$nearest, "blk_without_segments"), noseg_new = length(b$no_segments),
      check_ok = all(b$check[c("missing", "extra")] == 0), s_old = round(t_old), s_new = round(t_new))
    print(out[[length(out)]], row.names = FALSE)
  }
}
cat("\n== SUMMARY ==\n"); print(do.call(rbind, out), row.names = FALSE)
