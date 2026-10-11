# Task: fl_valley_attribute(complete = TRUE) runs a full-grid distance to place a few thousand cells (#71)

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

## Phase 1: Tests first
- [x] `test-fl_valley_attribute.R`: oracle test at `cost_threshold = 300` on the bundled tile.
      Recompute today's assignment with the primitives (`fl_stream_rasterize()` of the group
      index + `terra::distance(values = TRUE)`) and compare with the new helper cell by cell; any
      cell that differs must be a tie (equal distance to both groups' nearest burned cells, within
      float tolerance). Assert the fallback fires (> 0 cells) so the test is not vacuous.
- [x] Same test asserts the end-to-end output is unchanged: per-group cell sets from
      `fl_valley_attribute()` equal the oracle's (covered cells + fallback assignment), except
      cells that are measured ties (review finding 1: one such cell on the tile).
- [x] Guard the existing contract: `fl_fallback_cells` value and the "assigned to the nearest
      group" message text unchanged (existing tests at lines 118 and 178 cover the count; add a
      message check with `expect_message()`, matching on a fixed fragment, not an end anchor).
- [x] Restore-the-bug check: swap the helper to the tempting wrong rule, nearest stream
      *line* instead of nearest burned cell (review finding 5), and confirm the new test goes
      red; record it in `findings.md`.

## Phase 2: Implementation
- [x] Add internal `fl_nearest_group(idx_r, cells)` (`@noRd`, in `R/fl_valley_attribute.R`
      below the other helpers): burned cells = `which(!is.na(values(idx_r)))`; centres via
      `terra::xyFromCell()`; `sf::st_nearest_feature()` from the uncovered centres to the burned
      centres; return the burned cells' group index. Empty burned set returns all `NA`.
- [x] Replace the `terra::distance()` block with the helper; keep the `usable` guard,
      the assignment loop, `n_assigned`, the message and the attribute untouched.
- [x] Note in a comment that this is the same nearest-burned-cell rule, with ties possibly
      resolved differently.
- [x] `devtools::test()`, `lintr::lint_package()`, `devtools::document()` clean.

## Phase 3: Measure on MORR
- [x] `planning/active/bench_fallback.R <floodplains_data_dir> <source_tree>`: loads the given
      tree with `pkgload::load_all()`, reads the cached MORR inputs (no absolute paths in the
      script), asserts `fallback_cells == 14170` and 339 rows, and writes timing JSON.
- [x] Helper-level comparison in one process: time the old full-grid pass and the new helper on
      the same uncovered set; count differing cells and check each is a tie.
- [x] End-to-end: time `fl_valley_attribute(group = "blue_line_key")` with the new code, and with
      `main` from a frozen `git worktree` (same machine, same threads, so before/after are both
      measured, not taken from the 0.6.0 probe). Run in the background; edit nothing it reads.
- [x] Record the numbers, versions and threads in `findings.md` and the `.log`.

## Phase 4: Docs
- [ ] Rewrite the `## Performance` section of `fl_valley_attribute()` with the measured MORR
      figures (before/after fallback cost, total), replacing "has not been measured".
- [ ] `## Coverage` section: say the fallback uses the nearest burned stream cell and that ties
      may resolve either way.
- [ ] `devtools::document()`; NEWS line left to `/gh-pr-merge`.

## Validation
- [ ] Tests pass
- [ ] `/code-check` clean (once over the branch with `/code-check branch`)
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion, with Measurement / Evidence sections in the archive README

