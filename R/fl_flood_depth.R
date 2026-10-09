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
#' @param groups Which watercourse each stream cell belongs to, so that each
#'   watercourse's surface is interpolated from its own cells alone. Either a
#'   `SpatRaster` on the same grid holding a group id at each stream cell, or a
#'   list of integer vectors of cell numbers, one per group. The list form lets
#'   a cell belong to more than one watercourse, which is what
#'   [fl_valley_confine()] builds so that a confluence cell feeds both streams.
#'   Stream cells in no group, or with an `NA` id, form one group of their own.
#'   Default `NULL` interpolates every stream cell together, as every release
#'   did before flooded#68.
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
#' ## One surface per watercourse
#'
#' With `groups = NULL`, one interpolation runs over every stream cell, so a
#' cell between a large river and a small creek gets a distance-weighted blend
#' of a deep waterline and a shallow one. A creek crossing a river's valley
#' floor then pulls the river's waterline down around itself, and adding
#' streams to a run can *remove* floodplain (flooded#68: 452 ha of one
#' watershed group's floodplain lost when every FWA stream was seeded instead
#' of a species network).
#'
#' With `groups`, each group's surface is interpolated from its own stream
#' cells and the flood surface is their cell-wise maximum: a spot is as wet as
#' the stream that floods it highest. Adding a group can then only raise the
#' waterline. Nagel et al. (2014) set the flood height per stream segment and
#' do not say how neighbouring segments' heights combine; the Python VCA pools
#' every stream cell into one `griddata()` interpolation, as the
#' `groups = NULL` path does. Per-watercourse maxima are this package's choice.
#'
#' Each group is interpolated over its own bounding box grown by
#' `max_width / 2`, so the cost is one [terra::interpIDW()] per group on a
#' small window rather than one per group on the full grid.
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
                           streams = NULL, groups = NULL) {
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

  surf_v <- terra::values(flood_surface, mat = FALSE)
  stream_cells <- which(!is.na(surf_v))

  # Build interpolation target: template raster masked to corridor
  half_width <- max_width / 2
  target <- terra::ifel((dist <= half_width) & !is.na(dem), 1, NA)

  if (is.null(groups)) {
    # IDW interpolation from every stream point onto corridor
    pts <- cbind(terra::xyFromCell(flood_surface, stream_cells), surf_v[stream_cells])
    surface_interp <- terra::interpIDW(target, pts,
                                       radius = half_width,
                                       power = 2, fill = NA)
  } else {
    group_cells <- fl_depth_groups(groups, flood_surface, stream_cells)
    surface_interp <- fl_depth_grouped(target, flood_surface, surf_v,
                                       group_cells, half_width)
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

# Normalise `groups` to a list of cell-number vectors over the stream cells.
# Stream cells no group claims, and cells with an NA id, become one more group.
fl_depth_groups <- function(groups, flood_surface, stream_cells) {
  if (inherits(groups, "SpatRaster")) {
    if (!terra::compareGeom(flood_surface, groups, stopOnError = FALSE)) {
      stop("`groups` must have the same extent, resolution, and CRS as `dem`.",
           call. = FALSE)
    }
    ids <- terra::values(groups, mat = FALSE)[stream_cells]
    return(unname(split(stream_cells, factor(ids, exclude = NULL))))
  }
  if (!is.list(groups)) {
    stop("`groups` must be a SpatRaster of group ids or a list of cell numbers.",
         call. = FALSE)
  }
  n <- terra::ncell(flood_surface)
  ok <- vapply(groups, function(g) {
    is.numeric(g) && !anyNA(g) && all(g >= 1 & g <= n & g == round(g))
  }, logical(1))
  if (!all(ok)) {
    stop("`groups` list elements must be cell numbers between 1 and ", n, ".",
         call. = FALSE)
  }
  groups <- lapply(groups, function(g) intersect(as.integer(g), stream_cells))
  orphan <- setdiff(stream_cells, unlist(groups, use.names = FALSE))
  if (length(orphan)) groups <- c(groups, list(orphan))
  groups[lengths(groups) > 0L]
}

# One IDW per group over that group's bounding box grown by `half_width`, merged
# into one surface by cell-wise maximum. Windows are row/column ranges of the full
# grid, so a window cell maps back to its full-grid cell number by arithmetic.
fl_depth_grouped <- function(target, flood_surface, surf_v, group_cells, half_width) {
  nr <- terra::nrow(target)
  nc <- terra::ncol(target)
  pad_r <- ceiling(half_width / terra::yres(target))
  pad_c <- ceiling(half_width / terra::xres(target))
  best <- rep(NA_real_, terra::ncell(target))

  for (cells in group_cells) {
    rc <- terra::rowColFromCell(target, cells)
    r0 <- max(1L, min(rc[, 1]) - pad_r)
    r1 <- min(nr, max(rc[, 1]) + pad_r)
    c0 <- max(1L, min(rc[, 2]) - pad_c)
    c1 <- min(nc, max(rc[, 2]) + pad_c)
    win <- target[r0:r1, c0:c1, drop = FALSE]
    stopifnot(terra::nrow(win) == r1 - r0 + 1L, terra::ncol(win) == c1 - c0 + 1L)

    pts <- cbind(terra::xyFromCell(flood_surface, cells), surf_v[cells])
    s <- terra::values(terra::interpIDW(win, pts, radius = half_width,
                                        power = 2, fill = NA), mat = FALSE)
    idx <- rep((r0:r1 - 1L) * nc, each = c1 - c0 + 1L) + rep(c0:c1, times = r1 - r0 + 1L)
    best[idx] <- pmax(best[idx], s, na.rm = TRUE)
  }

  out <- terra::rast(target)
  terra::values(out) <- best
  out
}
