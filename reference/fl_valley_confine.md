# Delineate unconfined valleys using the Valley Confinement Algorithm

Orchestrates the full VCA pipeline: slope thresholding, cost-distance
analysis, flood surface modelling, and morphological cleanup to identify
unconfined valley bottoms.

## Usage

``` r
fl_valley_confine(
  dem,
  streams,
  field = "channel_width",
  slope = NULL,
  slope_threshold = 9,
  max_width = 2000,
  cost_threshold = 2500,
  flood_factor = 6,
  precip = 1,
  size_threshold = 5000,
  hole_threshold = 2500
)
```

## Arguments

- dem:

  A `SpatRaster` of elevation.

- streams:

  An `sf` linestring object or a `SpatRaster` of rasterized streams. If
  `sf`, it is rasterized using `field`.

- field:

  Character. Column name for
  [`fl_stream_rasterize()`](https://newgraphenvironment.github.io/flooded/reference/fl_stream_rasterize.md)
  when `streams` is `sf`. Default `"channel_width"`.

- slope:

  A `SpatRaster` of percent slope. If `NULL`, derived from `dem`.

- slope_threshold:

  Numeric. Maximum percent slope for valley floor. Default `9`.

- max_width:

  Numeric. Maximum valley width in map units (metres). Default `2000`.

- cost_threshold:

  Numeric. Maximum accumulated cost distance. Default `2500`.

- flood_factor:

  Numeric. Multiplier on bankfull depth. Default `6`.

- precip:

  A `SpatRaster` or numeric scalar of precipitation. Default `1`.

- size_threshold:

  Numeric. Minimum valley patch area (m²). Default `5000`.

- hole_threshold:

  Numeric. Maximum hole area to fill (m²). Default `2500`.

## Value

A `SpatRaster` with binary values: `1` = unconfined valley, `0` =
confined / hillslope, `NA` = outside analysis extent.

## Details

The algorithm combines four criteria via intersection (AND):

1.  **Slope mask** — cells with slope \<= `slope_threshold`

2.  **Distance mask** — cells within `max_width / 2` of a stream

3.  **Cost distance mask** — cells with accumulated cost \<
    `cost_threshold`

4.  **Flood mask** — cells identified as flooded by bankfull regression

The combined mask then undergoes morphological cleanup:

- Closing filter (3x3) to bridge small gaps

- Fill small holes (\< `hole_threshold`)

- Remove small patches (\< `size_threshold`)

- Majority filter (3x3) to smooth edges

Adapted from the USDA Valley Confinement Algorithm Toolbox (BlueGeo
implementation by Devin Cairns, MIT license) and bcfishpass lateral
habitat assembly (Simon Norris, Apache 2.0).

## See also

[`fl_mask()`](https://newgraphenvironment.github.io/flooded/reference/fl_mask.md),
[`fl_cost_distance()`](https://newgraphenvironment.github.io/flooded/reference/fl_cost_distance.md),
[`fl_flood_model()`](https://newgraphenvironment.github.io/flooded/reference/fl_flood_model.md),
[`fl_patch_rm()`](https://newgraphenvironment.github.io/flooded/reference/fl_patch_rm.md)

## Examples

``` r
dem <- terra::rast(system.file("testdata/dem.tif", package = "flooded"))
streams <- sf::st_read(
  system.file("testdata/streams.gpkg", package = "flooded"),
  quiet = TRUE
)
precip_r <- fl_stream_rasterize(streams, dem, field = "map_upstream")

valleys <- fl_valley_confine(
  dem, streams,
  field = "upstream_area_ha",
  precip = precip_r
)
terra::plot(valleys, col = c("grey90", "darkgreen"), main = "Unconfined valleys")

```
