#' Compute flood surface elevation at stream cells
#'
#' Estimates the bankfull flood surface elevation at each stream cell using
#' the VCA bankfull regression, then adds the DEM elevation. The result is
#' the water surface elevation that will be interpolated outward by
#' [fl_flood_depth()].
#'
#' @param dem A `SpatRaster` of elevation.
#' @param streams A `SpatRaster` of rasterized streams (output of
#'   [fl_stream_rasterize()]). Cell values are upstream contributing area in
#'   hectares (or another proxy for channel size).
#' @param flood_factor Numeric. Multiplier on bankfull depth to estimate flood
#'   depth. Default `6` (VCA convention).
#' @param precip A `SpatRaster` of mean annual precipitation (mm), or a single
#'   numeric value applied uniformly. Default `1` (omits precipitation term).
#'
#' @return A `SpatRaster` with flood surface elevation at stream cells and
#'   `NA` elsewhere. Same grid as `dem`.
#'
#' @details
#' Bankfull regressions follow the Valley Confinement Algorithm:
#'
#' ```
#' bankfull_width = (upstream_area ^ 0.280) * 0.196 * (precip ^ 0.355)
#' bankfull_depth = bankfull_width ^ 0.607 * 0.145
#' flood_depth    = bankfull_depth * flood_factor
#' flood_surface  = DEM + flood_depth
#' ```
#'
#' When `precip = 1` (default), the precipitation term drops out and
#' flood depth depends only on contributing area.
#'
#' If your stream raster contains channel width instead of contributing area,
#' the regression still produces a relative flood surface — the absolute
#' depth will differ but the spatial pattern is preserved.
#'
#' @export
fl_flood_surface <- function(dem, streams, flood_factor = 6, precip = 1) {
  stopifnot(
    inherits(dem, "SpatRaster"),
    inherits(streams, "SpatRaster"),
    is.numeric(flood_factor), length(flood_factor) == 1L, flood_factor > 0
  )

  if (!terra::compareGeom(dem, streams, stopOnError = FALSE)) {
    stop("`dem` and `streams` must have the same extent, resolution, and CRS.",
         call. = FALSE)
  }

  # Clamp negative values to 0
  contrib <- terra::ifel(streams < 0, 0, streams)

  # Precipitation term
 if (inherits(precip, "SpatRaster")) {
    if (!terra::compareGeom(dem, precip, stopOnError = FALSE)) {
      stop("`precip` must have the same extent, resolution, and CRS as `dem`.",
           call. = FALSE)
    }
    pcp <- terra::ifel(precip < 0, 0, precip) ^ 0.355
  } else {
    stopifnot(is.numeric(precip), length(precip) == 1L, precip >= 0)
    pcp <- precip ^ 0.355
  }

  # Bankfull regression (VCA coefficients)
  bankfull_width <- (contrib ^ 0.280) * 0.196 * pcp
  bankfull_depth <- (bankfull_width ^ 0.607) * 0.145
  flood_depth <- bankfull_depth * flood_factor

  # Flood surface = DEM + flood depth at stream cells
  surface <- dem + flood_depth

  # Mask to stream cells only
  out <- terra::mask(surface, streams)
  names(out) <- "flood_surface"
  out
}
