# Rasterize a stream network onto a DEM grid

Burns stream line features onto the grid defined by a template raster.
Each stream cell receives the value of `field` (typically upstream
contributing area or channel width); non-stream cells are `NA`.

## Usage

``` r
fl_stream_rasterize(streams, template, field = "channel_width")
```

## Arguments

- streams:

  An `sf` linestring object with the stream network.

- template:

  A `SpatRaster` that defines the output grid (extent, resolution, CRS).
  Typically the DEM.

- field:

  Character. Column name in `streams` to use as the cell value. Must be
  numeric. Default `"channel_width"`.

## Value

A `SpatRaster` with the same grid as `template`. Stream cells carry the
value of `field`; all other cells are `NA`.

## Details

Rasterization uses
[`terra::rasterize()`](https://rspatial.github.io/terra/reference/rasterize.html)
with `touches = FALSE` (only cells whose centre falls on a stream line
are burned). When multiple features overlap a cell, the maximum value is
kept.

The output CRS matches `template`. If `streams` and `template` have
different CRS, `streams` is reprojected to match.

## Examples

``` r
dem <- terra::rast(system.file("testdata/dem.tif", package = "flooded"))
streams <- sf::st_read(
  system.file("testdata/streams.gpkg", package = "flooded"),
  quiet = TRUE
)
stream_r <- fl_stream_rasterize(streams, dem, field = "upstream_area_ha")
terra::plot(stream_r, main = "Upstream area (ha)")

```
