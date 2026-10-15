# Code-check round 1: branch 81-readme-add-dem-fetch-flood-factor-scenarios

Reviewed `git diff c61cff4...34dfe0f`. A later commit, 792c8d7, landed during the review; its README change is noted at the end.
All runs were done in a scratchpad copy of the repo.

## Mechanical checks run

- README example re-run under `pkgload::load_all()` on the copy. The output matches the pasted block exactly
  (264 / 112 / 130 / 50 / 99). Valley cells 28,727 = 287.27 ha. Union of the attributed rows = 287.27 ha.
  Rows sum to 655 ha. `fl_fallback_cells` = 0.
- `data-raw/readme_figure.R` re-run on the copy gives a PNG byte-identical to the committed one (976 x 980, 3 channels, no alpha).
- The workflow's cffr call (`authors_roles = c("aut","cre","fnd")`, cffr 1.4.2) regenerates a `CITATION.cff` identical to the committed one.
  Its authors are Irvine and New Graph Environment Ltd.; no DOI.
- `R CMD build` + `R CMD check --no-tests --ignore-vignettes`: `LICENSE.note` now ships and adds no NOTE.
  The one NOTE (CITATION.cff in a non-standard place) also exists on main.
- `pkgdown::check_pkgdown()`: no problems. All 18 exports are placed.
- Licences checked against the publishers:
  - BC CKAN `package_search`: FWA Stream Network, Lakes, Wetlands and Watershed Groups are OGL-BC; BC Parks is OGL-BC;
    Railway Track Line is OGL-Canada; Indian Reserves and Band Names is OGL-Canada; the DRA records are Access Only.
  - open.canada.ca `package_show` for the MRDEM id: OGL-Canada.
  - bcfishpass `LICENSE` on GitHub: Apache 2.0 for the software, ODbL for the database, DbCL for its contents.
- terra 1.9.50 under `--vanilla`: `threads` = 16, as the terra NEWS line also says. `detectCores()` = 10.
- Every absolute URL returns 200. All Ecosystem repos are PUBLIC, and their roles match the About texts and the fresh and link READMEs.

## Claims enumerated (62)

### README

1. Tagline: OK, the same as the DESCRIPTION Title.
2. "maps floodplains and unconfined valley bottoms ... with the Valley Confinement Algorithm": OK.
3. "gentle": OK (slope <= 9%).
4. "near a stream": OK (`max_width/2` = 1,000 m).
5. "reachable from it without climbing": **FALSE** (F2).
6. "low relative to it": OK (flood mask).
7. "classifies terrain and does not simulate floods": OK. There is no discharge term anywhere.
8. "screening map, not a field-validated floodplain": OK.
9. "Floodplain that a coarse elevation model maps and 1 m lidar excludes, mostly on steep ground": **OVERREACH** (F1).
10. "is where to look for roads, rail grades, dykes or fill that may cut a floodplain off": OK. It is hedged and matches `stac-dem.Rmd`.
11. "fetches an elevation model for an area": OK (`fl_dem_aoi()`).
12. "three preset flood levels from active channel to valley bottom": OK. `flood_scenarios.csv` has ff02, ff04 and ff06.
13. "attributes one floodplain to each watercourse that shares it": OK (`fl_valley_attribute()`).
14. "carrying per-reach attributes such as fish habitat": **OVERREACH** (F3).
15. Alt text: OK, checked against the PNG.
16. Caption, "flood factor 4": OK (`wsg_vignette_data.R` passes `flood_factor = 4`).
17. Caption, "at 30 m from the MRDEM-30 elevation model": OK.
18. Caption, "lakes and wetlands included": OK (`waterbodies =`).
19. Caption, "streams of order 3 and up that bull trout can reach": OK (`streams_bt_vw`, `access IN (1,2)`, `stream_order >= 3`).
20. Caption, "those above barriers have no floodplain here": **OVERREACH** (F4).
21. Install command and pin line: OK.
22. "under active development, functions change between releases": OK.
23. "needs an elevation raster in a projected CRS with metre units": OK. Thresholds are in map units and m².
24. "stream lines that carry upstream area in hectares": OK (`area_field` is required).
25. "mean annual precipitation is optional": OK (`precip = NULL`).
26. "MRDEM-30 covers Canada, read over the internet with no credentials": OK (public S3 via `/vsicurl/`).
27. "A 6 km reach of the Bulkley River": **INACCURATE** (F5).
28. "default flood level (flood factor 6, valley bottom)": OK (`flood_factor = 6`; the ff06 label).
29. Example code and output: OK, exact match.
30. "Rows overlap ...; the whole floodplain here is 287 ha": OK (287.27 ha).
31. Learn more, valley-confinement: OK. It has step-by-step sections, "Flood factor scenarios" and "Whose floodplain is it?".
32. Learn more, stac-dem: OK.
33. Learn more, pars-floodplain ("from a fetched elevation model"): OK. The build uses `fl_dem_aoi()`.
34. Function reference link: OK.
35. to 43. Ecosystem roles (9): OK.
44. "Land cover change: fresh -> flooded -> drift": OK.
45. "USDA VCA Toolbox; code adapted from BlueGeo (Cairns, MIT) and bcfishpass (Norris, Apache 2.0)": OK. Matches `LICENSE.note` and the software part of the bcfishpass licence.
46. "Hall et al. (2007) bankfull regression ...; Nagel et al. (2014) flood-factor ranges": OK. The depth-from-width step is Knighton's; this framing is pre-existing.
47. MRDEM-30 link: OK. The CKAN title is MRDEM, CanElevation Series.
48. "In the bundled data and vignettes: FWA, bcfishpass attributes, BC lidar": **INCOMPLETE** (F8).
49. "BC lidar from the `stac-elevation-bc` catalogue": OK. `stac_dem_vignette_data.R` searches that collection.
50. Floodplain interpretation link: OK.
51. Citation line: OK.
52. License line: OK. The links were fixed in 792c8d7.

