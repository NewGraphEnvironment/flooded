# Code-check round 4 (#72): claims enumeration

Reviewer: subagent, 2026-10-11. Diff vs merge-base 1077e17, HEAD 41c2d59.

## Findings

The code is clean. `fl_rbind_pairwise()`'s body has not changed since 2c6a148, which is the
version `rbind_identity_morr_a2.log` tested (`git diff 2c6a148 HEAD -- R/` changes roxygen only).
`test-fl_valley_attribute.R` ran with `NOT_CRAN=true`: 22 blocks, 0 failed, 0 errors, 0 skipped.
Membership was re-checked this round: the main and branch `*_cells.rds` have identical `group`
and `cell` vectors on all six datasets. The bench and `extract_arm2.R` have no defects.

Eleven of the claims enumerated below are NOT SUPPORTED. They come from three defects plus the
audit table that certified them:

- **[fragile] planning/active/findings.md:5 (Run-to-run variation).** The sentence reads "Later runs of the same
  configuration took 52.7-57.7 s wall (`bench/main_filebacked_bulk_co_r*.json`)". Those two
  records hold **57.74 and 54.85 s**. The 52.7 s is `main_bulk_co_r1.json`, an in-memory run,
  which is a different configuration. "Same configuration" is not exact either. The planning
  probe "supplied slope", but `bench_attribution.R:101` passes `dem =`, so the bench derives
  slope inside the call. That costs only about 1.3 s, so it does not change the conclusion, but
  the sentence claims an identity its records do not show. The audit row for CLAUDE.md (line 112)
  repeats "52.7-57.7".

- **[fragile] planning/active/findings.md:6-8, and the two places that inherit it.** findings.md
  says "the load averages do not separate the slow runs from the fast ones: about 7 / 24 / 31
  ... against 6.2-7.7 / 15.6-17.0 / 25.8-27.0". The sentence's own numbers say the opposite. On
  the 5-minute and 15-minute averages, every slow-run value is above every fast-run value
  (24 > 17.0, 31 > 27.0), and the machine has 10 cores (`hw.ncpu`). Lines 81-83 read the same
  pattern on BULK order >= 2 (5- and 15-minute loads higher during the slow run) as "fits
  contention". The slow-run load figures also have no record. They are session output, like the
  timings beside them, but the sentence does not label them that way. Two places inherit the
  claim without labelling it:
  - CLAUDE.md (the added "Repeat attribution timings" bullet): "with load averages that did not
    explain it".
  - Issue #72 Outcome, "Timings vary run to run": "and the load averages did not explain it".

  An argument that the load gap is too small to explain a sixfold slowdown on 10 cores might hold.
  No record makes that argument, so it is not what the text rests on.

- **[fragile] CLAUDE.md (same bullet) and issue #72 Outcome, the "55 s to over 300 s" claim.**
  Both state "over 300 s" as fact. The only source is the planning probes (323.7 / 338.1 s), and
  findings.md:5-6 says outright that "Neither slow run has a committed record". Under this round's
  rule, an unrecorded figure may be cited only as unrecorded. "One configuration" (CLAUDE.md) is
  also loose: slope was supplied in the slow runs and dem in the fast ones (see the first finding).

- **[fragile] Issue #72 Outcome, "DEM 37.2 + delineation 5.9 + attribution 4.0 = 47.1 min".** All
  three figures are right. The sentence does not say that 37.2 and 5.9 are the 0.6.0 probe's wall
  times (`bulk/dem.json` t_dem_s 2,230.3 and `arm2_timing.json` t_delin_s 355.7, the second from a
  contended run) while 4.0 is branch CPU. findings.md:71 labels them; the issue does not. This is
  the round-2 mechanism, a figure quoted without its run.

- **[fragile] R/fl_valley_attribute.R Performance, "about 0.9 s against 1.4 s for the delineation
  itself".** The 0.9 s is supported (`branch_bundled_r1`, 0.91 s). The 1.4 s has no record on this
  branch. Its only support is the bundled re-time under "Session probes not kept as records".

