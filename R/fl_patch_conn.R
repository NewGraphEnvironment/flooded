#' Keep only patches connected to anchor features
#'
#' Identifies connected patches of `1`-valued cells and keeps only those that
#' overlap with anchor features (e.g., stream cells). Disconnected patches
#' are set to `0`.
#'
#' @param x A `SpatRaster` with binary values (`0`/`1`).
#' @param anchor A `SpatRaster` identifying anchor cells. Any non-`NA`,
#'   non-zero cell is an anchor (e.g., rasterized streams).
#' @param directions Integer. `4` for rook connectivity, `8` for queen.
#'   Default `4`.
#'
#' @return A `SpatRaster` with the same grid as `x`. Only patches touching
#'   at least one anchor cell are retained.
#'
#' @examples
#' dem <- terra::rast(system.file("testdata/dem.tif", package = "flooded"))
#' slope <- terra::rast(system.file("testdata/slope.tif", package = "flooded"))
#' streams <- sf::st_read(
#'   system.file("testdata/streams.gpkg", package = "flooded"),
#'   quiet = TRUE
#' )
#' stream_r <- fl_stream_rasterize(streams, dem, field = "upstream_area_ha")
#' gentle <- fl_mask(slope, threshold = 9, operator = "<=")
#'
#' # Keep only gentle-slope patches that touch a stream
#' connected <- fl_patch_conn(gentle, stream_r)
#' terra::plot(connected, col = c("grey90", "darkgreen"),
#'      main = "Gentle slopes connected to streams")
#'
#' @export
fl_patch_conn <- function(x, anchor, directions = 4L) {
  stopifnot(
    inherits(x, "SpatRaster"),
    inherits(anchor, "SpatRaster"),
    directions %in% c(4L, 8L)
  )

  if (!terra::compareGeom(x, anchor, stopOnError = FALSE)) {
    stop("`x` and `anchor` must have the same extent, resolution, and CRS.",
         call. = FALSE)
  }

  # Label connected patches
  patches <- terra::patches(x, directions = directions, zeroAsNA = TRUE)

  # Find which patch IDs overlap with anchor cells
  anchor_mask <- !is.na(anchor) & anchor != 0
  anchor_patches <- terra::mask(patches, anchor_mask, maskvalues = FALSE)
  connected_ids <- unique(terra::values(anchor_patches, na.rm = TRUE))

  if (length(connected_ids) == 0L) {
    # No connected patches — return all zeros
    out <- x * 0L
    names(out) <- names(x)
    return(out)
  }

  # Reclassify: keep connected IDs, set everything else to NA
  all_ids <- unique(terra::values(patches, na.rm = TRUE))
  drop_ids <- setdiff(all_ids, connected_ids)
  if (length(drop_ids) > 0L) {
    rcl <- cbind(drop_ids, NA)
    kept <- terra::classify(patches, rcl)
  } else {
    kept <- patches
  }
  out <- terra::ifel(!is.na(kept), x, 0L)
  names(out) <- names(x)
  out
}
