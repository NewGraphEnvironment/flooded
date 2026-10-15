# Findings — README refresh (#81)

## Issue context

## Problem

The core example is current (v0.7.2; `area_field` and the corrected regression), but the README covers only the core call. The functions that make flooded usable at watershed scale are not mentioned.

## Findings

**Shipped but not in the README (underselling)**
- `fl_dem_aoi()`: fetch an elevation model for an area, MRDEM-30 by default, on a pinned grid (v0.3.0, v0.7.0 to v0.7.2)
- `fl_valley_attribute()`: floodplain per watercourse (v0.4.0, v0.6.4, v0.6.5)
- `fl_scenarios()` and `fl_params()`: the flood-factor scenario ladder (v0.2.0)
- The watershed-scale Parsnip vignette (v0.3.0)

**Stale**
- The ecosystem table (README.md:71-82) omits floodplains, cd and link
- The performance note (README.md:67, also `R/fl_valley_confine.R:97`) is an older single measurement; newer timings are in NEWS 0.6.4 and 0.6.5

## Tasks

- [ ] Add the shipped capabilities above, framed as: where the floodplain is, and where it has been cut off
- [ ] Link the Parsnip vignette
- [ ] Update the ecosystem table and the performance note
- [ ] Group the `_pkgdown.yml` reference index by purpose. It has no `reference:` sections today, so the docs site shows a flat alphabetical list.

## Context

Audited 2026-10-14 against `origin/main` @ `1ca0d12`, from README, DESCRIPTION, NEWS, NAMESPACE and vignettes. Verify each item against the code before acting. Versions cited are where a capability landed.

The New Graph website will describe this package from its README (NewGraphEnvironment/newgraphenvironment.github.io#53), so the README is the source of truth for the public one-liner. Plain language in the opening paragraph: what it does today, and what restoration planning, implementation or monitoring decision it informs.


## Inputs read at planning (2026-10-15)

- soul `conventions/readme.md` @ 46bead4 (new, soul#416) and `conventions/writing.md` @ 838a76f.
- Performance note in README:67 and `R/fl_valley_confine.R:97` dates from `5e12c72`
  (2026-03-02, Version 0.0.0.9000).
- NEWS 0.6.4/0.6.5 timings are attribution timings (`fl_valley_attribute()`), not delineation,
  so they do not replace the delineation note.
- Ecosystem roles as worded elsewhere: fresh README ("Stream network modelling engine ...",
  flooded "Delineate floodplain extents from DEMs and stream networks"); link README
  ("Intrinsic habitat models: develop, test and communicate").
- `Authors@R` has third-party `cph` (Cairns, Norris, CWF, Province) and "New Graph Environment"
  as `cph` for bcfishpass; the citation workflow calls `cff_create()` with default roles.
- Cached Parsnip data: `pars_valleys.tif` 3,749 x 3,761 at 30 m; `pars.gpkg` layers aoi,
  streams, waterbodies, railways, roads, reserves, parks, named_streams, floodplain.
- gq registry layers available: `floodplains`, `lake`, `streams_all`, `watershed_group_boundary`.

## Baseline counts (README.md at main 0.8.1, 2026-10-15)

- File: 96 lines, 582 words. Body prose (outside code fences and tables): 406 words.

## Bundled third-party data and licences (checked 2026-10-15)

- `bcdata::bcdc_search()` per layer: FWA (streams, lakes, wetlands, named streams, watershed
  groups) and BC Parks are OGL-BC; Railway Track Line and Indian Reserves and Band Names are
  OGL-Canada; both Digital Road Atlas records are **Access Only**; no catalogue record found
  for the 25 m TRIM DEM (only CDED 1:250k, OGL-BC). MRDEM-30 is OGL-Canada (open.canada.ca
  CKAN API).
- `whse_basemapping.transport_line` (DRA) ships as the `roads` layer of `pars.gpkg`
  (8,304 features). Filed as #85, with the TRIM DEM gap; NOTICE.md cites it.
- `NOTICE.md` names catalogues, not publishers: the railway record's licence is OGL-Canada
  inside the BC catalogue, so "publisher" could not be stated without a further check.
- pkgdown renders root `NOTICE.md` as `NOTICE.html`, which the workflow's page gate rejects, so
  `NOTICE` is added to its allowlist deliberately.

## Errors Encountered

| Error | Resolution |
|-------|------------|
