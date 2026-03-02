#' Binary mask by Euclidean distance from features
#'
#' Computes Euclidean distance from non-`NA` cells in a raster and returns a
#' binary mask where distance is within the threshold. Useful for constraining
#' analysis to a corridor around streams (e.g., `max_width` parameter in VCA).
#'
#' @param x A `SpatRaster` where non-`NA` cells are the features to measure
#'   distance from (e.g., rasterized streams).
#' @param threshold Numeric. Maximum distance in map units (e.g., metres).
#'   Cells within this distance are `1`; cells beyond are `0`.
#'
#' @return A `SpatRaster` with values `1` (within threshold) and `0` (beyond).
#'
#' @details
#' Distance is computed with [terra::distance()] which calculates Euclidean
#' distance from the nearest non-`NA` cell. Feature cells themselves receive
#' distance `0` and are always included in the mask.
#'
#' @export
fl_mask_distance <- function(x, threshold) {
  stopifnot(
    inherits(x, "SpatRaster"),
    is.numeric(threshold), length(threshold) == 1L,
    threshold > 0
  )

  d <- terra::distance(x)
  out <- (d <= threshold) * 1L
  names(out) <- "mask"
  out
}
