#' Rasterize a stream network onto a DEM grid
#'
#' Burns stream line features onto the grid defined by a template raster.
#' Each stream cell receives the value of `field` (typically upstream
#' contributing area or channel width); non-stream cells are `NA`.
#'
#' @param streams An `sf` linestring object with the stream network.
#' @param template A `SpatRaster` that defines the output grid (extent, resolution,
#'   CRS). Typically the DEM.
#' @param field Character. Column name in `streams` to use as the cell value.
#'   Must be numeric. Default `"channel_width"`.
#'
#' @return A `SpatRaster` with the same grid as `template`. Stream cells carry
#'   the value of `field`; all other cells are `NA`.
#'
#' @details
#' Rasterization uses [terra::rasterize()] with `touches = FALSE` (only cells
#' whose centre falls on a stream line are burned). When multiple features
#' overlap a cell, the maximum value is kept.
#'
#' The output CRS matches `template`. If `streams` and `template` have
#' different CRS, `streams` is reprojected to match.
#'
#' @export
fl_stream_rasterize <- function(streams, template, field = "channel_width") {
  stopifnot(
    inherits(streams, "sf"),
    inherits(template, "SpatRaster"),
    is.character(field), length(field) == 1L
  )

  if (!field %in% names(streams)) {
    stop("`field` '", field, "' not found in `streams`. Available columns: ",
         paste(setdiff(names(streams), attr(streams, "sf_column")), collapse = ", "),
         call. = FALSE)
  }

  if (!is.numeric(streams[[field]])) {
    stop("`field` '", field, "' must be numeric, got ", class(streams[[field]])[1L],
         call. = FALSE)
  }

  # Reproject if CRS differs
  if (sf::st_crs(streams) != terra::crs(template)) {
    streams <- sf::st_transform(streams, terra::crs(template))
  }

  v <- terra::vect(streams)
  out <- terra::rasterize(v, template, field = field, fun = "max", touches = FALSE)
  names(out) <- field
  out
}