- **[fragile] planning/active/findings.md, Claims audit table.** It certifies the defects above:
  - The roxygen row cites "delineation re-timed 1.32-1.47 s", an unrecorded session probe, as if
    it were a record. Its verdict, "all branch-run or #71 records", is false for the 1.4 s.
  - The CLAUDE.md row paraphrases a sentence that no longer exists ("about 55 -> 324 s wall"). Its
    support is the unrecorded 323.7 s planning probe plus the wrong 52.7 s.
  - The closing line, "Nothing left that names a figure without its run.", is contradicted by the
    "over 300 s" claim (CLAUDE.md and the issue) and by the Outcome's 47.1 min sum.

## Enumeration

Verdict key: **S** means SUPPORTED, with the record and what in it supports the cause or scope as
well as the number. **NS** means NOT SUPPORTED. **U-labelled** means the claim is unrecorded and
the text says so, which is acceptable. **n/a** means the sentence is a prescription or process
text, not a claim. **pre** means the text predates this branch and the branch did not change it.

### R/fl_valley_attribute.R: Performance roxygen

| # | claim | verdict |
|---|---|---|
| R1a | bundled by gnis_name, 5 groups, 518,400 cells, about 0.9 s | S: `branch_bundled_r1.json` n_groups 5 (NA counts as a group, as in the function), ncell 518400, t_attr 0.91 s / cpu 0.914 s |
| R1b | "against 1.4 s for the delineation itself" | **NS**: no record. The only support is an unrecorded session re-time (1.32-1.47 s) |
| R2 | "That saving comes from the crop, so it shrinks ... worst case" | pre: not a branch claim, no #72 record |
| R3 | supplying slope avoids re-deriving it | S: the code derives slope with `terrain()` only when `slope` is NULL |
| R4 | table header: blue_line_key, 30 m grids, 12 threads, CPU s, `complete = TRUE` | S: json threads 12 and cpu_s; dem.json res 30.43 / 30.51; bench `attribute()` uses the default `complete` |
| R5 | rows: 18.1 M / 38.3 M cells; 340 / 1,711 / 428 / 2,550 lines; 38 / 155 / 50 / 240 s | S: branch json ncell, n_groups, cpu_s (38.2, 155.1, 49.5, 240.2 / 238.2) |
| R6 | "Between 70% and 75% ... is the per-group pass (crop, distance and cost distance)" | S: figures.csv branch groups_pct 70.1-74.2 on all four networks; that section is the `cells_by_group` loop only |
| R7 | 0.07 s per group on both order >= 2, 0.08 s on both coho | S: per_group 0.0667, 0.0699 / 0.0682; 0.0787, 0.082 |
| R8 | "so time follows the number of groups more than the size of the grid" | S: per-group cost is equal on grids 2.1x apart, and MORR order >= 2 (1,711 groups, 18.1 M) takes 155 s against BULK coho (428 groups, 38.3 M) at 50 s |
| R9 | polygonizing about a fifth | S: branch poly_pct 21.2-23.3 |
| R10 | "Two earlier steps cost more." | S, read as "cost more in earlier versions", which the next two sentences give. Read as "more than polygonizing" it would be false (rbind 52.8 < polygonize 59.3 at 0.6.4 on BULK order >= 2). Ambiguous, not reported |
| R11 | through 0.6.3 the full-grid distance took 805.6 of 855.8 s on MORR coho, against 0.4 s now | S: #71 archive README Measurement ("fallback step alone") and NEWS 0.6.4. This branch's `fallback` section (0.95-1.07 s) also covers the `idx_r` rasterize, so the two do not conflict |
| R12 | binding took 52.8 s on BULK order >= 2 through 0.6.4, against 5.0 s now | S: main_bulk_a2_r1 rbind 52.77; branch 4.97 / 5.0 |
| R13 | every group's cells unchanged on all four networks | S: `*_cells.rds` main vs branch have identical group and cell vectors on all 6 datasets (re-run this round; files gitignored) |

### `fl_rbind_pairwise()` @noRd and its comment

| # | claim | verdict |
|---|---|---|
| P1 | `do.call` took 24.5 s at MORR's 1,633 groups and 52.8 s at BULK's 2,391 (CPU) | S: main_morr_a2_r1 / main_bulk_a2_r1 rbind cpu, rows 1633 / 2391 (the parts count) |
| P2 | pairwise took 2.4 s and 5.0 s | S: branch sections |
| P3 | `identical()` to `do.call(rbind)` on MORR's parts | S: `rbind_identity_morr_a2.log` (n = 1633, TRUE); function body unchanged since 2c6a148 |
| P4 | `rbind()` of one sf reorders columns, so a single part is not returned as is | S: the n = 1 `expect_identical` passes (test ran) |
| P5 | rows come back in the order of `x` | S: adjacent pairing; test at n = 1, 2, 3, 7 |

