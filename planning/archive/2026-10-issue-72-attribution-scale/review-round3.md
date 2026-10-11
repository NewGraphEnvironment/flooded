# Code-check round 3 — #72 branch (vs 1077e17)

## Mechanism

R1 and R2's defects, and the ones below, share one assumption: **a figure that exists in a
record is taken to support the sentence built around it.** The claims audit in findings.md
checks the first half (each number traces to figures.csv, a json or a log) and never the second
(does that record support the *cause*, *scope* or *growth law* the sentence asserts). So it marks
fine every sentence whose numbers are right and whose inference is not. R2's "216 -> 174 s was
contention" was this exact shape and was fixed; the same shape survives elsewhere.

Verified independently and correct: every number in the roxygen table, the 70-75% / about a fifth
/ 0.07 and 0.08 s per group, 18.1 M / 38.3 M cells, 805.6 / 855.8 / 0.4 s (like-for-like in the #71
log: `t_old_distance_s` vs `t_new_nearest_s`), the issue body's per-group ranges, 65-71% / 18-23% /
up to 16%, 47.1 and 48.7 min (dem.json 2230.3 s, arm2 `t_delin_s` 355.7 s), 10,574 / 8,528 s and the
other `/usr/bin/time` rows, rows and fallback counts against the probe's `arm*_timing.json`.
Membership: I re-compared the committed-tree `*_cells.rds` main vs branch on all six inputs —
identical on every one (and branch bulk_a2 r1 == r2). Test file: 22 blocks, 0 failed, 0 errors.

## Findings

- **[fragile] CLAUDE.md:120 (added), issue #72 body Outcome last bullet, findings.md:67-76** —
  "One input's wall time moved from about 55 s to 324 s **with load**." The recorded load does not
  separate the two runs. The 55 s runs are `main_filebacked_bulk_co_r1/r2` (57.7 / 54.9 s), whose
  own jsons record load `{ 6.23 16.97 26.98 }` -> `{ 7.69 15.56 25.77 }` and
  `{ 7.69 15.56 25.77 }` -> `{ 7.25 13.92 24.46 }`; the 324 s probe is quoted at 7 / 24 / 31. The
  1-min load is the same (6.2-7.7 vs 7), and findings' table labels the 55 s runs "clean" while
  their 15-min load is 24-27 on 10 cores. The 323.7 s probe and its 7/24/31 have no committed
  record at all (grep finds them only in task_plan/findings prose), and it was a different
  configuration (slope supplied vs derived from dem). This is R2's defect again — a contention
  cause the load data do not support — in the sentence R2's fix left standing, and it is in
  CLAUDE.md, the durable rule. State the observation (same input, same tree, 55 s vs 324 s wall,
  cause not established by the recorded load) or drop the "with load".

- **[fragile] R/fl_valley_attribute.R (roxygen, "grew with the square of the group count") and the
  `fl_rbind_pairwise()` @noRd note; man/fl_valley_attribute.Rd; issue body Outcome "Profile";
  findings "The one superlinear term left"** — the only evidence cited is 24.5 s at 1,633 rows ->
  52.8 s at 2,391 (2.16x for 1.46x). The branch's own records show the *pairwise* bind growing by
  the same factor between the same two inputs: 2.40 s -> 4.97 / 5.00 s (2.08x for 1.46x;
  `branch_morr_a2_r1`, `branch_bulk_a2_r1/r2` rbind cpu). A synthetic probe (one small
  multipolygon per row, same `pw()` code) shows what a count-only effect looks like:
  do.call 1.64 -> 3.71 s (2.26x) but pairwise 1.80 -> 2.67 s (1.48x, linear). So between MORR and
  BULK something other than group count (polygon size/vertex count) roughly doubles the bind cost,
  and the 2.16x cannot be read as "the square of the group count", nor can the branch's 5.0 s be
  read as the superlinear term removed. The speed-up itself (10x at equal inputs) is real; the
  growth law attached to it is not shown by these data. Either cite the synthetic count-only
  scaling or drop "with the square of the group count".

- **[fragile] `fl_rbind_pairwise()` @noRd note ("gives an `identical()` result in 2.4 s and 5.0
  s"), issue body ("returns an `identical()` result"), findings ("`identical()` output")** — no
  record shows `identical()` was evaluated on the MORR/BULK outputs; the e2e harness saves only
  (group, cell) tables, and the only `identical()` check is the unit test on 7 synthetic parts.
  The property very likely holds (automatic row names, same columns; my 2,391-row synthetic probe
  is also identical), but the sentence presents it as measured at those inputs. Say "per-group
  cells identical on all six inputs; `identical()` checked in the unit test", or record the check.

- **[fragile] planning/active/findings.md:67-110 and task_plan.md Phase 4 box "Profile and bench
  logs committed"** — R1's mechanism (unrecorded side-probe timings) in sections the claims audit
  does not list: the contended Rprof run (338.1 s, 101 s sampled), "80 small groups ... 11.8 s
  wall / 9.5 s CPU ... 10.2 / 9.9 ... 8.9 / 8.9", "28% under terra's `spatOptions()`", and the
  roxygen audit row's "delineation re-timed 1.32-1.47 s". No `*_steps.csv`, `*.rprof`,
  `*_by_total.csv` or json for any of them is in `planning/active/bench/` (its .gitignore drops
  only `*.rds`), yet the box is ticked and the "Out of scope: buffer-shaped crop" decision leans on
  the "R-level overhead, not crop size" conclusion. Either commit the outputs or mark these figures
  as unrecorded.

- **[fragile, minor] findings.md "Baselines and result" bullet 1** — "plus contention on the BULK
  runs": the 0.6.0 BULK coho run was not contended (`bulk/.../logs/5.log`: 3,016.5 real vs 3,004.3
  user); only arms 2 and 3 were. A quantifier generalised from a subset, R1's other shape.

## Code

`fl_rbind_pairwise()`, the two new tests, `bench_attribution.R` and `extract_arm2.R`: no bugs
found. The oracle test's 11 expectations (1 non-vacuity + 2 thresholds x 5 groups incl. NA) run
and pass; checkpoint ordering in the bench matches body order; the rbind section also contains
`fl_check_out()` and `attr<-`, which is negligible.
