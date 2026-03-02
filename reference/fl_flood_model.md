# Run the full flood model

Convenience wrapper that calls
[`fl_flood_surface()`](https://newgraphenvironment.github.io/flooded/reference/fl_flood_surface.md)
and
[`fl_flood_depth()`](https://newgraphenvironment.github.io/flooded/reference/fl_flood_depth.md)
in sequence, returning a multi-layer `SpatRaster` with the flood surface
elevation, flood depth, and a binary flooded mask.

## Usage

``` r
fl_flood_model(dem, streams, flood_factor = 6, precip = 1, max_width = 2000)
```

## Arguments

- dem:

  A `SpatRaster` of elevation.

- streams:

  A `SpatRaster` of rasterized streams (output of
  [`fl_stream_rasterize()`](https://newgraphenvironment.github.io/flooded/reference/fl_stream_rasterize.md)).
  Cell values are upstream contributing area in hectares (or another
  proxy for channel size).

- flood_factor:

  Numeric. Multiplier on bankfull depth to estimate flood depth. Default
  `6` (VCA convention).

- precip:

  A `SpatRaster` of mean annual precipitation (mm), or a single numeric
  value applied uniformly. Default `1` (omits precipitation term).

- max_width:

  Numeric. Maximum corridor width in map units (metres) within which to
  interpolate. Default `2000` (1000m each side).

## Value

A `SpatRaster` with three layers:

- flood_surface:

  Water surface elevation at stream cells (`NA` elsewhere).

- flood_depth:

  Depth above terrain (metres). `0` at streams, `NA` where not flooded.

- flooded:

  Binary mask: `1` where `flood_depth > 0`, `0` at streams, `NA`
  elsewhere.

## Examples

``` r
dem <- terra::rast(system.file("testdata/dem.tif", package = "flooded"))
streams <- sf::st_read(
  system.file("testdata/streams.gpkg", package = "flooded"),
  quiet = TRUE
)
stream_r <- fl_stream_rasterize(streams, dem, field = "upstream_area_ha")
precip_r <- fl_stream_rasterize(streams, dem, field = "map_upstream")
flood <- fl_flood_model(dem, stream_r, flood_factor = 6, precip = precip_r)

# Three layers: flood_surface, flood_depth, flooded
names(flood)
#> [1] "flood_surface" "flood_depth"   "flooded"      
terra::plot(flood[["flood_depth"]], main = "Flood depth (m)")

```