### CLAUDE.md (lines added since 1077e17)

| # | claim | verdict |
|---|---|---|
| C1 | the full-grid distance was 805.6 s of MORR's 855.8 s | S: #71 README (pre-existing sentence) |
| C2 | "and it grew with network size" | S as inference. On the MORR grid, 0.6.0 -> 0.6.4 removed 1,791 s from order >= 2 (1,981.9 -> 190.7) against ~790 s from coho (829.9 -> 39.3-40.0). Between v0.6.0 and 1077e17 only the #71 commits touched attribution (`git log v0.6.0..1077e17 -- R/`; #63 changed `fl_valley_confine()` only). The MORR arm 2 log is uncontended (real 2,100.8 <= user 2,123.8). It is not a direct measurement |
| C3 | "so 0.6.0 timings ... read it as a per-group cost" | S: the issue's per-blue-line fit (0.66 / ~3.5 s) came from the 0.6.0 arms |
| C4 | "one configuration's wall time ranged from 55 s to over 300 s across a session" | **NS**: "over 300 s" is unrecorded (findings: "Neither slow run has a committed record") and is not labelled. The slow runs supplied slope, the fast ones dem |
| C5 | "with load averages that did not explain it" | **NS**: the slow-run loads are unrecorded, and the cited 5- and 15-minute values separate slow from fast (24 / 31 against <= 17.0 / <= 27.0) |
| C6 | "an unchanged section took 216 s in one run and 174-178 s in two later ones" | S: figures.csv groups 215.92 / 178.24 / 173.96; started 19:35:52, 19:56:08, 20:00:14 UTC; the groups code is unchanged in the diff |
| C7 | record CPU time and loads, repeat runs, credit only deltas beyond the spread | n/a (prescription) |
| C8 | harness path in the archive | accepted convention |
| C9 | runs on cached MORR and BULK probe inputs (coho, order >= 2); records CPU, loads and per-section times; writes per-group cell tables | S: `bench_attribution.R` lines 46-67, 119 / 145, 135-137, 141-144 (order >= 2 needs `extract_arm2.R` first, as the script header says) |

### Issue #72: top quote block

| # | claim | verdict |
|---|---|---|
| I1 | the premise does not hold once #71 is in | S (I2) |
| I2 | per group, BULK and MORR are within 20%, not 5x | S: worst ratios 0.0847 / 0.0721 = 1.17 and 0.0908 / 0.0779 = 1.17 |
| I3 | 0.085 vs 0.072, 0.068-0.070 vs 0.067, coho 0.084-0.091 vs 0.078-0.082, 0.082 vs 0.079 | S: figures.csv per_group |
| I4 | the table's 0.6.0 figures were mostly #71's fallback | S as inference: MORR order >= 2 lost 1,791 of 1,981.9 s (90%); BULK order >= 2 lost 9,870 of 10,202.9 s, still most after the ~1,981 s of contention excess. The parenthetical example is BULK coho, which is not in the table |
| I5 | the fallback's cost grew with network size (about 2,790 of BULK coho's 2,842 s) | S: 2,842.4 - 52.1 = 2,790.3; growth as in C2 |
| I6 | so a fit across arms read it as a per-blue-line cost | S |
| I7 | BULK arm 2 contended (10,574 s wall vs 8,528 s CPU) | S: bulk logs/2.log real 10,573.85, user 8,527.80, sys 64.81; 0 swaps and 124 page faults, so not paging; 4.82 M involuntary context switches (456/s against ~118/s on the uncontended runs) |
| I8 | the one step worth changing was `do.call(rbind)` | S: 15.8% of 0.6.4's BULK order >= 2 total; no other section moved beyond spread |

### Issue #72: Outcome

