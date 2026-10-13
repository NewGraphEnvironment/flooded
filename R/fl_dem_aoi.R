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
#' @param res Numeric. Output cell size in `target_crs` units, used when the
#'   raster is reprojected. `NULL` (default) takes the source's cell size when
#'   the source and `target_crs` share linear units (MRDEM-30 to BC Albers gives
#'   exactly 30 m). A `target_crs` in degrees has no single equivalent of a
#'   metre cell, so there `res` must be given; the error quotes the degree
#'   value at the AOI's latitude. Any other unit mismatch (a US-foot target,
#'   a geographic source with a projected target) also needs `res`.
#'
#' @return A `SpatRaster` covering the buffered AOI. In the source CRS (and
#'   `res` unset or equal to the source's) it is a crop on the source grid.
#'   Otherwise it is on a grid of `res` cells whose edges are multiples of
#'   `res`, spanning the buffered AOI's bounding box in `target_crs`.
#'
#' @details
#' MRDEM-30 (`s3://canelevation-dem/mrdem-30/mrdem-30-dtm.tif`) is a single
#' 84 GB Cloud-Optimized GeoTIFF in EPSG:3979 covering all of Canada. The
#' `/vsicurl/` access pattern range-reads only the bytes intersecting the AOI,
#' so total bandwidth scales with AOI size, not the COG size.
#'
#' When `target_crs` differs from the source CRS, the raster is projected onto
#' an explicit grid: the buffered AOI's bounding box in `target_crs`, snapped
#' outward to multiples of `res`. The grid therefore depends only on the AOI
#' and `res`, so the same AOI lands on the same cells whatever terra or GDAL
#' version runs it, and neighbouring AOIs share one alignment. Before flooded
#' 0.7.0 GDAL chose the origin and cell size itself (MRDEM-30 came out at about
#' 30.43 m), and that choice changed between GDAL 3.8.5 and 3.13.0 (#67).
#' Cells outside the buffered AOI can come back `NA`, where the grid's corners
#' reach past the area read from the source. The cell values still come from
#' the GDAL/PROJ stack that terra links. When `aoi` is not already in
#' `target_crs`, its bounding box is transformed through sf's PROJ, so an edge
#' lying within a datum shift of a multiple of `res` can snap one cell
#' differently on another machine.
#'
#' For sub-10 m riparian-scale work where lidar coverage exists, query the
#' `stac-elevation-bc` STAC catalog and pass an item's COG URL as `source`. See the
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
#' # LidarBC via stac-elevation-bc — sub-10 m where lidar coverage exists
#' bbox_4326 <- sf::st_bbox(sf::st_transform(aoi, 4326))
#' items <- rstac::stac("https://images.a11s.one/") |>
#'   rstac::stac_search(
#'     collections = "stac-elevation-bc",
#'     bbox = unname(bbox_4326)
#'   ) |>
#'   rstac::post_request() |>
#'   rstac::items_fetch()
#' if (length(items$features) > 0L) {
#'   cog <- paste0("/vsicurl/", items$features[[1]]$assets$dem$href)
#'   dem_lidar <- fl_dem_aoi(aoi, source = cog, buffer = 100)
#' }
#' }
#'
#' @export
fl_dem_aoi <- function(aoi, source = NULL, buffer = 2000, target_crs = NULL,
                       res = NULL) {
  if (!(inherits(aoi, "sf") || inherits(aoi, "sfc"))) {
    stop("`aoi` must be an sf or sfc object.", call. = FALSE)
  }
  stopifnot(is.numeric(buffer), length(buffer) == 1L, buffer >= 0)
  if (!is.null(res) &&
        !(is.numeric(res) && length(res) == 1L && is.finite(res) && res > 0)) {
    stop("`res` must be a single positive number, in `target_crs` units.",
         call. = FALSE)
  }

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
  r_res <- terra::res(r)

  aoi_buf_in_r <- if (r_crs == aoi_crs) aoi_buf else sf::st_transform(aoi_buf, r_crs)

  # Same CRS, source cell size: crop on the source grid, nothing to choose
  if (r_crs == target_crs &&
        (is.null(res) || (r_res[1] == r_res[2] && isTRUE(all.equal(res, r_res[1]))))) {
    return(terra::crop(r, terra::vect(aoi_buf_in_r), snap = "out"))
  }

  if (is.null(res)) res <- dem_res_default(r_crs, r_res, target_crs, aoi_buf)

  # Project onto an explicit grid: the buffered AOI's bbox in target_crs,
  # snapped outward to multiples of `res`. Left to choose, GDAL derives the
  # origin and cell size itself, and its choice changed between GDAL 3.8.5 and
  # 3.13.0 (#67).
  aoi_buf_in_t <- if (target_crs == aoi_crs) aoi_buf else sf::st_transform(aoi_buf, target_crs)
  bb <- sf::st_bbox(aoi_buf_in_t)
  tmpl <- terra::rast(
    terra::ext(
      floor(bb[["xmin"]] / res) * res, ceiling(bb[["xmax"]] / res) * res,
      floor(bb[["ymin"]] / res) * res, ceiling(bb[["ymax"]] / res) * res
    ),
    resolution = res,
    crs = target_crs$wkt
  )

  # Read only the buffered AOI's bbox in the source CRS, padded two source
  # cells so bilinear sampling has neighbours at the buffer edge. Template
  # corners beyond it lie outside the buffered AOI and come back NA; reading
  # the template's whole footprint instead costs about twice the bytes (#67).
  bs <- sf::st_bbox(aoi_buf_in_r)
  pad <- 2 * max(r_res)
  r_clip <- terra::crop(
    r,
    terra::ext(bs[["xmin"]] - pad, bs[["xmax"]] + pad,
               bs[["ymin"]] - pad, bs[["ymax"]] + pad),
    snap = "out"
  )

  terra::project(r_clip, tmpl, method = "bilinear")
}

# Default output cell size: the source's, when source and target share linear
# units. Otherwise there is no single right value, so the caller must choose;
# for a geographic target the message quotes the degree equivalent at the AOI.
dem_res_default <- function(r_crs, r_res, target_crs, aoi_buf) {
  if (identical(r_crs$units_gdal, target_crs$units_gdal)) {
    return(r_res[1])
  }
  if (isTRUE(sf::st_is_longlat(target_crs)) && !isTRUE(sf::st_is_longlat(r_crs))) {
    centre <- sf::st_transform(
      sf::st_as_sfc(sf::st_bbox(aoi_buf)), 4326
    )
    lat <- mean(sf::st_bbox(centre)[c("ymin", "ymax")])
    m_per_deg <- 111320
    d_lat <- r_res[1] / m_per_deg
    fmt <- function(x) format(signif(x, 2), scientific = FALSE)
    stop(
      "`target_crs` is in degrees, so the cell size cannot be taken from the ",
      "source's ", r_res[1], " m cells. Pass `res` in degrees: ", r_res[1],
      " m is about res = ", fmt(d_lat), " degrees north-south; at ",
      round(lat, 1), " degrees latitude the same value is ",
      round(cos(lat * pi / 180) * r_res[1], 1), " m east-west. For valley ",
      "confinement a metre CRS is the better choice, e.g. target_crs = 3005.",
      call. = FALSE
    )
  }
  stop(
    "`target_crs` (", target_crs$units_gdal, ") and the source (",
    r_crs$units_gdal, ") use different units, so the cell size cannot be ",
    "taken from the source. Pass `res` in `target_crs` units.",
    call. = FALSE
  )
}
