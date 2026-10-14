# Task: fl_dem_aoi(): the source read window is still transformed with PROJ's default operation (#78)

**If we do it:** `fl_dem_aoi()` returns the same DEM cells for the same AOI whichever PROJ sf links, not only whichever PROJ terra links.
**If we never do:** a PROJ upgrade on the sf side can change which edge cells of the returned DEM are `NA`, so a digest of the DEM moves with no data change. That is #67's symptom, at the edges instead of the whole grid.


## Phase 1: Tests first (red on the current code)
- [x] Bump `testthat (>= 3.1.5)` → `(>= 3.2.0)` in DESCRIPTION, for `local_mocked_bindings(.package = "sf")`
- [x] Test helper `mock_sf_datum_shift()`: mocks `sf::st_transform` so a call **with no
      `pipeline`** returns the real result shifted +1.3 m in x and y. This simulates an sf whose
      PROJ picks a datum step. Calls with a pipeline pass through unchanged.
- [x] Test: the read window does not follow sf's PROJ. Use the x-field 3979 source at 30 m and
      the hard-coded AOI offsets the probe found. First assert the shift moves a `snap = "out"`
      crop of the window at those offsets (so the test can tell if its data stops reaching the
      edge). Then `fl_dem_aoi()` with the mock must be `identical()` to `fl_dem_aoi()` without it.
- [x] Test: same, for the early-return path (target = source CRS, AOI in 3005). The crop extent
      and values must be identical with and without the mock.
- [x] Test: third-CRS AOI (EPSG:26910 NAD83 / UTM 10N → target 3005, source 3979). The grid extent
      must be identical with and without the mock.
- [x] Test: `pipeline = ""` still hands the window to PROJ, so the mock **does** change the
      result: the escape hatch stays live.
- [x] Run the new tests against the current code and record them red. Mutation check: if the
      mock does not reach `sf::st_transform` through `sf::`, the tests cannot fire, and that is
      what this run shows.

## Phase 2: Implementation (`R/fl_dem_aoi.R`)
- [x] Internal helper `dem_st_transform(x, to, pipeline, reverse = FALSE)`: return `x` if the CRS
      already matches; use plain `sf::st_transform()` when `pipeline` is `""`; otherwise transform
      to `to$wkt` with the pipeline, muffling only sf's "pipeline not found" warning (moved from
      the existing inline handler).
- [x] Resolve one operation per AOI transform:
  - read window, AOI → source CRS: `""` if the user passed `""`. Otherwise the user's pipeline
    with `reverse = TRUE` when a string was supplied and the AOI is in `target_crs`. Otherwise
    `dem_pipeline_nad83(aoi_crs, r_crs)`, which is itself `""` outside projected NAD83 pairs.
  - grid, AOI → target CRS: as now when the AOI is in the source CRS. Otherwise
    `dem_pipeline_nad83(aoi_crs, target_crs)`, unless the user passed `""`.
- [x] Move the `aoi_buf_in_r` computation onto the helper. The early-return crop and `r_clip`
      both use it.
- [x] Phase 1 tests green. The whole `test-fl_dem_aoi.R` file stays green, including the
      `pipeline = ""` expected-PROJ test.

## Phase 3: Docs and record
- [x] roxygen `@param pipeline`: a supplied string is also used, inverted, for the read window
      when the AOI is in `target_crs`. `@details`: replace the sf-PROJ caveat with the new
      behaviour, and keep the caveat for pairs outside projected NAD83. Then `devtools::document()`.
- [x] Save the probe as `planning/active/measure_window.R` and commit its log
      (`planning/active/logs/<date>_measure_window.log`)
- [x] `research/dem_reprojection.md`: a short "read window" paragraph under §2 with the measured
      3/60 and 0-inside-AOI figures. Bump the Verified line and add #78.
- [x] CLAUDE.md design-decision bullet on `fl_dem_aoi()`: one sentence saying the AOI transforms
      are pinned too (#78)

## Validation
- [ ] `devtools::test()` passes; `lintr::lint_package()` clean
- [ ] `/code-check branch` clean (three-round floor)
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive`, then `/gh-pr-push`

