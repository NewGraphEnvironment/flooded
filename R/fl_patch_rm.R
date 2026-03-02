#' Remove small patches from a binary raster
#'
#' Identifies connected patches of `1`-valued cells and removes (sets to `0`)
#' any patch whose area is below a size threshold.
#'
#' @param x A `SpatRaster` with binary values (`0`/`1`).
#' @param min_area Numeric. Minimum patch area in map units squared (e.g., m²).
#'   Patches smaller than this are removed.
#' @param directions Integer. `4` for rook connectivity, `8` for queen.
#'   Default `4` (matches VCA 4-connectivity convention).
#'
#' @return A `SpatRaster` with the same grid as `x`. Small patches are set to
#'   `0`; all other values are unchanged.
#'
#' @export
fl_patch_rm <- function(x, min_area, directions = 4L) {
  stopifnot(
    inherits(x, "SpatRaster"),
    is.numeric(min_area), length(min_area) == 1L, min_area > 0,
    directions %in% c(4L, 8L)
  )

  # Label connected patches (only where x == 1)
  patches <- terra::patches(x, directions = directions, zeroAsNA = TRUE)

  # Compute area of each patch
  cell_area <- prod(terra::res(x))
  freq_tbl <- terra::freq(patches)

  # Identify patches below threshold
  small_ids <- freq_tbl$value[freq_tbl$count * cell_area < min_area]

  if (length(small_ids) == 0L) return(x)

  # Reclassify small patch IDs to NA, then use as mask
  rcl <- cbind(small_ids, NA)
  masked <- terra::classify(patches, rcl)
  out <- terra::ifel(is.na(masked) | is.na(patches), 0L, x)
  names(out) <- names(x)
  out
}
