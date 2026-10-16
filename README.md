# flooded <img src="man/figures/logo.png" align="right" height="139" alt="flooded hex sticker" />

<!-- badges: start -->
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

> Map floodplains from an elevation model and a stream network.

flooded maps floodplains from terrain: the low, gently sloping ground beside streams. It reads
terrain rather than modelling flood flows, so it runs over whole watersheds and is built for
screening and planning. On 1 m lidar it also picks out raised ground across valley floors, such as
road and rail grades, dykes and fill, that can cut a floodplain off from its river.

<img src="man/figures/readme-pars.png" alt="Map of the Parsnip River watershed group over a grey hillshade. A blue floodplain follows the Parsnip River and its larger tributaries along the valley floors, with lakes and wetlands in the south-east; the mountain slopes between them carry none." width="100%" />

*Floodplain (flood factor 4) of the Parsnip River watershed group, BC, from the 30 m MRDEM-30
elevation model, modelled on streams of order 3 and up that bull trout can reach.*

## How it works

flooded uses the Valley Confinement Algorithm, published by the US Forest Service (Nagel et al.
2014) and ported to R from BlueGeo and bcfishpass. Ground counts as floodplain where it is:

- gently sloped (9% or less by default);
- close to a stream, both in a straight line (1 km by default) and in a distance that counts
  steep ground as farther;
- below a water level set at a multiple of bankfull depth above nearby streams, with bankfull
  depth estimated from upstream area and, optionally, precipitation (Hall et al. 2007).

That multiple is the flood factor. Three presets run from the active channel (2) through the
functional floodplain (4) to the valley bottom (6). Small gaps are then filled and small patches
dropped, and lakes and wetlands can be added.

flooded can also fetch the elevation model for you, and it can say which streams each part of a
shared floodplain belongs to, carrying reach flags such as fish habitat onto the ground beside
each reach.

## Installation

```r
pak::pak("NewGraphEnvironment/flooded")
```

Functions still change between releases ([NEWS](https://github.com/NewGraphEnvironment/flooded/blob/main/NEWS.md)),
so pin a version for repeatable work: `pak::pak("NewGraphEnvironment/flooded@vX.Y.Z")`.

You need an elevation raster in metres (projected CRS) and stream lines with upstream area in
hectares. Precipitation is optional. The default elevation model, MRDEM-30, covers Canada and needs
no login.

## Example

A 5 km reach of the Bulkley River ships with the package. Its floodplain at the default flood
factor (6), by stream:

```r
library(flooded)

dem <- terra::rast(system.file("testdata/dem.tif", package = "flooded"))
streams <- sf::st_read(system.file("testdata/streams.gpkg", package = "flooded"), quiet = TRUE)

valleys <- fl_valley_confine(
  dem, streams,
  area_field = "upstream_area_ha",
  precip = fl_stream_rasterize(streams, dem, field = "map_upstream")
)

by_river <- fl_valley_attribute(valleys, streams, group = "gnis_name", dem = dem)
by_river$area_ha <- round(as.numeric(sf::st_area(by_river)) / 1e4)
sf::st_drop_geometry(by_river)[, c("gnis_name", "area_ha")]
#>            gnis_name area_ha
#> 1      Bulkley River     264
#> 2      Cesford Creek     112
#> 3    Richfield Creek     130
#> 4 Robert Hatch Creek      50
#> 5               <NA>      99
```

Floodplain shared by two streams counts toward both, so the rows add up to more than the 287 ha
total.

## Learn more

- [Valley confinement](https://newgraphenvironment.github.io/flooded/articles/valley-confinement.html):
  each step on the bundled reach, and the three flood levels.
- [Bring your own DEM via STAC](https://newgraphenvironment.github.io/flooded/articles/stac-dem.html):
  25 m provincial data against 1 m lidar.
- [Watershed-scale floodplain delineation](https://newgraphenvironment.github.io/flooded/articles/pars-floodplain.html):
  the whole Parsnip watershed group.
- [Function reference](https://newgraphenvironment.github.io/flooded/reference/).

## Ecosystem

| Package | Role |
|---------|------|
| [fresh](https://github.com/NewGraphEnvironment/fresh) | Stream network modelling engine: segment, classify, cluster, aggregate |
| [link](https://github.com/NewGraphEnvironment/link) | Intrinsic habitat models: develop, test and communicate |
| **flooded** | Delineate floodplain extents from DEMs and stream networks (this package) |
| [drift](https://github.com/NewGraphEnvironment/drift) | Track land cover change within floodplains over time |
| [floodplains](https://github.com/NewGraphEnvironment/floodplains) | Floodplain and land cover change modelling for BC watershed groups |
| [cd](https://github.com/NewGraphEnvironment/cd) | Climate departure analysis from ERA5-Land reanalysis |
| [breaks](https://github.com/NewGraphEnvironment/breaks) | Delineate sub-basins from break points on stream networks |
| [fly](https://github.com/NewGraphEnvironment/fly) | Estimate airphoto footprints and select optimal coverage for a study area |
| [diggs](https://github.com/NewGraphEnvironment/diggs) | BC Historic Airphoto Explorer (interactive Shiny app) |

Land cover change: fresh (network) &rarr; flooded (floodplains) &rarr; drift (land cover change)

## Data and methods it builds on

- Code adapted from [BlueGeo](https://github.com/bluegeo/bluegeo) (Devin Cairns, MIT) and
  [bcfishpass](https://github.com/smnorris/bcfishpass) (Simon Norris, Apache 2.0), following the
  [USDA VCA Toolbox](https://www.fs.usda.gov/rm/boise/AWAE/projects/valley_confinement.shtml).
  Parameters and flood levels: [methodology](https://github.com/NewGraphEnvironment/flooded/blob/main/inst/notes/methodology.md).
  What the output can be used to claim: [floodplain interpretation](https://github.com/NewGraphEnvironment/flooded/blob/main/inst/notes/floodplain_interpretation.md).
- NRCan's [MRDEM-30](https://open.canada.ca/data/en/dataset/18752265-bda3-498c-a4ba-9dfe68cb98da)
  elevation model.
- Bundled data: BC's 25 m TRIM DEM, the Freshwater Atlas, bcfishpass stream attributes and BC
  lidar, with licences in [`inst/NOTICE.md`](https://github.com/NewGraphEnvironment/flooded/blob/main/inst/NOTICE.md).

## Citation

Cite flooded from [`CITATION.cff`](https://github.com/NewGraphEnvironment/flooded/blob/main/CITATION.cff), or with "Cite this repository" on GitHub.

## License

MIT (see [`LICENSE`](LICENSE)). Adapted code is credited in [`LICENSE.note`](https://github.com/NewGraphEnvironment/flooded/blob/main/LICENSE.note);
data licences are in [`inst/NOTICE.md`](https://github.com/NewGraphEnvironment/flooded/blob/main/inst/NOTICE.md).
