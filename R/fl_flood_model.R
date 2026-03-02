#' Run the full flood model
#'
#' Convenience wrapper that calls [fl_flood_surface()] and [fl_flood_depth()]
#' in sequence, returning a multi-layer `SpatRaster` with the flood surface
#' elevation, flood depth, and a binary flooded mask.
#'
#' @inheritParams fl_flood_surface
#' @inheritParams fl_flood_depth
#'
#' @return A `SpatRaster` with three layers:
#'   \describe{
#'     \item{flood_surface}{Water surface elevation at stream cells (`NA` elsewhere).}
#'     \item{flood_depth}{Depth above terrain (metres). `0` at streams, `NA` where not flooded.}
#'     \item{flooded}{Binary mask: `1` where `flood_depth > 0`, `0` at streams, `NA` elsewhere.}
#'   }
#'
#' @examples
#' dem <- terra::rast(system.file("testdata/dem.tif", package = "flooded"))
#' streams <- sf::st_read(
#'   system.file("testdata/streams.gpkg", package = "flooded"),
#'   quiet = TRUE
#' )
#' stream_r <- fl_stream_rasterize(streams, dem, field = "upstream_area_ha")
#' precip_r <- fl_stream_rasterize(streams, dem, field = "map_upstream")
#' flood <- fl_flood_model(dem, stream_r, flood_factor = 6, precip = precip_r)
#'
#' # Three layers: flood_surface, flood_depth, flooded
#' names(flood)
#' terra::plot(flood[["flood_depth"]], main = "Flood depth (m)")
#'
#' @export
fl_flood_model <- function(dem, streams, flood_factor = 6, precip = 1,
                           max_width = 2000) {
  surface <- fl_flood_surface(dem, streams,
                              flood_factor = flood_factor, precip = precip)
  depth <- fl_flood_depth(dem, surface, max_width = max_width,
                          streams = streams)

  # Binary flooded mask: 1 where depth > 0
  flooded <- terra::ifel(depth > 0, 1L, 0L)
  flooded <- terra::ifel(is.na(depth), NA, flooded)
  names(flooded) <- "flooded"

  c(surface, depth, flooded)
}
