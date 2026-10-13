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

## Phase 3: Measure (MORR coho ff04): `measure_grid.R`, `measure_proj.R`, `measure_pin.R`, `probe_warp_kernel.R`
- [x] (a) Values on one identical 30 m grid across warp paths and stacks. GDAL/PROJ versions, pipeline and network state logged (review B2)
- [x] (b) Three grid arms under current flooded: old 35,618.0 → mid 35,658.7 → 30 m 35,671.1 ha (+0.15%), about 1,400 ha changing hands at the margins. Source cells read ×1.0027
- [x] Root cause: the PROJ datum operation (9.5.1 shift-free vs 9.8.1 via WGS 84, ~1.3 m) moved GDAL's suggested grid. Gate decision 2: **pin plus override plus recording**
- [x] Pin `pipeline` for NAD83 pairs (`dem_pipeline_nad83()`), override argument, tests (synthetic x-field, mutation-checked)
- [x] With the pin, GDAL 3.8.5's warper with terra's settings reproduces terra on 3.13.0 to 0.12 mm; the residual vs `gdalwarp` defaults is warp settings, not version
- [x] Recorded in `findings.md`; log `logs/20261013_measure_grid_morr.log`. (Issue body edit in Phase 5, once the numbers are final)

## Phase 4: Rebuild the Parsnip cache from cached inputs (review B1) — `rebuild_pars.R`
- [x] DEM 30 m on multiples of 30, 14.1 Mcell (was 20.9 Mcell at 30.54 m). ff04 40,888.2 ha (was 41,142.9), ff06 42,667.8, ff07 43,460.1. The 8 other layers and `pars_meta.rds` are unchanged (md5)
- [x] Re-derived or labelled: vignette (6.3%, #49 history kept, #67 sentence, ~14 Mcells); `methodology.md` (pre-0.7.0 labels plus a re-run line); `floodplain_interpretation.md` (pre-0.7.0 labels, 4.4%)
- [x] Rendered the vignette: no live area figures; the full-WSG map checked

## Phase 5: Docs, follow-ups, release notes
- [x] `CLAUDE.md` design-decision bullet: the grid rule and the datum pin, the PROJ cause, and comparing warps like for like (#67)
- [x] floodplains follow-up: **edited floodplains#117** instead of filing a duplicate. Cause corrected to the PROJ operation, toolchain recording widened to `terra::gdal(lib = "all")`, and the after-merge consequences listed (review S2)
- [x] Filed flooded#76: UInt32 nodata reprojected as 4294967296 (pre-existing)
- [x] #67 issue body edited: cause corrected, proposal as built, measurements
- [ ] NEWS text in the PR body for `/gh-pr-merge`: results change **and** API change (geographic `target_crs` needs `res`; new `pipeline`); minor bump

## Validation

- [ ] Tests pass
- [ ] `/code-check` clean (each commit, or once over the branch with `/code-check branch`)
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
