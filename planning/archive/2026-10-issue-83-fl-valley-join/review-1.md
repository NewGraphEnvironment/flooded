# Plan review 1 (Plan agent, spawned 2026-10-15T00:51Z)

Read-only agent; findings transcribed here by the parent session. Summary of the 22 items and
their disposition:

| # | finding | disposition |
|---|---|---|
| 1 | Blocker: Phase 3 cannot drop `fp_hj_grid_cells()` — `g$cells` feeds `fp_hj_join_blk()`, shared-ground table, km test, demo's segment-grain join | Accepted: replace only `fp_hj_join_range()`; keep grid_cells / or_by_cell / join_blk / summ and the stop on integrity failure |
| 2 | Demo swap never checked; demo writes committed log + figures | Accepted: swap demo too, re-run in a scratch copy, compare log |
| 3 | Log match mixes function change with `fresh.streams` drift | Accepted: in-session A/B (old `fp_hj_join_range()` vs `fl_valley_join()`, `identical()`) is the primary check |
| 4 | No test pins equivalence to the driver; bundled tile has 48 ties, 78% shared cells | Accepted: reference implementation test |
| 5 | Example by-key contrast sums overlapping polygon areas (362.96 ha > valley 287.27 ha) | Accepted: count unique claimed cells |
| 6,7,8,12,18,20 | Plan text: `any` NA for no-segment-only cells, NA-key matching, unclaiming groups ignored, radix order, dedup of (cell, group), output column named after `group` | Accepted: plan + roxygen updated |
| 13 | `terra::cells()` exactness holds; pass `touches = FALSE` explicitly; `check` tests only the union | Accepted |
| 14 | Keep `st_nearest_feature` + `st_distance(by_element)` and input row order for exact ties | Kept as is |
| 15 | All logs have 0 groups without segments, callers resolve NA flags | No change |
| 16 | lon/lat + s2 measures on the sphere | Accepted: refuse a lon/lat `valleys` |
| 17 | Perf fine; one call with all flags as columns is ~6x faster | Noted in roxygen |
| 9 | Tests and code written together, mutation check is the evidence | Mutation run done: 11 mutants, each fails >= 1 test (progress.md) |
| 10 | floodplains main has uncommitted config edits | Use a clean worktree for Phase 3 |
| 11 | Re-run logs are stamped 20261015 (UTC) | Commit as new logs; diff against the committed ones |
| 19 | Acceptance wording | Narrowed: ha / ties / no-segment / integrity figures |
| 21 | Bundled flags are 0/1 integers | Roxygen notes `as.logical()` |
| 22 | Done-when otherwise covered; no pkgdown index | — |
