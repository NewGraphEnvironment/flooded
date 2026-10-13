# Code-check round 3 — #65 (diff 6b5cd1d...HEAD, planning/ and man/ skipped)

## Findings

- **[severity: fragile]** R/fl_valley_confine.R:280-287 (and nothing in roxygen or NEWS): **moving the
  zeroing changes outputs on DEM-valid cells, not just cells that used to be NA.** Before #65,
  `fl_patch_rm()` (default path) turned every valleys-NA cell into 0 *before* the modal filter, so
  modal counted those cells as 0 votes. Now they are still NA when modal runs, and
  `focal(..., "modal", na.rm = TRUE)` ignores them, so cells at depth 3 of a valleys-NA region (an
  island across a 1-cell gap, a slope-NA patch) come out 1 more often. Measured, main (6b5cd1d) vs
  HEAD, default `size_threshold = 5000`, `channel_buffer = FALSE`, bundled tile, window rows
  311:323 x cols 229:241 (all valley, no stream):
  - island behind a 1-cell DEM ring: 2 of 121 island cells were 1 on main, 34 at HEAD (32 cells
    changed 0 -> 1, all with DEM values and non-NA on both);
  - 13 x 13 user-`slope` NA block, DEM complete: 92 of 169 were 1 on main, 120 at HEAD (28 cells changed);
  - island behind a 2-cell ring with a user slope NA only on the ring: 4 of 81 on main, 32 at HEAD.
  - A plain gap (`na_block_fixture()`) does not change: 0 cells differ on either path, because a
    DEM-valid cell's modal window reaches only depth 2 of the NA region, which the closing filter
    has already filled.
  The bundled tile (no NA) is still identical, as stated, but "NA stays NA / zeroed after cleanup"
  is not the whole change. The new behaviour is arguably better (a gap should not vote 0), but it
  is unstated, and the comment's one reason ("so hole filling does not see a cut-off island as a
  hole") reads as if only the zeroing moved. Consequence: **the cached lidar results are no longer
  what the code produces** wherever the 2019 lidar has slivers or narrow gaps.
  `stac_valleys_5m.tif` / `stac_valleys_1m_site.tif` were built at 1ea1ae5 on the default path
  (patch removal certainly runs at 1 m with a 5000 m2 threshold), and `test-vignette_data.R`
  cannot see the change: its 10 m guard runs on the NA-free tile, and the pinned NA counts
  (115385 / 11020) do not move because the old code left no DEM-valid NA on that path. That is the
  drift CLAUDE.md says the cache test is there to signal, and here it stays silent. At minimum, say
  so in the comment and NEWS and re-run `data-raw/stac_dem_vignette_data.R`, or record that the
  cache predates #65. (Separately, and not caused by this diff: `pars_valleys.tif` has 0 NA cells
  while `pars_dem.tif` has 10,180,862, so the Parsnip cache already predates #63.)

- **[severity: fragile]** R/fl_valley_confine.R:55-57 (roxygen `@return`),
  tests/testthat/test-fl_valley_confine.R island-fixture comment ("behind a 1-2 cell gap"), and the
  test title "cells where a supplied slope is NA but the DEM is not are 0": **the round-1
  mechanism, still present.** The mechanism: prose explains a cell's final value by one criterion
  or by gap width, but the cleanup chain (closing max then min, then modal, each 3 x 3) carries
  values **three cells into any region where `valleys` is NA**, whatever made it NA: a DEM gap,
  the derived slope's NA rim, NA slope, or NA cost. Width of the DEM gap is only a proxy for that
  depth. Two places it gives the wrong answer:
  1. *"where the gap is narrow enough (one or two cells)"* / *"behind a 1-2 cell gap"*. With the
     default derived slope, the slope-NA rim outside the gap uses up one of the three cells, so
     only a **1-cell** gap lets cleanup mark island cells 1. Measured at HEAD, both cleanup paths:
     1-cell ring gives 34 of 121 island cells = 1; **2-cell ring gives 0 of 81**; 3-cell ring gives
     0 of 49. A 2-cell gap reaches only when a supplied `slope` is NA on the gap but valid at its
     rim (32 of 81).
  2. *"a cell whose slope is NA. The morphological cleanup can still mark such a cell 1 where the
     gap is narrow enough"*. A slope-NA cell needs no gap at all. A 13 x 13 user-slope NA block on
     a complete DEM on valley floor: **120 of 169 cells are 1** (exactly the cells within 3 of the
     block edge, 169 - 7 x 7), on both cleanup paths. So the test title "...slope is NA but the DEM
     is not are 0" states a general property that is false. Its `all(v[block] == 0)` passes only
     because rows 340:370 x cols 570:600 sit on hillslope.
  Suggested wording: cleanup can mark such a cell 1 when it lies within three cells of measured
  valley floor. With the derived slope, for a cut-off island, that means behind a one-cell gap.
  And retitle the test to say it covers a block away from valley floor (e.g., "...are 0 or 1, not
  NA", with the `== 0` assertion described as a property of this site).

## Mechanism check (every place in the diff the mechanism reaches)

| place | verdict |
|---|---|
| roxygen `@return`, l.52-57 | "Every cell with a DEM value is 0 or 1": true (l.287, then overlays only set 1). "one or two cells", and gap width as the condition for slope-NA cells: wrong (finding 2) |
| roxygen `@details` l.72-76 | unchanged; "can differ" is hedged; true |
| comment l.275-278 "smear 1s and 0s into a gap's edge" | true |
| comment l.280-286 | "Among the cells that reach here NA" is hedged; the reasons are true. Missing: the modal change (finding 1) |
| `fl_patch_rm` / `fl_patch_conn` comments and `@return` | true: `x * 0L` keeps NA, zeroes 0 and dropped 1; matches each early return |
| island_fixture comment "3-cell ring too wide" | true (0 of 49 at HEAD). "1-2 cell gap": finding 2 |
| `vc_both_paths` comment "differ only if it removed one" | true: `size_threshold` is read only at l.267, and `min_area = 1` at 100 m2 cells always takes the early return |
| speck test "no measured neighbour within a focal window" | true: the nearest measured cell is 16 rows/cols away |
| slope-NA test title / `== 0` | finding 2 |
| #63 test comment "every cell with a DEM value is measured, including the ring" | true (l.287 guarantees it whatever the focal filters reach) |
| CLAUDE.md trap entry | true: both helpers have an early return (`length(small_ids) == 0`, `length(connected_ids) == 0`); old conn path `ifel(!is.na(kept), x, 0L)` did zero NA; `size_threshold = 1` takes no-removal path |
| test-vignette_data.R comment | true as history; the guard's blindness to this diff is finding 1 |

## Other checks (clean)
- `x * 0L` in both helpers: 0 stays 0, a dropped/small 1 becomes 0, NA stays NA; matches each early
  return. `expect_true/expect_false(info =)` are valid (no `expect_gt(info =)`). Fixture
  premises are asserted (2892-cell ring, interior slope non-NA and cost NA, `any(p1 != p5000)`,
  island free of stream cells). Row-major comparisons in the patch tests are correct.

Probe scripts: scratchpad `r3_probe.R`, `r3_block.R`, run against an rsync copy (HEAD) and a
`git archive` of 6b5cd1d; the repo tree was not touched.
