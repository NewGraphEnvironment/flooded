# Task: Join per-segment attributes to the valley by position, not by group key (#83)

`fl_valley_attribute()` returns one floodplain row per watercourse group (for example `blue_line_key`), and rows overlap where ground is shared. A common next question is "which part of this floodplain sits beside segments with attribute X?", such as spawning or rearing habitat flags carried per stream segment.

Joining by the group key answers a different question. Measured in NewGraphEnvironment/floodplains, whole-network `all_ff04`, 2026-10-14:

| group | flag | by blue line (ha) | by position, nearest segment (ha) |
|---|---|---|---|
| BULK | coho spawning | 57,482 | 26,937 |
| BULK | sockeye spawning | 16,705 | 572 |

On MORR, joining by blue line reads 82% of the floodplain as chinook spawning.

Branch `83-join-per-segment-attributes-to-the-valle` off main.

## Design (decided; say so if you want otherwise)

- **Name / file:** `fl_valley_join()` in `R/fl_valley_join.R`, tests in `tests/testthat/test-fl_valley_join.R`.
- **Signature:** `fl_valley_join(valleys, attributed, segments, group, cols = NULL)`
  - `valleys` 0/1 `SpatRaster`; `attributed` the `fl_valley_attribute()` sf; `segments` an sf of lines
    with `group` and the logical columns; `cols` = attribute columns (default: every logical column
    except `group`). Validates columns exist and are logical; transforms `segments` to the valley CRS
    (as `fl_valley_attribute()` does); errors if `attributed` CRS differs.
- **Claims:** cells per group from `terra::cells(valleys, terra::vect(attributed))` (the driver's
  method, exact because attribution polygons are cell unions).
- **Per claim:** nearest segment of that group (`sf::st_nearest_feature()` on cell centres within
  the group's segments) and its distance (`sf::st_distance(by_element = TRUE)`), as the driver does.
- **`nearest`:** one row per cell: `cell`, the owner (column named after `group`), `dist`, then `cols`.
  Owner = smallest distance; ties → lowest group key in `sort(method = "radix")` order (numeric for
  numbers, C locale for text, NA last; review #12). Tie count = cells whose first and second claims
  have equal finite distance. (cell, group) claim pairs are de-duplicated (review #18).
- **`any`:** one row per cell: `cell`, then `cols` = `any()` over claiming groups that have segments.
  NA in a segment flag propagates the way `any()` does (no TRUE + an NA → NA); a cell claimed only by
  groups without segments → NA (review #6). An NA key matches the NA group; segment keys no
  `attributed` row carries are ignored (review #7, #8). Claims via `terra::cells(touches = FALSE)`;
  lon/lat `valleys` refused (review #13, #16).
- **Group with no segments:** reported by key; never owns a cell under `nearest` while another
  claimer has segments; a cell whose only claimers lack segments gets owner = that group,
  `dist = Inf`, attributes **NA** (unknown), not FALSE. (Driver used FALSE; all four logs report 0
  such groups, so the match is unaffected.)
- **Return:** `list(nearest, any, check, ties, no_segments)`; `check` = named integer
  `c(valley_cells, attributed_cells, missing, extra)`. Warn (not stop) when `missing`/`extra` ≠ 0 —
  `complete = FALSE` attribution legitimately leaves cells unclaimed; those cells get no row.
- Pure base R + sf + terra; no new Imports.

## Phase 1: Tests first (`test-fl_valley_join.R`)
- [x] Synthetic fixture helper: small projected grid, two or three groups as cell-union polygons, hand-placed segments
- [x] `nearest` vs `any` differ: shared cell nearer a FALSE segment on group A, farther a TRUE segment on group B → nearest FALSE, any TRUE
- [x] Position, not key: a group with a TRUE segment far away and a FALSE segment beside the cell → FALSE (fails for a by-key join)
- [x] Tie rule: cell equidistant from two groups' segments → lowest key owns it; `ties` counts it; NA key sorts last
- [x] Group with no segments: listed in `no_segments`, never owns a shared cell, sole-claimer cell → NA attributes
- [x] Cell claimed by none (valley cell outside every polygon): no row, `check["missing"]` = 1, warning; cell outside valley inside a polygon → `extra`
- [x] Bundled data (`streams.gpkg` + `fl_valley_attribute(..., "blue_line_key")`, constructed logical columns): check all zero, `nearest` covers every valley cell once, nearest TRUE ⇒ any TRUE per column, `cols = NULL` picks logical columns
- [x] Input validation: missing/non-logical `cols`, missing `group`, CRS mismatch on `attributed`, segments in another CRS transformed

## Phase 2: Implement `fl_valley_join()`
- [x] `R/fl_valley_join.R` with roxygen (rule, both resolutions, tie rule, NA semantics, why only claiming groups compete, the BULK contrast numbers from the issue) and a runnable `@examples` on bundled data
- [ ] `devtools::document()`, `devtools::test()` all green, `lintr::lint_package()` clean
- [x] Restore-the-bug check: swap to a by-key join / drop the claiming restriction in a scratch copy and confirm the Phase 1 tests go red
- [x] `CLAUDE.md` Architecture list + test counts; design-decision line pointing at the function

## Phase 3: floodplains driver swap (separate repo, separate PR)
- [ ] Branch in a clean floodplains worktree (main has unrelated uncommitted config edits); replace only `fp_hj_join_range()` with `flooded::fl_valley_join()` — keep `fp_hj_grid_cells()`, `fp_hj_or_by_cell()`, `fp_hj_join_blk()`, `fp_hj_summ()` and the integrity stop (review #1); update `habitat_join-query.R` and `habitat_join-demo.R` (`$ties`, `length($no_segments)`)
- [ ] Primary check, in session: old `fp_hj_join_range()` vs `fl_valley_join()` on the same inputs, `identical()` per-cell flags and equal ties, on every area (review #3)
- [ ] Install the flooded branch into a scratch library; re-run `habitat_join-query.R` for morr, bulk, kisp, dunc, and the demo in a scratch copy
- [ ] Compare every ha / ties / no-segment / integrity figure to the committed logs (morr/bulk/kisp 2026-10-14, dunc 2026-10-12, demo 2026-10-11); commit the new (20261015) logs
- [ ] Open floodplains PR referencing flooded#83; it depends on the flooded release, so note the minimum version

## Validation

- [ ] Tests pass
- [ ] `/code-check` clean (each commit, or once over the branch with `/code-check branch`)
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion, then `/gh-pr-push` (flooded); merge and version bump left to `/gh-pr-merge`

## Verification end to end
- `Rscript -e 'devtools::test()'` grep FAIL/ERROR; `devtools::run_examples()` for the new example.
- floodplains: four re-run logs equal the committed ones in every figure except run time and versions.
- Phase 3 needs the newgraph DB (`fresh.streams`) and `data/<area>/`; if unreachable, file it as a blocker and open the flooded PR anyway.
