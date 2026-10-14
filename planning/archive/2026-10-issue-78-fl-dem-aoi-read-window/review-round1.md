# Code-check round 1 (branch 78, diff 698042e...HEAD at 8387f56)

Reviewer: general-purpose subagent. Probes ran in scratch copies (`git archive` of 698042e and HEAD
under the session scratchpad `rv1/`); the repo was not touched except for this file.

## Verified clean

- Logic in `R/fl_dem_aoi.R`, walked case by case: AOI in source / target / third CRS, with `pipeline`
  NULL, `""` and a string, early-return crop and reproject paths. The window pin is
  `dem_pipeline_nad83(aoi_crs, r_crs)`, which is the inverse of the warp pin when the AOI is in
  `target_crs`. `pipeline_arg` is captured before `pipeline` is overwritten, so B1 holds. Behaviour
  for an AOI in the source CRS is the same as in 0.7.0.
- `sf::st_transform(..., pipeline =, reverse = TRUE)`: sf 1.1.2 passes `reverse` through to
  `CPL_transform`. Its "pipeline not found" check only warns, and the helper muffles that warning.
- The mock reaches flooded's `sf::st_transform` calls. `st_transform.sf` re-enters the mock for the
  geometry, and only sfc results are shifted, so each transform is shifted once.
- `test-fl_dem_aoi.R` on the branch copy (`NOT_CRAN=true`): 29 blocks, 0 failed, 0 errors.
- Mutation `user_pipeline <- FALSE` (the supplied string is ignored for the window) turned
  "inverts a supplied pipeline" red (2 failures), so that guard fires.
- lintr: only the pre-existing single-quote lint at R/fl_dem_aoi.R:280.

## Findings

- **[severity: fragile]** tests/testthat/test-fl_dem_aoi.R:814 (`# urm5 has no inverse`), with the
  error wording at R/fl_dem_aoi.R:181-185. The test's description of the failure is wrong.
  `dem_pipeline_nad83(3979, 3005)` ends in BC Albers metres, and urm5 needs lon/lat input, so PROJ
  rejects the whole string at `proj_create` in both directions ("Mismatched units between step 2
  and 3"). The first expectation therefore exercises an *invalid* pipeline going through the
  `tryCatch` branch. It does not exercise a non-invertible one. Probed: on 0.7.0 the same call
  fails with `[project] Cannot do this transformation`. On the branch the message becomes
  "`pipeline` could not be inverted ... (OGRCreateCoordinateTransformation(): transformation not
  available)". That message tells the user to look at invertibility when the string is invalid in
  any direction, and the PROJ cause is left only in a warning. A pipeline that is valid but has no
  inverse (`+proj=pipeline +step +inv +proj=lcc <3979 params> +step +proj=urm5 ...`) behaves
  differently: forward it returns finite coordinates, and with `reverse = TRUE` it returns NaN, so
  it takes the non-finite branch. The test does cover both code branches (the `to_degrees` case
  covers non-finite), so it is not dead. What is false is the comment, and the error text for the
  invalid-string case.
  Fix: correct the comment, or use the valid non-invertible string above. Optionally word the
  `tryCatch` message as "could not be applied (inverted) ...".

- **[severity: fragile, doc]** research/dem_reprojection.md, new paragraph "Measured against the
  fix", last sentence: "A WGS 84 source still leaves the read window to sf's PROJ (CSRS or NAD83 to
  WGS 84 has no pin); the grid is pinned there." This is true only for a NAD83 projected AOI in a
  third CRS. With the AOI in the WGS 84 source's own CRS, `aoi_crs == r_crs`, so the grid transform
  uses the resolved `dem_pipeline_nad83(32610, 3005)`. That is `""`, so the grid follows sf's PROJ.
  Probed: AOI in EPSG:32610 with a 32610 x-field source and target 3005, offsets 0:29; under the
  +1.3 m mock the grid extent moved at 3 of 30. With the AOI in `target_crs` there is no grid
  transform at all. This is the accepted "non-NAD83 pair left to PROJ" tradeoff, but the sentence
  states the opposite. Suggested wording: "...the grid is pinned when the AOI is in a projected
  NAD83 CRS; an AOI in the WGS 84 source's CRS leaves both to sf's PROJ."

- **[severity: fragile, doc]** CLAUDE.md, the new #78 sentence in the `fl_dem_aoi()` bullet:
  "through sf's default PROJ an edge within the datum step of a cell boundary flipped 47–91 edge
  cells". It is wrong in two ways:
  1. 47–91 is the count of *changed* cells (49/91/47). The NA/value flips were 31–60
     (`logs/20261014_measure_window.log`: 32/60/31). `research/` and the roxygen both say "changed"
     correctly.
  2. The probe did not run sf's default PROJ. It ran PROJ 9.8.1's WGS 84 route, written out as a
     pipeline, against the shift-free pin, on an sf whose default (9.5.1) applies no shift.
  Suggested wording: "where sf's PROJ takes the WGS 84 route (as 9.8.1 does), an edge within the
  datum step of a cell boundary changed 47–91 edge cells (31–60 NA/value flips)...".

No bugs found in the package code itself: no wrong DEM cells or grids on any path I walked.
