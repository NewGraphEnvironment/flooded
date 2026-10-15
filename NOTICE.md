# NOTICE

flooded's code is MIT-licensed (see `LICENSE`). Code adapted from BlueGeo and bcfishpass is
attributed in `LICENSE.note`. This file covers the third-party data flooded redistributes in its
test and vignette data. Each item below is listed with the catalogue that publishes it and the licence that
catalogue gives it. Licences were checked on 2026-10-15.

## Redistributed data

| Files | Data | Catalogue | Licence |
|---|---|---|---|
| `inst/testdata/streams.gpkg`, `inst/testdata/waterbodies.gpkg`; layers `aoi`, `streams`, `waterbodies` and `named_streams` of `inst/vignette-data/pars.gpkg` | Freshwater Atlas streams, lakes, wetlands, named streams and watershed groups; the stream attributes (upstream area, upstream precipitation, channel width, fish access and habitat) come from [bcfishpass](https://github.com/smnorris/bcfishpass) | BC Data Catalogue | [Open Government Licence - British Columbia](https://www2.gov.bc.ca/gov/content/data/policy-standards/open-data/open-government-licence-bc) |
| `inst/testdata/dem.tif`, `inst/testdata/slope.tif` | Provincial 25 m TRIM DEM, resampled to 10 m, and the slope derived from it | Not found in the BC Data Catalogue | Not yet confirmed: see [#85](https://github.com/NewGraphEnvironment/flooded/issues/85) |
| `inst/vignette-data/pars_dem.tif` | Medium Resolution Digital Elevation Model (MRDEM-30), CanElevation Series, Natural Resources Canada | open.canada.ca | [Open Government Licence - Canada](https://open.canada.ca/en/open-government-licence-canada) |
| layer `railways` of `inst/vignette-data/pars.gpkg` | Railway Track Line | BC Data Catalogue | [Open Government Licence - Canada](https://open.canada.ca/en/open-government-licence-canada) |
| layer `reserves` of `inst/vignette-data/pars.gpkg` | Indian Reserves and Band Names - Administrative Boundaries | BC Data Catalogue | [Open Government Licence - Canada](https://open.canada.ca/en/open-government-licence-canada) |
| layer `parks` of `inst/vignette-data/pars.gpkg` | BC Parks, Ecological Reserves, and Protected Areas | BC Data Catalogue | [Open Government Licence - British Columbia](https://www2.gov.bc.ca/gov/content/data/policy-standards/open-data/open-government-licence-bc) |
| layer `roads` of `inst/vignette-data/pars.gpkg` | Digital Road Atlas | BC Data Catalogue | Access Only: see [#85](https://github.com/NewGraphEnvironment/flooded/issues/85) |

Contains information licensed under the Open Government Licence - British Columbia, and under
the Open Government Licence - Canada.

## Data flooded produces

The valley rasters and floodplain polygons in `inst/vignette-data/` (`pars_valleys.tif`, layer
`floodplain` of `pars.gpkg`, `stac_valleys_*.tif`) are flooded's own output. The
`stac_valleys_*.tif` rasters were computed from BC provincial lidar and resampled to the bundled
10 m grid. The lidar itself is not redistributed.
