# Task: fl_valley_confine() returns 0, not NA, where the DEM is NA (#63)

`fl_valley_confine()` documents its return as `1` = valley, `0` = confined / hillslope, `NA` = outside
analysis extent. Where the input DEM is `NA`, it actually returns **0** — no-data reads as measured
non-valley, a plot draws the gap the same grey as hillslope, and any share over `ncell()` or non-NA
cells counts the gap as not-floodplain.

## Context

`fl_valley_confine()` documents `NA` = outside analysis extent, but returns `0` on NA DEM cells.
The cause is `fl_patch_rm()` (`R/fl_patch_rm.R:46`): it sets every NA cell to 0
(`is.na(patches) -> 0L`). After that, the focal smoothing smears 1s into the gap edge. Probe on the
bundled tile with a 31x31 NA block over a valley: **815 zeros, 146 ones, 0 NA**. Of the 146 ones,
about 43 are focal smear on the block edge and about 103 are the channel buffer. Without the buffer:
918 zeros, 43 ones.

Decisions taken at the gate:
- **Fix the output** rather than the docs.
- **Overlays win.** Mask by `dem` after the morphological cleanup and *before* the channel-buffer
  and waterbody ORs. A gap cell under a channel buffer or a waterbody is `1`. Every other gap cell
  is `NA`. Lidar is often NA over open water, and the overlays do not depend on the DEM.
- **Rebuild the stac-dem lidar cache in this PR.** The 5 m tile is 22.3% NA and the 1 m site is
  7.9% NA. The 10 m guard cannot see the change.

Measured facts that bound the change:
- The bundled DEM has no NA, so bundled output is identical by construction. The
  `test-vignette_data.R` guards (`n_10m` 28727, `n_site_10m` 20586) should hold.
- Parsnip cache: `pars_dem.tif` is 49% NA, but **0 of 441,054** valley cells sit on NA DEM.
  Published hectares are unaffected. `pars_valleys.tif` still carries 0 instead of NA outside the
  DEM. It is not rebuilt, because that needs the DB. I'll note it in findings.
- 1,028 valid-DEM cells *outside* the NA block also change. That is the NA acting as a barrier in
  cost distance and patch connectivity: real algorithm behaviour, not this bug. Out of scope; it
  goes in findings.

## Phase 1: Failing tests (synthetic NA, per the CLAUDE.md test-data trap)
- [ ] `tests/testthat/test-fl_valley_confine.R`: an NA block away from streams and waterbodies
      (`channel_buffer = FALSE`) gives every block cell `NA`, and no valid-DEM cell is `NA`
- [ ] NA block crossed by a stream, with the channel buffer on: buffer cells inside the block are
      `1`, all other block cells are `NA`
- [ ] A waterbody polygon inside an NA block gives `1` on the polygon and `NA` around it
- [ ] Confirm all three fail on current `main` code

## Phase 2: Fix + docs
- [ ] `R/fl_valley_confine.R`: after `valleys <- terra::ifel(valleys >= 1, 1L, 0L)`, add
      `valleys <- terra::mask(valleys, dem)` with a comment on why it sits before the overlays
- [ ] Roxygen `@return` and `@details`: say that NA is where `dem` is NA, except cells covered by
      the channel buffer or waterbodies; then run `devtools::document()`
- [ ] Restore the bug and prove the Phase 1 tests go red. Work in a scratch copy, then `cmp` the tree

## Phase 3: Verify
- [ ] `devtools::test()` passes in full, including the `test-vignette_data.R` 10 m guards
      (unchanged counts)
- [ ] `lintr::lint_package()` clean on the changed files
- [ ] `/code-check` on the staged diff, then commit

## Phase 4: Rebuild the stac-dem lidar cache
- [ ] Run `data-raw/stac_dem_vignette_data.R` from a frozen copy in the background (network, about
      1.3 GB, about 20 min)
- [ ] Diff the new `stac_meta.rds` against the old one (`n_5m`, `n_1m`, `popup_steep_share`,
      `site_steep_share`, etc.) and record the deltas in findings
- [ ] Update `vignettes/stac-dem.Rmd` wherever a number, a sentence or a caption moves: the gap now
      plots blank instead of grey, so the caption must say what blank means. Compute every claim;
      don't write one from the image
- [ ] Render the vignette and check the figure and the inline numbers

## Phase 5: NEWS + notes
- [ ] `NEWS.md` entry: the behaviour change, why, which callers it affects (patchy DEMs), and that
      the bundled-tile and Parsnip numbers are unchanged
- [ ] `CLAUDE.md` test-data trap: update the "hides #63" line so it records the fix
- [ ] `findings.md`: the Parsnip cache note and the barrier-effect cells

## Validation
- [ ] Tests pass
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion, then `/gh-pr-push`
