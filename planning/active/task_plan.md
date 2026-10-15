# Task: README: add DEM fetch, flood-factor scenarios, per-watercourse attribution and the Parsnip vignette (#81)

The core example is current (v0.7.2; `area_field` and the corrected regression), but the README covers only the core call. The functions that make flooded usable at watershed scale are not mentioned.

Reframed against soul `conventions/readme.md` (soul#416, 2026-10-15): a summary opening with no
function names, a figure of real output from committed code, a tiny example with real output,
sections in a fixed order, and nothing another file already keeps.

## Decisions (approved with the plan)

1. Capabilities go in the opening as summary sentences, not a list; #81's body edited to match.
2. Performance and Bankfull regression sections leave the README (kept in roxygen / methodology).
   The `fl_valley_confine()` roxygen timing (measured at 0.0.0.9000, `5e12c72`) is re-measured
   on the cached Parsnip DEM, threads 1 vs 12, 3 repeats each.
3. Lifecycle "experimental" badge, a pin line, "Under active development." in DESCRIPTION.
4. New Graph Environment Ltd. as `fnd`/`cph`; cffr `authors_roles = c("aut", "cre", "fnd")`
   (third-party `cph` holders are not authors); soul issue filed for the convention.

## Phase 1: Spec and inputs
- [x] Edit #81's body for the decisions above (summary not inventory, performance and
      regression out of the README, figure, `readme.md` order, the timing re-measure); add
      `fl_valley_join()`
- [x] Record README word and line counts before (body prose, and the file)
- [x] Find where the bundled `inst/testdata` and `inst/vignette-data` data come from
      (`data-raw/testdata*.R`, `wsg_vignette_data.R`). Add a `NOTICE` only if the repo
      redistributes third-party data.

## Phase 2: README figure
- [x] `data-raw/readme_figure.R`: Parsnip floodplain from the cached `inst/vignette-data/`
      (`pars_valleys.tif`, `pars.gpkg` aoi/streams/waterbodies), styled through gq
      (`floodplains`, `lake`, `streams_all`), following link's `data-raw/readme_figure.R`. It
      writes `man/figures/readme-pars.png` with an opaque background and needs no database.
- [x] Self-review the figure at its published width (~700 px) against cartography's 12 checks.
      Alt text, plus a caption saying what it shows and what is not drawn.

## Phase 3: README, DESCRIPTION, About
- [ ] Rewrite `README.md` in `readme.md` order: title, hex, badge and tagline; opening;
      figure; Installation (+ pin line); a tiny example on bundled data with output pasted
      from a real run against this tree (`load_all`); Learn more (valley-confinement, stac-dem,
      pars-floodplain, then reference); Ecosystem; Data and methods (VCA/BlueGeo/USDA,
      bcfishpass, Hall et al. regression, MRDEM-30, FWA); Citation; License (+ `LICENSE.note`).
      Keep the restoration value from "Resolution and restoration" in the opening.
- [ ] Ecosystem table: fresh, link, flooded, drift, floodplains, cd, breaks, fly, diggs. Each
      role worded as in the fresh/link READMEs where one exists, otherwise from the repo's
      About.
- [ ] DESCRIPTION `Title` and `Description` in step with the tagline and opening;
      `devtools::document()` (rebuilds `man/flooded-package.Rd`).
- [ ] `gh repo edit --description` to the same tagline.
- [ ] Authors@R: New Graph Environment Ltd. (`cph`, `fnd`).
      `update-citation-cff.yaml` passes `authors_roles = c("aut", "cre", "fnd")`.
      Regenerate `CITATION.cff` with that call and check that only Irvine and NGE are authors.
      File the soul issue (decision 4).
- [ ] Mechanical checks: every function named is exported, and every link resolves (`curl -sI`).

## Phase 4: Reference index and timing note
- [ ] `_pkgdown.yml` `reference:` sections by purpose:
  - Delineate: `fl_valley_confine`, `fl_valley_poly`
  - Get a DEM: `fl_dem_aoi`
  - Per watercourse: `fl_valley_attribute`, `fl_valley_join`
  - Scenarios and parameters: `fl_scenarios`, `fl_params`
  - Pipeline steps: the rest

  Then `pkgdown::check_pkgdown()`.
- [ ] Parsnip threads timing (decision 2); update the `fl_valley_confine()` roxygen Performance
      section; `devtools::document()`. Script and log go in the archive.

## Validation
- [ ] Tests pass; `lintr`; `pkgdown::build_site()` renders the README figure and the grouped
      reference
- [ ] `/code-check branch`, with reviewers enumerating every published claim (README,
      DESCRIPTION, About, caption) against the code path a run takes
- [ ] Word and line counts after, against the issue's aim (`writing.md`, "Measure the
      simplification")
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive`, then `/gh-pr-push`; the merge and the patch release are left to
      `/gh-pr-merge`

