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

## Phase 4 — plan-review fixes (2026-10-14)

- Plan review (background Plan agent) returned 1 blocker, 6 gaps; recorded with dispositions in `review-1.md`.
- B1 reproduced before fixing; its first offsets (2, 9) turned out to move the unpinnable CSRS -> WGS 84 window, not the grid. Re-searched for grid-moving offsets (1, 18); the B1 test is red on 734deb4 and green now.
- `x_field_3979(res = 30)` is really ~30.05 m (terra fits res to the extent); the independent expected result uses the fixture's own res.
- `measure_window_real_proj.R`: 0.7.0 3/60 (dx = 3.5, 21.5, 28.5), branch 0/60, under terra's PROJ 9.8.1 for unpinned sf transforms.
- Six call shapes identical, 0.7.0 vs branch, on sf PROJ 9.5.1.
- Test file: 0 failed, 0 errors on the branch; every #78 test red or erroring on 0.7.0.
