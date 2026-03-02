#' Delineate unconfined valleys using the Valley Confinement Algorithm
#'
#' Orchestrates the full VCA pipeline: slope thresholding, cost-distance
#' analysis, flood surface modelling, and morphological cleanup to identify
#' unconfined valley bottoms.
#'
#' @param dem A `SpatRaster` of elevation.
#' @param streams An `sf` linestring object or a `SpatRaster` of rasterized
#'   streams. If `sf`, it is rasterized using `field`.
#' @param field Character. Column name for [fl_stream_rasterize()] when
#'   `streams` is `sf`. Default `"channel_width"`.
#' @param slope A `SpatRaster` of percent slope. If `NULL`, derived from `dem`.
#' @param slope_threshold Numeric. Maximum percent slope for valley floor.
#'   Default `9`.
#' @param max_width Numeric. Maximum valley width in map units (metres).
#'   Default `2000`.
#' @param cost_threshold Numeric. Maximum accumulated cost distance.
#'   Default `2500`.
#' @param flood_factor Numeric. Multiplier on bankfull depth. Default `6`.
#' @param precip A `SpatRaster` or numeric scalar of precipitation. Default `1`.
#' @param size_threshold Numeric. Minimum valley patch area (m²). Default `5000`.
#' @param hole_threshold Numeric. Maximum hole area to fill (m²). Default `2500`.
#'
#' @return A `SpatRaster` with binary values: `1` = unconfined valley, `0` =
#'   confined / hillslope, `NA` = outside analysis extent.
#'
#' @details
#' The algorithm combines four criteria via intersection (AND):
#' 1. **Slope mask** — cells with slope <= `slope_threshold`
#' 2. **Distance mask** — cells within `max_width / 2` of a stream
#' 3. **Cost distance mask** — cells with accumulated cost < `cost_threshold`
#' 4. **Flood mask** — cells identified as flooded by bankfull regression
#'
#' The combined mask then undergoes morphological cleanup:
#' - Closing filter (3x3) to bridge small gaps
#' - Fill small holes (< `hole_threshold`)
#' - Remove small patches (< `size_threshold`)
#' - Majority filter (3x3) to smooth edges
#'
#' Adapted from the USDA Valley Confinement Algorithm Toolbox (BlueGeo
#' implementation by Devin Cairns, MIT license) and bcfishpass lateral
#' habitat assembly (Simon Norris, Apache 2.0).
#'
#' @seealso [fl_mask()], [fl_cost_distance()], [fl_flood_model()],
#'   [fl_patch_rm()]
#'
#' @examples
#' dem <- terra::rast(system.file("testdata/dem.tif", package = "flooded"))
#' streams <- sf::st_read(
#'   system.file("testdata/streams.gpkg", package = "flooded"),
#'   quiet = TRUE
#' )
#' precip_r <- fl_stream_rasterize(streams, dem, field = "map_upstream")
#'
#' valleys <- fl_valley_confine(
#'   dem, streams,
#'   field = "upstream_area_ha",
#'   precip = precip_r
#' )
#' terra::plot(valleys, col = c("grey90", "darkgreen"), main = "Unconfined valleys")
#'
#' @export
fl_valley_confine <- function(dem, streams,
                              field = "channel_width",
                              slope = NULL,
                              slope_threshold = 9,
                              max_width = 2000,
                              cost_threshold = 2500,
                              flood_factor = 6,
                              precip = 1,
                              size_threshold = 5000,
                              hole_threshold = 2500) {
  stopifnot(inherits(dem, "SpatRaster"))

  # --- Rasterize streams if needed ---
  if (inherits(streams, "sf")) {
    stream_r <- fl_stream_rasterize(streams, dem, field = field)
  } else if (inherits(streams, "SpatRaster")) {
    stream_r <- streams
  } else {
    stop("`streams` must be an sf object or SpatRaster.", call. = FALSE)
  }

  # --- Derive slope if not provided ---
  if (is.null(slope)) {
    slope_deg <- terra::terrain(dem, "slope", unit = "degrees")
    slope <- tan(slope_deg * pi / 180) * 100
  }

  # --- 1. Slope mask ---
  mask_slope <- fl_mask(slope, threshold = slope_threshold, operator = "<=")

  # --- 2. Distance mask (within max_width/2 of streams) ---
  mask_dist <- fl_mask_distance(stream_r, threshold = max_width / 2)

  # --- 3. Cost distance mask ---
  cost <- fl_cost_distance(slope, stream_r)
  mask_cost <- fl_mask(cost, threshold = cost_threshold, operator = "<")

  # --- 4. Flood mask ---
  flood <- fl_flood_model(dem, stream_r,
                          flood_factor = flood_factor, precip = precip,
                          max_width = max_width)
  mask_flood <- flood[["flooded"]]
  # Include stream cells in the flood mask; convert NA to 0
  mask_flood <- terra::ifel(!is.na(stream_r), 1L, mask_flood)
  mask_flood <- terra::ifel(is.na(mask_flood), 0L, mask_flood)

  # --- Combine masks (AND) ---
  valleys <- mask_slope * mask_dist * mask_cost * mask_flood

  # --- Morphological cleanup ---
  # Closing filter: dilate then erode (3x3 max then min)
  valleys <- terra::focal(valleys, w = 3, fun = "max", na.rm = TRUE)
  valleys <- terra::focal(valleys, w = 3, fun = "min", na.rm = TRUE)


  # Fill small holes: find 0-patches, fill those below hole_threshold
  inv <- terra::ifel(valleys == 1, 0L, 1L)
  hole_patches <- terra::patches(inv, directions = 8L, zeroAsNA = TRUE)
  cell_area <- prod(terra::res(dem))
  freq_tbl <- terra::freq(hole_patches)
  small_hole_ids <- freq_tbl$value[freq_tbl$count * cell_area < hole_threshold]
  if (length(small_hole_ids) > 0L) {
    rcl <- cbind(small_hole_ids, NA)
    holes_labeled <- terra::classify(hole_patches, rcl)
    # Where small holes were removed (now NA), set valley to 1
    valleys <- terra::ifel(is.na(holes_labeled) & !is.na(hole_patches), 1L, valleys)
  }

  # Remove small valley patches
  valleys <- fl_patch_rm(valleys, min_area = size_threshold, directions = 8L)

  # Majority filter (3x3 modal)
  valleys <- terra::focal(valleys, w = 3, fun = "modal", na.rm = TRUE)

  # Ensure binary output
  valleys <- terra::ifel(valleys >= 1, 1L, 0L)

  names(valleys) <- "valley"
  valleys
}
