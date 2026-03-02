# Interpolate flood surface and compute depth above terrain

Takes the flood surface elevation at stream cells (from
[`fl_flood_surface()`](https://newgraphenvironment.github.io/flooded/reference/fl_flood_surface.md))
and interpolates it outward to produce a continuous water surface, then
subtracts the DEM to get flood depth. Positive values indicate flooding.

## Usage

``` r
fl_flood_depth(dem, flood_surface, max_width = 2000, streams = NULL)
```

## Arguments

- dem:

  A `SpatRaster` of elevation.

- flood_surface:

  A `SpatRaster` of flood surface elevation at stream cells (output of
  [`fl_flood_surface()`](https://newgraphenvironment.github.io/flooded/reference/fl_flood_surface.md)).
  `NA` at non-stream cells.

- max_width:

  Numeric. Maximum corridor width in map units (metres) within which to
  interpolate. Default `2000` (1000m each side).

- streams:

  A `SpatRaster` of rasterized streams used to define the interpolation
  corridor. If `NULL`, derived from non-`NA` cells in `flood_surface`.

## Value

A `SpatRaster` of flood depth (metres above terrain). Positive values
are flooded; `0` at stream cells; `NA` outside the corridor or where
depth is negative (terrain above flood surface).

## Details

Interpolation uses
[`terra::interpIDW()`](https://rspatial.github.io/terra/reference/interpIDW.html)
(inverse distance weighting) to propagate the flood surface from stream
cells outward. This differs from the Python VCA which uses
`scipy.interpolate.griddata` with linear interpolation — IDW is
available natively in terra and produces similar results for this
application.

The interpolation domain is limited to cells within `max_width / 2` of
the nearest stream cell to avoid extrapolating into distant terrain.

## Examples

``` r
dem <- terra::rast(system.file("testdata/dem.tif", package = "flooded"))
streams <- sf::st_read(
  system.file("testdata/streams.gpkg", package = "flooded"),
  quiet = TRUE
)
stream_r <- fl_stream_rasterize(streams, dem, field = "upstream_area_ha")
precip_r <- fl_stream_rasterize(streams, dem, field = "map_upstream")
surface <- fl_flood_surface(dem, stream_r, precip = precip_r)
depth <- fl_flood_depth(dem, surface, max_width = 2000, streams = stream_r)
terra::plot(depth, main = "Flood depth (m)")

```
