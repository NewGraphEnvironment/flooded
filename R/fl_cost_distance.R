#' Accumulated cost distance from stream cells
#'
#' Computes the least-cost distance from every cell to the nearest stream cell,
#' accumulating friction (typically slope) along the path. Stream cells are
#' seed points with cost zero.
#'
#' @param friction A `SpatRaster` of movement cost per cell (e.g., percent
#'   slope). Higher values = harder to traverse.
#' @param streams A `SpatRaster` of rasterized streams (output of
#'   [fl_stream_rasterize()]). Any non-`NA` cell is treated as a seed point.
#'
#' @return A `SpatRaster` of accumulated cost distance. Stream cells have
#'   value `0`; other cells increase with cost-weighted distance from the
#'   nearest stream.
#'
#' @details
#' Uses [terra::costDist()] which implements a push-broom algorithm for
#' weighted distance. The `friction` raster defines per-cell traversal cost
#' and `streams` identifies seed cells (cost = 0).
#'
#' Cells that are `NA` in `friction` are impassable barriers.
#'
#' Seeds are encoded by setting stream cells to zero in the friction surface,
#' which is only unambiguous if no other cell is zero. Friction rasters do
#' contain exact zeros — integer-metre DEMs, hydro-flattened lake surfaces and
#' void-filled plateaus all quantize to perfectly flat — so cells with friction
#' exactly `0` are floored to `1e-6` before seeding. Flat ground therefore
#' remains cheap to cross but is no longer a cost source: at 10 m resolution a
#' 100 km path over floored ground accumulates 0.1, against a typical
#' `cost_threshold` of 2500.
#'
#' Negative friction is not floored — [terra::costDist()] rejects a negative
#' cost surface, and that error is left intact.
#'
#' If your friction is in units whose typical values approach `1e-6`, floor the
#' raster yourself before calling.
#'
#' @examples
#' dem <- terra::rast(system.file("testdata/dem.tif", package = "flooded"))
#' slope <- terra::rast(system.file("testdata/slope.tif", package = "flooded"))
#' streams <- sf::st_read(
#'   system.file("testdata/streams.gpkg", package = "flooded"),
#'   quiet = TRUE
#' )
#' stream_r <- fl_stream_rasterize(streams, dem, field = "upstream_area_ha")
#' cost <- fl_cost_distance(slope, stream_r)
#' terra::plot(cost, main = "Cost distance from streams", range = c(0, 5000))
#'
#' @export
fl_cost_distance <- function(friction, streams) {
  stopifnot(
    inherits(friction, "SpatRaster"),
    inherits(streams, "SpatRaster")
  )

  if (!terra::compareGeom(friction, streams, stopOnError = FALSE)) {
    stop("`friction` and `streams` must have the same extent, resolution, and CRS.",
         call. = FALSE)
  }

  # costDist(x, target) seeds on every cell in x equal to `target`, so encoding
  # stream cells as 0 is only correct if nothing else is 0. Friction rasters do
  # contain exact zeros — integer-metre DEMs, hydro-flattened lake surfaces and
  # void-filled plateaus all quantize to perfectly flat — and each one was
  # silently acting as a free cost source (#41).
  #
  # Floor them to a negligible positive value so that zero means "stream cell"
  # by construction. Percent slope runs 0-100+, so 1e-6 is eight orders below
  # the signal: costDist accumulates friction x distance in map units, making a
  # 100 km path over floored ground worth 0.1 against a default cost_threshold
  # of 2500. Flat ground stays cheap to cross; it just stops being a source.
  #
  # `== 0` and not `<= 0`: terra rejects a negative cost surface outright, and
  # flooring negatives would disable that guard, turning meaningless input into
  # plausible-looking output. NA is left alone (NA == 0 is NA), so impassable
  # cells stay impassable.
  friction <- terra::ifel(friction == 0, 1e-6, friction)

  cost <- terra::ifel(!is.na(streams), 0, friction)
  out <- terra::costDist(cost, target = 0)
  names(out) <- "cost_distance"
  out
}
