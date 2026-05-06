# Task: Add DEM source helpers (file, STAC) for AOI-driven workflows (#34)

## Problem

`fl_valley_confine()` and related flooded functions accept `SpatRaster` — the
user is responsible for sourcing the DEM. Two patterns surface in real use
(manual file copy hardcoded to project paths, and an illustrative STAC vignette
that production drivers re-roll). Scaling to FWCP Peace (Pars WSG to start,
then more) means each project shouldn't have to hand-roll AOI-driven DEM fetch.

## Resolved approach

Single function — `fl_dem_aoi(aoi, source = NULL, buffer = 2000, target_crs = NULL)`
— that defaults to MRDEM-30 via `/vsicurl/` (the architecture settled in
`Projects/repo/rtj/docs/dem-sources.md`). LidarBC via STAC stays as an example
pattern in roxygen/vignettes, not a wrapper function. PARS WSG floodplain
showcase vignette is the big deliverable, built so it can port to the Peace
report appendix.

## Phase 1 — Implement `fl_dem_aoi()`

- [x] Create `R/fl_dem_aoi.R` with function body lifting `rtj/docs/dem-sources.md:50-65`
- [x] Roxygen with two examples: default MRDEM-30 fetch, and `\dontrun{}` LidarBC-via-STAC override
- [x] Update `R/flooded-package.R` if any new `@importFrom` needed
- [x] Create `tests/testthat/test-fl_dem_aoi.R`:
  - [x] File mode happy path with bundled `dem.tif`
  - [x] CRS mismatch (AOI in 4326, raster in 3005) — function transforms correctly
  - [x] `target_crs` override reprojects after crop
  - [x] MRDEM `/vsicurl/` mode gated by `skip_on_cran()` + `skip_if_offline()`
  - [x] Buffer semantics — larger buffer yields larger extent
- [x] `lintr::lint_package()` clean
- [x] `devtools::document()` regenerates NAMESPACE / man cleanly

## Phase 2 — Floodplain showcase vignette + data-raw cache

Generic data-raw script that runs for any WSG by changing one variable
(`wsg <- "PARS"`); PARS is the worked example for the vignette and the
Peace report appendix.

- [x] Create `data-raw/wsg_vignette_data.R` (generic — `wsg` parameter at top, output filenames namespaced):
  - [x] Fetch WSG boundary + streams from fwapg via `fresh::frs_*`
  - [x] Run `fl_dem_aoi()` against MRDEM-30 (streams-as-aoi pattern for tight crop)
  - [x] Drop XYZM in `fl_dem_aoi()` so fwapg streams flow through GEOS — bug fix
  - [x] Drop XYZM on streams in script before `fl_valley_confine()` (workaround pending follow-up issue)
  - [x] Run `fl_valley_confine()` end-to-end
  - [x] Cache outputs to `inst/vignette-data/` as INT2S DEM (target <15 MB total)
- [x] Run data-raw locally for PARS; cache 11 MB across 5 files
- [x] Create `vignettes/pars-floodplain.Rmd` (using `bookdown::html_vignette2` to match existing flooded style; YAML easily swappable for Peace report appendix bookdown config)
  - [x] Why MRDEM-30 (link to rtj doc rationale)
  - [x] AOI definition (PARS WSG, framed as "any WSG via the generic data-raw script")
  - [x] `fl_dem_aoi(aoi = streams, buffer = 2000)` — streams-as-aoi pattern
  - [x] `fl_valley_confine()` walkthrough
  - [x] Result map: hillshade + valleys overlay + streams + WSG boundary via terra::plot
  - [x] Summary stats: floodplain area (449 km², 8% of PARS), stream + polygon counts
- [x] Confirm vignette renders cleanly (`rmarkdown::render` produces 604 KB HTML)
- [x] Existing `vignettes/stac-dem.Rmd` left untouched (LidarBC reference)

## Phase 3 — Polish + release prep

- [x] `devtools::document()` — clean
- [x] `lintr::lint_package()` — 0 lints in new files (3 pre-existing in fl_flood_surface, fl_valley_poly, zzz; not touching adjacent code)
- [x] `devtools::test()` — 172/172 PASS including live MRDEM `/vsicurl/` fetch
- [x] `devtools::check()` — Status: OK (0 errors, 0 warnings, 0 notes) after `.Rbuildignore` updates and `vignettes/figure/` cleanup
- [x] `du -sh inst/vignette-data/` — 11 MB, under 15 MB budget
- [x] `NEWS.md` entry: `fl_dem_aoi()`, PARS vignette, generic data-raw script — all linked to #34
- [x] `DESCRIPTION` version bump `0.2.1` → `0.3.0`
- [x] `.Rbuildignore` — added `^planning$` and `^\.claude$`

## Validation

- [x] All tests pass — 172/172 PASS
- [x] `/code-check` clean on each commit (c84f301, 1304fd4, 0b62424, fd8bc98)
- [x] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
- [ ] `/gh-pr-push` opens PR with `Fixes #34`

## Follow-ups filed

- flooded#36 — Harden `fl_valley_confine()` against XYZM streams from fwapg (worked around for #34 via `sf::st_zm()` in data-raw script)
- soul (TBD) — `/planning-init` slug regex uses GNU `sed`-only `\+`; fix to `sed -E` for macOS BSD compatibility
