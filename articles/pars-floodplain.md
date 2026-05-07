# Watershed-scale floodplain delineation — Parsnip River Watershed Group

This vignette runs the `flooded` pipeline on the Parsnip River Watershed
Group (`PARS`, 5,597 km², north-eastern BC) and demonstrates the
AOI-driven helper
[`flooded::fl_dem_aoi()`](https://newgraphenvironment.github.io/flooded/reference/fl_dem_aoi.md).

PARS sits between Prince George and Mackenzie, BC. The Parsnip River
flows north and enters the southern arm of Williston Reservoir at
Mackenzie, joining the Peace River system. From there the drainage runs
Peace → Slave → Mackenzie River, ultimately discharging to the Arctic
Ocean via the Mackenzie Delta.

## Why floodplains

Floodplains are the low-lying, periodically inundated lands flanking a
stream — the parts of the valley that water reclaims when discharge
exceeds bankfull. They store flood water and dissipate flood energy,
recharge shallow groundwater, sort sediment, and host the off-channel
ponds, side channels, sloughs, lakes, and wetlands that drive
disproportionate ecological productivity per unit area. For salmonids in
particular, floodplain habitat — slow-water margins, beaver complexes,
off-channel rearing — is often the limiting factor for freshwater
survival, especially through winter low-flow and high-flow refugia.
Mapping the *extent* of the floodplain at watershed scale is therefore
the first step in scoping where restoration, protection, or flood-risk
planning has the most leverage.

## Modelling parameters

[`flooded::fl_valley_confine()`](https://newgraphenvironment.github.io/flooded/reference/fl_valley_confine.md)
combines four masks — slope, distance from stream, cost-distance through
the terrain, and a bankfull flood model — and applies morphological
cleanup (closing, hole-fill, patch removal) before returning a binary
valley raster. The algorithm is adapted from the [USDA Valley
Confinement Algorithm](https://github.com/Ecotrust/BlueGeo) (Nagel et
al. 2014) (BlueGeo R port by Devin Cairns, MIT) and the
[bcfishpass](https://github.com/smnorris/bcfishpass) lateral habitat
assembly (Simon Norris, Apache 2.0). The bankfull flood model follows
the regional regression of Hall et al. (2007). The parameter legend
(units, defaults, citations, ecological effect) lives in
[`flooded::fl_params()`](https://newgraphenvironment.github.io/flooded/reference/fl_params.md).

This run uses the **`ff04`** scenario from
[`flooded::fl_scenarios()`](https://newgraphenvironment.github.io/flooded/reference/fl_scenarios.md)
— *functional floodplain*, the recurrent-inundation footprint. The
active parameter values are shown in the table below.

| parameter | value | unit | effect | source |
|:---|---:|:---|:---|:---|
| flood_factor | 4 | dimensionless | Higher = deeper flood; more floodplain | (Nagel et al. 2014; Hall et al. 2007) |
| slope_threshold | 9 | percent | Higher = more valley floor included | (Nagel et al. 2014) |
| max_width | 2000 | metres | Analysis corridor width | (Nagel et al. 2014) |
| cost_threshold | 2500 | dimensionless | Higher = valley extends further up hillslopes | (Nagel et al. 2014) |

Active parameter values for the PARS run. `flood_factor = 4` (`ff04`);
other values are package defaults from
[`flooded::fl_params()`](https://newgraphenvironment.github.io/flooded/reference/fl_params.md).
{.table}

The package ships three pre-baked scenarios (table below). They differ
only in `flood_factor`; all other parameters are held constant so output
differences isolate the ecological signal.

| scenario_id | flood_factor | description | ecological_process | source |
|:---|---:|:---|:---|:---|
| ff02 | 2 | Flood-prone width / active channel margin | Rosgen flood-prone width approximating 50-yr flood stage. Captures the zone of frequent inundation and active channel migration. | (Nagel et al. 2014) |
| ff04 | 4 | Functional floodplain | Historical floodplain extent where nutrient exchange and LWD recruitment occur. Hall et al. found ff=3 best fit on 10m DEM; ff=4 compensates for 25m TRIM vertical smoothing. | (Hall et al. 2007; Nagel et al. 2014) |
| ff06 | 6 | Valley bottom extent | Full depositional zone including terraces. Nagel et al. recommended ff=5-7 for valley bottom mapping. Wider than functional floodplain — includes areas not regularly influenced by high flows. | (Nagel et al. 2014) |

Pre-baked flood-factor scenarios shipped with the package. Switch by
passing `flood_factor =` to
[`flooded::fl_valley_confine()`](https://newgraphenvironment.github.io/flooded/reference/fl_valley_confine.md).
{.table}

For a side-by-side comparison of all three scenarios on a smaller reach,
see the [valley-confinement
vignette](https://newgraphenvironment.github.io/flooded/articles/valley-confinement.html).

## Cached inputs

The vignette renders against pre-computed outputs from
`data-raw/wsg_vignette_data.R` so it builds fast and doesn’t touch the
network or database. The hydro / context layers ship as a single
multi-layer GeoPackage and the rasters as separate GeoTIFFs (raster
tiles in GPKG would lose the continuous DTM precision and the binary
valleys semantics — wrong format for analytical layers).

Direct downloads of the cached PARS bundle from the repo (open in QGIS
or any GDAL-aware tool):

- [`pars.gpkg`](https://github.com/NewGraphEnvironment/flooded/raw/main/inst/vignette-data/pars.gpkg)
  — vectors: `aoi`, `streams`, `waterbodies`, `floodplain`, `railways`,
  `roads`, `reserves`, `parks`, `named_streams`
- [`pars_dem.tif`](https://github.com/NewGraphEnvironment/flooded/raw/main/inst/vignette-data/pars_dem.tif)
  — MRDEM-30 clip (Int16)
- [`pars_valleys.tif`](https://github.com/NewGraphEnvironment/flooded/raw/main/inst/vignette-data/pars_valleys.tif)
  —
  [`fl_valley_confine()`](https://newgraphenvironment.github.io/flooded/reference/fl_valley_confine.md)
  binary output

## DEM

The underlying elevation data is
[MRDEM-30](https://open.canada.ca/data/en/dataset/18752265-bda3-498c-a4ba-9dfe68cb98da),
NRCan’s 30 m Medium-Resolution Digital Elevation Model — a single
Cloud-Optimized GeoTIFF covering all of Canada, hosted on public S3 with
no authentication required, integrated from LidarBC where lidar coverage
exists with Copernicus TanDEM-X / CDEM-derived fallback elsewhere.
[`flooded::fl_dem_aoi()`](https://newgraphenvironment.github.io/flooded/reference/fl_dem_aoi.md)
reads it via `/vsicurl/`, so the only bytes transferred are those
intersecting the AOI — bandwidth scales with the AOI, not with the COG
size.

The DEM was fetched in `data-raw/wsg_vignette_data.R` with a single
call, passing the streams as the AOI so the crop hugs the stream
corridor (a memory-efficient pattern for large watersheds with sparse
stream networks):

``` r

dem <- flooded::fl_dem_aoi(streams, buffer = 2000)
```

The default `source = NULL` resolves to the canonical MRDEM-30 DTM
`/vsicurl/` URL inside
[`flooded::fl_dem_aoi()`](https://newgraphenvironment.github.io/flooded/reference/fl_dem_aoi.md).
`buffer = 2000` extends the AOI by 2 km in metres before crop. To
override the source — e.g., to fetch a LidarBC COG — pass
`source = "/vsicurl/https://.../tile.tif"`.

## Streams and waterbodies

Streams are habitat segments modelled as accessible to bull trout from
[bcfishpass](https://github.com/smnorris/bcfishpass) outputs. bcfishpass
runs weekly on a hosted virtual machine and republishes the
`streams_bt_vw` view, so the data is current to within a week of any
upstream FWA, observation, or barrier change.

This run is built against bcfishpass v0.7.14-125-g6e9cf1c (LINEAR model,
completed 2026-05-05). The version stamp is cached at data-raw time (see
`data-raw/wsg_vignette_data.R`) so the vignette renders without touching
the database.

The streams query is a single
[`fresh::frs_db_query()`](https://newgraphenvironment.github.io/fresh/reference/frs_db_query.html)
call — every row in `bcfishpass.streams_bt_vw` is already classified
accessible (`access IN (1, 2)` = assessed or modelled), so filtering to
“best accessible habitat order 3+” needs no working-table
classification:

``` r

streams <- fresh::frs_db_query(conn, "
  SELECT segmented_stream_id, blue_line_key, waterbody_key,
         upstream_area_ha, map_upstream, channel_width, stream_order,
         gradient, mapping_code, access, spawning, rearing, geom
  FROM bcfishpass.streams_bt_vw
  WHERE watershed_group_code = 'PARS'
    AND access IN (1, 2)
    AND stream_order >= 3")
```

Waterbodies (lakes + wetlands) come from
`whse_basemapping.fwa_lakes_poly` and
`whse_basemapping.fwa_wetlands_poly` joined on `waterbody_key` — only
those physically anchored to the streams above are pulled in. They feed
`flooded::fl_valley_confine(waterbodies = ...)` so the final valley
raster fills lake / wetland cells the gradient and cost-distance masks
would otherwise carve donut holes around.

## Valley confinement

[`flooded::fl_valley_confine()`](https://newgraphenvironment.github.io/flooded/reference/fl_valley_confine.md)
runs the full VCA pipeline on the cached DEM, streams, and waterbodies.
On PARS at 30 m (~20 Mcells) it takes a couple of minutes
single-threaded; `terra::terraOptions(threads = N)` parallelises the
heavy raster ops.

``` r

valleys <- flooded::fl_valley_confine(
  dem = dem,
  streams = streams,
  field = "upstream_area_ha",
  precip = flooded::fl_stream_rasterize(streams, dem, field = "map_upstream"),
  waterbodies = waterbodies,
  flood_factor = 4   # ff04 — functional floodplain
)
floodplain <- flooded::fl_valley_poly(valleys)
```

## Floodplain map — full WSG

![PARS unconfined valleys (green) over MRDEM-30 hillshade. Parks (light
green polygon), First Nations reserves (light grey polygon, black
diamond marker at centroid + label), accessible order 3+ streams in
blue, lakes and wetlands in light blue, forest service / resource roads
grey, railways black-dashed, watershed boundary heavy
black.](pars-floodplain_files/figure-html/map-floodplain-1.png)

PARS unconfined valleys (green) over MRDEM-30 hillshade. Parks (light
green polygon), First Nations reserves (light grey polygon, black
diamond marker at centroid + label), accessible order 3+ streams in
blue, lakes and wetlands in light blue, forest service / resource roads
grey, railways black-dashed, watershed boundary heavy black.

## Detail map — south-east corner

The full-WSG view compresses a lot of detail. Cropping to the
bottom-right quadrant — the lower confluences where the trunk approaches
Williston — shows the per-reach floodplain pattern, individual channels,
lakes / wetlands, and the named First Nations reserves at full
resolution.

![South-east corner of PARS at full resolution. Parks (light green),
First Nations reserves (light grey polygon with black diamond marker +
formal english_name label at centroid), waterbodies, valleys, named
streams (italic blue labels), roads (grey), railways (black
dashed).](pars-floodplain_files/figure-html/map-detail-1.png)

South-east corner of PARS at full resolution. Parks (light green), First
Nations reserves (light grey polygon with black diamond marker + formal
english_name label at centroid), waterbodies, valleys, named streams
(italic blue labels), roads (grey), railways (black dashed).

## References

Hall, Jason E., Diane M. Holzer, and Timothy J. Beechie. 2007.
“Predicting River Floodplain and Lateral Channel Migration for Salmon
Habitat Conservation.” *Journal of the American Water Resources
Association* 43 (3): 786–97.
<https://doi.org/10.1111/j.1752-1688.2007.00063.x>.

Nagel, David E., John M. Buffington, Sharon L. Parkes, Seth Wenger, and
John R. Goode. 2014. *A Landscape Scale Valley Confinement Algorithm:
Delineating Unconfined Valley Bottoms for Geomorphic, Aquatic, and
Riparian Applications*. Gen. Tech. Rep. RMRS-GTR-321. U.S. Department of
Agriculture, Forest Service, Rocky Mountain Research Station.
<https://www.fs.usda.gov/rmrs/publications/landscape-scale-valley-confinement-algorithm-delineating-unconfined-valley-bottoms>.
