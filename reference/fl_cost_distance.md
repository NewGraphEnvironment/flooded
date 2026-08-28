# Accumulated cost distance from stream cells

Computes the least-cost distance from every cell to the nearest stream
cell, accumulating friction (typically slope) along the path. Stream
cells are seed points with cost zero.

## Usage

``` r
fl_cost_distance(friction, streams)
```

## Arguments

- friction:

  A `SpatRaster` of movement cost per cell (e.g., percent slope). Higher
  values = harder to traverse.

- streams:

  A `SpatRaster` of rasterized streams (output of
  [`fl_stream_rasterize()`](https://newgraphenvironment.github.io/flooded/reference/fl_stream_rasterize.md)).
  Any non-`NA` cell is treated as a seed point.

## Value

A `SpatRaster` of accumulated cost distance. Stream cells have value
`0`; other cells increase with cost-weighted distance from the nearest
stream.

## Details

Uses
[`terra::costDist()`](https://rspatial.github.io/terra/reference/costDist.html)
which implements a push-broom algorithm for weighted distance. The
`friction` raster defines per-cell traversal cost and `streams`
identifies seed cells (cost = 0).

Cells that are `NA` in `friction` are impassable barriers.

Seeds are encoded by setting stream cells to zero in the friction
surface, which is only unambiguous if no other cell is zero. Friction
rasters do contain exact zeros — integer-metre DEMs, hydro-flattened
lake surfaces and void-filled plateaus all quantize to perfectly flat —
so cells with friction exactly `0` are floored to `1e-6` before seeding.
Flat ground therefore remains cheap to cross but is no longer a cost
source: at 10 m resolution a 100 km path over floored ground accumulates
0.1, against a typical `cost_threshold` of 2500.

Negative friction is not floored —
[`terra::costDist()`](https://rspatial.github.io/terra/reference/costDist.html)
rejects a negative cost surface, and that error is left intact.

If your friction is in units whose typical values approach `1e-6`, floor
the raster yourself before calling.

## Examples

``` r
dem <- terra::rast(system.file("testdata/dem.tif", package = "flooded"))
slope <- terra::rast(system.file("testdata/slope.tif", package = "flooded"))
streams <- sf::st_read(
  system.file("testdata/streams.gpkg", package = "flooded"),
  quiet = TRUE
)
stream_r <- fl_stream_rasterize(streams, dem, field = "upstream_area_ha")
cost <- fl_cost_distance(slope, stream_r)
terra::plot(cost, main = "Cost distance from streams", range = c(0, 5000))

```
