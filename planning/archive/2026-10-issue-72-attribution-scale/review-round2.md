# Code-check round 2 — #72 branch (HEAD d62038b vs merge-base 1077e17)

## Verdict on the code

The package change is sound. Checked:

- `fl_rbind_pairwise()` vs `do.call(rbind, x)`: `identical()` on the cached MORR order >= 2 parts
  (1,633 parts, mixed 1,394 / 239 POLYGON and MULTIPOLYGON, scratchpad `rbind_parts_morr.rds`),
  and on synthetic parts mixing POLYGON / MULTIPOLYGON / GEOMETRYCOLLECTION / EMPTY, NA keys and
  factor keys, for n = 1..8. The one way it diverges is character row names (`make.unique`
  applied pairwise gives `"211"` where all-at-once gives `"23"`), but `fl_cells_poly()` returns
  integer row names (checked), which rbind treats as automatic, so this cannot arise.
- `test-fl_valley_attribute.R` run with `NOT_CRAN=true`: 22 blocks, 0 failed, 0 errors, 0 warnings.
- Per-group cell tables main vs branch: identical on all six inputs (morr_co, morr_a2, bulk_co,
  bulk_a2, bundled, bundled_300).
- Roxygen / Rd numbers (38 / 155 / 50 / 240 s; 70-75% groups; 0.07 / 0.08 s per group; ~a fifth
  polygonize; 52.8 -> 5.0 s; 0.4 s on #71's step-alone basis) match the branch records.
- `fl_rbind_pairwise()` @noRd figures (24.5 / 52.8 / 2.4 / 5.0 s) match the section CSVs.
- lintr clean on both changed R files.

## Findings

- **[fragile, prose claim]** Issue #72 body, quote block at top: "Measured at 0.6.4, per group,
  BULK and MORR cost the same: the per-group pass averages 0.070 s (BULK) against 0.067 s (MORR)
  on the order >= 2 networks, and 0.082 s against 0.079 s on coho." Those four figures are the
  **branch** runs (tree 2c6a148: 178.24/2550, 114.11/1711, 35.11/428, 26.77/340). The 0.6.4 runs
  (tree 1077e17) give 0.085 vs 0.072 s on order >= 2 (215.92/2550, 123.43/1711) and 0.084-0.091 vs
  0.078-0.082 s on coho. The groups-pass code is unchanged between the trees, so using the branch
  figures is defensible (main's BULK a2 run was the contended one), but the text says "measured
  at 0.6.4" and "cost the same", and the 0.6.4 records show BULK 17% higher on order >= 2. Same
  sentence in `planning/active/findings.md` ("The issue's premise does not survive at 0.6.4 ...
  groups pass 0.070 vs 0.067 s"). Fix: say the figures are from the branch runs, whose groups pass
  is unchanged 0.6.4 code, or quote both.

- **[fragile, prose claim]** Issue #72 body, Outcome, "Profile" bullet: "the per-group pass is
  70-75% of the total and polygonizing 21-23%, on each of the four networks." True only for the
  branch. The bullet is about the profile that found the `do.call(rbind)` term, i.e. 0.6.4, where
  the groups pass is 64.7-69.3% (MORR a2 64.7%, BULK a2 64.9%, BULK co 68.6%, MORR co 69.3%) and
  polygonize 17.8-21.6% (BULK a2 17.8%, BULK co 20.6%). Same unscoped claim in
  `planning/active/findings.md` "Out of scope": "polygonizing is 21-23% of the total on all four
  watershed networks" — at 0.6.4 BULK order >= 2 is 17.8%. This is the round-1 fix (scoped to the
  four watershed networks) still missing its tree scope. Fix: "on this branch".

- **[fragile, prose claim]** `planning/active/findings.md`, Baselines bullet: "The groups pass moved
  216 -> 174-178 s on BULK order >= 2 with no change to it: load (main ran at 1-min load 7.6, the
  branch at 4.3-7.7)." The cited discriminator does not discriminate: branch r2 started at 1-min
  load 7.66, the same as main's 7.64, and was the *fastest* run (173.96 s). What differs is the
  5/15-min load (main 8.06 / 16.83; branch 4.93 / 8.19 and 5.97 / 7.80). Cite those, or state the
  load attribution as an inference. CLAUDE.md's derived sentence ("CPU time inflated too (an
  unchanged section moved 216 -> 174 s between two runs)") rests on this.

- **[fragile, PWF accuracy]** `planning/active/task_plan.md` Phase 2, first box is ticked: "Fix each
  full-grid or fixed-cost operation repeated per group that the profile names, one commit each
  with its measured saving." No per-group operation was fixed; the one fix (pairwise rbind) is a
  once-per-call bind, not a per-group cost. Round 1 annotated three other boxes "as built" but not
  this one. Similarly Phase 5's third ticked box still gives its basis as "Polygonizing is 37 of
  277 s, and the mainstem's 18 s is far below the budget once groups run in parallel" — the
  contended planning numbers findings.md calls an artefact, and a parallel path that was not
  built. Annotate both as built.
