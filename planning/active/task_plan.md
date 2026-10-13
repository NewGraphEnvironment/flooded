# Task: fl_patch_rm() and fl_patch_conn() turn NA input cells into 0 (#65)


Two exported helpers turn `NA` cells into `0`, which is the mechanism behind #63:

- **`fl_patch_rm()`** (`R/fl_patch_rm.R`): `out <- terra::ifel(is.na(masked) | is.na(patches), 0L, x)`.
  `patches` is NA on every cell that is not a `1`, including NA input cells, so they come back as 0.
  This only happens when at least one patch falls under `min_area`. Otherwise the early
  `if (length(small_ids) == 0L) return(x)` hands `x` back with its NA intact. So whether NA
  survives depends on an unrelated property of the data. The `@return` says all other values are
  unchanged.
- **`fl_patch_conn()`** (`R/fl_patch_conn.R`): `out <- terra::ifel(!is.na(kept), x, 0L)` sets NA
  input cells to 0 the same way. It has its own early return too: when no patch touches the
  anchor it returns `x * 0L`, which keeps NA. So it is also path-dependent.

The early return has a second consequence. Cells that do have DEM values but are cut off from every
stream by a gap get no cost distance (`costDist` gives NaN past an NA barrier), so they are NA going
into `fl_patch_rm()`. If no patch is small enough to remove, they come out of `fl_valley_confine()`
as NA even though the DEM has values there. When some patch is small enough, they come out as 0.
The output therefore depends on an unrelated property of the data in both directions.

#63 fixed the symptom in `fl_valley_confine()` by masking its result with the DEM after cleanup.
A caller that runs `fl_patch_conn()` on that output, as the valley-confinement vignette does, gets
the 0s back on any DEM with gaps. The bundled tile has no NA cells, so nothing in the suite shows it.


## Context

Both helpers zero NA input cells, and whether they do depends on which code path runs:
- `fl_patch_rm()` (`R/fl_patch_rm.R`): `ifel(is.na(masked) | is.na(patches), 0L, x)` zeroes NA, but only
  when some patch is under `min_area`. Otherwise the early `return(x)` keeps NA. Reproduced: a 6x6
  grid with 2 NA cells gives 0 NA on the removal path and 2 NA on the early path.
- `fl_patch_conn()` (`R/fl_patch_conn.R`): `ifel(!is.na(kept), x, 0L)` zeroes NA; the no-anchor path
  (`x * 0L`) keeps it.

Effect in `fl_valley_confine()`: cells with DEM values that a gap cuts off from every stream have NaN
cost distance, so they are NA going into cleanup. They come out as NA or 0 depending on whether an
unrelated patch is small. **Decision (plan gate): such cells fail the cost criterion and read 0**; NA
stays reserved for "no DEM".

Fix shape, verified in a probe: `terra::ifel(is.na(kept), x * 0L, x)`. `x * 0L` is 0 where x is a value
and NA where x is NA. That is the same form as the no-anchor path, so all paths agree.

## Phase 1: Tests that reproduce #65 (failing first)
- [x] `test-fl_patch_rm.R`: synthetic grid with an NA block, run on both paths (a `min_area` that
      removes a patch, and one that removes none). Assert NA cells stay NA on both, and 0/1 cells match
      the expected result
- [x] `test-fl_patch_conn.R`: NA block on the connected path and on the no-anchor path. NA preserved on both
- [x] `test-fl_patch_conn.R`: in the existing real-data test, assert that the `slope.tif` NA border ring
      (2,892 cells) is still NA in the output, cell for cell
- [x] `test-fl_valley_confine.R`: fixture with a hollow NA ring in the bundled DEM, placed away from
      streams, so an island of DEM cells has no stream path. Assert the island is 0, not NA, under both a
      `size_threshold` that removes no patch and the default
- [x] Confirm each new test fails on current `main` code (restore-the-bug check), counting errors as failures

## Phase 2: Fix the helpers
- [x] `fl_patch_rm()`: replace the zeroing `ifel` with `ifel(is.na(masked), x * 0L, x)`; update
      `@return` to say NA cells stay NA on every path
- [x] `fl_patch_conn()`: `ifel(is.na(kept), x * 0L, x)`; `@return` says NA is preserved
- [x] `devtools::document()`

## Phase 3: Cut-off cells in fl_valley_confine() read 0
- [x] After `mask_cost`: `mask_cost <- terra::ifel(is.na(cost) & !is.na(slope), 0L, mask_cost)`, with
      a comment saying unreachable means it fails the cost criterion
- [x] Remove the `(#65)` sentence from `@return`. Update the line-272 comment, the test comments at
      `test-fl_valley_confine.R:358,390` and `test-vignette_data.R:63` to reflect the fix
- [x] Confirm the bundled-tile 10 m pins in `test-vignette_data.R` still hold. That tile has no cut-off
      cells, so they should not move

## Phase 3b: Plan-review fixes (review-plan.md)
- [x] B1: `fl_valley_confine()` zeroes NA where the DEM has a value, after the `mask(dem)` line
      (cut-off cells, slope-NA specks, supplied slope NA). The `mask_cost` line from Phase 3 is
      removed: the guard subsumes it (mutation: dropping it failed nothing), and during cleanup it
      let hole filling see a cut-off island as a hole
- [x] AC2/AC3: island test asserts the fixture reaches the case; tests for a DEM speck in a gap and a
      supplied slope with NA where the DEM is valid, on both cleanup paths (both fail without the guard)
- [x] G1: CLAUDE.md Test-data-traps bullet no longer says the bundled DEM hides #65

## Phase 4: Cached vignette data
- [ ] If the STAC endpoint is reachable, re-run `data-raw/stac_dem_vignette_data.R` into scratch and
      compare the lidar NA counts with the pins (115,385 at 5 m; 11,020 at 1 m site). If they match,
      leave the cache alone. If they differ, update the cache, the pins and any page prose that cites them
- [ ] If it is unreachable, file a follow-up issue and say so in the PR
- [ ] Check whether the Parsnip cache (`pars_valleys.tif`, a watershed-clipped DEM) can contain cut-off
      cells; note the outcome (no rebuild needed without a DB connection)

## Phase 5: Docs
- [ ] Remove or rewrite the NEWS.md line 36 known-issue entry (release wording is left to `/gh-pr-merge`)

## Validation

- [ ] Tests pass (`devtools::test()`, grep for FAIL/ERROR), and `lintr::lint_package()` is clean
- [ ] `/code-check` clean (each commit, or once over the branch with `/code-check branch`)
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
