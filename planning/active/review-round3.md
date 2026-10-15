# Code-check round 3: fl_valley_join() (flooded#83) and the floodplains adapter

Reviewer: round-3 subagent, 2026-10-14. Probes ran on a copy of the flooded tree under the session
scratchpad (`r3.*/`, `pkgload::load_all()`); nothing in flooded, floodplains or floodplains-hj was
modified except this file.

## Mechanism

Every earlier finding is one fact computed in two places, by two pieces of code (or by code and
hand-typed prose), that agree only because the inputs at hand never reach the case where they part,
and nothing compares the two copies. In r1 and r2 that was: the claim rule (terra's `small = TRUE` default
in one copy, an explicit argument in the other; the tile has no centreless polygon, so they agreed);
the NA rule (package NA vs floodplains FALSE; no test or real input had a no-segment group under a
hectare sum); the test count (typed into CLAUDE.md, derived from nothing); and the NaN-cell drop
(exercised by no fixture). The fix each time made the two copies agree again. It did not make one derive from the
other, so the next edit to either reopens the gap. Where the mechanism reaches in these diffs:

| # | Two computations of one fact | Verdict |
|---|---|---|
| 1 | Claims: `fl_valley_join()` (`touches = FALSE, small = FALSE`, NaN drop) vs `fp_hj_grid_cells()` | **Consistent** (identical call now). **Not pinned**: two hand-copied calls. Both integrity checks compare only the *union* of claims with the floodplain, so a drift that moves cells between groups passes both, and only the blk-vs-position contrast would show it. |
| 2 | Claims: `jn_reference()` in the test (terra defaults, `small = TRUE`) vs `fl_valley_join()` | Rules **differ**. On the tile they give identical cells (probed: 65,495 claims both ways), so the reference test cannot see the claim rule. **Pinned elsewhere** by the sliver test. Acceptable. |
| 3 | Claims: the roxygen example's by-key contrast (`terra::cells` defaults) vs the function | Differ by rule, identical on the tile. Harmless. |
| 4 | NA rules: package `any`/`nearest` (NA for sole no-segment claims) vs adapter `%in% TRUE` vs old local join (FALSE) | **Consistent**. Both callers resolve segment NA before the call (demo: SQL `coalesce`, query: `!is.na(...) &`), so NA arises only from no-segment groups, as the adapter comment says. The A/B covers it. |
| 5 | `no_segments` vs old `blk_without_segments` | **Consistent**. The old count included claims outside the floodplain, the new one drops them first; both callers stop on `extra != 0`, so the counts match. |
| 6 | Tie order and count: old `(cell, dist, blk)` vs rank of `sort(lvls, method = "radix")` | **Consistent** for the numeric keys floodplains uses. **Pinned** by the reference test (equal and > 0; 48 on the tile, re-measured). The old join would count a duplicate claim of a group split over several rows as a tie, and the new one dedups it. The blue-line layers have one row per group, so this does not arise. |
| 7 | `check` (counted from `claim$cell`) vs the output rows (built from `cells_by_rank`, which drops an NA `rank`) | **Inconsistent**. See finding 2. |
| 8 | Tie-order prose vs `sort(method = "radix")` | **Inconsistent for factor keys**. See finding 3. |
| 9 | CLAUDE.md test counts vs `tests/testthat/` | **Stale again**. See finding 1. |
| 10 | CLAUDE.md "49 of 50 segments" and "48 on the tile"; roxygen "16,705 ha vs 572 ha" | **Verified**: the tile's integer `spawning`/`rearing` read `1 1` on 49 rows and `0 0` on 1; ties = 48; BULK sk log rows 72-73 read 16705.26 / 571.86. |
| 11 | `@return check`: "zero for a `complete = TRUE` attribution" vs `fl_valley_attribute()`'s fallback | Not always. See finding 4. |
| 12 | Adapter capability check (`exists("fl_valley_join")`) vs the claim rule it relies on | **Not pinned**. See finding 5. |

## Findings

1. **[bug: false doc]** `CLAUDE.md` line 51 says "19 test files, 183 test_that blocks". The count is
   185: 166 at base plus 19 in `test-fl_valley_join.R`, counted per file with
   `grep -cE '^[[:space:]]*test_that\('`. b295b10 added two blocks after the r2 fix. This is the r2
   finding recurring, because the number is typed by hand rather than derived.

2. **[fragile: silent row loss with a passing check]** `R/fl_valley_join.R`. `lvls` holds only the
   *first* missing key (`keys[is.na(keys)][1L]`), and `match()` tells `NA` from `NaN`. When a numeric
   group column holds both `NA` and `NaN`, the claims of the other one get `rank = NA`. `factor(..., levels = seq_along(lvls))`
   then drops them from `cells_by_rank`, while `claimed <- unique(claim$cell)` still counts them. Probed
   with keys `c(NA, NaN)` on the 10 x 10 fixture: 60 rows returned for 100 valley cells, and
   `check` = `100 100 0 0`. 40 cells vanish with `missing = 0` and no warning. The input is unlikely
   (no blue_line_key is NaN), but it is the one path where the output disagrees with its own
   integrity check. Either fold NaN into NA before ranking (`keys[is.nan(keys)] <- NA` for doubles), or
   count `missing` from the rows actually produced.

3. **[bug: false doc]** `R/fl_valley_join.R` @details, and `man/fl_valley_join.Rd`: "Exactly equal
   distances go to the lowest key (numeric order for numbers, C-locale order for text, `NA` last)".
   For a **factor** group column, `sort(method = "radix")` orders by level, not by C-locale text. Probed:
   keys `factor(c("A","B"), levels = c("B","A"))` give the tie to `"B"`. Either state the factor
   case ("level order for factors") or sort `as.character()` for factors.

4. **[bug: false doc, edge]** `R/fl_valley_join.R` @return `check`: "Both of the last two are zero for
   a `complete = TRUE` attribution of the same delineation." `fl_valley_attribute()` runs its fallback
   only when `usable`, meaning the streams are non-empty and at least one is non-empty. When the fallback is
   unusable, or `fl_nearest_group()` finds no burned cell (all NA), uncovered valley cells stay
   unattributed even with `complete = TRUE`, so `missing > 0`. A qualifier ("normally zero") or a
   pointer to those cases would make it true.

5. **[fragile]** `floodplains-hj/scripts/floodplain_lcc/fp_habitat_join.R`, `fp_hj_join_position()`
   capability check. `exists("fl_valley_join", ...)` is also TRUE for a dev install of this branch at
   f32176a. That commit's claims call is `terra::cells(..., touches = FALSE)`, with the default
   `small = TRUE`, and its version is the same 0.7.2. On such an install the position join would claim
   differently from `fp_hj_grid_cells()` (now `small = FALSE`). That is exactly the r2 divergence, and
   neither union-only integrity check would catch it. The capability check is an accepted tradeoff,
   but here the capability is not the property: once flooded is released, a version floor (the release
   version) is what pins it. Until then, say in the floodplains PR that flooded must be reinstalled from the merged
   main, not from an earlier branch commit.

No other defects found. The adapter's column handling was checked: `merge()` suffixes in `agree()` and
`diff_builds()`, `cls()`, and `fp_hj_summ()` ignore the new `blue_line_key`/`dist` columns. So were the type paths:
the query coerces `v`'s key to numeric before both claim tables, and in the demo `match()` of an
integer gpkg key against numeric DB keys works.
