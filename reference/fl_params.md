# Load VCA parameter legend

Returns a tibble of Valley Confinement Algorithm parameters with units,
defaults, literature sources, and descriptions. The bundled CSV
documents every tuning parameter in
[`fl_valley_confine()`](https://newgraphenvironment.github.io/flooded/reference/fl_valley_confine.md)
with DEM resolution guidance from Nagel et al. (2014) and Hall et al.
(2007).

## Usage

``` r
fl_params(path = NULL)
```

## Arguments

- path:

  Character. Path to a custom parameter CSV. When `NULL` (default),
  loads the bundled `inst/extdata/flood_params.csv`.

## Value

A tibble with columns: `parameter`, `unit`, `default`, `source`,
`citation_keys`, `effect`, `description`.

## Examples

``` r
params <- fl_params()
params[, c("parameter", "unit", "default")]
#> # A tibble: 6 × 3
#>   parameter       unit          default
#>   <chr>           <chr>           <int>
#> 1 flood_factor    dimensionless       6
#> 2 slope_threshold percent             9
#> 3 max_width       metres           2000
#> 4 cost_threshold  dimensionless    2500
#> 5 size_threshold  m2               5000
#> 6 hole_threshold  m2               2500
```
