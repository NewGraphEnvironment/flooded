# Binary mask by Euclidean distance from features

Computes Euclidean distance from non-`NA` cells in a raster and returns
a binary mask where distance is within the threshold. Useful for
constraining analysis to a corridor around streams (e.g., `max_width`
parameter in VCA).

## Usage

``` r
fl_mask_distance(x, threshold)
```

## Arguments

- x:

  A `SpatRaster` where non-`NA` cells are the features to measure
  distance from (e.g., rasterized streams).

- threshold:

  Numeric. Maximum distance in map units (e.g., metres). Cells within
  this distance are `1`; cells beyond are `0`.

## Value

A `SpatRaster` with values `1` (within threshold) and `0` (beyond).

## Details

Distance is computed with
[`terra::distance()`](https://rspatial.github.io/terra/reference/distance.html)
which calculates Euclidean distance from the nearest non-`NA` cell.
Feature cells themselves receive distance `0` and are always included in
the mask.

## Examples

``` r
dem <- terra::rast(system.file("testdata/dem.tif", package = "flooded"))
streams <- sf::st_read(
  system.file("testdata/streams.gpkg", package = "flooded"),
  quiet = TRUE
)
stream_r <- fl_stream_rasterize(streams, dem, field = "upstream_area_ha")
corridor <- fl_mask_distance(stream_r, threshold = 1000)
terra::plot(corridor, col = c("grey90", "steelblue"), main = "Within 1 km of stream")

```
