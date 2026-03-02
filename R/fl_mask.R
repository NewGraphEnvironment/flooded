#' Create a binary mask from a raster by thresholding
#'
#' Applies a comparison operator and threshold to a raster, returning a binary
#' (0/1) mask. Useful for slope masks, elevation masks, depth masks, etc.
#'
#' @param x A `SpatRaster` with numeric values.
#' @param threshold Numeric scalar. The threshold value.
#' @param operator Character. One of `"<="`, `"<"`, `">="`, `">"`, `"=="`,
#'   `"!="`. Default `"<="`.
#'
#' @return A `SpatRaster` with values `1` (condition met) and `0` (condition
#'   not met). `NA` cells in `x` remain `NA`.
#'
#' @examples
#' slope <- terra::rast(system.file("testdata/slope.tif", package = "flooded"))
#' gentle <- fl_mask(slope, threshold = 9, operator = "<=")
#' terra::plot(gentle, col = c("grey90", "darkgreen"), main = "Slope <= 9%")
#'
#' @export
fl_mask <- function(x, threshold, operator = "<=") {
  stopifnot(
    inherits(x, "SpatRaster"),
    is.numeric(threshold), length(threshold) == 1L
  )

  ops <- c("<=", "<", ">=", ">", "==", "!=")
  if (!operator %in% ops) {
    stop("`operator` must be one of: ", paste(ops, collapse = ", "),
         call. = FALSE)
  }

  out <- switch(operator,
    "<=" = x <= threshold,
    "<"  = x <  threshold,
    ">=" = x >= threshold,
    ">"  = x >  threshold,
    "==" = x == threshold,
    "!=" = x != threshold
  )

  # terra comparison returns TRUE/FALSE; convert to integer 1/0
  out <- out * 1L
  names(out) <- "mask"
  out
}
