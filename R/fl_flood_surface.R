#' Compute flood surface elevation at stream cells
#'
#' Estimates the bankfull flood surface elevation at each stream cell using
#' the VCA bankfull regression, then adds the DEM elevation. The result is
#' the water surface elevation that will be interpolated outward by
#' [fl_flood_depth()].
#'
#' @param dem A `SpatRaster` of elevation.
#' @param streams A `SpatRaster` of rasterized streams (output of
#'   [fl_stream_rasterize()]). Cell values **must be upstream contributing
#'   area in hectares** — they are the drainage-area term of the bankfull
#'   regression, not a generic channel-size proxy. Converted to km2 internally.
#' @param flood_factor Numeric. Multiplier on bankfull depth to estimate flood
#'   depth. Default `6` (VCA convention).
#' @param precip A `SpatRaster` of mean annual precipitation in **millimetres**,
#'   or a single numeric value in mm applied uniformly. Converted to cm/yr
#'   internally. Default `NULL`, which drops the precipitation term.
#'
#' @return A `SpatRaster` with flood surface elevation at stream cells and
#'   `NA` elsewhere. Same grid as `dem`.
#'
#' @details
#' Bankfull regressions follow the Valley Confinement Algorithm. Hall et al.
#' (2007) and Nagel et al. (2014) both specify drainage area in **km2** and
#' mean annual precipitation in **cm/yr**, so the hectares and millimetres
#' callers carry are converted before the coefficients are applied:
#'
#' ```
#' area_km2       = upstream_area_ha / 100
#' precip_cm      = precip_mm / 10
#'
#' bankfull_width = (area_km2 ^ 0.280) * 0.196 * (precip_cm ^ 0.355)
#' bankfull_depth = bankfull_width ^ 0.607 * 0.145
#' flood_depth    = bankfull_depth * flood_factor
#' flood_surface  = DEM + flood_depth
#' ```
#'
#' When `precip = NULL` (default), the precipitation term drops out — the
#' multiplier is exactly `1` — and flood depth depends only on contributing
#' area. Supplying precipitation matters: on the bundled test data it raises
#' predicted depth by ~2.4x (2.366 averaged over stream cells).
#'
#' The equation predicts a *fitted index*, not a surveyed channel. Hall's
#' regression has an R2 of 0.47, and its widths run well below independent
#' estimates such as bcfishpass's — 5.7 m against 31.3 m for the Bulkley.
#' `flood_factor` is what scales the index onto a mapped footprint.
#'
#' Passing anything other than upstream area in hectares (channel width, for
#' instance) silently produces a plausible-looking but wrong flood surface;
#' see the units defect recorded in `inst/notes/floodplain_interpretation.md`.
#'
#' @examples
#' dem <- terra::rast(system.file("testdata/dem.tif", package = "flooded"))
#' streams <- sf::st_read(
#'   system.file("testdata/streams.gpkg", package = "flooded"),
#'   quiet = TRUE
#' )
#' stream_r <- fl_stream_rasterize(streams, dem, field = "upstream_area_ha")
#' precip_r <- fl_stream_rasterize(streams, dem, field = "map_upstream")
#'
#' # With precipitation — realistic flood surface
#' surface <- fl_flood_surface(dem, stream_r, flood_factor = 6, precip = precip_r)
#' terra::plot(surface, main = "Flood surface elevation (m)")
#'
#' @export
fl_flood_surface <- function(dem, streams, flood_factor = 6, precip = NULL) {
  stopifnot(
    inherits(dem, "SpatRaster"),
    inherits(streams, "SpatRaster"),
    is.numeric(flood_factor), length(flood_factor) == 1L, flood_factor > 0
  )

  if (!terra::compareGeom(dem, streams, stopOnError = FALSE)) {
    stop("`dem` and `streams` must have the same extent, resolution, and CRS.",
         call. = FALSE)
  }

  # Clamp negative values to 0, then convert hectares to km2. Hall et al.
  # (2007) state the regression takes drainage area in km2 (flooded#49).
  contrib <- terra::ifel(streams < 0, 0, streams)
  area_km2 <- contrib / 100

  # Precipitation term. Inputs are millimetres; the regression takes cm/yr.
  # `NULL` drops the term entirely — a multiplier of exactly 1, which no
  # numeric value in millimetres can express: 1 mm is 0.1 cm/yr, which scales
  # width by 0.4416 and depth by 0.6089, i.e. shallower than omitting the term.
  if (is.null(precip)) {
    pcp <- 1
  } else if (inherits(precip, "SpatRaster")) {
    if (!terra::compareGeom(dem, precip, stopOnError = FALSE)) {
      stop("`precip` must have the same extent, resolution, and CRS as `dem`.",
           call. = FALSE)
    }
    pcp <- (terra::ifel(precip < 0, 0, precip) / 10) ^ 0.355
  } else {
    stopifnot(is.numeric(precip), length(precip) == 1L, precip >= 0)
    pcp <- (precip / 10) ^ 0.355
  }

  # Bankfull regression (VCA coefficients, on km2 and cm/yr)
  bankfull_width <- (area_km2 ^ 0.280) * 0.196 * pcp
  bankfull_depth <- (bankfull_width ^ 0.607) * 0.145
  flood_depth <- bankfull_depth * flood_factor

  # Flood surface = DEM + flood depth at stream cells
  surface <- dem + flood_depth

  # Mask to stream cells only
  out <- terra::mask(surface, streams)
  names(out) <- "flood_surface"
  out
}
