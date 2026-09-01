# Compute flood surface elevation at stream cells

Estimates the bankfull flood surface elevation at each stream cell using
the VCA bankfull regression, then adds the DEM elevation. The result is
the water surface elevation that will be interpolated outward by
[`fl_flood_depth()`](https://newgraphenvironment.github.io/flooded/reference/fl_flood_depth.md).

## Usage

``` r
fl_flood_surface(dem, streams, flood_factor = 6, precip = NULL)
```

## Arguments

- dem:

  A `SpatRaster` of elevation.

- streams:

  A `SpatRaster` of rasterized streams (output of
  [`fl_stream_rasterize()`](https://newgraphenvironment.github.io/flooded/reference/fl_stream_rasterize.md)).
  Cell values **must be upstream contributing area in hectares** — they
  are the drainage-area term of the bankfull regression, not a generic
  channel-size proxy. Converted to km2 internally.

- flood_factor:

  Numeric. Multiplier on bankfull depth to estimate flood depth. Default
  `6` (VCA convention).

- precip:

  A `SpatRaster` of mean annual precipitation in **millimetres**, or a
  single numeric value in mm applied uniformly. Converted to cm/yr
  internally. Default `NULL`, which drops the precipitation term.

## Value

A `SpatRaster` with flood surface elevation at stream cells and `NA`
elsewhere. Same grid as `dem`.

## Details

Bankfull regressions follow the Valley Confinement Algorithm. Hall et
al. (2007) and Nagel et al. (2014) both specify drainage area in **km2**
and mean annual precipitation in **cm/yr**, so the hectares and
millimetres callers carry are converted before the coefficients are
applied:

    area_km2       = upstream_area_ha / 100
    precip_cm      = precip_mm / 10

    bankfull_width = (area_km2 ^ 0.280) * 0.196 * (precip_cm ^ 0.355)
    bankfull_depth = bankfull_width ^ 0.607 * 0.145
    flood_depth    = bankfull_depth * flood_factor
    flood_surface  = DEM + flood_depth

When `precip = NULL` (default), the precipitation term drops out — the
multiplier is exactly `1` — and flood depth depends only on contributing
area. Supplying precipitation matters: on the bundled test data it
raises predicted depth by ~2.4x (2.366 averaged over stream cells).

The equation predicts a *fitted index*, not a surveyed channel. Hall's
regression has an R2 of 0.47, and its widths run well below independent
estimates such as bcfishpass's — 5.7 m against 31.3 m for the Bulkley.
`flood_factor` is what scales the index onto a mapped footprint.

Passing anything other than upstream area in hectares (channel width,
for instance) silently produces a plausible-looking but wrong flood
surface; see the units defect recorded in
`inst/notes/floodplain_interpretation.md`.

## Examples

``` r
dem <- terra::rast(system.file("testdata/dem.tif", package = "flooded"))
streams <- sf::st_read(
  system.file("testdata/streams.gpkg", package = "flooded"),
  quiet = TRUE
)
stream_r <- fl_stream_rasterize(streams, dem, field = "upstream_area_ha")
precip_r <- fl_stream_rasterize(streams, dem, field = "map_upstream")

# With precipitation — realistic flood surface
surface <- fl_flood_surface(dem, stream_r, flood_factor = 6, precip = precip_r)
terra::plot(surface, main = "Flood surface elevation (m)")

```
