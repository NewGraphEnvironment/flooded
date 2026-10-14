# Progress — fl_dem_aoi() read window transform (#78)

## Session 2026-10-13

- Plan-mode exploration — phases approved by user (scope widened to the third-CRS grid transform by user answer)
- Read-only probe: 3/60 sub-cell AOI offsets change the returned DEM under a 1.3 m window shift; 0 changed cells inside the buffered AOI
- Created branch `78-fl-dem-aoi-the-source-read-window-is-sti` off main
- Scaffolded PWF baseline from issue #78 with approved phases
- Next: start Phase 1

## Phase 1 — tests (2026-10-14)

- Mock `mock_sf_datum_shift()` (via `local_mocked_bindings(.package = "sf")`) verified to reach `sf::st_transform` from flooded, and to shift once (sfc results only; `st_transform.sf` re-enters the mock for its geometry).
- First offset search used a source with a different origin from the test fixture, so its offsets missed every boundary and the identity tests passed on 0.7.0: offsets are a property of the fixture grid. Re-searched on `x_field_3979(aoi, 100, res = 30)`: reproject 12,21,22,23; crop 12,21,22,23; third-CRS 8,12,18,21,22,23 (d = 0:29).
- Against 0.7.0: sensitivity test green, three identity tests red (2, 4, 4 failures), `pipeline = ""` escape hatch green.

## Phase 2 — implementation (2026-10-14)

- `dem_st_transform()` helper; read window and grid transforms pinned via `dem_pipeline_nad83(aoi_crs, ·)`, a supplied pipeline inverted (`reverse = TRUE`) for the window when the AOI is in `target_crs`, `""` hands both to PROJ.
- `test-fl_dem_aoi.R` 27/27 green. Added a supplied-pipeline identity test.
- Mutation table (scratch copy): window pin → `""` reddens the reproject and crop tests (2, 4 failures); template pin → `""` reddens the third-CRS test (4); `reverse = FALSE` errors the new supplied-pipeline test and the #67 `pipeline` test.

## Phase 3 — docs and record (2026-10-14)

- roxygen `@param pipeline` and `@details` updated; `man/` regenerated.
- `measure_window.R` + `logs/20261014_measure_window.log`: reproduces the plan-mode probe (3/60 positions; 49, 91, 47 cells; 0 inside the buffered AOI), sf PROJ 9.5.1 / terra PROJ 9.8.1.
- `research/dem_reprojection.md` §2 paragraph; CLAUDE.md `fl_dem_aoi()` bullet.
