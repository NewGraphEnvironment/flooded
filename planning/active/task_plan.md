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

- [ ] Branch `41-fl-cost-distance-seeds-every-zero-friction-c` off main
- [ ] `planning/active/` — `task_plan.md`, `findings.md`, `progress.md`

## Phase 2: Tests first — must be red before Phase 3

- [ ] **Only stream cells are seeds** — `which(cost == 0)` is exactly the stream cell indices
- [ ] **A flat patch is no longer a cost sink** — patch-centre cost exceeds near-stream cost
- [ ] **The floor does not turn flat ground into a barrier** — crossing flat ground costs less than
      an equal-length path over 10 %-friction ground
- [ ] **Negative friction is floored too**
- [ ] **Integer-typed friction survives the floor** (`INT2S`, no zeros after flooring)
- [ ] **NA friction stays a barrier**
- [ ] **Bundled data is unchanged** — premise (`sum(slope <= 0) == 0`) asserted in the same test
- [ ] **`fl_valley_confine()` on bundled data is unchanged** — raw vs pre-floored slope identical
- [ ] Restore the bug via namespace patch, confirm the core tests go red, record in `progress.md`

## Phase 3: Fix + documentation

- [ ] `R/fl_cost_distance.R` — floor before seeding, with the scale reasoning in a comment
- [ ] Roxygen — `@details` paragraph on flooring and NA-as-barrier
- [ ] `devtools::document()`

## Phase 4: Verify + measure

- [ ] `devtools::test()`, `lintr::lint_package()`, `devtools::check()` clean
- [ ] Measure whether MRDEM-30 (the package default DEM source) contains exact-zero slope cells
- [ ] Record the finding in `inst/notes/methodology.md` (`:123` is a forward reference today)
- [ ] Confirm `fl_valley_attribute()` output on bundled data is unmoved

## Phase 5: Release + close

- [ ] `/code-check` on the staged diff
- [ ] `NEWS.md` + `DESCRIPTION` `0.4.0` → `0.4.1` as the final commit
- [ ] `/planning-archive`, then PR

## Validation

- [ ] Tests pass
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
