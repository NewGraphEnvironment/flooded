#' Interpolate flood surface and compute depth above terrain
#'
#' Takes the flood surface elevation at stream cells (from
#' [fl_flood_surface()]) and interpolates it outward to produce a continuous
#' water surface, then subtracts the DEM to get flood depth. Positive values
#' indicate flooding.
#'
#' @param dem A `SpatRaster` of elevation.
#' @param flood_surface A `SpatRaster` of flood surface elevation at stream
#'   cells (output of [fl_flood_surface()]). `NA` at non-stream cells.
#' @param max_width Numeric. Maximum corridor width in map units (metres)
#'   within which to interpolate. Default `2000` (1000m each side).
#' @param streams A `SpatRaster` of rasterized streams used to define the
#'   interpolation corridor. If `NULL`, derived from non-`NA` cells in
#'   `flood_surface`.
#'
#' @return A `SpatRaster` of flood depth (metres above terrain). Positive
#'   values are flooded; `0` at stream cells; `NA` outside the corridor or
#'   where depth is negative (terrain above flood surface).
#'
#' @details
#' Interpolation uses [terra::interpIDW()] (inverse distance weighting) to
#' propagate the flood surface from stream cells outward. This differs from
#' the Python VCA which uses `scipy.interpolate.griddata` with linear
#' interpolation — IDW is available natively in terra and produces similar
#' results for this application.
#'
#' The interpolation domain is limited to cells within `max_width / 2` of
#' the nearest stream cell to avoid extrapolating into distant terrain.
#'
#' @examples
#' dem <- terra::rast(system.file("testdata/dem.tif", package = "flooded"))
#' streams <- sf::st_read(
#'   system.file("testdata/streams.gpkg", package = "flooded"),
#'   quiet = TRUE
#' )
#' stream_r <- fl_stream_rasterize(streams, dem, field = "upstream_area_ha")
#' precip_r <- fl_stream_rasterize(streams, dem, field = "map_upstream")
#' surface <- fl_flood_surface(dem, stream_r, precip = precip_r)
#' depth <- fl_flood_depth(dem, surface, max_width = 2000, streams = stream_r)
#' terra::plot(depth, main = "Flood depth (m)")
#'
#' @export
fl_flood_depth <- function(dem, flood_surface, max_width = 2000,
                           streams = NULL) {
  stopifnot(
    inherits(dem, "SpatRaster"),
    inherits(flood_surface, "SpatRaster"),
    is.numeric(max_width), length(max_width) == 1L, max_width > 0
  )

  if (!terra::compareGeom(dem, flood_surface, stopOnError = FALSE)) {
    stop("`dem` and `flood_surface` must have the same extent, resolution, and CRS.",
         call. = FALSE)
  }

  # Build stream mask for distance corridor
  if (is.null(streams)) {
    stream_mask <- !is.na(flood_surface)
  } else {
    stream_mask <- !is.na(streams)
  }

  # Distance from streams
  dist <- terra::distance(terra::ifel(stream_mask, 1, NA))

  # Extract stream cell coordinates + flood surface values as xyz matrix
  stream_cells <- which(!is.na(terra::values(flood_surface)))
  xy <- terra::xyFromCell(flood_surface, stream_cells)
  z <- terra::values(flood_surface)[stream_cells]
  pts <- cbind(xy, z)

  # Build interpolation target: template raster masked to corridor
  half_width <- max_width / 2
  target <- terra::ifel((dist <= half_width) & !is.na(dem), 1, NA)

  # IDW interpolation from stream points onto corridor
  surface_interp <- terra::interpIDW(target, pts,
                                     radius = half_width,
                                     power = 2, fill = NA)

  # Merge: keep original surface at stream cells, interpolated elsewhere
  surface_full <- terra::ifel(!is.na(flood_surface), flood_surface, surface_interp)

  # Depth = surface - DEM
  depth <- surface_full - dem

  # Set stream cells to 0 (stream bed, not "flooded")
  depth <- terra::ifel(stream_mask, 0, depth)
  # NA where depth is negative (terrain above flood surface)
  depth <- terra::ifel(depth < 0, NA, depth)

  names(depth) <- "flood_depth"
  depth
}

