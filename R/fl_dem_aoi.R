#' Fetch a DEM cropped to an AOI
#'
#' Returns a `SpatRaster` of elevation cropped to a buffered AOI. Source is a
#' local file, an HTTP COG (`/vsicurl/`), or an S3 COG (`/vsis3/`). Defaults to
#' MRDEM-30 — NRCan's Medium-Resolution Digital Elevation Model (30 m, all of
#' Canada, public S3, no auth) — a sensible default for watershed-scale BC
#' floodplain work.
#'
#' @param aoi An `sf` or `sfc` object — polygon, lines, or points. Buffered by
#'   `buffer` (via [sf::st_buffer()]) before crop. To crop tightly along a
#'   stream corridor (memory-efficient when the watershed-scale AOI has sparse
#'   stream coverage), pass the streams `sf` here rather than the full WSG
#'   polygon.
#' @param source Character. Path or URL for the source raster. `NULL` (default)
#'   uses MRDEM-30 DTM via `/vsicurl/`. Local file paths, `/vsicurl/https://...`
#'   URLs, and `/vsis3/...` S3 paths all work — `terra::rast()` handles them
#'   identically.
#' @param buffer Numeric. Distance in metres to buffer `aoi` before crop.
#'   Default `2000`.
#' @param target_crs CRS spec recognised by [sf::st_crs()] (EPSG code, WKT,
#'   PROJ string, or `crs` object). `NULL` (default) returns the raster in the
#'   input AOI's CRS. **Reprojection happens after crop**, never before — the
#'   84 GB MRDEM COG must not be reprojected as a whole.
#'
#' @return A `SpatRaster` cropped to the buffered AOI extent, projected to
#'   `target_crs` if it differs from the source raster's CRS.
#'
#' @details
#' MRDEM-30 (`s3://canelevation-dem/mrdem-30/mrdem-30-dtm.tif`) is a single
#' 84 GB Cloud-Optimized GeoTIFF in EPSG:3979 covering all of Canada. The
#' `/vsicurl/` access pattern range-reads only the bytes intersecting the AOI,
#' so total bandwidth scales with AOI size, not the COG size.
#'
#' For sub-10 m riparian-scale work where lidar coverage exists, query the
#' `stac-dem-bc` STAC catalog and pass an item's COG URL as `source`. See the
#' example below.
#'
#' @seealso [fl_valley_confine()]
#'
#' @examples
#' aoi <- sf::st_read(
#'   system.file("testdata/streams.gpkg", package = "flooded"),
#'   quiet = TRUE
#' )
#'
#' # Local file (any path or URL works the same way)
#' dem <- fl_dem_aoi(
#'   aoi,
#'   source = system.file("testdata/dem.tif", package = "flooded"),
#'   buffer = 200
#' )
#' terra::plot(dem)
#'
#' \dontrun{
#' # Default: MRDEM-30 DTM via /vsicurl/ — fetched lazily from NRCan S3
#' dem <- fl_dem_aoi(aoi, buffer = 2000)
#' terra::plot(dem, main = "MRDEM-30 over AOI")
#'
#' # LidarBC via stac-dem-bc — sub-10 m where lidar coverage exists
#' bbox_4326 <- sf::st_bbox(sf::st_transform(aoi, 4326))
#' items <- rstac::stac("https://images.a11s.one/") |>
#'   rstac::stac_search(
#'     collections = "stac-dem-bc",
#'     bbox = unname(bbox_4326)
#'   ) |>
#'   rstac::post_request() |>
#'   rstac::items_fetch()
#' if (length(items$features) > 0L) {
#'   cog <- paste0("/vsicurl/", items$features[[1]]$assets$image$href)
#'   dem_lidar <- fl_dem_aoi(aoi, source = cog, buffer = 100)
#' }
#' }
#'
#' @export
fl_dem_aoi <- function(aoi, source = NULL, buffer = 2000, target_crs = NULL) {
  if (!(inherits(aoi, "sf") || inherits(aoi, "sfc"))) {
    stop("`aoi` must be an sf or sfc object.", call. = FALSE)
  }
  stopifnot(is.numeric(buffer), length(buffer) == 1L, buffer >= 0)

  if (is.null(source)) {
    source <- paste0(
      "/vsicurl/https://canelevation-dem.s3.ca-central-1.amazonaws.com/",
      "mrdem-30/mrdem-30-dtm.tif"
    )
  }
  stopifnot(is.character(source), length(source) == 1L)

  aoi_crs <- sf::st_crs(aoi)
  target_crs <- if (is.null(target_crs)) aoi_crs else sf::st_crs(target_crs)

  # GEOS can't buffer XYZM/XYZ — fwapg streams carry route-measure M values
  aoi_buf <- sf::st_buffer(sf::st_zm(aoi), dist = buffer)

  r <- terra::rast(source)
  r_crs <- sf::st_crs(terra::crs(r))

  aoi_buf_in_r <- if (r_crs == aoi_crs) aoi_buf else sf::st_transform(aoi_buf, r_crs)
  r_clip <- terra::crop(r, terra::vect(aoi_buf_in_r), snap = "out")

  if (r_crs != target_crs) {
    r_clip <- terra::project(r_clip, target_crs$wkt)
  }

  r_clip
}
