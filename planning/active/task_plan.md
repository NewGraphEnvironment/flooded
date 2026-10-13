# Task: fl_dem_aoi() lets GDAL choose the output grid, so a terra/GDAL upgrade moves every floodplain (#67)

`fl_dem_aoi()` crops MRDEM-30 (EPSG:3979) with `snap = "out"` and then calls `terra::project(r_clip, target_crs$wkt)` with no template, resolution or alignment. GDAL's warper then chooses the output origin and resolution (it projects sample points along the source edges and derives an extent and a pixel size that preserve the pixel count, which is why the resolution comes out ~30.43 m rather than 30). That choice changed between GDAL 3.8.5 and 3.13.0, isolated below.

Measured 2026-10-09 on one machine for one AOI: the MORR coho network (`floodplains` `data/morr/aquatic_network.gpkg`, layer `streams_co3`), `buffer = 2000`, `target_crs = 3005`. The source is unchanged (S3 `Last-Modified` 2026-06-24).

| | published 2026-09-03 (terra 1.9.34) | 2026-10-09 (terra 1.9.50, GDAL 3.13.0) |
|---|---|---|
| xmin | 847158.237520556 | 847157.099813495 |
| ymin | 957244.209692687 | 957244.821618025 |
| res | 30.430634377 | 30.430634931 |
| ncell | 16,478,040 | 16,478,040 |

Decisions taken at the gate:
- **`res` default.** Use the source's cell size when the source and target CRS share linear units:
  MRDEM to 3005 gives exactly 30 m. For a geographic target with no `res`, **stop**. The message
  must say what to do: it computes and quotes a degree value at the AOI's latitude (e.g.
  `res = 0.00027`) and suggests a metre CRS such as EPSG:3005 for VCA work.
- **Parsnip cache.** Rebuild it in this PR and update the vignette's figures.

## Phase 1: Failing tests (tests/testthat/test-fl_dem_aoi.R)
- [x] Reprojecting the bundled 10 m DEM (EPSG:3005) to EPSG:3157 with no `res`: the res is exactly `c(10, 10)`, and the extent equals the floor/ceiling-to-10 of the buffered AOI's bbox in 3157, computed independently, at `tolerance = 0`
- [x] Explicit `res = 30`: res exactly 30, every edge `%% 30 == 0`
- [x] ~~No NA rim~~ → no NA **inside the buffered AOI** (review G2: the crop stays minimal). Mutation-checked: a shrunken crop turns it red
- [x] AOI already in target CRS ≠ source (the floodplains shape) is aligned (review G5)
- [x] Same CRS with a different `res` resamples onto an aligned grid (review G5)
- [x] Same CRS with `res = NULL` is unchanged: identical to `terra::crop(r, ..., snap = "out")`
- [x] A geographic target with no `res` errors with `res = <degrees>`; the existing 4326 tests pass `res`
- [x] `res` validation (`"\`res\` must be"`)
- [x] Online MRDEM test asserts 30 m and edges on multiples of 30 (review G5)
- [x] The new grid tests fail on the old code (res 10.0124, 24,039 NA cells, unused argument `res`)

## Phase 2: Implement (R/fl_dem_aoi.R)
- [x] `res = NULL` as the last formal
- [x] Default `res` = source cell size when `units_gdal` matches. A geographic target stops with the degree value at the AOI's latitude; any other unit mismatch stops asking for `res`
- [x] Template = buffered AOI's bbox in `target_crs`, snapped outward to multiples of `res`
- [x] Crop = buffered AOI's bbox in the source CRS + 2 source cells (review G2; the template footprint read 1.9–2.3× the bytes for cells outside the AOI)
- [x] `terra::project(r_clip, tmpl, method = "bilinear")`
- [x] Same CRS with `res` NULL or the source's: crop only, as before
- [x] Roxygen `@param res`, `@return`, `@details` (#67, PROJ caveat review A1); `devtools::document()`; no lints in the changed files; full suite

## Phase 3: Measure (MORR coho ff04) — `planning/active/measure_grid.R`
- [ ] (a) Values on one identical 30 m grid: terra default vs terra `by_util` vs sf gdalwarp (Float64). Exact and Float32 difference counts and max |diff|; both GDAL/PROJ versions, the pipeline and the PROJ network state logged (review B2)
- [ ] (b) Three arms, all under current flooded in one session: old GDAL-chosen (3.13.0) grid, aligned at the old 30.4306 m, aligned at 30 m. Hectares plus shared and only-in-one area (review G1). Source cells read, old vs new crop
- [ ] Record in `findings.md`; edit the #67 issue body; commit the log

## Phase 4: Rebuild the Parsnip cache from cached inputs (review B1)
- [ ] From the cached `pars.gpkg` streams and waterbodies (no DB): `fl_dem_aoi()` → `pars_dem.tif`, `fl_valley_confine()` ff04 → `pars_valleys.tif`, `fl_valley_poly()` → the `floodplain` layer. Confirm 30 m and alignment; other layers and `pars_meta.rds` unchanged (md5 of the exported layers)
- [ ] Re-derive or label every Parsnip figure in `vignettes/pars-floodplain.Rmd`, `inst/notes/methodology.md` and `inst/notes/floodplain_interpretation.md` (41,142.9 ha, ~20 Mcells, the ff02/04/06 cell table, 6.4%, 4.6%, 84.7%, 90.1%). Keep the #49 sentence as history on the pre-#67 grid; add the #67 change separately (review G3)
- [ ] Render the vignette; check figures and inline numbers

## Phase 5: Docs, follow-ups, release notes
- [ ] `CLAUDE.md` design-decision bullet: `fl_dem_aoi()` grid rule (#67), scoped to the reprojecting path (review A3), with measured deltas
- [ ] File a floodplains follow-up (provenance values move; re-anchor #110 / `dem_common.tif`; record terra's GDAL/PROJ) — review S2
- [ ] File a flooded issue: UInt32 sources with nodata 4294967295 warp to 4294967296 instead of NA when file-backed (pre-existing, found in Phase 2)
- [ ] NEWS / PR body: results change **and** API change (a geographic `target_crs` now needs `res`, review S1). The version bump is left to `/gh-pr-merge` (minor)

## Validation

- [ ] Tests pass
- [ ] `/code-check` clean (each commit, or once over the branch with `/code-check branch`)
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
