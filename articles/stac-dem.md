# Bring your own DEM via STAC

`flooded` works with any DEM — it doesn’t require a specific source.
This vignette demonstrates fetching 1 m lidar tiles from a STAC catalog
and comparing the resulting floodplain with the bundled 10 m DEM.

We use the same Neexdzii Kwah test area (Bulkley River near Topley, BC)
as the main vignette, but source the DEM from
[stac-elevation-bc](https://images.a11s.one/) — a STAC collection of BC
provincial lidar DEMs.

The 10 m runs below execute live when this page is built. The lidar
steps need the STAC endpoint and about 20 minutes of processing, so
their code is shown as you would run it, and their results come from
`data-raw/stac_dem_vignette_data.R`, last run from `flooded` 0.6.2
source (1ea1ae5) on 2026-10-08. When this page is built, the two 10 m
runs are checked against the 10 m counts that script recorded, and a
note appears beside the comparison if they differ. That check catches
changes to the 10 m pipeline; it cannot see a change that only shows at
1–5 m, or a change in the lidar itself.

## Setup

``` r

library(flooded)
#> 
#>  'Whatever you think is a permanent, lasting, eternal feature of human life — all of it will be affected by climate change.' - David Wallace-Wells
#>   source
library(terra)
#> terra 1.9.50
library(sf)
#> Linking to GEOS 3.12.1, GDAL 3.8.4, PROJ 9.4.0; sf_use_s2() is TRUE

terra::terraOptions(threads = 12)
```

The lidar steps also need `rstac` and `gdalcubes`:

``` r

library(rstac)
library(gdalcubes)
```

## What does “resampled to 10 m” mean?

The bundled test DEM is the 25 m BC TRIM DEM resampled to a 10 m grid
using bilinear interpolation. That means each original 25 m pixel gets
split into smaller 10 m pixels, with values smoothly blended from
neighbours. The grid is genuinely 10 m — each cell is 10 m × 10 m — but
the terrain detail is still 25 m quality. It’s like zooming into a
low-resolution photo: the image gets bigger but not sharper. No real
topographic detail is added.

In contrast, the 1 m lidar tiles from the STAC catalog are *natively* 1
m. They capture real features at that scale — side channels, terrace
edges, drainage ditches — that a 25 m DEM physically cannot see, no
matter how finely you resample it.

## Bundled 10 m baseline

First, load the bundled test data and run the VCA to establish a
baseline.

``` r

dem_10m <- rast(system.file("testdata/dem.tif", package = "flooded"))
slope_10m <- rast(system.file("testdata/slope.tif", package = "flooded"))
streams <- st_read(
  system.file("testdata/streams.gpkg", package = "flooded"),
  quiet = TRUE
)

precip_r <- fl_stream_rasterize(streams, dem_10m, field = "map_upstream")

valleys_10m <- fl_valley_confine(
  dem_10m, streams,
  area_field = "upstream_area_ha",
  slope = slope_10m,
  slope_threshold = 9,
  max_width = 2000,
  cost_threshold = 2500,
  flood_factor = 6,
  precip = precip_r
)

n_10m <- sum(values(valleys_10m) == 1, na.rm = TRUE)
cat("10 m DEM valley cells:", n_10m, "/", ncell(valleys_10m),
    "(", round(100 * n_10m / ncell(valleys_10m), 1), "%)\n")
#> 10 m DEM valley cells: 28727 / 518400 ( 5.5 %)
```

## Fetch 1 m lidar DEM from STAC

Query the `stac-elevation-bc` collection for tiles intersecting our test
area. We filter to 2019 tiles only (1 m lidar).

``` r

# Test area bounding box in WGS84
# terra ext() gives xmin,xmax,ymin,ymax — STAC needs xmin,ymin,xmax,ymax
dem_wgs <- project(dem_10m, "EPSG:4326")
e <- ext(dem_wgs)
bbox <- c(e$xmin, e$ymin, e$xmax, e$ymax)

# Query STAC
items <- stac("https://images.a11s.one/") |>
  stac_search(
    collections = "stac-elevation-bc",
    bbox = bbox,
    datetime = "2019-01-01T00:00:00Z/2019-12-31T23:59:59Z"
  ) |>
  post_request() |>
  items_fetch()

cat("STAC items found:", length(items$features), "\n")
for (f in items$features) cat(" ", f$id, "\n")
```

    #> STAC items found: 2
    #>   093-093l-2019-dem-bc_093l059_xli1m_utm09_2019 
    #>   093-093l-2019-dem-bc_093l049_xli1m_utm09_2019

## Mosaic and crop with gdalcubes

Use `gdalcubes` to mosaic the STAC tiles and reproject to BC Albers
(EPSG:3005), matching the test area extent. We use 5 m resolution as a
practical compromise — finer than the bundled 10 m, but fast enough for
a watershed-scale run. For production work, set `dx = 1, dy = 1` for
full 1 m resolution.

``` r

# The tiles are strip-organised GeoTIFFs (~630 MB each, no overviews).
# Reading them over /vsicurl/ is slow and can leave gdalcubes with a partial
# mosaic and no error, so download them first and point the collection at
# the local copies.
hrefs <- vapply(items$features, function(f) f$assets$dem$href, character(1))
tiles <- file.path(tempdir(), basename(hrefs))
for (i in seq_along(hrefs)) {
  if (!file.exists(tiles[i])) curl::curl_download(hrefs[i], tiles[i])
}

# Build gdalcubes image collection from STAC items
col <- stac_image_collection(
  items$features, asset_names = "dem",
  url_fun = function(u) tiles[match(u, hrefs)]
)

# Define target cube — same extent as bundled DEM, 5 m resolution
e <- ext(dem_10m)
stac_res <- 5  # use 1 for full resolution (25x more cells)
v <- cube_view(
  srs = "EPSG:3005",
  extent = list(
    left = e$xmin, right = e$xmax,
    bottom = e$ymin, top = e$ymax,
    t0 = "2019-01-01", t1 = "2019-12-31"
  ),
  dx = stac_res, dy = stac_res, dt = "P1Y",
  aggregation = "first",
  resampling = "bilinear"
)

# write_tif creates a directory with timestamped TIF(s) inside
cube <- raster_cube(col, v)
out_dir <- tempfile()
write_tif(cube, out_dir)
dem_stac_path <- list.files(out_dir, pattern = "\\.tif$", full.names = TRUE)[1]
dem_stac <- rast(dem_stac_path)

cat(stac_res, "m DEM:", ncol(dem_stac), "x", nrow(dem_stac), "pixels\n")
cat("Resolution:", res(dem_stac), "m\n")
```

    #> 5 m DEM: 1600 x 1296 pixels
    #> Resolution: 5 5 m

## Derive slope

``` r

slope_stac <- terra::terrain(dem_stac, v = "slope", unit = "degrees")
# Convert to percent slope to match flooded convention
slope_stac <- tan(slope_stac * pi / 180) * 100
```

## Run VCA on STAC DEM

``` r

# Rasterize streams onto the STAC DEM grid
precip_stac <- fl_stream_rasterize(streams, dem_stac, field = "map_upstream")

valleys_stac <- fl_valley_confine(
  dem_stac, streams,
  area_field = "upstream_area_ha",
  slope = slope_stac,
  slope_threshold = 9,
  max_width = 2000,
  cost_threshold = 2500,
  flood_factor = 6,
  precip = precip_stac
)

n_stac <- sum(values(valleys_stac) == 1, na.rm = TRUE)
cat(stac_res, "m DEM valley cells:", n_stac, "/", ncell(valleys_stac),
    "cells in the tile, no-lidar cells included (",
    round(100 * n_stac / ncell(valleys_stac), 1), "%)\n")
```

    #> 5 m DEM valley cells: 186675 / 2073600 cells in the tile, no-lidar cells included ( 9 %)

## Compare

``` r

# Resample STAC result to 10 m grid for visual comparison
valleys_stac_10 <- resample(valleys_stac, dem_10m, method = "near")
```

``` r

# Area comparison
area_10m <- n_10m * res(dem_10m)[1] * res(dem_10m)[2] / 1e6
area_stac <- sum(values(valleys_stac_10) == 1, na.rm = TRUE) *
  res(dem_10m)[1] * res(dem_10m)[2] / 1e6

cat("Valley area (bundled 10 m DEM):", round(area_10m, 2), "km²\n")
#> Valley area (bundled 10 m DEM): 2.87 km²
cat("Valley area (STAC", stac_res, "m DEM):", round(area_stac, 2), "km²\n")
#> Valley area (STAC 5 m DEM): 4.67 km²
```

The lidar maps more valley bottom than the resampled TRIM DEM. The two
mostly agree where the 10 m run finds floodplain, and the lidar adds to
it along both the tributaries and the main stem. The 2019 lidar flight
covers about 78% of the test area. The rest is upland: only 32 of the
28,727 10 m floodplain cells fall outside the lidar, so the missing
coverage has almost no effect on this comparison.

``` r

par(mfrow = c(2, 1), mar = c(2, 4, 2, 1))
plot(valleys_10m, col = c("grey90", "darkgreen"),
     main = "Bundled 10 m DEM (25 m TRIM resampled)", legend = FALSE)
plot(st_geometry(streams), add = TRUE, col = "blue", lwd = 1)

# Cells with no lidar are NA outside the channel buffer; give them their own colour so the gap does not
# read as hillslope (grey) or as page-white.
plot(valleys_stac_10, col = c("grey90", "darkgreen"), colNA = "tan",
     main = paste0("STAC lidar ", stac_res, " m DEM"), legend = FALSE)
plot(st_geometry(streams), add = TRUE, col = "blue", lwd = 1)
```

![Valley delineation from bundled 10 m DEM (top) vs STAC lidar DEM
(bottom). Green is valley, grey is not; tan in the bottom panel has no
2019 lidar, so it was not
assessed.](stac-dem_files/figure-html/plot-compare-1.png)

Valley delineation from bundled 10 m DEM (top) vs STAC lidar DEM
(bottom). Green is valley, grey is not; tan in the bottom panel has no
2019 lidar, so it was not assessed.

## Site-level zoom: 1 m lidar

At watershed scale, 5–10 m resolution is practical. But for site-level
restoration prescriptions — identifying where to excavate historic fill,
reconnect side channels, or plug drainage trenches — 1 m lidar is
essential. Those features are smeared or lost at 25 m.

Here we crop to a ~3.5 × 4 km site around Robert Hatch Creek and
Richfield Creek where they enter the Bulkley River floodplain, and run
at full 1 m resolution.

``` r

# Site extent — Robert Hatch / Richfield confluence with Bulkley
site_ext <- ext(976560, 980060, 1055808, 1059808)

# Crop streams to site
# (suppressWarnings: st_crop notes that attributes are carried over unchanged)
streams_site <- suppressWarnings(st_crop(streams, st_as_sfc(st_bbox(c(
  xmin = 976560, ymin = 1055808, xmax = 980060, ymax = 1059808
), crs = st_crs(streams)))))
```

``` r

# Fetch 1 m lidar for the site extent
site_wgs <- project(rast(site_ext, crs = "EPSG:3005"), "EPSG:4326")
se <- ext(site_wgs)
site_bbox <- c(se$xmin, se$ymin, se$xmax, se$ymax)

site_items <- stac("https://images.a11s.one/") |>
  stac_search(
    collections = "stac-elevation-bc",
    bbox = site_bbox,
    datetime = "2019-01-01T00:00:00Z/2019-12-31T23:59:59Z"
  ) |>
  post_request() |>
  items_fetch()

cat("STAC tiles for site:", length(site_items$features), "\n")

# Mosaic at 1 m. These are the same two tiles as above, already downloaded.
site_hrefs <- vapply(site_items$features, function(f) f$assets$dem$href, character(1))
site_tiles <- file.path(tempdir(), basename(site_hrefs))
for (i in seq_along(site_hrefs)) {
  if (!file.exists(site_tiles[i])) curl::curl_download(site_hrefs[i], site_tiles[i])
}
site_col <- stac_image_collection(
  site_items$features, asset_names = "dem",
  url_fun = function(u) site_tiles[match(u, site_hrefs)]
)
site_view <- cube_view(
  srs = "EPSG:3005",
  extent = list(
    left = 976560, right = 980060,
    bottom = 1055808, top = 1059808,
    t0 = "2019-01-01", t1 = "2019-12-31"
  ),
  dx = 1, dy = 1, dt = "P1Y",
  aggregation = "first",
  resampling = "bilinear"
)

site_cube <- raster_cube(site_col, site_view)
site_dir <- tempfile()
write_tif(site_cube, site_dir)
dem_1m <- rast(list.files(site_dir, "\\.tif$", full.names = TRUE)[1])

cat("1 m DEM:", ncol(dem_1m), "x", nrow(dem_1m), "pixels (",
    format(ncell(dem_1m), big.mark = ","), "cells)\n")
```

    #> STAC tiles for site: 2
    #> 1 m DEM: 3500 x 4000 pixels ( 1.4e+07 cells)

``` r

slope_1m <- terra::terrain(dem_1m, v = "slope", unit = "degrees")
slope_1m <- tan(slope_1m * pi / 180) * 100

precip_1m <- fl_stream_rasterize(streams_site, dem_1m, field = "map_upstream")

valleys_1m <- fl_valley_confine(
  dem_1m, streams_site,
  area_field = "upstream_area_ha",
  slope = slope_1m,
  slope_threshold = 9,
  max_width = 2000,
  cost_threshold = 2500,
  flood_factor = 6,
  precip = precip_1m
)

n_1m <- sum(values(valleys_1m) == 1, na.rm = TRUE)
cat("1 m DEM valley cells:", format(n_1m, big.mark = ","), "/",
    format(ncell(valleys_1m), big.mark = ","),
    "cells in the site, no-lidar cells included (",
    round(100 * n_1m / ncell(valleys_1m), 1), "%)\n")
```

    #> 1 m DEM valley cells: 3,096,003 / 1.4e+07 cells in the site, no-lidar cells included ( 22.1 %)

Run the resampled 10 m DEM over the same site for comparison:

``` r

dem_site_10m <- terra::crop(dem_10m, site_ext)
slope_site_10m <- terra::crop(slope_10m, site_ext)
precip_site_10m <- fl_stream_rasterize(streams_site, dem_site_10m, field = "map_upstream")

valleys_site_10m <- fl_valley_confine(
  dem_site_10m, streams_site,
  area_field = "upstream_area_ha",
  slope = slope_site_10m,
  slope_threshold = 9,
  max_width = 2000,
  cost_threshold = 2500,
  flood_factor = 6,
  precip = precip_site_10m
)
```

``` r

# Resample 1 m result to the 25 m (resampled to 10 m) site grid
valleys_1m_on_10m <- resample(valleys_1m, dem_site_10m, method = "near")
```

``` r

par(mfrow = c(2, 1), mar = c(2, 4, 2, 1))
plot(valleys_site_10m, col = c("grey90", "darkgreen"),
     main = "Site: 10 m (25 m TRIM resampled)", legend = FALSE)
plot(st_geometry(streams_site), add = TRUE, col = "blue", lwd = 1)

plot(valleys_1m_on_10m, col = c("grey90", "darkgreen"), colNA = "tan",
     main = "Site: 1 m native lidar", legend = FALSE)
plot(st_geometry(streams_site), add = TRUE, col = "blue", lwd = 1)
```

![Site-level comparison: resampled 10 m (top) vs native 1 m lidar
(bottom). Narrow linear breaks emerge at 1 m. Tan in the bottom panel
has no 2019 lidar.](stac-dem_files/figure-html/site-compare-1.png)

Site-level comparison: resampled 10 m (top) vs native 1 m lidar
(bottom). Narrow linear breaks emerge at 1 m. Tan in the bottom panel
has no 2019 lidar.

## Quantifying the difference

``` r

# Site floodplain area from each DEM
cell_area_m2 <- res(dem_site_10m)[1] * res(dem_site_10m)[2]  # 100 m²
fp_25m <- sum(values(valleys_site_10m) == 1, na.rm = TRUE)
fp_1m  <- sum(values(valleys_1m_on_10m) == 1, na.rm = TRUE)

# "Pop-ups": cells that are floodplain at 25 m but NOT at 1 m. Cells with no
# 1 m lidar are NA and drop out, so the share below is taken over the 25 m
# floodplain that the lidar covers.
popups <- sum(values(valleys_site_10m) == 1 & values(valleys_1m_on_10m) != 1,
              na.rm = TRUE)
fp_25m_lidar <- sum(values(valleys_site_10m) == 1 & !is.na(values(valleys_1m_on_10m)),
                    na.rm = TRUE)

# Slope of the pop-up cells as the 25 m DEM sees them
is_popup <- values(valleys_site_10m) == 1 & values(valleys_1m_on_10m) != 1
popup_slope_25m <- median(values(slope_site_10m)[is_popup], na.rm = TRUE)

# The other direction: floodplain at 1 m that the 25 m DEM misses
fp_1m_only <- sum(values(valleys_site_10m) != 1 & values(valleys_1m_on_10m) == 1,
                  na.rm = TRUE)

data.frame(
  Metric = c(
    "Floodplain area (25 m TRIM)",
    "Floodplain area (1 m lidar)",
    "Floodplain only at 25 m (pop-ups)",
    "Pop-ups as % of 25 m floodplain with 1 m lidar",
    "Floodplain found only at 1 m"
  ),
  Value = c(
    paste(round(fp_25m * cell_area_m2 / 1e4, 1), "ha"),
    paste(round(fp_1m * cell_area_m2 / 1e4, 1), "ha"),
    paste(round(popups * cell_area_m2 / 1e4, 1), "ha"),
    paste0(round(100 * popups / fp_25m_lidar, 1), "%"),
    paste(round(fp_1m_only * cell_area_m2 / 1e4, 1), "ha")
  )
) |> knitr::kable()
```

| Metric                                         | Value    |
|:-----------------------------------------------|:---------|
| Floodplain area (25 m TRIM)                    | 205.9 ha |
| Floodplain area (1 m lidar)                    | 310.3 ha |
| Floodplain only at 25 m (pop-ups)              | 19.8 ha  |
| Pop-ups as % of 25 m floodplain with 1 m lidar | 9.6%     |
| Floodplain found only at 1 m                   | 124.3 ha |

The “pop-ups” are floodplain at 25 m that the 1 m run excludes. The
table does not say why:
[`fl_valley_confine()`](https://newgraphenvironment.github.io/flooded/reference/fl_valley_confine.md)
can exclude a cell on any of its criteria — slope, distance,
cost-distance, flood depth — or in cleanup. One measurement helps. 77%
of pop-up cells sit on 1 m ground steeper than the 9% slope threshold,
against 24% across the whole 25 m floodplain. The lidar resolves the
sides of embankments, banks and terrace risers, which a 25 m pixel
smooths to below the threshold: the same cells have a median slope of 5%
on the 25 m DEM. These are the candidate barriers: roads, dykes, fill,
and other raised features that can block lateral connectivity. Some will
be natural high ground.

The difference runs in both directions. The 1 m lidar also finds
floodplain that the 25 m DEM misses entirely — low ground that a 25 m
pixel likely averages upward with the slopes around it — and at this
site that is the larger of the two. The coarse DEM does not simply
over-map the floodplain; it gets the shape wrong.

## Anthropogenic barriers to floodplain connectivity

In the site-level comparison, the 25 m TRIM DEM (resampled to a 10 m
grid but still only 25 m terrain detail) shows broad gaps in the
floodplain. The 1 m lidar fills most of them in, and reveals a different
pattern: narrow white lines cut diagonally across the green, where the
lidar resolves steep ground — the sides of a raised grade — that the 25
m DEM cannot see.

These white features are areas the VCA identifies as “not floodplain” —
pixels it excludes as too steep, or as too high above the modelled flood
surface. At 25 m resolution those features are smeared or lost, because
a single pixel averages the road embankment with the surrounding low
ground — where the 25 m DEM registers a raised grade at all, it shows a
broad gap rather than a line. At 1 m, the steep sides of a raised road
bed, railway grade, or dyke are resolved, so it stands out as a line.

**Linear white features** cutting through the floodplain are likely:

- **Roads** — raised road beds, even a metre or two of fill is enough
- **Railway grades** — often built on significant embankments
- **Dykes and levees** — flood protection berms along the river
- **Riprap and erosion protection** — armoured banks

**Irregular white patches** may be:

- **Agricultural fill** — floodplain built up over decades of farming
- **Building pads** — cleared and filled for structures
- **Natural terraces** — legitimately higher ground not connected to the
  flood surface

The implication for restoration: **the pop-ups — floodplain at 25 m that
the 1 m run excludes, mostly on steep ground — are where to look for the
anthropogenic footprint on the floodplain.** The model does not say that
a feature blocks connectivity; it says the ground there is steep, which
is what the sides of an embankment look like. Whether a given line is a
road, a dyke or a natural bank is a question for the map and the field.
Where it is a raised grade, it is a potential intervention target:
breaching or removing it, excavating historic fill back to floodplain
grade, or installing culverts and bridges could restore lateral
connectivity.

Run at 1 m, `flooded` gives more than a floodplain/not-floodplain map:
it points to **where to look** for what may be preventing floodplain
from functioning.

## Summary

### A practical workflow

Use coarse resolution (5–10 m) at watershed scale to identify candidate
floodplain sites, then zoom into specific sites at 1 m for restoration
prescriptions. The 1 m lidar reveals features that matter for
on-the-ground work: historic fill from agriculture, drainage trenches,
disconnected side channels, and terrace edges where excavation could
reconnect floodplain.

### DEM sources

The `flooded` pipeline is DEM-agnostic. Any source works:

| Source | Native resolution | Notes |
|----|----|----|
| BC Data Catalogue (WCS) | 25 m | Provincial TRIM DEM; `bcdata get-dem` (Python CLI) |
| Bundled test data | 25 m → 10 m | TRIM resampled via bilinear; `system.file("testdata/", package = "flooded")` |
| stac-elevation-bc (this vignette) | 1 m | Provincial lidar; `rstac` + `gdalcubes` |
| CDEM / SRTM | 30 m | Federal/global fallback for areas without lidar |
