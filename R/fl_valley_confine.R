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
#' @param waterbodies An `sf` polygon object of lakes and/or wetlands, or
#'   `NULL` (default). Waterbody polygons are rasterized onto the valley grid
#'   and added to the output after morphological cleanup. No buffer is applied —
#'   a lake or wetland in the valley is part of the flood system as-is.
#'   Only waterbody cells that touch (or are adjacent to) the existing valley
#'   output are included — headwater features disconnected from the valley
#'   floor are excluded.
#' @param channel_buffer Logical. Buffer streams by their `channel_width`
#'   attribute and add to the valley output. Default `TRUE` when `streams` is
#'   an `sf` object with a `channel_width` column, `FALSE` otherwise. The
#'   stream channel is floodplain but can be sub-pixel at coarse DEM resolution.
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
#' After cleanup, optional features are added via logical OR:
#' - **Channel buffer** — streams buffered by `channel_width` (DEM correction)
#' - **Waterbodies** — lake/wetland polygons rasterized as-is (fill donut holes)
#'
#' Adapted from the USDA Valley Confinement Algorithm Toolbox (BlueGeo
#' implementation by Devin Cairns, MIT license) and bcfishpass lateral
#' habitat assembly (Simon Norris, Apache 2.0).
#'
#' ## Performance
#'
#' Several internal operations (focal filters, distance calculations, raster
#' math) support multi-threading via [terra::terraOptions()]. Set threads
#' before calling this function to speed up processing on large rasters:
#'
#' ```
#' terra::terraOptions(threads = 12)
#' ```
#'
#' On an Apple M4 Max (16 cores), 12 threads reduced runtime from ~3.5
#' minutes to ~1 minute for a 27M-cell raster (~2,700 km² at 10 m).
#'
#' @seealso [fl_mask()], [fl_cost_distance()], [fl_flood_model()],
#'   [fl_patch_rm()], [fl_valley_poly()]
#'
#' @examples
#' dem <- terra::rast(system.file("testdata/dem.tif", package = "flooded"))
#' streams <- sf::st_read(
#'   system.file("testdata/streams.gpkg", package = "flooded"),
#'   quiet = TRUE
#' )
#' precip_r <- fl_stream_rasterize(streams, dem, field = "map_upstream")
#'
#' # Basic VCA (channel buffer auto-detected from streams$channel_width)
#' valleys <- fl_valley_confine(
#'   dem, streams,
#'   field = "upstream_area_ha",
#'   precip = precip_r
#' )
#' terra::plot(valleys, col = c("grey90", "darkgreen"), main = "Unconfined valleys")
#'
#' # With waterbodies — fills lake/wetland donut holes
#' waterbodies <- sf::st_read(
#'   system.file("testdata/waterbodies.gpkg", package = "flooded"),
#'   quiet = TRUE
#' )
#' valleys_wb <- fl_valley_confine(
#'   dem, streams,
#'   field = "upstream_area_ha",
#'   precip = precip_r,
#'   waterbodies = waterbodies
#' )
#' terra::plot(valleys_wb, col = c("grey90", "darkgreen"), main = "With waterbodies")
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
                              waterbodies = NULL,
                              channel_buffer = NULL,
                              size_threshold = 5000,
                              hole_threshold = 2500) {
  stopifnot(inherits(dem, "SpatRaster"))

  # --- Auto-detect channel_buffer ---
  if (is.null(channel_buffer)) {
    channel_buffer <- inherits(streams, "sf") &&
      "channel_width" %in% names(streams)
  }

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

  # --- Add features (OR into valley output) ---

  # Channel buffer: stream width is floodplain but sub-pixel at coarse DEM res

  if (isTRUE(channel_buffer) && inherits(streams, "sf")) {
    if (!"channel_width" %in% names(streams)) {
      warning("channel_buffer = TRUE but streams has no 'channel_width' column; skipping.",
              call. = FALSE)
    } else {
      buffered <- sf::st_buffer(streams, dist = streams$channel_width / 2)
      buf_r <- terra::rasterize(terra::vect(buffered), dem, field = 1L,
                                background = 0L)
      valleys <- terra::ifel(buf_r == 1L, 1L, valleys)
    }
  }

  # Waterbodies: valley-bottom lakes/wetlands fill donut holes in the VCA.
  # Only include waterbodies that touch the existing valley output — this
  # fills actual donut holes without adding disconnected headwater features
  # that happen to be within the stream corridor.
  if (!is.null(waterbodies)) {
    stopifnot(inherits(waterbodies, "sf"))
    if (nrow(waterbodies) > 0L) {
      wb_r <- terra::rasterize(terra::vect(waterbodies), dem, field = 1L,
                               background = 0L)
      # Dilate valley by 1 pixel so waterbodies adjacent to (not just
      # overlapping) the valley edge are included
      valley_dilated <- terra::focal(valleys, w = 3, fun = "max", na.rm = TRUE)
      valleys <- terra::ifel(wb_r == 1L & valley_dilated == 1L, 1L, valleys)
    }
  }

  names(valleys) <- "valley"
  valleys
}
