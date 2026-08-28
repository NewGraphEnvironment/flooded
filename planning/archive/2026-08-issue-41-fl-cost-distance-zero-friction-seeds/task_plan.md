# Task: fl_cost_distance() seeds every zero-friction cell, not just stream cells (#41)

## Problem

`fl_cost_distance()` documents stream cells as the seed points, and does not deliver that.
`R/fl_cost_distance.R:51-52` sets stream cells to 0 and hands the raster to
`terra::costDist(target = 0)`, which finds **every** cell equal to 0 — including any cell whose
friction (percent slope) is already exactly zero. Those cells become free cost sources they were
never meant to be.

Fix: floor non-positive friction to a negligible positive value *before* seeding, so zero is
constructed to mean "stream cell" and nothing else.

## Phase 1: Branch + PWF baseline

- [x] Branch `41-fl-cost-distance-seeds-every-zero-friction-c` off main
- [x] `planning/active/` — `task_plan.md`, `findings.md`, `progress.md`

## Phase 2: Tests first — must be red before Phase 3

- [x] **Only stream cells are seeds** — `which(cost == 0)` is exactly the stream cell indices
- [x] **A flat patch is no longer a cost sink** — patch-centre cost exceeds near-stream cost
- [x] **The floor does not turn flat ground into a barrier** — crossing flat ground costs less than
      an equal-length path over 10 %-friction ground
- [x] **Negative friction still errors** — revised during Phase 2. `costDist()` rejects a negative
      cost surface, so flooring `<= 0` as the issue proposed would have disabled a real guard.
      Floor `== 0` only; the test now asserts the guard survives
- [x] **Integer-typed friction survives the floor** (`INT2S`, no zeros after flooring)
- [x] **NA friction stays a barrier**
- [x] **Bundled data is unchanged** — premise (`sum(slope <= 0) == 0`) asserted in the same test
- [x] **The fix cannot move any bundled-data result** — revised: assert cost-raster equality plus
      the no-exact-zeros premise, which implies the `fl_valley_confine()` claim without a second
      full VCA run. Confirmed empirically too: 53,635 valley cells, unchanged
- [x] Restore the bug via namespace patch, confirm the core tests go red, record in `progress.md`

## Phase 3: Fix + documentation

- [x] `R/fl_cost_distance.R` — floor `friction == 0` before seeding, scale reasoning in a comment
- [x] Roxygen — `@details` on flooring, NA-as-barrier, and the negative-friction guard
- [x] `devtools::document()`

## Phase 4: Verify + measure

- [x] `devtools::test()` 246 pass / 0 fail; `check()` 0 errors 0 warnings 1 pre-existing NOTE
      (`pkgdown/`); `lint_package()` leaves only two pre-existing lints outside this diff
- [x] MRDEM-30: **0** exact zeros on the small test-AOI clip but **80** on the shipped 20.9 Mcell
      `pars_dem.tif`. First reading generalized from one clip and was corrected after review — the
      default source *does* produce exact zeros at scale. Cost mask moves 2,289 cells (214 ha,
      0 added); the delineation does not move at all (521,028 cells both ways)
- [x] `inst/notes/methodology.md` — forward reference replaced with the finding and the DEM table
- [x] Confirmed unmoved: 53,635 valley cells, same 5 attribution rows, 0 fallback cells. Also
      verified `costDist` target matching is exact equality (a 1e-14 cell reads 7.07e-14, not 0)
      and that the zero set on bundled data is now identical to the 1,607 stream cells

## Phase 5: Release + close

- [x] `/code-check` — round 1 found 2 real defects (fixed on branch), 1 disproved by measurement,
      1 minor fragility (fixed)
- [x] `NEWS.md` + `DESCRIPTION` `0.4.0` → `0.4.1` as the final commit
- [x] PR #45 opened; `/planning-archive` on merge

## Validation

- [x] Tests pass
- [x] `/code-check` run; findings folded in
- [x] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
