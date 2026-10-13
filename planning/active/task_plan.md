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
- [ ] Reprojecting the bundled 10 m DEM (EPSG:3005) to EPSG:3157 with no `res`: the result's res is exactly `c(10, 10)`. Its extent equals the floor/ceiling-to-10 of the buffered AOI's bbox in 3157, computed independently in the test.
- [ ] With an explicit `res = 30`, the res is exactly 30 and every edge is a multiple of 30.
- [ ] No NA rim: when the source covers the AOI (the bundled AOI + 100 m sits about 900 m inside `dem.tif`), the reprojected result has zero NA cells.
- [ ] Same CRS with `res = NULL` keeps today's behaviour: the result is identical to `terra::crop(r, ..., snap = "out")`.
- [ ] A geographic target with no `res` errors, and the message contains `res =` and a numeric suggestion. The existing 4326 test passes `res`.
- [ ] `res` validation: a non-numeric, length > 1 or non-positive `res` errors.
- [ ] Confirm the new grid tests fail against the current code (`r$failed > 0 | r$error`).

## Phase 2: Implement (R/fl_dem_aoi.R)
- [ ] Add `res = NULL` as the **last** formal, so positional callers still work.
- [ ] Resolve `res`. With no `res` and matching `units_gdal`, use `terra::res(r)[1]`. With no `res` and a geographic target, stop with the computed suggestion (30 m / 111,320 m per degree at the AOI centroid latitude).
- [ ] Build the template: `sf::st_bbox(sf::st_transform(aoi_buf, target_crs))`, snapped outward to multiples of `res`, then `terra::rast(e, resolution = res, crs = target_crs$wkt)`.
- [ ] Crop the source to the **template's footprint**, not `aoi_buf`: the template extent as a segmentized polygon, transformed to `r_crs`, padded by 2 source cells for bilinear sampling, with `snap = "out"`. Otherwise the template's axis-aligned corners fall outside the crop and come back NA.
- [ ] `terra::project(r_clip, tmpl, method = "bilinear")`. Bilinear is already the default; it is written out here.
- [ ] Same CRS with `res` NULL or equal to the source's: crop only, as today. Same CRS with a different `res`: take the template path.
- [ ] Roxygen: `@param res`, plus an `@details` paragraph on the fixed grid and why it exists (#67). Then `devtools::document()`, `lintr::lint_package()`, and the full `devtools::test()`.

## Phase 3: Measure the issue's two open questions (MORR, coho, ff04)
Inputs: floodplains `data/morr/aquatic_network.gpkg` (`streams_co3`, `waterbodies_co3`), `buffer = 2000`, `target_crs = 3005`, and the ff04 parameters from floodplains' `config/morr` and `02_floodplain_model.R`. The harness goes in `planning/active/` (archived with the PWF). Record CPU time and repeat any timing claim.
- [ ] (a) Do cell values differ between GDALs on an **identical** template? Compare `terra::project` (GDAL 3.13.0) with `sf::gdal_utils("warp", -te -tr -r bilinear)` (GDAL 3.8.5): count of differing cells and maximum absolute difference.
- [ ] (b) What does the fixed 30 m grid do to the delineation? Run `fl_valley_confine()` at ff04 on the old GDAL-chosen grid and on the new 30 m grid, both under the current flooded code in one session. Report hectares and % change against the issue's 35,618.0 / 35,769.1 ha.
- [ ] Record the results in `findings.md` and edit the #67 issue body with them.

## Phase 4: Rebuild the Parsnip vignette cache
- [ ] Re-run `data-raw/wsg_vignette_data.R` under `load_all()` (needs the bcfishpass DB and an MRDEM read). Confirm `pars_dem.tif` is 30 m with its origin on multiples of 30.
- [ ] Re-derive every number in `vignettes/pars-floodplain.Rmd` that comes from the cache, including 41,142.9 ha. Trace where the 6.4% ff04–ff07 span came from, and re-measure it or scope it. Add one sentence saying the cache was regenerated for the fixed grid (#67).
- [ ] Render the vignette and check that the figures and inline numbers match the new cache.

## Phase 5: Docs and release notes
- [ ] Add a `CLAUDE.md` design-decision bullet: `fl_dem_aoi()` projects onto an explicit grid aligned to multiples of `res`, never one GDAL chooses (#67, with the measured deltas).
- [ ] Write the NEWS / PR body as a **results change**: the grid moves once for every caller, with the Phase 3 numbers and the new `res` argument. The version bump is left to `/gh-pr-merge`; this is a minor bump.

## Validation

- [ ] Tests pass
- [ ] `/code-check` clean (each commit, or once over the branch with `/code-check branch`)
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
