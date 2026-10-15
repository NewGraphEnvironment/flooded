## Outcome

Added `fl_valley_join()`, which joins per-segment logical attributes (habitat flags) to valley
cells by position, never by group key. Each valley cell takes the nearest segment on each group
that claims it. `nearest` gives one owner per cell (the rule for areas; ties go to the lowest key
and are counted), and `any` ORs over the claimers (the connected view). It generalizes the 77-line
join that floodplains carried for #104 to any group column and any logical columns. The floodplains
driver now calls it (NewGraphEnvironment/floodplains#135) and reproduces its committed logs.

What the review loop taught: every defect found in rounds 1-3 was one fact kept in two places
with nothing comparing them. Examples: terra's `small = TRUE` default in one claim computation
against an explicit `small = FALSE` in the other; NA in the package against FALSE in the driver;
a test count typed into CLAUDE.md. The fixes made the second copy derive from the first, or
removed it. The loop ended on a mutation table over every decision line, not on a quiet round.

## Measurement

- Equivalence with the floodplains join, on identical inputs: per-cell `nearest` and `any`
  `identical()` and tie counts equal for all 21 area x species pairs. DUNC 203,285 cells / 590
  ties, MORR 532,577 / 1,877, KISP 360,449 / 385, BULK 733,324 / 674; 0 groups without segments.
  Per species, single runs on a loaded machine: the new join was faster in 19 of 21 pairs (DUNC
  bt 25 s vs 34 s, BULK sk 44 s vs 65 s), equal in one (MORR pk, 44 s) and slower in one (BULK ch,
  54 s vs 53 s).
- Logs: the floodplains query re-runs (`20261015_*`) equal the committed logs line for line
  except timestamp, flooded version and run time. Demo: same; six class rasters `identical()`,
  one figure off by 3 of 3.7 M pixel-channel values (render noise).
- Bundled tile, a constructed `wide` flag (channel width > 20 m): nearest 190.41 ha, any 260.68
  ha, by key 263.85 ha. The tile is a weak contrast (49 of 50 segments carry the same habitat
  flags); BULK sockeye spawning is the strong one, 16,705 ha by key against 572 ha by position.
- Mutation table: 41 mutants (every decision line, plus the round 3 NaN fold); 40 red at first.
  The survivor (`is.finite` in the tie count) is now pinned by a test, verified red.
- Plan review's first draft of the example summed `st_area()` over overlapping polygons:
  362.96 ha, more than the whole valley (287.27 ha). Counting unique cells gives 263.85 ha.

## Evidence

`ab_join_compare.R` in this directory (the A/B harness); floodplains
`scripts/floodplain_lcc/logs/20261015_habitat_join-query_*` (the re-run logs, PR #135);
`review-*.md` here.

Closed by: PR #84