### DESCRIPTION

53. Title and Description: these carry claims 2 to 8 and 11 to 14 again, so F2 and F3 apply here too (also in `CITATION.cff` and `man/flooded-package.Rd`).
    "Ported from bcfishpass ... USDA VCA Toolbox and BlueGeo" and "Under active development." are OK.
    `fnd` for NGE Ltd. is the deliberate deferral.

### inst/NOTICE.md

54. FWA (streams, lakes, wetlands, named streams, watershed groups), OGL-BC: OK. `named_streams` is fwapg's table derived from the FWA stream network.
55. bcfishpass attributes under ODbL and DbCL: OK. Every attribute listed exists across the two stream files; `dam_dnstr_ind` is only in `pars.gpkg`.
56. `map_upstream`, ClimateBC, not confirmed: OK. fwapg's `extras/precipitation` derives it from the ClimateBC MAP raster. Tracked in #85.
57. TRIM DEM, not found in the catalogue: OK. bcfishpass `valley_confinement.py` gets it with `bcdata.get_dem` (25 m, upscaled 2.5x to 10 m). Tracked in #85.
58. MRDEM OGL-Canada, railways OGL-Canada, reserves OGL-Canada, parks OGL-BC: OK, as listed above.
59. DRA roads, Access Only: OK, accepted under #85.
60. "Data flooded produces ... are flooded's own output": **LICENCE NOTICE GAP** (F7).

### _pkgdown.yml

61. "Pipeline steps: the steps `fl_valley_confine()` runs": OK. It calls `fl_mask`, `fl_mask_distance`, `fl_cost_distance`, `fl_flood_model` and `fl_patch_rm` directly; `fl_flood_surface` and `fl_flood_depth` run through `fl_flood_model`.
    "Raster helpers ... outside `fl_valley_confine()`": OK. Nothing in `R/` calls `fl_flood_assemble`, `fl_flood_trim` or `fl_patch_conn`.

### Timing text (roxygen, two vignettes, CLAUDE.md)

62. Grid 3,749 x 3,761: OK. 8,436 segments and 664 waterbodies: OK. 83 to 122 s: OK (82.6 to 122.2). M1 Max with 10 cores: OK. terra 1.9.50 defaults to 16 threads: OK. Threads 1 and 8 overlapped: OK. The load caveat is missing (F6).

## Findings

- **[false-claim]** README.md:12-15, the claim "Floodplain that a coarse elevation model maps and 1 m lidar excludes, mostly on steep ground".
  - The only measurement behind "mostly on steep ground" is one site: `stac_meta.rds$popup_steep_share` = 0.774, 2019 1 m lidar against 25 m TRIM at the stac-dem site.
  - The README states it as a general property of any coarse model against lidar, and that includes MRDEM-30, the package default, for which nothing was measured.
  - `stac-dem.Rmd:544-546` scopes the same phrase to "the pop-ups" at that site. The repo's CLAUDE.md design note says a non-valley cell has no single cause and to "compute it or do not make it".
  - Fix: scope it to the measured site ("at one lidar site, three quarters of it sat on ground the lidar resolves as steep"), or drop "mostly on steep ground".

- **[false-claim]** README.md:10-11, DESCRIPTION (Description), CITATION.cff (abstract) and man/flooded-package.Rd, the claim "reachable from it without climbing".
  - The criterion is `fl_cost_distance()`, `terra::costDist()` over percent slope: accumulated |slope|% x metres, below `cost_threshold = 2500`. The code comment says it "accumulates friction x distance in map units".
  - So a cell 1 km from a stream across 2% ground costs 2,000 and passes after a 20 m climb.
  - Descending ground costs the same as climbing, so "climbing" names neither the property nor its direction.
  - The phrase comes from `floodplain_interpretation.md` §1 ("reachable without climbing?"), a shared ancestor and not a check.
  - Fix: "reachable from it without crossing much steep ground".

