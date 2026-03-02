# Valley confinement on Neexdzii Kwah

This vignette walks through the full `flooded` pipeline on a section of
Neexdzii Kwah (Bulkley River) near Topley, BC. The test data covers ~8
km of mainstem plus tributaries (Richfield Creek, Cesford Creek, Robert
Hatch Creek) at 10 m resolution.

## Load data

``` r
library(flooded)
library(terra)
#> terra 1.8.93
library(sf)
#> Linking to GEOS 3.12.1, GDAL 3.8.4, PROJ 9.4.0; sf_use_s2() is TRUE

dem <- rast(system.file("testdata/dem.tif", package = "flooded"))
slope <- rast(system.file("testdata/slope.tif", package = "flooded"))
streams <- st_read(
  system.file("testdata/streams.gpkg", package = "flooded"),
  quiet = TRUE
)

cat("DEM:", ncol(dem), "x", nrow(dem), "pixels at", res(dem)[1], "m\n")
#> DEM: 800 x 648 pixels at 10 m
cat("Streams:", nrow(streams), "segments\n")
#> Streams: 50 segments
cat("Upstream area range:", range(streams$upstream_area_ha), "ha\n")
#> Upstream area range: 1928.765 110337.4 ha
cat("Mean annual precip range:", range(streams$map_upstream), "mm\n")
#> Mean annual precip range: 526 587 mm
```

``` r
plot(dem, main = "Elevation (m)")
plot(st_geometry(streams), add = TRUE, col = "blue", lwd = 1.5)
```

![DEM with stream network
overlay.](valley-confinement_files/figure-html/plot-dem-1.png)

DEM with stream network overlay.

## Step 1: Rasterize streams

Burn the stream network onto the DEM grid using upstream contributing
area as the cell value. This is what the VCA bankfull regression expects
— it estimates flood depth from contributing area in hectares.

``` r
stream_r <- fl_stream_rasterize(streams, dem, field = "upstream_area_ha")
```

``` r
plot(stream_r, main = "Upstream area (ha)")
```

![Rasterized streams coloured by upstream area
(ha).](valley-confinement_files/figure-html/plot-streams-1.png)

Rasterized streams coloured by upstream area (ha).

## Step 2: Precipitation

The VCA bankfull regression has a precipitation term that strongly
controls flood depth:

    bankfull_width = (upstream_area ^ 0.280) * 0.196 * (precip ^ 0.355)
    bankfull_depth = bankfull_width ^ 0.607 * 0.145
    flood_depth    = bankfull_depth * flood_factor

With `precip = 1` (the default), the precipitation term drops out and
flood depths are dramatically underestimated. For the Bulkley mainstem
(`upstream_area_ha ~ 110,000`), the difference is ~2 m vs ~8 m flood
depth.

The test data includes `map_upstream` — mean annual precipitation (mm)
from fwapg/ClimateBC, carried as a stream attribute. We rasterize it
alongside the streams to create a spatially varying precipitation
surface at stream cells.

``` r
precip_r <- fl_stream_rasterize(streams, dem, field = "map_upstream")
cat("Precip at stream cells:", range(values(precip_r), na.rm = TRUE), "mm\n")
#> Precip at stream cells: 526 587 mm
```

## Step 3: Individual mask components

The VCA combines four spatial criteria. Let’s inspect each one.

### Slope mask

Cells with slope \<= 9% (the VCA default) represent potentially flat
valley floor.

``` r
mask_slope <- fl_mask(slope, threshold = 9, operator = "<=")
cat("Gentle slope:", sum(values(mask_slope) == 1, na.rm = TRUE), "cells\n")
#> Gentle slope: 280449 cells
```

``` r
plot(mask_slope, col = c("grey90", "darkgreen"), main = "Slope <= 9%",
     legend = FALSE)
plot(st_geometry(streams), add = TRUE, col = "blue", lwd = 0.8)
```

![Slope mask: green = slope \<=
9%.](valley-confinement_files/figure-html/plot-slope-mask-1.png)

Slope mask: green = slope \<= 9%.

### Distance mask

Cells within 1000 m of a stream (half the default `max_width = 2000`).

``` r
mask_dist <- fl_mask_distance(stream_r, threshold = 1000)
cat("Within 1 km:", sum(values(mask_dist) == 1, na.rm = TRUE), "cells\n")
#> Within 1 km: 288888 cells
```

``` r
plot(mask_dist, col = c("grey90", "steelblue"), main = "Within 1 km of stream",
     legend = FALSE)
plot(st_geometry(streams), add = TRUE, col = "blue", lwd = 0.8)
```

![Distance mask: corridor within 1 km of
streams.](valley-confinement_files/figure-html/plot-dist-mask-1.png)

Distance mask: corridor within 1 km of streams.

### Cost distance

Accumulated cost (slope-weighted) distance from streams. The VCA default
threshold is 2500.

``` r
cost <- fl_cost_distance(slope, stream_r)
mask_cost <- fl_mask(cost, threshold = 2500, operator = "<")
cat("Cost < 2500:", sum(values(mask_cost) == 1, na.rm = TRUE), "cells\n")
#> Cost < 2500: 113534 cells
```

``` r
plot(cost, main = "Cost distance", range = c(0, 5000))
plot(st_geometry(streams), add = TRUE, col = "blue", lwd = 0.8)
```

![Cost distance from streams. Warm colours = high
cost.](valley-confinement_files/figure-html/plot-cost-1.png)

Cost distance from streams. Warm colours = high cost.

### Flood model

The bankfull regression estimates flood depth from upstream contributing
area and precipitation, interpolates the water surface outward from
streams, and identifies cells below the flood surface.

