# Plan review 1 — #67 (Plan agent, 2026-10-13)

The reviewer read task_plan.md, the issue, `R/fl_dem_aoi.R`, its tests, `data-raw/wsg_vignette_data.R`,
`vignettes/pars-floodplain.Rmd` and floodplains' `02_floodplain_model.R`, and ran the draft code
in memory. Each finding is condensed below with what was done about it.

| # | Finding | Disposition |
|---|---|---|
| B1 | Phase 4 as written re-runs the whole data-raw script: it re-pulls streams, waterbodies and context layers from the DB, so a newer bcfishpass would move the vignette for reasons unrelated to the grid. #49 rebuilt from the cached `pars.gpkg` instead. | **Accepted.** Rebuild only the DEM-dependent outputs (dem, valleys, floodplain layer) from cached `pars.gpkg` streams and waterbodies. The other layers and `pars_meta.rds` stay unchanged, checked with md5. |
| B2 | Phase 3(a) `terra::project` vs `sf::gdal_utils("warp")` differs in GDAL, PROJ (9.8.1 vs 9.5.1), interface and output type all at once. | **Accepted.** The harness compares terra default, terra `by_util = TRUE` and sf gdalwarp `-ot/-wt Float64`, reports exact and Float32 differences, and logs both PROJ versions, the pipeline and the network state. The wording becomes "GDAL/PROJ stack". |
| G1 | 3(b) old vs new mixes resolution, origin and coverage, and the baseline should be re-run under current flooded. | **Accepted.** Three arms (old GDAL-chosen 3.13.0 grid, aligned at the old 30.4306 m, aligned at 30 m), all in one session, with shared and only-in-one hectares. |
| G2 | Cropping to the template footprint reads 1.9–2.3× the source cells. Every cell it adds lies outside the buffered AOI. | **Accepted, design changed.** The crop is back to the buffered AOI's bbox in the source CRS, padded 2 cells. Template corners outside the buffer may be NA, as before #67. The "no NA rim" test became "no NA inside the buffered AOI" and was mutation-checked: a shrunken crop turns it red. |
| G3 | The rebuild invalidates Parsnip numbers in `inst/notes/methodology.md` and `floodplain_interpretation.md` as well as the vignette. "~20 Mcells" changes, and the #49 "48,603.1 → 41,142.9" sentence would absorb the grid change. | **Accepted.** Phase 4 re-derives or labels every Parsnip figure in all three files, and keeps the #49 sentence as history on the pre-#67 grid. |
| G4 | `expect_equal` default tolerance (1.5e-8 relative) is about 9 cm at y ≈ 6e6. | **Accepted.** `tolerance = 0` and `%% res == 0` checks. |
| G5 | No test of AOI CRS = target ≠ source (the floodplains shape), of same CRS with a different res, or of the online MRDEM grid. | **Accepted.** All three added. |
| G6 | The plan text describes only the geographic stop; the code also stops on any unit mismatch. `@return` was stale. | **Accepted.** Roxygen updated; plan updated. |
| O1/O2 | Measure before the rebuild; write NEWS after the notes. | **Accepted.** That is the phase order. |
| A1 | When the AOI CRS ≠ target, the bbox goes through sf's PROJ, so an edge near a multiple of `res` can snap differently on another machine. | **Accepted.** Stated in `@details`. It does not apply when the AOI is already in the target CRS (floodplains). |
| A2 | Same-CRS MRDEM crop is already on a 30 m multiple grid. | Noted. |
| A3 | "Every area shares one grid" holds only when reprojecting. | **Accepted.** NEWS and CLAUDE.md wording scoped. |
| A4 | The error quoted a longitude value that `res` cannot take. | **Accepted.** The message now gives the one degree value and says what it means east-west in metres. |
| S1 | A geographic AOI with no `target_crs` used to work and now errors: an API break. | **Accepted.** Named in NEWS / the PR body. |
| S2 | floodplains provenance (`dem_res_m`, `dem_ncell`, digest) moves, and the #110 anchor and `dem_common.tif` digest need re-anchoring. `fp_toolchain()` should record terra's GDAL/PROJ. | **Accepted.** Follow-up issue in floodplains, linked from the PR. |
| S3 | The stac-dem cache does not call `fl_dem_aoi()`. | Noted; the PR says it is unchanged. |
