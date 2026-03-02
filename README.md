# flooded

Portable floodplain delineation from DEM and stream network.

`flooded` extracts unconfined valleys and floodplain extent using the Valley Confinement Algorithm (VCA) — combining slope thresholding, cost-distance analysis, and flood surface modelling. Built on `terra` for R-native raster processing.

## Installation

```r
pak::pak("NewGraphEnvironment/flooded")
```

## Usage

```r
library(flooded)

# bring your own DEM and streams
dem <- terra::rast("path/to/dem.tif")
streams <- sf::st_read("path/to/streams.gpkg")

# delineate unconfined valleys
valleys <- fl_valley_confine(dem, streams)

# or use individual components
stream_rast <- fl_stream_rasterize(streams, dem, field = "contributing_area_ha")
cost <- fl_cost_distance(terra::terrain(dem, "slope", unit = "percent"), stream_rast)
flood <- fl_flood_model(dem, stream_rast)
```

## Origins

The core algorithm is adapted from:

- [BlueGeo](https://github.com/bluegeo/bluegeo) by Devin Cairns (MIT license) — Valley Confinement Algorithm implementation
- [USDA VCA Toolbox](https://www.fs.usda.gov/rm/boise/AWAE/projects/valley_confinement.shtml) — original method
- [bcfishpass](https://github.com/smnorris/bcfishpass) by Simon Norris (Apache 2.0) — lateral habitat assembly logic

See `LICENSE.note` for full attribution.
