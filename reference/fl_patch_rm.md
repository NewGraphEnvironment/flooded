# Remove small patches from a binary raster

Identifies connected patches of `1`-valued cells and removes (sets to
`0`) any patch whose area is below a size threshold.

## Usage

``` r
fl_patch_rm(x, min_area, directions = 4L)
```

## Arguments

- x:

  A `SpatRaster` with binary values (`0`/`1`).

- min_area:

  Numeric. Minimum patch area in map units squared (e.g., m²). Patches
  smaller than this are removed.

- directions:

  Integer. `4` for rook connectivity, `8` for queen. Default `4`
  (matches VCA 4-connectivity convention).

## Value

A `SpatRaster` with the same grid as `x`. Small patches are set to `0`;
all other values are unchanged.

## Examples

``` r
slope <- terra::rast(system.file("testdata/slope.tif", package = "flooded"))
gentle <- fl_mask(slope, threshold = 9, operator = "<=")

# Remove patches smaller than 5000 m²
cleaned <- fl_patch_rm(gentle, min_area = 5000)
terra::plot(cleaned, col = c("grey90", "darkgreen"), main = "Large gentle-slope patches")

```
