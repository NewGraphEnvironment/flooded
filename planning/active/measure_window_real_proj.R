# #78 acceptance: with sf's unpinned transforms routed through terra's PROJ
# (9.8.1, which takes the WGS 84 route for NAD83 <-> NAD83(CSRS)), does
# fl_dem_aoi() return the same DEM as with sf's own PROJ (9.5.1, no shift)?
# Counts AOI positions (60, 0.5 m steps) where it does not, for the package
# tree given as the first argument (0.7.0 vs this branch).
#
# Rscript planning/active/measure_window_real_proj.R <package dir>
pkg <- commandArgs(TRUE)[1]
suppressMessages(pkgload::load_all(pkg, quiet = TRUE))
library(testthat)

real <- sf::st_transform
# An sfc without a pipeline goes through terra::project(), i.e. terra's PROJ
via_terra <- function(x, crs, ...) {
  pipeline <- list(...)$pipeline
  if (inherits(x, "sfc") && (is.null(pipeline) || !nzchar(pipeline))) {
    to <- sf::st_crs(crs)
    v <- terra::project(terra::vect(x), to$wkt)
    return(sf::st_set_crs(sf::st_as_sfc(sf::st_as_sf(v)), to))
  }
  real(x, crs, ...)
}
with_terra_proj <- function(expr) {
  local_mocked_bindings(st_transform = via_terra, .package = "sf")
  expr
}

aoi0 <- sf::st_read(system.file("testdata/streams.gpkg", package = "flooded"), quiet = TRUE)
bb <- sf::st_bbox(sf::st_transform(sf::st_buffer(aoi0, 3000), 3979))
src <- tempfile(fileext = ".tif")
terra::writeRaster(terra::init(
  terra::rast(terra::ext(bb[c(1, 3, 2, 4)]), resolution = 30, crs = "EPSG:3979"), "x"
), src, datatype = "FLT8S")

# The mock's own reach: the shift terra's PROJ applies here
p <- sf::st_sfc(sf::st_point(c(980000, 1057000)), crs = 3005)
cat("terra-PROJ minus sf-PROJ, 3005 -> 3979 (m):",
    round(sf::st_coordinates(with_terra_proj(sf::st_transform(p, 3979))) -
            sf::st_coordinates(sf::st_transform(p, 3979)), 3), "\n")

same <- function(a, b) {
  identical(as.vector(terra::ext(a)), as.vector(terra::ext(b))) &&
    identical(terra::values(a), terra::values(b))
}
offs <- seq(0, 29.5, by = 0.5)
changed <- vapply(offs, function(dx) {
  aoi <- aoi0
  sf::st_geometry(aoi) <- sf::st_geometry(aoi0) + c(dx, dx * 0.7)
  sf::st_crs(aoi) <- 3005
  !same(fl_dem_aoi(aoi, source = src, buffer = 100),
        with_terra_proj(fl_dem_aoi(aoi, source = src, buffer = 100)))
}, logical(1))
cat("flooded", as.character(packageVersion("flooded", lib.loc = NULL)), "at", pkg, "\n")
cat("sf PROJ:", sf::sf_extSoftVersion()[["PROJ"]], " terra PROJ:", terra::gdal(lib = "proj"), "\n")
cat("positions:", length(offs), " DEM changed under terra's PROJ:", sum(changed),
    " at dx =", offs[changed], "\n")
