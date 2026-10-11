# Review round 3 — #71 (branch diff b701391...HEAD)

## Findings

- **[severity: fragile, pre-existing text the diff fixed in only one place]** R/fl_valley_attribute.R:24-27 (`@param complete`), man/fl_valley_attribute.Rd (arguments) — still says uncovered cells "are assigned to the group whose streams are nearest". The diff rewrote the same claim in `## Coverage` (it used to read "the group with the nearest streams") to the precise rule, "the group of the nearest burned stream cell (centre to centre, the cells fl_stream_rasterize() burns)". The branch measured that the two rules differ: findings.md, Phase 1, says nearest stream *line* (`st_nearest_feature(pts, streams)`) disagrees with nearest burned cell in 10 of 9,904 cells at ct = 300, none of them ties. That mutation was used as the test's restore-the-bug case. A group whose segments burn no cell (`touches = FALSE`) can never win the fallback, even when its line is nearest. So the shipped `@param` states the rule this branch proved wrong, and it now contradicts the Details a few lines below it. The fix is a one-line edit pointing `@param complete` at the burned-cell rule, or at "See Details". This is not a code bug.

## Checked and true (no finding)

Roxygen/Rd claims the diff adds, each checked against the bench log, the code or the data:
- "18.1-million-cell 30 m grid": `arm5_floodplain.tif` is 4082 x 4431 = 18,087,342 cells at 30.43 m, EPSG:3005, and matches `dem_common.tif` (checked directly from floodplains `data/morr`).
- "340 blue lines": `streams_co3` has 340 unique `blue_line_key` and 0 empty geometries. The output has 339 rows because 360652838 is dropped with a warning. The doc describes the input, so this is correct.
- "385,021 valley cells": asserted by `bench_fallback.R`.
- 37.8 s / 35.2 s / 0.4 s / 805.6 s / 855.8 s / 14,170: these match `e2e_new.t_attr_s`, `helper_new.t_strict_s`, `t_new_nearest_s`, `t_old_distance_s`, `e2e_main.t_attr_s` and `fallback_cells`. "Placing … 0.4 s" and "that step took 805.6 s" both leave out the 0.3 s rasterize, so they are compared on the same basis.
- "Through 0.6.3": b701391 is `v0.6.3-33`, and `git diff v0.6.3 b701391 -- R/ DESCRIPTION NAMESPACE` is empty, so the 855.8 s run is 0.6.3's code.
- "assigned identically": `cells_differing: 0` over all 14,170 cells (an `is.na` mismatch would also count), and 0 of 339 group counts differ.
- "centre to centre, the cells fl_stream_rasterize() burns": `idx_r` is `fl_stream_rasterize(idx_streams, valleys, ...)`. The streams were already transformed to `valleys`' CRS, and `fl_stream_rasterize()` would make the same transform itself, so these are the cells it burns on that grid. `xyFromCell` gives centres.
- "either may win": correct, and conservative. A cell burned by two groups carries `max` index deterministically, which "may" allows.

R CMD check:
- sf and terra are in Imports, and every call uses `::`. No non-ASCII characters in any added line of R/, man/ or tests (checked with `LC_ALL=C grep`). The existing em-dashes are covered by `Encoding: UTF-8`.
- A copy of the tree re-roxygenised with no diff in man/ or R/, so the Rd matches its source. `tools::checkRd` reports only the existing encoding notes, which do not apply inside the package. The examples are unchanged.

Control flow against b701391:
- `complete = FALSE` with `uncovered` non-empty: `usable` is FALSE, so the helper is not called, `n_assigned` = 0 and the message is the same. All geometries empty: `usable` is FALSE, as before. No burned cells: the helper returns all NA and the guard skips the loop, as the old `values(idx_r)` guard did.
- One theoretical difference, not reachable through `fl_valley_attribute()`. For a query cell that is itself burned, `terra::distance(target = NA, values = TRUE)` returns **NaN**, not the cell's own value. Probed on a 5x5 grid: burned cells read NaN. The old code therefore left such a cell unassigned, and the new code assigns it to its own group. So the `@noRd` sentence "The same rule as terra::distance(...)" does not hold for burned cells. It cannot happen here, though: a burned valley cell is a seed of its own group, where cost = 0 even under NA friction (`fl_cost_distance()` sets seeds to 0) and distance = 0, so it is always covered and never reaches the fallback. The MORR helper run confirms this with 0 differing cells, `is.na` mismatches included. No action needed, and the new behaviour is the better one if it were ever reached.

## Verdict

One documentation finding: the `@param complete` text left behind by the Coverage rewrite. Otherwise clean.
