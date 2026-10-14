# Fetch a DEM cropped to an AOI

Returns a `SpatRaster` of elevation cropped to a buffered AOI. Source is
a local file, an HTTP COG (`/vsicurl/`), or an S3 COG (`/vsis3/`).
Defaults to MRDEM-30 — NRCan's Medium-Resolution Digital Elevation Model
(30 m, all of Canada, public S3, no auth) — a sensible default for
watershed-scale BC floodplain work.

## Usage

``` r
fl_dem_aoi(
  aoi,
  source = NULL,
  buffer = 2000,
  target_crs = NULL,
  res = NULL,
  pipeline = NULL
)
```

## Arguments

- aoi:

  An `sf` or `sfc` object — polygon, lines, or points. Buffered by
  `buffer` (via
  [`sf::st_buffer()`](https://r-spatial.github.io/sf/reference/geos_unary.html))
  before crop. To crop tightly along a stream corridor (memory-efficient
  when the watershed-scale AOI has sparse stream coverage), pass the
  streams `sf` here rather than the full WSG polygon.

- source:

  Character. Path or URL for the source raster. `NULL` (default) uses
  MRDEM-30 DTM via `/vsicurl/`. Local file paths, `/vsicurl/https://...`
  URLs, and `/vsis3/...` S3 paths all work —
  [`terra::rast()`](https://rspatial.github.io/terra/reference/rast.html)
  handles them identically.

- buffer:

  Numeric. Distance in metres to buffer `aoi` before crop. Default
  `2000`.

- target_crs:

  CRS spec recognised by
  [`sf::st_crs()`](https://r-spatial.github.io/sf/reference/st_crs.html)
  (EPSG code, WKT, PROJ string, or `crs` object). `NULL` (default)
  returns the raster in the input AOI's CRS. **Reprojection happens
  after crop**, never before — the 84 GB MRDEM COG must not be
  reprojected as a whole.

- res:

  Numeric. Output cell size in `target_crs` units, used when the raster
  is reprojected. `NULL` (default) takes the source's cell size when the
  source and `target_crs` share linear units (MRDEM-30 to BC Albers
  gives exactly 30 m). A `target_crs` in degrees has no single
  equivalent of a metre cell, so there `res` must be given; the error
  quotes the degree value at the AOI's latitude. Any other unit mismatch
  (a US-foot target, a geographic source with a projected target) also
  needs `res`.

- pipeline:

  Character or `NULL`. The PROJ coordinate operation used to reproject.
  `NULL` (default) pins the operation between two NAD83 realizations on
  GRS80 (NAD83, NAD83(CSRS), ...; MRDEM-30 to BC Albers is one) to the
  projection-only pipeline, with no datum shift, when both are projected
  with easting-then-northing axes, and leaves any other pair to PROJ.
  `""` leaves every pair to PROJ. Any other string is a PROJ pipeline
  passed to
  [`terra::project()`](https://rspatial.github.io/terra/reference/project.html)
  as given; supply one only between CRSs whose axes are easting then
  northing, because a pipeline can meet a CRS's authority axis order
  (lat/lon, or northing first) and silently return `NA` or a misplaced
  raster. When `aoi` is in `target_crs`, a supplied string is also used,
  inverted, to carry the AOI into the source CRS for the read window, so
  it must be invertible. When `aoi` is in a third CRS, its transforms
  take the default pin, not the string. `""` hands the AOI's transforms
  to sf's PROJ as well.

## Value

A `SpatRaster` covering the buffered AOI. In the source CRS (and `res`
unset or equal to the source's) it is a crop on the source grid.
Otherwise it is on a grid of `res` cells whose edges are multiples of
`res`, spanning the buffered AOI's bounding box in `target_crs`.

## Details

MRDEM-30 (`s3://canelevation-dem/mrdem-30/mrdem-30-dtm.tif`) is a single
84 GB Cloud-Optimized GeoTIFF in EPSG:3979 covering all of Canada. The
`/vsicurl/` access pattern range-reads only the bytes intersecting the
AOI, so total bandwidth scales with AOI size, not the COG size.

When `target_crs` differs from the source CRS, the raster is projected
onto an explicit grid: the buffered AOI's bounding box in `target_crs`,
snapped outward to multiples of `res`. The grid therefore depends only
on the AOI and `res`, so the same AOI lands on the same cells whatever
terra or GDAL version runs it, and neighbouring AOIs share one
alignment. Before flooded 0.7.0 GDAL chose the origin and cell size
itself (MRDEM-30 came out at 30.4 to 30.5 m, depending on the AOI), and
that choice moved between toolchains (GDAL 3.8.5 / PROJ 9.5.1 against
GDAL 3.13.0 / PROJ 9.8.1) because the datum operation below moved (#67).
Cells outside the buffered AOI can come back `NA`, where the grid's
corners reach past the area read from the source. An integer source is
reprojected through a floating-point copy, so those cells are `NA`
whatever its NoData value: projected directly from a file (a crop of the
whole source, or one terra keeps on disk), terra writes a NoData such as
UInt32 4294967295 as 4294967296, a value, wherever the output reaches
past the area read (#76).

The cell values depend on the coordinate operation, and left to PROJ
that choice follows its EPSG database: between MRDEM-30's NAD83(CSRS)
and BC Albers' NAD83, PROJ 9.5.1 applies no datum shift and PROJ 9.8.1
routes through WGS 84, about 1.3 m apart in BC. So between projected
CRSs on NAD83 realizations with easting-then-northing axes (MRDEM-30 to
BC Albers is one) the operation is pinned by default (see `pipeline`)
and changes only with flooded. With it pinned, GDAL 3.8.5's warper
reproduces terra on GDAL 3.13.0 to within 0.2 mm per cell (#67). The
`gdalwarp` utility's defaults (an approximate transformer and a kernel
widened with scale) differ from terra's by up to ~10 m per cell, so
re-derive a kept DEM through `fl_dem_aoi()`, not `gdalwarp`, and record
terra's GDAL and PROJ versions (`terra::gdal(lib = "all")`) with it.

The AOI's own transforms, into the source CRS for the read window and
into `target_crs` for the grid, go through sf's PROJ, and between
projected NAD83 pairs they are pinned the same way (#78). Left to PROJ,
a datum step of about a metre moves an edge that lies that close to a
cell boundary by a whole cell: on the bundled streams it changed 47 to
91 cells of a 30 m DEM for 3 of 60 AOI positions, all outside the
buffered AOI. Where the AOI's pair is not pinned (a geographic,
northing-first or non-NAD83 CRS on either side) and with
`pipeline = ""`, those edges still follow sf's PROJ, so record sf's PROJ
too
([`sf::sf_extSoftVersion()`](https://r-spatial.github.io/sf/reference/sf_extSoftVersion.html)).

For sub-10 m riparian-scale work where lidar coverage exists, query the
`stac-elevation-bc` STAC catalog and pass an item's COG URL as `source`.
See the example below.

## See also

[`fl_valley_confine()`](https://newgraphenvironment.github.io/flooded/reference/fl_valley_confine.md)

## Examples

``` r
aoi <- sf::st_read(
  system.file("testdata/streams.gpkg", package = "flooded"),
  quiet = TRUE
)

# Local file (any path or URL works the same way)
dem <- fl_dem_aoi(
  aoi,
  source = system.file("testdata/dem.tif", package = "flooded"),
  buffer = 200
)
terra::plot(dem)


if (FALSE) { # \dontrun{
# Default: MRDEM-30 DTM via /vsicurl/ — fetched lazily from NRCan S3
dem <- fl_dem_aoi(aoi, buffer = 2000)
terra::plot(dem, main = "MRDEM-30 over AOI")

# LidarBC via stac-elevation-bc — sub-10 m where lidar coverage exists
bbox_4326 <- sf::st_bbox(sf::st_transform(aoi, 4326))
items <- rstac::stac("https://images.a11s.one/") |>
  rstac::stac_search(
    collections = "stac-elevation-bc",
    bbox = unname(bbox_4326)
  ) |>
  rstac::post_request() |>
  rstac::items_fetch()
if (length(items$features) > 0L) {
  cog <- paste0("/vsicurl/", items$features[[1]]$assets$dem$href)
  dem_lidar <- fl_dem_aoi(aoi, source = cog, buffer = 100)
}
} # }
```
