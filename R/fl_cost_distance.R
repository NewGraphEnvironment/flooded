#' Accumulated cost distance from stream cells
#'
#' Computes the least-cost distance from every cell to the nearest stream cell,
#' accumulating friction (typically slope) along the path. Stream cells are
#' seed points with cost zero.
#'
#' @param friction A `SpatRaster` of movement cost per cell (e.g., percent
#'   slope). Higher values = harder to traverse.
#' @param streams A `SpatRaster` of rasterized streams (output of
#'   [fl_stream_rasterize()]). Any non-`NA` cell is treated as a seed point.
#'
#' @return A `SpatRaster` of accumulated cost distance. Stream cells have
#'   value `0`; other cells increase with cost-weighted distance from the
#'   nearest stream.
#'
#' @details
#' Uses [terra::costDist()] which implements a push-broom algorithm for
#' weighted distance. The `friction` raster defines per-cell traversal cost
#' and `streams` identifies seed cells (cost = 0).
#'
#' Cells that are `NA` in `friction` are impassable barriers.
#'
#' @export
fl_cost_distance <- function(friction, streams) {
  stopifnot(
    inherits(friction, "SpatRaster"),
    inherits(streams, "SpatRaster")
  )

  if (!terra::compareGeom(friction, streams, stopOnError = FALSE)) {
    stop("`friction` and `streams` must have the same extent, resolution, and CRS.",
         call. = FALSE)
  }

  # costDist(x, target) finds cells in x equal to `target` as seed points.

  # Set stream cells to 0 in the friction raster so costDist treats them as

  # target cells (cost = 0 starting points).
  cost <- terra::ifel(!is.na(streams), 0, friction)
  out <- terra::costDist(cost, target = 0)
  names(out) <- "cost_distance"
  out
}
