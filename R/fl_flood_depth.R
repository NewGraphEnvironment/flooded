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
#' @param method Character. How the waterline is carried away from the streams.
#'   `"pooled"` (default) interpolates every stream cell's flood surface into one
#'   inverse-distance surface. `"drainage"` gives each cell the highest flood
#'   surface among the streams on its downstream flow path; it needs the
#'   `whitebox` package and its WhiteboxTools binary. See Details.
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
#' ## `method = "pooled"` and `method = "drainage"`
#'
#' The pooled interpolation averages over every stream cell within `max_width / 2`,
#' whatever stream it belongs to, as the Python VCA's `griddata` does. A small creek
#' crossing a river's valley floor therefore pulls the river's waterline down around
#' itself, and adding streams to a run can remove floodplain (flooded#68).
#'
#' `method = "drainage"` replaces the average with ownership by drainage:
#'
#' 1. WhiteboxTools breaches the DEM's depressions (least cost, then a breach-fill pass
#'    for what that leaves) and assigns each cell a D8 flow direction. The directions come from the
#'    DEM alone, not from the streams. WhiteboxTools runs single-threaded here, because
#'    its multi-threaded breaching is not deterministic.
#' 2. Each cell's candidate level is the lowest ground in its 3x3 window plus the
#'    deepest flood depth (`flood_factor` x bankfull depth) among the stream cells in
#'    that window. The lowest neighbour stands in for the channel bed, as in
#'    height-above-nearest-drainage (HAND) methods, so one high stream-cell elevation
#'    (a stream line drawn on a bank, an integer DEM) is not carried upstream. The level
#'    can sit up to one cell's down-path drop below the stream's own.
#' 3. A cell's waterline is the highest candidate level on its downstream path,
#'    the cell itself included.
#'
#' Because the flow paths do not depend on the streams and a maximum can only grow,
#' adding a watercourse never lowers a waterline, so the flood mask is monotone in the
#' streams. Through [fl_valley_confine()] the delineation is monotone too on a DEM
#' without `NA` gaps. Gaps can break it through the cost surface and #65. A large
#' river's level carries up the lower reach of a tributary that drains into it, as
#' backwater does. A tributary's level never reaches valley floor that does not drain
#' through it.
#'
#' A cell whose path meets no stream gets no waterline and is not flooded. That includes
#' ground that drains off the edge of the DEM, and ground whose path runs into an `NA`
#' gap over the channel (lidar water returns).
#'
#' **The drainage method is experimental and maps much less floodplain than the pooled
#' one.** Valley-floor ground that drains down-valley before reaching the river takes the
#' river's level where it joins, not beside it. On the Parsnip watershed group at
#' `flood_factor = 4` it maps 27% fewer valley cells than the pooled method. See
#' flooded#68 and `research/flood_surface_interpolation.md`.
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
#' # Drainage ownership needs WhiteboxTools
#' if (requireNamespace("whitebox", quietly = TRUE) &&
#'     isTRUE(whitebox::check_whitebox_binary())) {
#'   depth_d <- fl_flood_depth(dem, surface, max_width = 2000, streams = stream_r,
#'                             method = "drainage")
#'   terra::plot(depth_d, main = "Flood depth (m), drainage ownership")
#' }
#'
#' @export
fl_flood_depth <- function(dem, flood_surface, max_width = 2000,
                           streams = NULL, method = c("pooled", "drainage")) {
  method <- match.arg(method)
  stopifnot(
    inherits(dem, "SpatRaster"),
    inherits(flood_surface, "SpatRaster"),
    is.numeric(max_width), length(max_width) == 1L, max_width > 0
  )

  if (!terra::compareGeom(dem, flood_surface, stopOnError = FALSE)) {
    stop("`dem` and `flood_surface` must have the same extent, resolution, and CRS.",
         call. = FALSE)
  }
  if (method == "drainage") fl_whitebox_check()

  # Build stream mask for distance corridor
  if (is.null(streams)) {
    stream_mask <- !is.na(flood_surface)
  } else {
    stream_mask <- !is.na(streams)
  }

  # Distance from streams
  dist <- terra::distance(terra::ifel(stream_mask, 1, NA))

  # Build interpolation target: template raster masked to corridor
  half_width <- max_width / 2
  target <- terra::ifel((dist <= half_width) & !is.na(dem), 1, NA)

  if (method == "drainage") {
    # Candidate level at each path cell: its conditioned elevation plus the deepest
    # flood depth among the stream cells in its 3x3 window. Then the highest
    # candidate on the cell's downstream path (#68).
    route <- fl_flow_route(dem)
    owned <- fl_path_max(route[["next"]], fl_drainage_level(flood_surface, dem, route))
    surface_interp <- terra::rast(dem)
    terra::values(surface_interp) <- owned
    surface_interp <- terra::mask(surface_interp, target)
  } else {
    # Extract stream cell coordinates + flood surface values as xyz matrix
    stream_cells <- which(!is.na(terra::values(flood_surface)))
    xy <- terra::xyFromCell(flood_surface, stream_cells)
    z <- terra::values(flood_surface)[stream_cells]
    pts <- cbind(xy, z)

    # IDW interpolation from stream points onto corridor
    surface_interp <- terra::interpIDW(target, pts,
                                       radius = half_width,
                                       power = 2, fill = NA)
  }

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

# TRUE when the whitebox package and its WhiteboxTools binary are both available.
fl_has_whitebox <- function() {
  requireNamespace("whitebox", quietly = TRUE) &&
    isTRUE(suppressMessages(whitebox::check_whitebox_binary()))
}

fl_whitebox_check <- function() {
  if (!fl_has_whitebox()) {
    stop("`method = \"drainage\"` needs the whitebox package and its WhiteboxTools binary: ",
         "install with `pak::pak(\"whitebox\")` then `whitebox::install_whitebox()`.",
         call. = FALSE)
  }
  invisible(TRUE)
}

# D8 flow route over the conditioned DEM (#68): `next`, the next cell on each cell's
# path as a cell-number vector, and `z`, the conditioned elevations. Whitebox breaches
# depressions (least cost, then a breach-fill pass for what is left) and writes an ESRI pointer:
# 1 E, 2 SE, 4 S, 8 SW, 16 W, 32 NW, 64 N, 128 NE. Cells with no outflow (pits, flats,
# NA, or a step off the grid) point to themselves, so every path ends at a fixed point.
# The directions come from the DEM alone, never from the streams: that is what keeps the
# drainage surface monotone in added watercourses.
fl_flow_route <- function(dem, breach_dist = 50L) {
  fl_whitebox_check()
  # Multi-threaded breaching and filling are not deterministic: two identical calls on
  # the bundled tile gave 36,000 to 60,000 different cells, so a run would not even be
  # monotone against itself. One thread is exact. The env var outranks the
  # `whitebox.max_procs` option, so set it for this call only and put back what was there.
  old_procs <- Sys.getenv("R_WHITEBOX_MAX_PROCS", unset = NA)
  Sys.setenv(R_WHITEBOX_MAX_PROCS = "1")
  on.exit(if (is.na(old_procs)) Sys.unsetenv("R_WHITEBOX_MAX_PROCS")
          else Sys.setenv(R_WHITEBOX_MAX_PROCS = old_procs), add = TRUE)
  wd <- tempfile("fl_flow_")
  dir.create(wd)
  on.exit(unlink(wd, recursive = TRUE), add = TRUE)
  f_dem <- file.path(wd, "dem.tif")
  f_lc <- file.path(wd, "dem_breached_lc.tif")
  f_cond <- file.path(wd, "dem_breached.tif")
  f_pntr <- file.path(wd, "d8_pointer.tif")
  terra::writeRaster(dem, f_dem, datatype = "FLT8S", NAflag = -32768)
  # Least-cost breaching first (WhiteboxTools' recommended method), then a hybrid
  # breach-fill pass for the pits it leaves. Not `fill = TRUE`: that branch of
  # BreachDepressionsLeastCost (and FillDepressions) panics intermittently on an
  # `Arc::try_unwrap` race in WhiteboxTools 2.4.0, whatever the thread count.
  whitebox::wbt_breach_depressions_least_cost(f_dem, f_lc, dist = breach_dist,
                                              fill = FALSE, verbose_mode = FALSE)
  whitebox::wbt_breach_depressions(f_lc, f_cond, verbose_mode = FALSE)
  whitebox::wbt_d8_pointer(f_cond, f_pntr, esri_pntr = TRUE, verbose_mode = FALSE)
  if (!file.exists(f_cond) || !file.exists(f_pntr)) {
    stop("WhiteboxTools did not write its output; see its messages above.", call. = FALSE)
  }
  code <- terra::values(terra::rast(f_pntr), mat = FALSE)
  z <- terra::values(terra::rast(f_cond), mat = FALSE)
  if (length(code) != terra::ncell(dem) || length(z) != terra::ncell(dem)) {
    stop("WhiteboxTools returned a raster on a different grid.", call. = FALSE)
  }
  list(`next` = fl_pointer_next(code, terra::nrow(dem), terra::ncol(dem)), z = z)
}

# ESRI D8 pointer codes to next-cell numbers on an nr x nc grid (row 1 at the top).
# Anything without a valid code, or stepping off the grid, points to itself.
fl_pointer_next <- function(code, nr, nc) {
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

# Candidate waterline at each cell for the drainage method (#68): the lowest ground in the
# cell's 3x3 window plus the deepest flood depth (flood_factor x bankfull depth) among the
# stream cells in that window. The lowest neighbour stands in for the channel bed, so a
# stream line drawn on a bank, or an integer DEM's rounding, is not carried upstream by the
# path maximum (review B1). The ground is the original DEM, not the conditioned one:
# breaching cuts trenches, and a level read from them moved the bundled tile's ff4 extent
# from -50% to -75% of pooled with the conditioning algorithm alone.
fl_drainage_level <- function(flood_surface, dem, route) {
  bed <- terra::focal(dem, w = 3, fun = "min", na.rm = TRUE)
  depth_near <- terra::focal(flood_surface - dem, w = 3, fun = "max", na.rm = TRUE)
  terra::values(bed, mat = FALSE) + terra::values(depth_near, mat = FALSE)
}

# Maximum of `value` over each cell's downstream path, the cell included (#68). Pointer
# jumping: after step k, `m[x]` is the max over the first 2^k cells of x's path and `nxt[x]`
# is the cell 2^k steps on, so the loop runs log2(longest path) times. `NA` values never win;
# a cell whose whole path is `NA` stays `NA`.
fl_path_max <- function(nxt, value, which = FALSE) {
  m <- value
  m[is.na(m)] <- -Inf
  # `from`: the cell that supplied each max, for auditing ownership.
  from <- seq_along(m)
  # A breached, filled DEM has no cycles, but cap the loop so one can never hang it.
  for (i in seq_len(ceiling(log2(length(nxt))) + 2L)) {
    take <- m[nxt] > m
    from[take] <- from[nxt][take]
    m[take] <- m[nxt][take]
    nxt2 <- nxt[nxt]
    if (identical(nxt2, nxt)) break
    nxt <- nxt2
  }
  none <- m == -Inf
  m[none] <- NA
  if (!which) return(m)
  from[none] <- NA
  list(max = m, from = from)
}
