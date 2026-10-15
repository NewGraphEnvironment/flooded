# Progress — Join per-segment attributes to the valley by position, not by group key (#83)

## Session 2026-10-14

- Plan-mode exploration — phases approved by user
- Created branch `83-join-per-segment-attributes-to-the-valle` off main
- Scaffolded PWF baseline from issue #83 with approved phases
- Next: start Phase 1
- Plan review (Plan agent, 00:51Z) returned 22 findings; dispositions in `review-1.md`. Main
  result: on the bundled tile the reference driver join and `fl_valley_join()` agree cell for cell,
  48 ties each. Fixed: by-key contrast in the example double-counted overlapping polygons; Phase 3
  keeps `fp_hj_grid_cells()`; `touches = FALSE`; lon/lat refused; reference-equivalence test added.
- Mutation run (11 mutants in scratch copies: by-key join, nearest-anywhere, ties to highest key,
  NA key first, text sort of numeric keys, no-segment cells FALSE, NA flags as FALSE, tie count
  zeroed, extra cells kept, no type-mismatch warning, no CRS transform): every mutant fails >= 1 test.
- `test-fl_valley_join.R`: 16 blocks, all pass; example runs (nearest 190.41 ha, any 260.68 ha,
  by key 263.85 ha on the bundled tile).