| # | claim | verdict |
|---|---|---|
| O1 | CPU s, `complete = TRUE`, 12 threads, in-memory valleys "as floodplains' step 02 passes them" | S: json valleys_in_memory TRUE. `02_floodplain_model.R:196, 303` passes `fl_valley_confine()`'s returned raster, plus `dem`, as the bench does |
| O2 | table: 0.6.4 39.3-40.0 / 190.7 / 52.1-54.7 / 332.9; branch 38.2 / 155.1 / 49.5 / 238.2-240.2 | S: figures.csv |
| O3 | "DEM 37.2 + delineation 5.9 + attribution 4.0 = 47.1 min" | **NS** as written: the figures are right, but the DEM and delineation times are 0.6.0 probe wall times (the delineation from the contended arm 2 run) mixed with branch CPU, and no run is named |
| O4 | #71 had already brought it to 48.7 min | S: 37.17 + 5.93 + 5.55 |
| O5 | branch per-group 70-75%, polygonizing 21-23%, on each of the four networks | S: figures.csv |
| O6 | 65-71% and 18-23% at 0.6.4, rbind up to 16% | S: 64.7-71.1 / 17.8-22.8 / 15.8 |
| O7 | "No step repeats full-grid work per group." | S by code: `fl_group_cells()` crops slope and valleys to the group window, `fl_cells_poly()` crops to the cells' bounding box, and the per-group subset is O(segments), not O(grid). Equal per-group cost on grids 2.1x apart agrees |
| O8 | rbind 24.5 / 52.8 -> 2.4 / 5.0 s; `identical()` on MORR | S: as P1-P3 |
| O9 | every group's cells identical on bundled (both thresholds), MORR and BULK, coho and order >= 2 | S: as R13 |
| O10 | a new test checks every group on the bundled tile against its uncropped membership | S: test present; ran with 0 failures (criteria membership, `complete = FALSE`) |
| O11 | parallel: 4.0 min serial against about 17 min left | S: 60 - 37.2 - 5.9 = 16.9 |
| O12 | buffer crop: nothing isolates crop size; bound met at 47.1 | S: no steps record committed |
| O13 | cell-table: polygonizing about a fifth | S |
| O14 | "BULK coho's wall time ranged from 55 s to over 300 s within one session" | **NS**: the upper bound is unrecorded and not labelled |
| O15 | "and the load averages did not explain it" | **NS**: as C5 |
| O16 | CPU time not stable: 216 vs 174-178 s | S: as C6 |
| O17 | harness records CPU, loads, repeat runs; only the rbind delta is credited | S: one json per run, r1 / r2; the roxygen and Outcome credit only rbind |

### planning/active/findings.md, from "Run-to-run variation" to the end

