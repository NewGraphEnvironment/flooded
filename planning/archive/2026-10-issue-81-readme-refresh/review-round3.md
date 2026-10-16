# Code-check round 3: branch 81-readme-add-dem-fetch-flood-factor-scenarios

Reviewed `git diff c61cff4...0e86663` (HEAD). The round 2 fixes in `0e86663` were read first.
All runs used a scratchpad copy of the repo (`cp -R`, `pkgload::load_all()`). Nothing in the repo
was edited except this file.

## Enumeration (92 claims; how the list was built)

The list was built by walking every changed file in `git diff --stat c61cff4...HEAD` that
publishes text, and taking each sentence or clause in order:

- every line of `README.md`
- DESCRIPTION Title, Authors@R and Description; CITATION.cff title, abstract and authors; `man/flooded-package.Rd`
- every row and sentence of `inst/NOTICE.md`
- every section title, description and member in `_pkgdown.yml`
- the Performance roxygen in `R/fl_valley_confine.R`, and the timing passages in both vignettes
- the changed `CLAUDE.md` line
- the legend labels and comments in `data-raw/readme_figure.R`
- the cffr workflow line

Every verdict comes from code, data or a primary source, using the commands listed below.

### Mechanical runs

| check | command (scratchpad copy) | result |
|---|---|---|
| README example | `pkgload::load_all()`, then the README code verbatim | 264 / 112 / 130 / 50 / 99. Whole floodplain 287.27 ha; rows sum to 655. Exact match. |
| Criteria membership on the tile | masks rebuilt as in `fl_valley_confine.R:223-242` at defaults | 28,727 valley cells. 1,931 (6.7%) fail at least one criterion: they come from cleanup or the channel buffer. Straight-line distance binds 0 cells; cost binds 357. |
| terra `costDist` definition | `tools::Rd2txt(Rd_db("terra")[["costDist.Rd"]])` | "Distances are multiplied with the friction". With percent-slope friction (`fl_valley_confine.R:229`) that is a slope-weighted distance. |
| README figure | `Rscript data-raw/readme_figure.R`, then `cmp` against the committed PNG | **byte-identical** (980 x 976 RGB, no alpha) |
| CITATION.cff | the workflow's `cffr::cff_create(authors_roles = c("aut","cre","fnd"))` | no diff against the committed file |
| roxygen | `devtools::document()`, then `git status` | no diff (`man/` is current) |
| pkgdown index | `pkgdown::check_pkgdown()` | "No problems found". 18 exports, 18 listed. |
| Links | `curl -L` on every URL in README and NOTICE | All return 200 except the `blob/main/inst/NOTICE.md` links (404). That file exists only on the branch, so they resolve at merge. |
| Timing | `planning/active/bench_threads.log`, `bench_threads_env.txt` | Wall 82.6-122.2 s. 1-minute load average before each run 6.06-16.52. M1 Max, 10 cores, terra 1.9.50, flooded 9d852e1. `git diff 9d852e1 HEAD -- R/` has no non-roxygen line. |
| terra threads default | `terraOptions(print=FALSE)$threads`; terra NEWS | 16; "now defaults to 16 (instead of no limit)" |
| Licences | `bcdata::bcdc_get_record()` on 8 ids; `bcdc_search()`; open.canada.ca `package_show`; `gh api repos/smnorris/bcfishpass/contents/LICENSE` | listed per row below |
| bcfishpass access codes | `bcfishpass/db/schema.sql:5283-5288`, `:12566-12581` | `access_bt` 1 = naturally accessible (modelled) and 2 = naturally accessible (observed). `streams_bt_vw` is `WHERE access_bt > 0`. |
| Stream selection | `data-raw/network_extract.R:53-63`; `data-raw/wsg_vignette_data.R:101-109`; layer read | testdata: `streams_co_vw`, orders 4-6, access 1/2. Parsnip: `streams_bt_vw`, orders 3-7, access 1 (5,761) and 2 (2,675). |

