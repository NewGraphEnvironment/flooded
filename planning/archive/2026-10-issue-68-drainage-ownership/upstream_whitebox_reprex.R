# Reprex: WhiteboxTools BreachDepressionsLeastCost / FillDepressions are not deterministic
# when multi-threaded. Needs only the R packages whitebox and terra (and the WBT binary:
# whitebox::install_whitebox()).
library(terra)
set.seed(1)
# Synthetic 800 x 800 DEM: a tilted surface with random noise, so it has many pits
r <- rast(nrows = 800, ncols = 800, xmin = 0, xmax = 8000, ymin = 0, ymax = 8000,
          crs = "EPSG:3005")
xy <- xyFromCell(r, 1:ncell(r))
values(r) <- round(1000 - 0.01 * xy[, 2] + 5 * sin(xy[, 1] / 300) + rnorm(ncell(r), sd = 0.5))  # whole metres: ties, like an integer DEM
dem <- file.path(tempdir(), "dem.tif")
writeRaster(r, dem, overwrite = TRUE)

run_twice <- function(tool, procs) {
  whitebox::wbt_options(max_procs = procs)
  out <- file.path(tempdir(), paste0(tool, "_", c(1, 2), ".tif"))
  for (o in out) switch(tool,
    breach_lc_fill = whitebox::wbt_breach_depressions_least_cost(dem, o, dist = 50, fill = TRUE),
    breach_lc      = whitebox::wbt_breach_depressions_least_cost(dem, o, dist = 50, fill = FALSE),
    fill           = whitebox::wbt_fill_depressions(dem, o, fix_flats = TRUE),
    breach         = whitebox::wbt_breach_depressions(dem, o))
  a <- values(rast(out[1]), mat = FALSE); b <- values(rast(out[2]), mat = FALSE)
  sum(a != b, na.rm = TRUE)
}
tools <- c("breach_lc_fill", "breach_lc", "fill", "breach")
res <- data.frame(tool = tools,
  differ_default = sapply(tools, run_twice, procs = -1L),
  differ_1_thread = sapply(tools, run_twice, procs = 1L))
print(whitebox::wbt_version()[1])
cat("cells:", ncell(r), "\n")
print(res, row.names = FALSE)
