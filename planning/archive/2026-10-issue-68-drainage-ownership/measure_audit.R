# Phase 4 audit (#68 round 2): where do pooled and drainage disagree, and why?
# Bundled tile and Parsnip at ff4 (precip; Parsnip with its waterbodies), conditioned-bed rule.
#   lost   = valley under pooled, not under drainage
#   gained = valley under drainage, not under pooled
# Lost cells split by the drainage flood mask: unowned (path meets no stream), owned but
# dry (waterline below ground), or wet but removed by cleanup. For owned cells, the
# straight-line distance to the cell that supplied the waterline (a lower bound on path
# length) and the pooled waterline minus the drainage waterline.
#
# Run: Rscript planning/active/measure_audit.R > planning/active/measure_audit.log 2>&1
pkgload::load_all(quiet = TRUE)
terra::terraOptions(threads = 4, memfrac = 0.3, progress = 0)  # two session ends from memory pressure
ns <- asNamespace("flooded")
q <- c(0.1, 0.5, 0.9)
fmt <- function(x) paste(sprintf("%.1f", quantile(x, q, na.rm = TRUE)), collapse = " / ")

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
for (site in names(sites)) {
  s <- sites[[site]]()
  dem <- s$dem
  sr <- fl_stream_rasterize(s$st, dem, field = "upstream_area_ha")
  pr <- fl_stream_rasterize(s$st, dem, field = "map_upstream")
  vc <- function(m) terra::values(fl_valley_confine(dem, s$st, area_field = "upstream_area_ha",
    precip = pr, waterbodies = s$wb, flood_factor = 4, flood_method = m), mat = FALSE)
  vp <- vc("pooled"); vd <- vc("drainage")
  surf <- fl_flood_surface(dem, sr, flood_factor = 4, precip = pr)
  # pooled waterline: depth + dem where flooded; recompute the surface itself for the gap
  route <- fl_flow_route(dem)
  lev <- fl_drainage_level(surf, dem, route)
  own <- fl_path_max(route[["next"]], lev, which = TRUE)
  z <- terra::values(dem, mat = FALSE)
  dist <- terra::values(terra::distance(terra::ifel(!is.na(sr), 1, NA)), mat = FALSE)
  in_corr <- dist <= 1000 & !is.na(z)
  wet_d <- !is.na(own$max) & own$max > z & in_corr
  # pooled waterline (IDW surface) at every corridor cell
  pts_cells <- which(!is.na(terra::values(surf, mat = FALSE)))
  pts <- cbind(terra::xyFromCell(dem, pts_cells), terra::values(surf, mat = FALSE)[pts_cells])
  target <- terra::ifel(terra::rast(dem, vals = in_corr), 1, NA)
  w_pool <- terra::values(terra::interpIDW(target, pts, radius = 1000, power = 2, fill = NA), mat = FALSE)

  is1 <- function(v) !is.na(v) & v == 1
  lost <- which(is1(vp) & !is1(vd)); gained <- which(is1(vd) & !is1(vp))
  cat(sprintf("\n== %s ff4: pooled %d, drainage %d valley cells; lost %d, gained %d\n", site,
              sum(is1(vp)), sum(is1(vd)), length(lost), length(gained)))
  unowned <- is.na(own$max[lost])
  dry <- !unowned & !(own$max[lost] > z[lost])
  cat(sprintf("lost: unowned %.1f%% | owned but dry %.1f%% | wet, removed by cleanup %.1f%%\n",
              100 * mean(unowned), 100 * mean(dry), 100 * mean(!unowned & !dry)))
  od <- lost[dry]
  xy <- terra::xyFromCell(dem, od); xo <- terra::xyFromCell(dem, own$from[od])
  cat("owned-but-dry lost cells, p10 / p50 / p90:\n")
  cat("  straight-line distance to waterline source (m):", fmt(sqrt(rowSums((xy - xo)^2))), "\n")
  cat("  pooled waterline - drainage waterline (m):     ", fmt(w_pool[od] - own$max[od]), "\n")
  cat("  pooled depth on them (m):                      ", fmt(w_pool[od] - z[od]), "\n")
  cat("  distance to nearest stream (m):                ", fmt(dist[od]), "\n")
  if (length(gained)) {
    g_own <- !is.na(own$max[gained])
    xg <- terra::xyFromCell(dem, gained[g_own]); xs <- terra::xyFromCell(dem, own$from[gained[g_own]])
    cat("gained cells, p10 / p50 / p90:\n")
    cat("  drainage depth (m):                             ", fmt(own$max[gained] - z[gained]), "\n")
    cat("  drainage waterline - pooled waterline (m):      ", fmt(own$max[gained] - w_pool[gained]), "\n")
    cat("  straight-line distance to waterline source (m): ", fmt(sqrt(rowSums((xg - xs)^2))), "\n")
    cat(sprintf("  owned %.1f%%\n", 100 * mean(g_own)))
  }
  # Reach on the corridor: share of corridor cells whose path meets a stream
  cat(sprintf("corridor cells owned: %.1f%%; pooled-valley cells owned: %.1f%%\n",
              100 * mean(!is.na(own$max[in_corr])), 100 * mean(!is.na(own$max[is1(vp)]))))
}
