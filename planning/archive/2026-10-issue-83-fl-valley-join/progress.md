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

## Session 2026-10-14 (evening, PDT) — Phase 3 and review

- Full suite: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 553 ]` (01:02Z).
- floodplains swap in a separate floodplains worktree, branch `habitat-join-fl-valley-join` off origin/main
  8db7165: only `fp_hj_join_range()` replaced; new `fp_hj_join_position()` adapter (NA flags read as
  FALSE = the old semantics; asserts `fl_valley_join()` exists).
- A/B (`ab_join_compare.R` in this archive, old `fp_hj_join_range()` vs `fl_valley_join()`, same inputs, branch build
  in a scratch library): per-cell nearest and any `identical()`, ties equal, on every species of
  DUNC (203,285 cells, 590 ties), MORR (532,577, 1,877), KISP (360,449, 385), BULK (733,324, 674).
  Per species the new join was faster (DUNC 25 s vs 34 s).
- Re-runs of `habitat_join-query.R` dunc/morr/kisp/bulk (logs `20261015_*`) equal the committed
  logs line for line except timestamp, flooded version string and run time. Demo (scratch copy,
  outputs redirected): log equal likewise; all six class rasters `identical()`; fig1/fig3 byte
  identical, fig2 differs in 3 of 3.7 M pixel-channel values (render noise).
- Code-check round 1: 4 findings, all fixed (b2c7dc3 + floodplains adapter). `terra::cells(small =
  TRUE)` claim leak and the empty-only group, each verified red against its defect.
- Code-check branch (both repos in each round):

  | Round | Findings | Fixed | Accepted | Inside previous fix? |
  |---|---|---|---|---|
  | 1 | 4 | 4 | 0 | — |
  | 2 | 3 | 3 | 0 | yes (the r1 NaN-cell drop had no test; floodplains claims diverged from the r1 `small = FALSE`) |
  | 3 | 5 | 5 | 0 | yes (test count re-stale; adapter capability check admitted a pre-fix dev install) |

  Round 3 named the mechanism: one fact kept in two places with nothing comparing them (claim
  rule, NA rule, hand-typed counts). Fixes made the second copy derive or disappear (CLAUDE.md
  test count deleted; floodplains claims use the identical call; adapter floor `> 0.7.2`).
  The loop ended by enumeration: a mutation table over every decision line of
  `fl_valley_join()` (39 mutants + 2 for the r3 NaN fold); 38 red at first, the survivor
  (`is.finite` in the tie count) pinned by a new test and verified red. Three reviewer rounds
  plus one plan review: four subagents.
- Final: flooded d6b8497 full suite `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 578 ]`; lint clean for new
  files. Final floodplains scripts re-ran all four queries and the demo; logs equal (timestamp,
  version, run time only). floodplains PR NewGraphEnvironment/floodplains#135 (merge after the
  flooded release; adapter refuses flooded <= 0.7.2).
