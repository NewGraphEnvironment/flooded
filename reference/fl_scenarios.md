# Load flood factor scenarios

Returns a tibble of pre-defined flood factor scenarios for
[`fl_valley_confine()`](https://newgraphenvironment.github.io/flooded/reference/fl_valley_confine.md).
Each row is a complete parameter set that can be passed to the function.
The bundled CSV includes three scenarios spanning active channel margin
(ff=2) to full valley bottom (ff=6).

## Usage

``` r
fl_scenarios(path = NULL)
```

## Arguments

- path:

  Character. Path to a custom scenarios CSV. When `NULL` (default),
  loads the bundled `inst/extdata/flood_scenarios.csv`. Users can copy
  the default CSV, add rows for site-level work (e.g., smaller
  thresholds for 1m lidar), and pass the custom path.

## Value

A tibble with columns: `scenario_id`, `flood_factor`, `slope_threshold`,
`max_width`, `cost_threshold`, `size_threshold`, `hole_threshold`,
`run`, `description`, `ecological_process`, `citation_keys`.

## Details

The `flood_factor` is a DEM compensation parameter, not an ecological
threshold — no paper maps specific ff values to ecological processes.
The scenario descriptions are an interpretive overlay based on where
different ff values fall relative to field-validated studies:

- **ff=2**: Rosgen flood-prone width, ~50-yr flood stage

- **ff=3-4**: Historical floodplain (Hall et al. 2007 validated ff=3 on
  10m DEM against 213 field sites; ff=4 compensates for 25m DEM
  smoothing)

- **ff=5-7**: Valley bottom including terraces (Nagel et al. 2014)

DEM resolution matters: coarser DEMs need larger ff to compensate for
smoothed valley floors. At 1m lidar, ff=2-3 may suffice.

The `run` column allows consuming projects to document all scenarios but
only execute selected ones (e.g., `dplyr::filter(scenarios, run)`).

## Examples

``` r
scenarios <- fl_scenarios()
scenarios[, c("scenario_id", "flood_factor", "description")]
#> # A tibble: 3 × 3
#>   scenario_id flood_factor description                              
#>   <chr>              <int> <chr>                                    
#> 1 ff02                   2 Flood-prone width / active channel margin
#> 2 ff04                   4 Functional floodplain                    
#> 3 ff06                   6 Valley bottom extent                     

# Filter to scenarios marked for execution
to_run <- scenarios[scenarios$run, ]
```
