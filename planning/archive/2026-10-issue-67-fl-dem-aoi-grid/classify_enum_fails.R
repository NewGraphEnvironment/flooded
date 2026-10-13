# classify_enum_fails.R -- #67: classify every pinned case enumerate_pin.R did not pass, against a
# second oracle. At X's area-of-use centre, compare the pin with sf's own choice (PROJ 9.5.1) and
# with terra's (PROJ 9.8.1), point by point.
#   "PROJ outlier": the pin matches sf's PROJ to < 0.01 m, and terra's PROJ is >= 10 source units
#                   away and at least 90% of the value gap; the gap measures PROJ 9.8.1's
#                   choice, not the pin.
#   "snap":         values agree (< 10 units) and only coverage differs (a template row/column
#                   snapping differently between the two template bboxes).
#   "UNEXPLAINED":  anything else -- a real defect candidate.
# Usage: Rscript planning/archive/2026-10-issue-67-fl-dem-aoi-grid/classify_enum_fails.R <enumerate_pin.csv>
suppressMessages(pkgload::load_all(".", quiet = TRUE))
d <- utils::read.csv(commandArgs(TRUE)[1])
p <- d[d$pinned %in% TRUE & !d$pass %in% TRUE, ]
cen <- function(X) {
  w <- X$wkt
  v <- as.numeric(strsplit(gsub("BBOX\\[|\\]", "", regmatches(w, regexpr("BBOX\\[[^]]+\\]", w))), ",")[[1]])
  if (v[4] < v[2]) v[4] <- v[4] + 360
  c(((v[2] + v[4]) / 2 + 180) %% 360 - 180, (v[1] + v[3]) / 2)
}
gap <- function(code) {
  X <- sf::st_crs(code)
  p0 <- sf::st_coordinates(sf::st_transform(sf::st_sfc(sf::st_point(cen(X)), crs = 4326), X))[, 1:2, drop = FALSE]
  g <- sf::st_sfc(sf::st_point(p0[1, ]), crs = X)
  pin <- suppressWarnings(sf::st_coordinates(sf::st_transform(
    g, sf::st_crs(3005)$wkt, pipeline = dem_pipeline_nad83(X, sf::st_crs(3005)))))[1, 1:2]
  c(sf = sqrt(sum((sf::st_coordinates(sf::st_transform(g, 3005))[1, 1:2] - pin)^2)),
    terra = sqrt(sum((terra::project(p0, X$wkt, "EPSG:3005")[1, ] - pin)^2)))
}
codes <- unique(p$code)
g <- t(vapply(codes, gap, numeric(2)))
p$sf_gap <- g[match(p$code, codes), "sf"]
p$terra_gap <- g[match(p$code, codes), "terra"]
# terra's gap in X's units, since `med` is in the source's (X's) units for cases B and B2
to_units <- vapply(p$code, function(k) {
  u <- sf::st_crs(k)$units_gdal
  if (grepl("US survey foot", u)) 1200 / 3937 else if (grepl("foot", u, ignore.case = TRUE)) 0.3048 else 1
}, numeric(1))
p$terra_gap_units <- p$terra_gap / to_units
p$class <- ifelse(p$sf_gap < 0.01 & p$terra_gap_units >= 10 & p$terra_gap_units >= 0.9 * p$med, "PROJ outlier",
                  ifelse(!is.na(p$med) & p$med < 10 & p$ran, "snap", "UNEXPLAINED"))
print(p[, c("code", "case", "n_pin", "n_prj", "med", "sf_gap", "terra_gap", "terra_gap_units", "class")],
      row.names = FALSE)
cat("\nclass counts (cases):\n"); print(table(p$class))
cat("CRSs:", length(codes), "\n")
