# Create a binary mask from a raster by thresholding

Applies a comparison operator and threshold to a raster, returning a
binary (0/1) mask. Useful for slope masks, elevation masks, depth masks,
etc.

## Usage

``` r
fl_mask(x, threshold, operator = "<=")
```

## Arguments

- x:

  A `SpatRaster` with numeric values.

- threshold:

  Numeric scalar. The threshold value.

- operator:

  Character. One of `"<="`, `"<"`, `">="`, `">"`, `"=="`, `"!="`.
  Default `"<="`.

## Value

A `SpatRaster` with values `1` (condition met) and `0` (condition not
met). `NA` cells in `x` remain `NA`.

## Examples

``` r
slope <- terra::rast(system.file("testdata/slope.tif", package = "flooded"))
gentle <- fl_mask(slope, threshold = 9, operator = "<=")
terra::plot(gentle, col = c("grey90", "darkgreen"), main = "Slope <= 9%")

```
