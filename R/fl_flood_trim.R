#' Subtract mask layers from a binary raster
#'
#' Removes (sets to `0`) cells in a binary raster that overlap with any
#' exclusion mask. Useful for trimming floodplain by urban areas, steep
#' terrain, waterbodies, or other features.
#'
#' @param x A `SpatRaster` with binary values (`0`/`1`).
#' @param ... One or more `SpatRaster` exclusion masks. Cells with value `1`
#'   in any mask are removed from `x`.
#'
#' @return A `SpatRaster` with the same grid as `x`. Cells overlapping any
#'   exclusion mask are set to `0`.
#'
#' @export
fl_flood_trim <- function(x, ...) {
  masks <- list(...)
  stopifnot(inherits(x, "SpatRaster"), length(masks) >= 1L)

  out <- x
  for (m in masks) {
    stopifnot(inherits(m, "SpatRaster"))
    out <- terra::ifel(m == 1, 0L, out)
  }
  names(out) <- names(x)
  out
}