| # | claim | verdict |
|---|---|---|
| F1 | heading: planning probes not usable, cause not established | S |
| F2 | planning probes took 323.7 s and 338.1 s | U-labelled (the next sentence says there is no record) |
| F3 | "Later runs of the same configuration took 52.7-57.7 s wall (`main_filebacked_bulk_co_r*.json`)" | **NS**: those records hold 54.85-57.74 s; 52.7 s is in-memory `main_bulk_co_r1`; the bench passes dem, not slope |
| F4 | neither slow run has a committed record | S: no json |
| F5 | "the load averages do not separate the slow runs from the fast ones" | **NS**: contradicted by its own figures on the 5- and 15-minute averages, and the slow-run loads are unrecorded. The fast-run figures (6.2-7.7 / 15.6-17.0 / 25.8-27.0) are S from the filebacked load_start values |
| F6 | contention is a candidate, not a finding | S (hedged) |
| F7 | planning-time split (108 / 37 / 130 s) discarded | U-labelled |
| F8 | the bench records CPU, loads, repeats | S |
| F9 | probe logs show contention on two 0.6.0 BULK runs, wall well above CPU | S: arm 2 is +1,981 s over user + sys; arm 3 is +269 s with 384 involuntary switches/s against ~118/s |
| F10 | log table (5 rows) | S: every cell matches `logs/{2,5}.log` (MORR) and `logs/{2,3,5}.log` (BULK) |
| F11 | BULK arm 2 ~2,000 s more wall than CPU | S: 2,046 s against user; 1,981 s against user + sys |
| F12 | 8,528 s CPU is real work; DEM a separate mode; delineation ~356 s | S: separate dem.log; t_delin_s 355.7 |
| F13 | BULK coho was not contended | S: real 3,016.5 < user + sys 3,026.3; 118 involuntary switches/s, the MORR runs' rate |
| F14-16 | session probes (80 groups, Rprof 28%, bundled re-time) | U-labelled |
| F17 | plan review B1 / A3 / G1 / G2 / M1 and what the bench now does | S: review-plan.md lines 7, 33, 52, 56, 87; bench lines 66 and 77-94; non-vacuity test present; arm5 tif is LZW, `Block=5727x1` (gdalinfo) |
| F18 | membership identical main vs branch on all six inputs | S: re-checked |
| F19 | baselines table (every cell) | S: jsons and section CSVs |
| F20 | premise does not survive; within 20%, not 5x | S |
| F21 | groups pass unchanged; per-group figures | S |
| F22 | 0.6.0 figures were the fallback, which grew with network size, plus contention on BULK arms 2 and 3 | S as inference (C2, F9) |
| F23 | MORR fell 1,791 s vs ~791 s, so the old pass cost about 2.3x more | S as inference (1,791.2 / ~790 = 2.27). The premise "with the per-group pass about equal per group" is not what carries it, because the subtraction cancels the pass either way. What carries it is that only #71 changed attribution code. "~791" is really 789.9-790.6 |
| F24 | BULK coho 2,842.4 -> 52.1-54.7, ~2,790 s | S |
| F25 | 47.1 min (labelled probe 0.6.0 + branch); main 48.7; #71 did most; Phase 3 gate not reached | S |
| F26 | rbind 24.5 / 52.8 -> 2.4 / 5.0; pairwise grows 2.1x; 10x claimed; `identical()` on MORR; BULK membership only | S: 5.0 / 2.4 = 2.08; 10.2-10.6x; log |
| F27 | groups 215.9 vs 178.2 / 174.0; branch runs agree within 2.4% | S: 2.40% of the larger |
| F28 | 1-minute load does not explain it (7.64 vs 7.66) | S: main_bulk_a2_r1 / branch_bulk_a2_r2 load_start |
| F29 | 5- and 15-minute loads higher during the 0.6.4 run; fits contention, does not prove it | S: start 8.06 / 16.83 against 4.93-5.97 / 7.80-8.19; end 7.94 / 13.95 |
| F30 | only the rbind delta is credited | S |
| F31 | rows and fallback counts match the probe (2,391 / 2,218; 1,633 / 6,988) | S: jsons against arm2_timing.json |
| F32 | parallel: 4.0 min against ~17; arm 1 extrapolation ~11 min, unmeasured | S (labelled): 6,753 x 0.07 / 0.73 = 648 s |
| F33 | buffer crop: nothing isolates crop size; issue's ~42 k / ~46 k | S: issue table |
| F34 | polygonizing 21-23% branch, 18-23% at 0.6.4, rbind up to 16%, 18% bundled_300 | S: figures.csv (17.7 rounds to 18) |
| F35 | audit intro: round 2 found defects from one mechanism | n/a (history in review-round2.md) |
| F36 | audit row, roxygen: "all branch-run or #71 records" | **NS**: the 1.4 s rests on the unrecorded re-time |
| F37 | audit row, rbind note | S |
| F38 | audit row, CLAUDE.md: "about 55 -> 324 s wall ... clean runs 52.7-57.7 s vs planning probe 323.7 s" | **NS**: paraphrases a sentence that no longer exists; support is an unrecorded probe plus a wrong range (F3) |
| F39 | audit row, issue quote | S |
| F40 | audit row, issue Outcome | S for the figures (but see O3, O14, O15) |
| F41 | audit row, findings results | S |
| F42 | "Nothing left that names a figure without its run." | **NS**: contradicted by O3, C4 and O14 |
| F43 | Errors Encountered table | n/a (process notes) |

**Count:** 94 table rows (R 14, P 5, C 9, I 8, O 17, F 41, where one F row covers F14-16). 11 NOT SUPPORTED: R1b, C4, C5, O3, O14, O15, F3, F5, F36, F38,
F42. They share the round-3 mechanism, applied to records rather than to figures. An unrecorded
probe is cited as a record (R1b, C4, O14, F36, F38). A recorded range is attributed to the wrong
files (F3). A sentence's verdict is not read back against its own numbers (F5 -> C5 / O15).