# Next cell on each cell's D8 flow path, as a cell-number vector (#68). Whitebox breaches
# depressions (least cost, then fills what it cannot breach) and writes an ESRI pointer:
# 1 E, 2 SE, 4 S, 8 SW, 16 W, 32 NW, 64 N, 128 NE. Cells with no outflow (pits, flats,
# NA, or a step off the grid) point to themselves, so every path ends at a fixed point.
# The directions come from the DEM alone, never from the streams: that is what keeps the
# drainage surface monotone in added watercourses.
fl_flow_next <- function(dem, breach_dist = 50L) {
  if (!requireNamespace("whitebox", quietly = TRUE) ||
      !isTRUE(suppressMessages(whitebox::check_whitebox_binary()))) {
    stop("`method = \"drainage\"` needs the whitebox package and its WhiteboxTools binary: ",
         "install with `pak::pak(\"whitebox\")` then `whitebox::install_whitebox()`.",
         call. = FALSE)
  }
  wd <- tempfile("fl_flow_")
  dir.create(wd)
  on.exit(unlink(wd, recursive = TRUE), add = TRUE)
  f_dem <- file.path(wd, "dem.tif")
  f_cond <- file.path(wd, "dem_breached.tif")
  f_pntr <- file.path(wd, "d8_pointer.tif")
  terra::writeRaster(dem, f_dem, datatype = "FLT8S")
  whitebox::wbt_breach_depressions_least_cost(f_dem, f_cond, dist = breach_dist,
                                              fill = TRUE, verbose_mode = FALSE)
  whitebox::wbt_d8_pointer(f_cond, f_pntr, esri_pntr = TRUE, verbose_mode = FALSE)
  if (!file.exists(f_pntr)) {
    stop("WhiteboxTools did not write a D8 pointer raster.", call. = FALSE)
  }
  code <- terra::values(terra::rast(f_pntr), mat = FALSE)

  nr <- terra::nrow(dem)
  nc <- terra::ncol(dem)
  cell <- seq_len(nr * nc)
  row <- (cell - 1L) %/% nc + 1L
  col <- (cell - 1L) %% nc + 1L
  # position in the lookup = log2(code) + 1, for the eight valid codes only
  k <- match(code, c(1, 2, 4, 8, 16, 32, 64, 128))
  dr <- c(0L, 1L, 1L, 1L, 0L, -1L, -1L, -1L)[k]
  dc <- c(1L, 1L, 0L, -1L, -1L, -1L, 0L, 1L)[k]
  r2 <- row + dr
  c2 <- col + dc
  nxt <- (r2 - 1L) * nc + c2
  off <- is.na(k) | r2 < 1L | r2 > nr | c2 < 1L | c2 > nc
  nxt[off] <- cell[off]
  nxt
}

# Maximum of `value` over each cell's downstream path, the cell included (#68). Pointer
# jumping: after step k, `m[x]` is the max over the first 2^k cells of x's path and `nxt[x]`
# is the cell 2^k steps on, so the loop runs log2(longest path) times. `NA` values never win;
# a cell whose whole path is `NA` stays `NA`.
fl_path_max <- function(nxt, value) {
  m <- value
  m[is.na(m)] <- -Inf
  # A breached, filled DEM has no cycles, but cap the loop so one can never hang it.
  for (i in seq_len(ceiling(log2(length(nxt))) + 2L)) {
    m <- pmax(m, m[nxt])
    nxt2 <- nxt[nxt]
    if (identical(nxt2, nxt)) break
    nxt <- nxt2
  }
  m[m == -Inf] <- NA
  m
}
