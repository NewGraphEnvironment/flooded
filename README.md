# flooded <img src="man/figures/logo.png" align="right" height="139" alt="flooded hex sticker" />

> Portable floodplain delineation from DEM and stream network.

Delineate unconfined valleys and floodplain extent using the Valley Confinement Algorithm (VCA) — combining slope thresholding, cost-distance analysis, and flood surface modelling. Built on `terra` for R-native raster processing. Bring your own DEM and streams; works anywhere.

## Installation

```r
pak::pak("NewGraphEnvironment/flooded")
```

## Quick start

```r
library(flooded)

dem <- terra::rast("dem.tif")
streams <- sf::st_read("streams.gpkg")

# full pipeline — one call
valleys <- fl_valley_confine(dem, streams, field = "upstream_area_ha")
```

See the [Valley confinement on Neexdzii Kwah](https://newgraphenvironment.github.io/flooded/articles/valley-confinement.html) vignette for a full walkthrough with bundled test data.

## Functions

| Function | Purpose |
|----------|---------|
| `fl_valley_confine()` | Full VCA pipeline (orchestrator) |
| `fl_stream_rasterize()` | Burn streams onto DEM grid |
| `fl_cost_distance()` | Slope-weighted distance from streams |
| `fl_flood_surface()` | Bankfull regression → water surface elevation |
| `fl_flood_depth()` | Interpolate surface outward, subtract DEM |
| `fl_flood_model()` | Wraps surface + depth + binary mask |
| `fl_mask()` | Generic binary mask (threshold + operator) |
| `fl_mask_distance()` | Euclidean distance corridor mask |
| `fl_patch_conn()` | Keep patches connected to streams |
| `fl_patch_rm()` | Remove patches below size threshold |
| `fl_flood_assemble()` | Union multiple floodplain layers |
| `fl_flood_trim()` | Subtract exclusion masks (roads, urban, etc.) |
| `fl_valley_poly()` | Convert binary valley raster to sf polygons |

## Bankfull regression

The flood model uses the VCA bankfull regression to estimate flood depth at stream cells:

```
bankfull_width = (upstream_area ^ 0.280) * 0.196 * (precip ^ 0.355)
bankfull_depth = bankfull_width ^ 0.607 * 0.145
flood_depth    = bankfull_depth * flood_factor
```

Both `upstream_area` (hectares) and `precip` (mean annual precipitation, mm) are important — omitting precipitation underestimates flood depth by ~4x.

## Origins

Adapted from:

- [BlueGeo](https://github.com/bluegeo/bluegeo) by Devin Cairns (MIT) — Valley Confinement Algorithm
- [USDA VCA Toolbox](https://www.fs.usda.gov/rm/boise/AWAE/projects/valley_confinement.shtml) — original method
- [bcfishpass](https://github.com/smnorris/bcfishpass) by Simon Norris (Apache 2.0) — lateral habitat assembly

See `LICENSE.note` for full attribution.

## License

MIT
