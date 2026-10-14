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
#' @param pipeline Character or `NULL`. The PROJ coordinate operation used to
#'   reproject. `NULL` (default) pins the operation between two NAD83
#'   realizations on GRS80 (NAD83, NAD83(CSRS), ...; MRDEM-30 to BC Albers is
#'   one) to the projection-only pipeline, with no datum shift, when both are
#'   projected with easting-then-northing axes, and leaves any other pair to
#'   PROJ. `""` leaves every pair to
#'   PROJ. Any other string is a PROJ pipeline passed to [terra::project()] as
#'   given; supply one only between CRSs whose axes are easting then northing,
#'   because a pipeline can meet a CRS's authority axis order (lat/lon, or
#'   northing first) and silently return `NA` or a misplaced raster. When
#'   `aoi` is in `target_crs`, a supplied string is also used, inverted, to
#'   carry the AOI into the source CRS for the read window, so it must be
#'   invertible. When `aoi` is in a third CRS, its transforms take the default
#'   pin, not the string. `""` hands the AOI's transforms to sf's PROJ as well.
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
#' 0.7.0 GDAL chose the origin and cell size itself (MRDEM-30 came out at
#' 30.4 to 30.5 m, depending on the AOI), and that choice moved between toolchains (GDAL 3.8.5 / PROJ 9.5.1
#' against GDAL 3.13.0 / PROJ 9.8.1) because the datum operation below moved
#' (#67).
#' Cells outside the buffered AOI can come back `NA`, where the grid's corners
#' reach past the area read from the source. An integer source is reprojected
#' through a floating-point copy, so those cells are `NA` whatever its NoData
#' value: projected directly from a file (a crop of the whole source, or one
#' terra keeps on disk), terra writes a NoData such as UInt32 4294967295 as
#' 4294967296, a value, wherever the output reaches past the source (#76).
#'
#' The cell values depend on the coordinate operation, and left to PROJ that
#' choice follows its EPSG database: between MRDEM-30's NAD83(CSRS) and BC
#' Albers' NAD83, PROJ 9.5.1 applies no datum shift and PROJ 9.8.1 routes
#' through WGS 84, about 1.3 m apart in BC. So between projected CRSs on NAD83
#' realizations with easting-then-northing axes (MRDEM-30 to BC Albers is one)
#' the operation is pinned by default (see `pipeline`) and changes only with
#' flooded. With it pinned, GDAL 3.8.5's warper reproduces terra on GDAL
#' 3.13.0 to within 0.2 mm per cell (#67). The `gdalwarp` utility's defaults
#' (an approximate transformer and a kernel widened with scale) differ from
#' terra's by up to ~10 m per cell, so re-derive a kept DEM through
#' `fl_dem_aoi()`, not `gdalwarp`, and record terra's GDAL and PROJ versions
#' (`terra::gdal(lib = "all")`) with it.
#'
#' The AOI's own transforms, into the source CRS for the read window and
#' into `target_crs` for the grid, go through sf's PROJ, and between projected
#' NAD83 pairs they are pinned the same way (#78). Left to PROJ, a datum step
#' of about a metre moves an edge that lies that close to a cell boundary by
#' a whole cell: on the bundled streams it changed 47 to 91 cells of a 30 m
#' DEM for 3 of 60 AOI positions, all outside the buffered AOI. Where the
#' AOI's pair is not pinned (a geographic, northing-first or non-NAD83 CRS on
#' either side) and with `pipeline = ""`, those edges still follow sf's PROJ,
#' so record sf's PROJ too (`sf::sf_extSoftVersion()`).
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
                       res = NULL, pipeline = NULL) {
  if (!(inherits(aoi, "sf") || inherits(aoi, "sfc"))) {
    stop("`aoi` must be an sf or sfc object.", call. = FALSE)
  }
  stopifnot(is.numeric(buffer), length(buffer) == 1L, buffer >= 0)
  if (!is.null(res) &&
        !(is.numeric(res) && length(res) == 1L && is.finite(res) && res > 0)) {
    stop("`res` must be a single positive number, in `target_crs` units.",
         call. = FALSE)
  }
  if (!is.null(pipeline) &&
        !(is.character(pipeline) && length(pipeline) == 1L && !is.na(pipeline))) {
    stop("`pipeline` must be NULL or a single string (\"\" lets PROJ choose).",
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

  # The AOI's own transforms are pinned like the warp. Left to sf's PROJ, a
  # metre-scale datum step moves the read window and the grid edges, and an
  # edge within that of a cell boundary reads or snaps one cell differently
  # (#78). `pipeline = ""` hands these to PROJ too. Read from the argument as
  # given: `pipeline` itself is later replaced by the source -> target pin.
  pipeline_arg <- pipeline
  aoi_pipeline <- function(to) {
    if (identical(pipeline_arg, "")) "" else dem_pipeline_nad83(aoi_crs, to)
  }
  # A supplied pipeline runs source -> target; inverted, it is AOI -> source
  # whenever the AOI is in target_crs
  user_pipeline <- !is.null(pipeline_arg) && nzchar(pipeline_arg) &&
    aoi_crs == target_crs
  not_inverted <- function(why) {
    stop("`pipeline` could not be applied in reverse to carry the AOI into ",
         "the source CRS for the read window (", why, "). A supplied pipeline ",
         "must be valid, invertible, and run between CRSs whose axes are ",
         "easting then northing.",
         call. = FALSE)
  }
  aoi_buf_in_r <- if (user_pipeline) {
    tryCatch(
      dem_st_transform(aoi_buf, r_crs, pipeline = pipeline_arg, reverse = TRUE),
      error = function(e) e
    )
  } else {
    dem_st_transform(aoi_buf, r_crs, pipeline = aoi_pipeline(r_crs))
  }
  if (inherits(aoi_buf_in_r, "error")) not_inverted(conditionMessage(aoi_buf_in_r))
  if (user_pipeline && !all(is.finite(sf::st_bbox(aoi_buf_in_r)))) {
    not_inverted("non-finite coordinates")
  }

  # Same CRS, source cell size: crop on the source grid, nothing to choose
  if (r_crs == target_crs &&
        (is.null(res) || (r_res[1] == r_res[2] && isTRUE(all.equal(res, r_res[1]))))) {
    return(terra::crop(r, terra::vect(aoi_buf_in_r), snap = "out"))
  }

  if (is.null(res)) res <- dem_res_default(r_crs, r_res, target_crs, aoi_buf)
  if (is.null(pipeline)) pipeline <- dem_pipeline_nad83(r_crs, target_crs)

  # Project onto an explicit grid: the buffered AOI's bbox in target_crs,
  # snapped outward to multiples of `res`. Left to choose, GDAL derives the
  # origin and cell size itself from the transformed source edges, so the grid
  # moved whenever the datum operation did (#67).
  aoi_buf_in_t <- dem_st_transform(
    aoi_buf, target_crs,
    pipeline = if (aoi_crs == r_crs) pipeline else aoi_pipeline(target_crs)
  )
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
  # terra::project() of a file-backed integer raster writes cells beyond the
  # source as NaN only when they match its NoData in the Float32 output. A
  # NoData Float32 cannot hold exactly (UInt32 4294967295, Int32 2147483647)
  # is stored rounded, no longer matches, and comes back as data: 4294967296 m
  # (#76). A float copy carries NA instead. An in-memory crop reports datatype "" and is already
  # fine. On disk the copy is Float32: integers above 2^24 lose precision.
  if (any(grepl("^INT", terra::datatype(r_clip)))) r_clip <- r_clip * 1

  terra::project(r_clip, tmpl, method = "bilinear", pipeline = pipeline)
}

# Transform `x` to the crs `to` through `pipeline` ("" lets PROJ choose).
dem_st_transform <- function(x, to, pipeline, reverse = FALSE) {
  if (sf::st_crs(x) == to) return(x)
  if (!nzchar(pipeline)) return(sf::st_transform(x, to))
  # sf warns when a pipeline is not among PROJ's own candidates, which is the
  # point of pinning one
  withCallingHandlers(
    sf::st_transform(x, to$wkt, pipeline = pipeline, reverse = reverse),
    warning = function(w) {
      if (grepl("pipeline not found", conditionMessage(w), fixed = TRUE)) {
        invokeRestart("muffleWarning")
      }
    }
  )
}

# The coordinate operation between two NAD83 realizations on GRS80 (NAD83,
# NAD83(CSRS), ...) is pinned to the projection-only pipeline: no datum shift.
# Left to PROJ, the choice follows its EPSG database: PROJ 9.5.1 picked "NAD83
# to NAD83(CSRS) (4)", itself shift-free (2 m accuracy), and PROJ 9.8.1 routes
# through WGS 84 with Helmert steps (5 m), moving MRDEM ~1.3 m in BC (#67). For
# any other pair this returns "" and PROJ chooses. Both sides must also be
# easting-then-northing: a supplied pipeline meets the CRS's authority axis
# order (lat/lon for geographic NAD83, northing first for e.g. EPSG:2953) on
# some paths and east/north on others, and the mismatch returns an all-NA
# raster or one placed thousands of km away, without an error.
dem_pipeline_nad83 <- function(from, to) {
  is_nad83 <- function(crs) {
    w <- crs$wkt
    datum <- regmatches(w, regexpr('DATUM\\["[^"]+"', w))
    ellps <- regmatches(w, regexpr('ELLIPSOID\\["[^"]+"', w))
    length(datum) == 1L && length(ellps) == 1L &&
      grepl('"(North American Datum (of )?1983[^"]*|NAD83[^"]*)"$', datum) &&
      grepl('"GRS 1980"$', ellps)
  }
  east_north <- function(crs) {
    w <- crs$wkt
    dirs <- sub('.*,[[:space:]]*', "",
                regmatches(w, gregexpr('AXIS\\["[^"]*",[[:space:]]*[a-z]+', w))[[1]])
    length(dirs) >= 2L && identical(dirs[1:2], c("east", "north"))
  }
  if (!is_nad83(from) || !is_nad83(to)) return("")
  if (isTRUE(sf::st_is_longlat(from)) || isTRUE(sf::st_is_longlat(to))) return("")
  if (!east_north(from) || !east_north(to)) return("")
  step <- function(crs) {
    tok <- strsplit(trimws(crs$proj4string), "[[:space:]]+")[[1]]
    tok <- tok[!grepl("^\\+(no_defs|type|towgs84|datum|vunits|geoidgrids)", tok)]
    paste(c(tok, if (!any(grepl("^\\+ellps=", tok))) "+ellps=GRS80"), collapse = " ")
  }
  steps <- c(paste("+inv", step(from)), step(to))
  paste("+proj=pipeline", paste("+step", steps, collapse = " "))
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