- **[false-claim]** README.md:18-19 ("carrying per-reach attributes such as fish habitat"), and DESCRIPTION, CITATION.cff and man/flooded-package.Rd ("carrying per-reach attributes onto the ground beside each reach").
  - `fl_valley_join()` joins logical columns only. `R/fl_valley_join.R:158-170` stops with "`cols` must be logical columns; not logical: ..." and defaults to logical columns.
  - Numeric or character reach attributes (channel width, gradient, a habitat class) cannot be carried.
  - Fix: "per-reach flags such as fish habitat".

- **[false-claim]** README.md:25-26, caption, the claim "so smaller streams and those above barriers have no floodplain here".
  - `streams_bt_vw` keeps `access_bt > 0`.
  - bcfishpass sets `access_bt` from `barriers_bt_dnstr`, natural barriers to bull trout only (`model/01_access/sql/load_streams_access.sql:70-75`). 0 means a natural barrier downstream; 1 or 2 means none.
  - Streams above dams and road or rail crossings are therefore modelled and do have floodplain.
  - On a README whose opening is about roads, rail grades and dykes cutting floodplain off, "barriers" reads as including those.
  - Fix: "those above natural barriers to bull trout".

- **[false-claim]** README.md:44, the claim "A 6 km reach of the Bulkley River is bundled".
  - The bundled Bulkley River line in `inst/testdata/streams.gpkg` is 5.3 km long. Its route measures run 216,610 to 221,722 m, which is 5.1 km.
  - The DEM tile is 8.0 x 6.5 km.
  - The "6 km" is inherited from the `~6km section` comment in `data-raw/testdata.R`; it was not measured.
  - Evidence: `sum(st_length(streams[streams$gnis_name == "Bulkley River", ]))` = 5,307 m.
  - Fix: "A 5 km reach".

- **[fragile]** R/fl_valley_confine.R:89-95, man/fl_valley_confine.Rd, vignettes/valley-confinement.Rmd:499-503, vignettes/pars-floodplain.Rmd:227-228, the claim "one call took 83 to 122 s ... made no difference beyond that spread".
  - `bench_threads.log` shows load averages of 6 to 16 on the 10-core machine during the runs.
  - r1, at load about 7, gave 85.6 and 88.7 s. r2, at load about 16, gave 119.5 and 122.2 s. So most of the published 40 s spread is other work on the machine, and the text does not say so.
  - A threads comparison run under core contention is also the case where extra threads cannot help.
  - Not false as worded, but the range reads as the function's own runtime variability.
  - Fix: say the machine was under other load, or cite the CPU time (108 to 134 s, similar for both settings), which is the cleaner evidence that the threads did no parallel work.

- **[false-claim, licence]** inst/NOTICE.md:28-32, the claim "The valley rasters and floodplain polygons ... are flooded's own output".
  - `pars_valleys.tif` and the `floodplain` layer were produced from bcfishpass's ODbL database: the streams were selected by `access` and `stream_order`, and the flood surface is driven by `upstream_area_ha`, `map_upstream` and `channel_width`.
  - ODbL 4.3 requires a notice on a publicly used Produced Work that its content was obtained from the database and is available under ODbL.
  - The NOTICE attributes ODbL to "the bcfishpass attributes" only, and calls these outputs flooded's own, which reads as "no third-party terms".
  - `man/figures/readme-pars.png` ships in the tarball and on the site. It is drawn from the MRDEM hillshade, FWA and bcfishpass streams, and the NOTICE does not list it.
  - Fix: one sentence saying these outputs, and the README figure, are derived from the data above and carry its attribution, including the ODbL Produced Work notice.

- **[false-claim]** README.md:111-113, the claim "In the bundled data and vignettes: the BC Freshwater Atlas, stream attributes from bcfishpass ..., and BC lidar".
  - The list reads as complete, but it omits the bundled 25 m TRIM DEM, which `inst/testdata/dem.tif` is and which the README's own example runs on, and the BC context layers (railways, reserves, parks, roads) shipped in `pars.gpkg`.
  - Fix: name the provincial 25 m DEM, or point the line at `inst/NOTICE.md` for the full set.

## Resolved during the review

- Relative README links (`NEWS.md`, `CITATION.cff`, `LICENSE.note`, `inst/NOTICE.md`) gave 404 on the pkgdown home page.
  The built `docs/index.html` linked `NEWS.html`, `CITATION.cff`, `LICENSE.note` and `inst/NOTICE.html`, and all four return 404 on the live site.
  Commit 792c8d7 made them absolute GitHub links. The remaining relative `LICENSE` link returns 200 on the live site.
