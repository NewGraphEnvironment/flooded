# Keep only patches connected to anchor features

Identifies connected patches of `1`-valued cells and keeps only those
that overlap with anchor features (e.g., stream cells). Disconnected
patches are set to `0`.

## Usage

``` r
fl_patch_conn(x, anchor, directions = 4L)
```

## Arguments

- x:

  A `SpatRaster` with binary values (`0`/`1`).

- anchor:

  A `SpatRaster` identifying anchor cells. Any non-`NA`, non-zero cell
  is an anchor (e.g., rasterized streams).

- directions:

  Integer. `4` for rook connectivity, `8` for queen. Default `4`.

## Value

A `SpatRaster` with the same grid as `x`. Only patches touching at least
one anchor cell are retained.

## Examples

``` r
dem <- terra::rast(system.file("testdata/dem.tif", package = "flooded"))
slope <- terra::rast(system.file("testdata/slope.tif", package = "flooded"))
streams <- sf::st_read(
  system.file("testdata/streams.gpkg", package = "flooded"),
  quiet = TRUE
)
stream_r <- fl_stream_rasterize(streams, dem, field = "upstream_area_ha")
gentle <- fl_mask(slope, threshold = 9, operator = "<=")

# Keep only gentle-slope patches that touch a stream
connected <- fl_patch_conn(gentle, stream_r)
terra::plot(connected, col = c("grey90", "darkgreen"),
     main = "Gentle slopes connected to streams")

```
