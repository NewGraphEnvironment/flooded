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

## Phase 2 — PARS floodplain showcase vignette + data-raw cache

- [ ] Create `data-raw/pars_vignette_data.R`:
  - [ ] Fetch PARS WSG boundary + streams from fwapg
  - [ ] Run `fl_dem_aoi()` against MRDEM-30 to get the PARS DEM clip
  - [ ] Run `fl_valley_confine()` end-to-end
  - [ ] Cache outputs to `inst/vignette-data/` (target <15 MB total)
- [ ] Run data-raw locally; verify cache size budget
- [ ] Create `vignettes/pars-floodplain.Rmd` mirroring `cd/vignettes/peace-fwcp.Rmd` YAML scaffold
  - [ ] Why MRDEM-30 (link to rtj doc rationale)
  - [ ] AOI definition (PARS WSG)
  - [ ] `fl_dem_aoi(aoi = streams, buffer = 2000)` — streams-as-aoi pattern
  - [ ] `fl_valley_confine()` walkthrough with PARS-tuned parameters
  - [ ] Result map via `tmap` or `mapgl` per gq registry conventions
  - [ ] Summary stats
- [ ] Confirm vignette renders via `pkgdown::build_site()`
- [ ] Existing `vignettes/stac-dem.Rmd` left untouched (LidarBC reference)

## Phase 3 — Polish + release prep

- [ ] `devtools::document()` — clean
- [ ] `lintr::lint_package()` — no new lints
- [ ] `devtools::test()` — full pass
- [ ] `devtools::check()` — no new errors/warnings/notes
- [ ] `du -sh inst/vignette-data/` under budget
- [ ] `NEWS.md` entry: new `fl_dem_aoi()`, new PARS vignette
- [ ] `DESCRIPTION` version bump `0.2.0` → `0.3.0`

## Validation

- [ ] All tests pass
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
- [ ] `/gh-pr-push` opens PR with `Fixes #34`