``` r
flood <- fl_flood_model(dem, stream_r, flood_factor = 6, precip = precip_r,
                        max_width = 2000)
cat("Flooded cells:", sum(values(flood[["flooded"]]) == 1, na.rm = TRUE), "\n")
#> Flooded cells: 62943
```

``` r
depth <- flood[["flood_depth"]]
depth[depth == 0] <- NA
plot(depth, main = "Flood depth (m)")
plot(st_geometry(streams), add = TRUE, col = "blue", lwd = 0.8)
```

![Flood model: depth above terrain
(m).](valley-confinement_files/figure-html/plot-flood-1.png)

Flood model: depth above terrain (m).

## Step 4: Full VCA pipeline

[`fl_valley_confine()`](https://newgraphenvironment.github.io/flooded/reference/fl_valley_confine.md)
chains all the above (slope + distance + cost + flood masks), applies
morphological cleanup (closing, hole filling, small patch removal,
majority filter), and returns a binary valley raster.

Note the `precip` argument — without it, flood depths are ~4x too
shallow and the resulting valley is significantly narrower.

``` r
valleys <- fl_valley_confine(
  dem, streams,
  field = "upstream_area_ha",
  slope_threshold = 9,
  max_width = 2000,
  cost_threshold = 2500,
  flood_factor = 6,
  precip = precip_r
)

n_valley <- sum(values(valleys) == 1, na.rm = TRUE)
cat("Valley cells:", n_valley, "/", ncell(valleys),
    "(", round(100 * n_valley / ncell(valleys), 1), "%)\n")
#> Valley cells: 55420 / 518400 ( 10.7 %)
```

``` r
plot(valleys, col = c("grey90", "darkgreen"),
     main = "Unconfined valleys", legend = FALSE)
plot(st_geometry(streams), add = TRUE, col = "blue", lwd = 1.2)
```

![Unconfined valleys (green) with stream
network.](valley-confinement_files/figure-html/plot-valleys-1.png)

Unconfined valleys (green) with stream network.

## Step 5: Post-processing

### Connect to streams

Keep only valley patches that touch a stream cell — removes isolated
flat areas disconnected from the network.

``` r
connected <- fl_patch_conn(valleys, stream_r)
cat("Connected valley cells:",
    sum(values(connected) == 1, na.rm = TRUE), "\n")
#> Connected valley cells: 54487
```

``` r
plot(connected, col = c("grey90", "darkgreen"),
     main = "Connected valleys", legend = FALSE)
plot(st_geometry(streams), add = TRUE, col = "blue", lwd = 1.2)
```

![Valley patches connected to
streams.](valley-confinement_files/figure-html/plot-connected-1.png)

Valley patches connected to streams.

### Trim with exclusion masks

[`fl_flood_trim()`](https://newgraphenvironment.github.io/flooded/reference/fl_flood_trim.md)
subtracts user-supplied masks. For example, you could trim by urban
areas, steep terrain, railways, or waterbodies. Here we demonstrate by
removing cells on slopes \> 5% (a stricter threshold).

``` r
steep_mask <- fl_mask(slope, threshold = 5, operator = ">")
trimmed <- fl_flood_trim(connected, steep_mask)
cat("After trimming steep cells:",
    sum(values(trimmed) == 1, na.rm = TRUE), "\n")
#> After trimming steep cells: 37694
```

### Assemble multiple layers

[`fl_flood_assemble()`](https://newgraphenvironment.github.io/flooded/reference/fl_flood_assemble.md)
unions multiple binary rasters. This is useful when combining outputs
from different flood models or data sources.

``` r
# Example: union the connected valleys with a wider flood-only mask
flooded_mask <- flood[["flooded"]]
flooded_mask <- ifel(is.na(flooded_mask), 0L, flooded_mask)
assembled <- fl_flood_assemble(connected, flooded_mask)
cat("Assembled cells:", sum(values(assembled) == 1, na.rm = TRUE), "\n")
#> Assembled cells: 64302
```

## Precipitation matters

The VCA bankfull regression includes a precipitation term
(`precip ^ 0.355`) that scales flood depth with local climate. In BC,
`map_upstream` (mean annual precipitation in mm) is available as a
stream attribute from fwapg (the Freshwater Atlas Postgres layer). For
other jurisdictions, any gridded precipitation product will work —
rasterize it to the DEM grid and pass it as the `precip` argument.

Omitting precipitation (`precip = 1`, the default) underestimates flood
depth by roughly 4x in wet climates (~500 mm MAP). This produces a
valley that is about half the width of the correct result:

``` r
valleys_no_precip <- fl_valley_confine(
  dem, streams, field = "upstream_area_ha",
  precip = 1
)

n_no <- sum(values(valleys_no_precip) == 1, na.rm = TRUE)
cat("Without precip:", n_no, "cells (",
    round(100 * n_no / ncell(dem), 1), "%)\n")
#> Without precip: 24840 cells ( 4.8 %)
cat("With precip:   ", n_valley, "cells (",
    round(100 * n_valley / ncell(dem), 1), "%)\n")
#> With precip:    55420 cells ( 10.7 %)
```

## Summary

Key tuning parameters:

| Parameter         | Default | Effect                                         |
|-------------------|---------|------------------------------------------------|
| `slope_threshold` | 9%      | Higher = more valley floor included            |
| `max_width`       | 2000 m  | Analysis corridor width                        |
| `cost_threshold`  | 2500    | Higher = valley extends further up hillslopes  |
| `flood_factor`    | 6       | Higher = deeper flood, more floodplain         |
| `precip`          | 1       | MAP in mm — critical for realistic flood depth |
| `size_threshold`  | 5000 m² | Minimum valley patch area                      |
| `hole_threshold`  | 2500 m² | Maximum hole size to fill                      |
