# Convert a binary valley raster to polygons

Polygonizes a binary (0/1) valley raster, returning an `sf` polygon
layer. Valley cells (`1`) are dissolved into contiguous polygons;
non-valley cells are dropped. This is the natural final step after
[`fl_valley_confine()`](https://newgraphenvironment.github.io/flooded/reference/fl_valley_confine.md).

## Usage

``` r
fl_valley_poly(x, dissolve = TRUE)
```

## Arguments

- x:

  A `SpatRaster` with binary values (`0`/`1`), typically the output of
  [`fl_valley_confine()`](https://newgraphenvironment.github.io/flooded/reference/fl_valley_confine.md).

- dissolve:

  Logical. If `TRUE` (default), adjacent valley cells are dissolved into
  multipolygon features. If `FALSE`, each contiguous patch is a separate
  polygon.

## Value

An `sf` polygon object in the CRS of `x`. Contains a `valley` column
with value `1`.

## Examples

``` r
dem <- terra::rast(system.file("testdata/dem.tif", package = "flooded"))
slope <- terra::rast(system.file("testdata/slope.tif", package = "flooded"))
gentle <- fl_mask(slope, threshold = 9, operator = "<=")
poly <- fl_valley_poly(gentle)
terra::plot(dem, main = "Gentle slopes as polygons")
plot(sf::st_geometry(poly), add = TRUE, col = "#00800040", border = "darkgreen")

```
