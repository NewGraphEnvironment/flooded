#' Union multiple binary rasters
#'
#' Combines multiple binary (0/1) rasters via logical OR. A cell is `1` if
#' it is `1` in any input layer. Useful for merging flood or floodplain layers
#' from different sources.
#'
#' @param ... Two or more `SpatRaster` objects with binary values, or a single
#'   multi-layer `SpatRaster`.
#'
#' @return A `SpatRaster` with `1` where any input is `1`, `0` otherwise.
#'
#' @export
fl_flood_assemble <- function(...) {
  layers <- list(...)
  if (length(layers) == 1L && terra::nlyr(layers[[1L]]) > 1L) {
    stk <- layers[[1L]]
  } else {
    stk <- terra::rast(layers)
  }

  stopifnot(terra::nlyr(stk) >= 2L)

  out <- terra::app(stk, fun = "max", na.rm = TRUE)
  out <- terra::ifel(out >= 1, 1L, 0L)
  names(out) <- "assembled"
  out
}
