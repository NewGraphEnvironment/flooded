# Findings — fl_valley_attribute(complete = TRUE) runs a full-grid distance to place a few thousand cells (#71)

## Issue context

## Problem

`fl_valley_attribute(complete = TRUE)` places the valley cells no group reached by running one
**full-grid** `terra::distance(idx_r, target = NA, values = TRUE)`. That one pass costs about as much as
attributing hundreds of blue lines, and it does the same amount of work whether 14 cells or 14,000
are left over.

Measured in NewGraphEnvironment/floodplains#110 / #104 (MORR, 18.1 M cells, `co_ff04`, coho network as 340
blue lines). Evidence: floodplains `research/whole_fwa_floodplain.md`, "Cost".

| run | attribution time |
|---|---|
| 340 groups, `complete = TRUE` | 829.9 s |
| 1 group, `complete = FALSE` | 5.0 s |
| 1 group, `complete = TRUE` (superseded run, planning log only) | 825 s |

Across the five MORR arms, attribution fits **790 s + 0.66 s per blue line**. The intercept is this
fallback. On BULK (38.3 M cells), the same two-point fit gives an intercept of about 1,360 s
(23 min). That fit is rough, because the BULK slope grew too (#72). The run only
needed it for 2,218 to 4,440 cells (`fallback_cells` in the arms' `timing.json`).

## Proposal

Compute the nearest group only for the uncovered cells, against the burned stream cells:

1. Take the cell centres of the burned stream cells in `idx_r` (the same raster the full-grid pass
   uses), with their group index.
2. `sf::st_nearest_feature()` (or a k-d tree) from the uncovered cells' centres to those points.

This is the same nearest-burned-cell rule as `terra::distance(values = TRUE)`, so assignments should
match except where two groups tie. The cost becomes O(uncovered x log(stream cells)), not O(grid).

## Acceptance

- [ ] On the bundled tile, at a squeezed `cost_threshold` (300; the defaults leave nothing to fall
      back, see CLAUDE.md "Test-data traps"), the new assignment equals today's for every cell, or
      any difference is a measured tie.
- [ ] `fl_fallback_cells` and the "assigned to the nearest group" message are unchanged.
- [ ] Timed on MORR's coho network (340 groups): the ~790 s fixed cost goes, measured not inferred.
- [ ] The Performance section of `fl_valley_attribute()` states the measured figure.

## Related

- #44: the scale measurement that found the intercept. Its MORR comment attributed the fixed cost to
  "the full-extent setup and the fallback"; floodplains#110 isolated it to the fallback.
- #72: per-group cost, the other half of attribution cost.


## Exploration (plan mode, 2026-10-11)

What exploration found:
- `idx_r` is `fl_stream_rasterize(..., field = "fl_group_idx")`: `touches = FALSE`, `fun = "max"`.
  Reusing that raster keeps the same seed set and the same overlap rule.
- `sf::st_nearest_feature()` (sf is already in Imports) uses a GEOS STRtree for planar CRS, so
  no new dependency. Ties may break differently from terra; acceptance allows a measured tie.
- MORR arm 5 runs offline from floodplains' cache: `data/morr/aquatic_network.gpkg`
  layer `streams_co3` (4,877 segments, 340 blk), `data/morr/probe_whole_fwa/arm5_floodplain.tif`
  (385,021 valley cells), `dem_common.tif`, and `co_ff04` = `max_width 2000`, `cost_threshold 2500`.
  The recorded `fallback_cells = 14170` and `attr_rows = 339` are the reproduction check.
- Precedent for a measurement script: `planning/archive/2026-10-issue-68-flood-surface-blend/`
  carries `measure_lost_cells.R` + `.log`, archived with the PWF.


## Design (2026-10-11)

- `fl_nearest_group(idx_r, cells)`: burned cells are `which(!is.na(values(idx_r)))`; both sets
  become `sf` points at cell centres in `idx_r`'s CRS and `sf::st_nearest_feature()` picks the
  nearest burned centre. Same seed set and same max-of-overlap index as the old pass, because
  `idx_r` is unchanged. Ties (two groups' burned cells equidistant) may resolve differently.
- The old pass's only output the caller used was `values(nearest)[uncovered]`, so the helper
  returns exactly that vector and the assignment loop, count, message and attribute are untouched.
- Timing hygiene: the MORR "before" run (main, frozen worktree) and the "after" run are timed
  with nothing else running on the machine, since both use 12 terra threads.

## Phase 1 results (2026-10-11)

- The new test (`the coverage fallback matches the full-grid nearest-stream assignment`)
  passes against `main`'s code (the test file was copied into a worktree of b701391) and against
  the new helper: 20 tests in the file, 0 failed, 0 errors, 0 skipped, under `NOT_CRAN=true`.
- Restore-the-bug: in a copy of the tree, assigning each uncovered cell to the nearest stream
  *line* (`st_nearest_feature(pts, streams)`) instead of the nearest burned cell fails exactly
  that test (1 failed, 0 errors). The reviewer measured that this rule differs in 10 of 9,904
  cells at ct = 300, all of them non-ties.
- Not testable on this tile (review finding 4): the max-of-overlap index in `idx_r`, and cell
  order. Neither can diverge between old and new, because both read the same `idx_r` and
  `uncovered` comes out of `setdiff()` in ascending order.

## Errors Encountered

| Error | Resolution |
|-------|------------|
