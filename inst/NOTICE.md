# NOTICE

flooded's code is MIT-licensed (see `LICENSE`). Code adapted from BlueGeo and bcfishpass is
attributed in `LICENSE.note`. This file covers the third-party data flooded redistributes in its
test and vignette data. Each item below is listed with the catalogue that publishes it and the licence that
catalogue gives it. Licences were checked on 2026-10-15; the stream attribute rows were revised on
2026-10-18, when the stream data moved to link's tables (#87).

## Redistributed data

| Files | Data | Catalogue | Licence |
|---|---|---|---|
| `inst/testdata/streams.gpkg`, `inst/testdata/waterbodies.gpkg`; layers `aoi`, `streams`, `waterbodies` and `named_streams` of `inst/vignette-data/pars.gpkg` | Freshwater Atlas stream, lake, wetland, named stream and watershed group geometry and identifiers | BC Data Catalogue | [Open Government Licence - British Columbia](https://www2.gov.bc.ca/gov/content/data/policy-standards/open-data/open-government-licence-bc) |
| column `upstream_area_ha` of the stream files (`inst/testdata/streams.gpkg`, layer `streams` of `inst/vignette-data/pars.gpkg`) | Upstream area, computed by [fwapg](https://github.com/smnorris/fwapg) from Freshwater Atlas watersheds | BC Data Catalogue | [Open Government Licence - British Columbia](https://www2.gov.bc.ca/gov/content/data/policy-standards/open-data/open-government-licence-bc) |
| column `map_upstream` of the same stream files | Mean annual precipitation upstream, from ClimateBC through fwapg | ClimateBC | Not yet confirmed: see [#85](https://github.com/NewGraphEnvironment/flooded/issues/85) |
| column `channel_width` of the same stream files | fwapg's channel widths: measured in fish habitat (FISS) and crossing (PSCIS) surveys, taken from Freshwater Atlas river polygons, or modelled from upstream area and ClimateBC precipitation (Thorley et al. 2021) | BC Data Catalogue; ClimateBC | Open Government Licence - British Columbia for the measured and polygon widths; the modelled widths are not yet confirmed: see [#85](https://github.com/NewGraphEnvironment/flooded/issues/85) |
| columns `access`, `spawning`, `rearing`, `mapping_code`, `gradient` and `dam_dnstr_ind` of the same stream files | Outputs of [link](https://github.com/NewGraphEnvironment/link)'s `default` configuration (link 0.66.0; runs `cypherjob3-20261017T034609.698-65b431` for the Bulkley test reach and `cypherjob2-20261017T034533.534-1b8d39` for the Parsnip, 2026-10-17, with access and mapping codes recomputed by `m1-20261017T071424.051-24a90b` and `m1-20261017T092007.555-1b04b0`), modelled over the Freshwater Atlas with fish observations, dams, and bcfishpass's barrier, crossing-status, observation and habitat-confirmation override tables | link, from the Freshwater Atlas and Known BC Fish Observations (BC Data Catalogue, Open Government Licence - British Columbia), the [Canadian Aquatic Barriers Database](https://cabd.ca/) and [bcfishpass](https://github.com/smnorris/bcfishpass) | The bcfishpass override tables are under the [Open Database License 1.0](https://opendatacommons.org/licenses/odbl/1-0/), contents under the [Database Contents License](https://opendatacommons.org/licenses/dbcl/1-0/) (bcfishpass `LICENSE`); the Canadian Aquatic Barriers Database dams are not yet confirmed: see [#85](https://github.com/NewGraphEnvironment/flooded/issues/85) |
| `inst/testdata/dem.tif`, `inst/testdata/slope.tif` | Provincial 25 m TRIM DEM, resampled to 10 m, and the slope derived from it | Served by the BC Data Catalogue's WCS; no catalogue record or licence found | Not yet confirmed: see [#85](https://github.com/NewGraphEnvironment/flooded/issues/85) |
| `inst/vignette-data/pars_dem.tif` | Medium Resolution Digital Elevation Model (MRDEM-30), CanElevation Series, Natural Resources Canada | open.canada.ca | [Open Government Licence - Canada](https://open.canada.ca/en/open-government-licence-canada) |
| layer `railways` of `inst/vignette-data/pars.gpkg` | Railway Track Line | BC Data Catalogue | [Open Government Licence - Canada](https://open.canada.ca/en/open-government-licence-canada) |
| layer `reserves` of `inst/vignette-data/pars.gpkg` | Indian Reserves and Band Names - Administrative Boundaries | BC Data Catalogue | [Open Government Licence - Canada](https://open.canada.ca/en/open-government-licence-canada) |
| layer `parks` of `inst/vignette-data/pars.gpkg` | BC Parks, Ecological Reserves, and Protected Areas | BC Data Catalogue | [Open Government Licence - British Columbia](https://www2.gov.bc.ca/gov/content/data/policy-standards/open-data/open-government-licence-bc) |
| layer `roads` of `inst/vignette-data/pars.gpkg` | Digital Road Atlas | BC Data Catalogue | Access Only: see [#85](https://github.com/NewGraphEnvironment/flooded/issues/85) |

Contains information licensed under the Open Government Licence - British Columbia, and under
the Open Government Licence - Canada. The access and habitat attributes contain information from
bcfishpass, which is made available under the Open Database License; any rights in individual
contents of the database are licensed under the Database Contents License.

## Data flooded produces

The valley rasters and floodplain polygons in `inst/vignette-data/` (`pars_valleys.tif`, layer
`floodplain` of `pars.gpkg`, `stac_valleys_*.tif`) and the README figure
(`man/figures/readme-pars.png`) are made by flooded from the data above: the streams are chosen by
link's access model and stream order, fwapg supplies the upstream area and precipitation that set
the flood surface and the channel width that sets the channel buffer. Because link's access model
applies bcfishpass's override tables, they contain information from bcfishpass, which is made
available under the Open Database License 1.0. The
`stac_valleys_*.tif` rasters were computed from BC provincial lidar and resampled to the bundled
10 m grid; the lidar itself is not redistributed. The README figure also draws a hillshade of
MRDEM-30, and the Freshwater Atlas streams selected by link's access model, with lakes, wetlands
and the watershed group boundary.
