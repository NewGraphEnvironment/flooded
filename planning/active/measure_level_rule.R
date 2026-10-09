# Review B1 (#68 round 2): which candidate level should the path maximum take?
#   raw      the stream cells' own flood surface (DEM bed + ff*d), 3x3 max
#   cond     conditioned elevation of the path cell + 3x3 max of ff*d   (HAND convention)
#   condmin  3x3 min of conditioned elevation + 3x3 max of ff*d
# Valley cells from fl_valley_confine() at ff2/4/6 against pooled, on the bundled tile and on
# the Parsnip WSG (MRDEM-30, vignette inputs: bull trout order 3+, precip, waterbodies).
#
# Run: Rscript planning/active/measure_level_rule.R > planning/active/measure_level_rule.log 2>&1
pkgload::load_all(quiet = TRUE)
terra::terraOptions(threads = 12, progress = 0)
ns <- asNamespace("flooded")

route_cache <- new.env()
real_route <- get("fl_flow_route", ns)
cached_route <- function(dem, breach_dist = 50L) {
  key <- paste(terra::ext(dem)[], terra::res(dem), collapse = "_")
  if (is.null(route_cache[[key]])) route_cache[[key]] <- real_route(dem, breach_dist)
  route_cache[[key]]
}
rules <- list(
  raw = function(flood_surface, dem, route)
    terra::values(terra::focal(flood_surface, 3, "max", na.rm = TRUE), mat = FALSE),
  cond = get("fl_drainage_level", ns),
  condmin = function(flood_surface, dem, route) {
    zc <- terra::rast(dem); terra::values(zc) <- route$z
    zmin <- terra::values(terra::focal(zc, 3, "min", na.rm = TRUE), mat = FALSE)
    d <- terra::values(terra::focal(flood_surface - dem, 3, "max", na.rm = TRUE), mat = FALSE)
    zmin + d
  }
)
unlockBinding("fl_flow_route", ns); assign("fl_flow_route", cached_route, ns)
unlockBinding("fl_drainage_level", ns)

sites <- list(
  bundled = function() {
    dem <- terra::rast(system.file("testdata/dem.tif", package = "flooded"))
    st <- sf::st_read(system.file("testdata/streams.gpkg", package = "flooded"), quiet = TRUE)
    list(dem = dem, st = st, wb = NULL)
  },
  parsnip = function() {
    g <- "inst/vignette-data/pars.gpkg"
    list(dem = terra::rast("inst/vignette-data/pars_dem.tif"),
         st = sf::st_read(g, "streams", quiet = TRUE),
         wb = sf::st_read(g, "waterbodies", quiet = TRUE))
  }
)
res <- list()
for (site in names(sites)) {
  s <- sites[[site]]()
  pr <- fl_stream_rasterize(s$st, s$dem, field = "map_upstream")
  cat(sprintf("\n== %s: %d cells, %d segments\n", site, terra::ncell(s$dem), nrow(s$st)))
  for (method in c("pooled", names(rules))) {
    if (method != "pooled") assign("fl_drainage_level", rules[[method]], ns)
    for (ff in c(2, 4, 6)) {
      t0 <- Sys.time()
      v <- fl_valley_confine(s$dem, s$st, area_field = "upstream_area_ha", precip = pr,
                             waterbodies = s$wb, flood_factor = ff,
                             flood_method = if (method == "pooled") "pooled" else "drainage")
      n <- sum(terra::values(v, mat = FALSE) == 1L, na.rm = TRUE)
      res[[length(res) + 1]] <- data.frame(site, method, ff, cells = n,
                                           secs = round(as.numeric(Sys.time() - t0, units = "secs"), 1))
      cat(sprintf("%-8s ff%d  %9d cells  (%.0f s)\n", method, ff, n,
                  as.numeric(Sys.time() - t0, units = "secs")))
    }
  }
}
res <- do.call(rbind, res)
base <- res[res$method == "pooled", c("site", "ff", "cells")]
names(base)[3] <- "pooled"
res <- merge(res, base)
res$vs_pooled <- sprintf("%+.1f%%", 100 * (res$cells / res$pooled - 1))
cat("\n== summary\n"); print(res[order(res$site, res$method, res$ff), ], row.names = FALSE)
gaps <- do.call(rbind, lapply(split(res, list(res$site, res$method)), function(d) {
  d <- d[order(d$ff), ]
  data.frame(site = d$site[1], method = d$method[1],
             gap_ff4_ff2 = sprintf("%.1f%%", 100 * (d$cells[2] / d$cells[1] - 1)),
             gap_ff6_ff4 = sprintf("%.1f%%", 100 * (d$cells[3] / d$cells[2] - 1)))
}))
cat("\n== flood_factor gaps\n"); print(gaps, row.names = FALSE)