### Claim table

| # | Claim | Source of truth | Verdict |
|---|---|---|---|
| **README** ||||
| 1 | Tagline "Map floodplains from an elevation model and a stream network" | `DESCRIPTION:2`, `CITATION.cff:10` | OK, all three identical |
| 2 | maps floodplains and unconfined valley bottoms ... with the VCA | `fl_valley_confine.R:222-242` | OK |
| 3 | ground that is gentle | `:223` slope <= 9 % | OK |
| 4 | near a stream in straight-line distance | `:226`, `fl_mask_distance.R:37-38` (`terra::distance`, <= 1,000 m) | OK |
| 5 | near a stream in slope-weighted distance | `:229-230`, `fl_cost_distance.R:79-80` (costDist over percent slope, < 2,500); terra doc "distances are multiplied with the friction" | OK. The new 0e86663 wording matches the code. |
| 6 | "both" (both distances are required) | `:242` mask product (AND) | OK |
| 7 | and low relative to it | `:233-239` flood mask | OK |
| 8 | "keeping ground that is ..." (all criteria together) | example run: 6.7 % of output cells fail some criterion (cleanup and channel buffer) | OK as a criteria summary. See Note 1. |
| 9 | classifies terrain, does not simulate floods | code: masks plus an IDW surface, no hydraulics | OK |
| 10 | screening map, not field-validated | no validation in the package | OK |
| 11 | STAC vignette: 25 m-only floodplain marks where to look for roads, rail grades, dykes, fill | `stac-dem.Rmd:544-549` | OK, scoped and hedged |
| 12 | "that may cut a floodplain off", "where reconnection could be planned" | `stac-dem.Rmd:546-552` | OK |
| 13 | fetches an elevation model for an area | `fl_dem_aoi()` | OK |
| 14 | three preset flood levels, active channel to valley bottom | `inst/extdata/flood_scenarios.csv` ff02 / ff04 / ff06 | OK |
| 15 | attributes one floodplain to each watercourse that shares it | `fl_valley_attribute()`; the example has overlapping rows | OK |
| 16 | per-reach flags such as fish habitat | `fl_valley_join()` takes logical cols only | OK |
| 17 | Alt text: blue floodplain on the Parsnip and larger tributaries, lakes and wetlands in the SE, none on the slopes | PNG read | OK |
| 18 | Caption: flood factor 4 | `wsg_vignette_data.R:261`; cached run | OK |
| 19 | Caption: 30 m, MRDEM-30 | `pars_dem.tif` 30 m, layer name `mrdem-30-dtm`; `wsg_vignette_data.R:239` | OK |
| 20 | Caption: lakes and wetlands included | `waterbodies =` passed, `:260` | OK |
| 21 | Caption: order 3 and up that bull trout can reach | `streams_bt_vw`, `access IN (1,2)`, orders 3-7 | OK |
| 22 | Caption: those above natural barriers have no floodplain | access 1/2 = naturally accessible (schema.sql) | OK (see Note 2) |
| 23 | Install: `pak::pak("NewGraphEnvironment/flooded")` | repo public | OK |
| 24 | Under active development; pin `@vX.Y.Z` | `git tag` v0.7.0 to v0.8.1 | OK |
| 25 | needs a projected CRS in metres | `max_width` and `cost_threshold` in map units | OK |
| 26 | stream lines with upstream area in ha | `area_field` roxygen | OK |
| 27 | precipitation optional | `precip = NULL` | OK |
| 28 | MRDEM-30 covers Canada, read over the internet with no credentials | `fl_dem_aoi.R:156-157`; `curl -sI` returns 200 with no auth; CKAN title | OK |
| 29 | A 5 km reach of the Bulkley | Bulkley lines 5,306.9 m | OK |
| 30 | default flood level ff6 = valley bottom | `formals()$flood_factor` = 6; CSV ff06 "Valley bottom extent" | OK |
| 31 | Example code and pasted output | re-run | OK, exact |
| 32 | rows overlap; whole floodplain 287 ha | 655 vs 287.27 | OK |
| 33 | Learn more: valley-confinement covers the pipeline, flood levels, "whose" | vignette headings at lines 62-421 | OK |
| 34 | Learn more: stac-dem covers the 25 m model and lidar, and the steep ground 1 m resolves, where raised grades or fill may be | `stac-dem.Rmd:494-505, 544-549`; `popup_steep_share` 0.774 | OK, hedged (the 0e86663 text) |
| 35 | Learn more: pars-floodplain covers a whole WSG from a fetched DEM | `wsg_vignette_data.R:239` | OK |
| 36 | Function reference link | 200 | OK |
| 37-45 | Ecosystem rows (9) | `gh api repos/NewGraphEnvironment/<r>` descriptions; all public | OK |
| 46 | Land cover change: fresh, then flooded, then drift | CLAUDE.md pipeline | OK |
| 47 | VCA, USDA Toolbox; BlueGeo (Cairns, MIT); bcfishpass (Norris, Apache 2.0) | `LICENSE.note`; bcfishpass LICENSE SOFTWARE section | OK |
| 48 | Hall et al. (2007) bankfull regression sets the flood-level height | `fl_flood_surface.R:23-34, 101-103` | OK |
| 49 | flood-factor ranges of Nagel et al. (2014) | `methodology.md:60`; CSV | OK |
| 50 | MRDEM-30 link, fetched by default | CKAN: "Medium Resolution Digital Elevation Model (MRDEM) - CanElevation Series" | OK |
| 51 | bundled/vignette data: 25 m TRIM, FWA, bcfishpass attributes (area, precip, width, access), lidar from `stac-elevation-bc` | layer columns; `stac_dem_vignette_data.R` | OK |
| 52 | "Every bundled dataset and its licence is listed in NOTICE" | `find inst -type f` | OK. The only other files are flooded's own CSVs and notes. |
| 53 | link to floodplain interpretation | outside the diff (accepted) | - |
| 54 | Citation line | CITATION.cff present | OK |
| 55 | License: MIT, LICENSE.note, NOTICE | DESCRIPTION, files | OK |
| **DESCRIPTION / CITATION.cff / flooded-package.Rd** ||||
| 56 | Title | = tagline | OK |
| 57 | Description clauses (= claims 2-10, 13-16) | as above | OK |
| 58 | "Ported from the bcfishpass lateral habitat pipeline (Python) with origins in USDA VCA / BlueGeo" | LICENSE.note | OK |
| 59 | cph roles, with bcfishpass holders as listed | bcfishpass LICENSE line 193-195 | OK |
| 60 | NGE Ltd. `fnd`; cffr authors Irvine and NGE Ltd. | accepted (soul#426); cffr regenerates identically | OK |
| 61 | `man/flooded-package.Rd` matches DESCRIPTION | `document()` no diff | OK |
| **inst/NOTICE.md** ||||
| 62 | code MIT; adapted code in LICENSE.note | files | OK |
| 63 | covers third-party data in test and vignette data | `find inst` | OK |
| 64 | Row FWA: OGL-BC | `bcdc_get_record`: stream network, lakes, wetlands and watershed groups all OGL-BC. `fwa_named_streams` is derived from the stream network. | OK |
| 65 | Row bcfishpass attributes (area, width, gradient, access, spawning, rearing, mapping codes, dams) | layer columns: `upstream_area_ha`, `channel_width`, `gradient`, `access`, `spawning`, `rearing`, `mapping_code`, `dam_dnstr_ind` | OK (the 0e86663 list is complete) |
| 66 | ODbL 1.0, contents under DbCL (bcfishpass LICENSE) | LICENSE lines 212-215 and 764-770 | OK |
| 67 | `map_upstream`: ClimateBC via bcfishpass, #85 | accepted | - |
| 68 | TRIM row: "Served by the BC Data Catalogue's WCS; no catalogue record or licence found" | `testdata.R:8-9` (bcfishpass BULK DEM); `bcfishpass valley_confinement.py:137-147` (`bcdata.get_dem` then 2.5x bilinear to 10 m); `bcdc_search` "digital elevation model" / "TRIM DEM" / "elevation 25m" find no 25 m DEM record | OK. The 0e86663 wording matches the provenance chain. #85 is accepted. |
| 69 | MRDEM row: OGL-Canada | CKAN `license_title` | OK |
| 70 | Railway Track Line: OGL-Canada | bcdc record | OK |
| 71 | Indian Reserves and Band Names: OGL-Canada | bcdc record | OK |
| 72 | BC Parks, Ecological Reserves, and Protected Areas: OGL-BC | bcdc record | OK |
| 73 | Digital Road Atlas: Access Only | bcdc record DRA "Access Only" | OK (#85 accepted) |
| 74 | Attribution statements (OGL-BC, OGL-Canada, ODbL/DbCL) | licence texts | OK |
| 75 | Produced data: list of produced files | `ls inst/vignette-data` | OK |
| 76 | streams chosen by bcfishpass access and stream order | `network_extract.R:53-63`, `wsg_vignette_data.R:106-109` | OK |
| 77 | area and precipitation set the flood surface | `fl_flood_surface.R:101-102` | OK |
| 78 | channel width sets the channel buffer | `fl_valley_confine.R:288-299`. Buffer active for both runs: `channel_width` is present with 0 NA in both stream files, and no `channel_buffer =` override in `wsg_vignette_data.R:256-262` or `stac_dem_vignette_data.R:39-75`. | OK (the 0e86663 text) |
| 79 | outputs contain bcfishpass information, ODbL 1.0 | as above | OK |
| 80 | `stac_valleys_*.tif` computed from lidar, resampled to the bundled 10 m grid; lidar not redistributed | `terra::res` = 10 for both | OK |
| 81 | "The README figure also draws a hillshade of MRDEM-30 and Freshwater Atlas lakes and wetlands" | `readme_figure.R:61-75` | **INCOMPLETE** (R3-2) |
| **_pkgdown.yml** ||||
| 82 | Delineate: `fl_valley_confine`, `fl_valley_poly`, `fl_stream_rasterize` | code | OK |
| 83 | Get an elevation model: `fl_dem_aoi` | code | OK |
| 84 | Per watercourse: "join per-reach flags" | `fl_valley_join.R:158-170` | OK (the 0e86663 text) |
| 85 | Pipeline steps = the steps `fl_valley_confine()` runs | `fl_valley_confine.R:223-264`; `fl_flood_model.R:34-36` calls `fl_flood_surface` and `fl_flood_depth` | OK |
| 86 | Raster helpers (union, subtract, connectivity filter) are used outside `fl_valley_confine()` | bodies; none is called by `fl_valley_confine` | OK |
| **Timing** ||||
| 87 | roxygen: grid 3,749 x 3,761 at 30 m; 8,436 segments; 664 waterbodies; `flood_factor = 4` | rasters and layers read; bench script | OK |
| 88 | roxygen, valley-confinement and pars vignettes: 83 to 122 s of wall time, M1 Max (10 cores), flooded 0.8.1, terra 1.9.50 | log 82.6-122.2; env file | OK |
| 89 | roxygen: "measured with other work on the machine (load average 6 to 16)"; CLAUDE.md "load average 6-16" | log: 1-minute load 6.06-16.52, sampled before each run | **IMPRECISE** (R3-1) |
| 90 | roxygen and valley-confinement: three runs each at threads 1 and 8 overlapped, so no effect could be separated; default 16 | log: walls {85.6, 119.5, 115.4} vs {88.7, 122.2, 82.6}; terra default 16 | OK |
| 91 | CLAUDE.md: "don't promise one without a measurement on an idle machine" | follows from 90 | OK |
| **data-raw/readme_figure.R** ||||
| 92 | Legend labels: Floodplain (flood factor 4), Lake, Wetland, "Stream, order 3+ accessible to bull trout", Parsnip River watershed group. Comments: needs no db or network; cairo writes no alpha; 20 km scale bar. | aoi `watershed_group_name` = "Parsnip River"; `file` reports RGB; the script ran offline from cache, output byte-identical; 20,000 m in EPSG:3005 | OK |

## Findings

- **[imprecise quantity; low]** `R/fl_valley_confine.R:93` (and `man/fl_valley_confine.Rd`),
  `CLAUDE.md:59`: "load average 6 to 16".
  - The log's 1-minute load averages run from 6.06 to **16.52**
    (`grep -o 'loadavg_before= [0-9.]*' planning/active/bench_threads.log`). That rounds to 17,
    so "6 to 16" truncates the top.
  - Each value was sampled *before* its run (`bench_threads.R:13`). The roxygen's "measured
    with other work on the machine (load average 6 to 16)" reads as the load *during* the
    measurement, the point round 2 made about r3.
  - The conclusion is not affected.
  - Fix: "(1-minute load average 6 to 17 before each run)". Apply the same figure in CLAUDE.md.

- **[incomplete enumeration in a licence notice; low]** `inst/NOTICE.md:36-37`: "The README
  figure also draws a hillshade of MRDEM-30 and Freshwater Atlas lakes and wetlands."
  - `data-raw/readme_figure.R:67-68` also draws the `streams` layer: FWA geometry selected by
    bcfishpass access and order.
  - `:74-75` also draws the `aoi` watershed group boundary (FWA).
  - So the "also draws" list names two of the four source layers drawn beside the floodplain.
    These are the familiar members of the set, not the set the code draws.
  - The licence substance holds. Both omitted layers are OGL-BC FWA data carried by table row 1,
    and the bcfishpass selection is covered by the ODbL sentence.
  - Fix: "... also draws a hillshade of MRDEM-30, and Freshwater Atlas streams, lakes, wetlands
    and the watershed group boundary."

No finding inside the 0e86663 fixes. Each of the following was checked against code or primary
data and holds:

- the distance clause (claims 4-6)
- the NOTICE channel-buffer sentence (77-78)
- the TRIM catalogue cell (68)
- the bcfishpass attribute list (65)
- the `_pkgdown.yml` "flags" wording (84)
- the stac-dem Learn more line (34)
- the wall-time and threads wording (88, 90)

## Notes (not findings)

1. **Claim 8.** "keeping ground that is gentle, near ..., and low" describes the four criteria.
   On the bundled tile, 1,931 of 28,727 output cells (6.7 %) fail at least one of them; cleanup
   and the channel buffer add them. With waterbodies, any supplied polygon is added too, and the
   caption says so. This is acceptable for a one-sentence summary. It matters only if the
   sentence is later read as "every output cell meets all four".
2. **Claim 22.** "smaller streams and those above natural barriers ... have no floodplain here"
   means none of their own. An unmodelled order 1-2 stream crossing the Parsnip valley floor
   still lies inside mapped floodplain. Not measured: it needs the full FWA network, which is
   not bundled.
3. The bench produced 456,075 valley cells, while the cached `pars_valleys.tif` has 454,313.
   - `wsg_vignette_data.R:239-262` runs the VCA on the float DEM returned by `fl_dem_aoi()`.
   - The bench runs it on the INT2S `pars_dem.tif` written from that DEM.
   - No published claim states either count, and the timing claim correctly names "cached inputs".
4. The `blob/main/inst/NOTICE.md` links in README return 404 until the branch merges.

/Users/airvine/Projects/repo/flooded/planning/active/review-round3.md
