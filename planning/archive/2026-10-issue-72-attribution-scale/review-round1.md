# Review round 1 — branch 72 vs main (merge-base 1077e17)

## Verified (no issue)

- `fl_rbind_pairwise()` is `identical()` to `do.call(rbind, x)` beyond what the shipped test covers.
  Probed n = 1, 2, 3, 4, 5, 9, 17, 50 with mixed POLYGON / MULTIPOLYGON / GEOMETRYCOLLECTION parts and a
  factor group column, multi-row parts, non-automatic row names, a character group with NA last,
  and a zero-row part in the middle: all `identical()`.
- Membership main vs branch: re-read the six `*_r1_cells.rds` pairs; all `identical()` (bundled 65,495,
  bundled_300 33,133, morr_co 748,569, bulk_co 766,830, morr_a2 1,697,149, bulk_a2 1,871,376 rows).
  The roxygen claim "every group's cells unchanged on all four networks" holds.
- Oracle test fires: in a copy, shifting `fl_group_cells()`'s local -> global cell map by one turned
  10 of its 11 expectations red (plus three older tests). Test file green on the unmodified copy
  (22 blocks, 0 failed, 0 error, NOT_CRAN=true).
- Roxygen Performance numbers match the branch records: 38 / 155 / 50 / 240 s CPU; 18.1 M / 38.3 M
  cells; 340 / 1,711 / 428 / 2,550 groups; per-group pass 70.2-74.2% of total; 0.067/0.070 s
  (order >= 2) and 0.079/0.082 s (coho) per group; polygonize 21-23%; rbind 52.77 s CPU main -> 4.97 /
  5.00 s branch on BULK order >= 2. findings.md's baseline table and the 47.1 / 48.7 min budget sums
  also check out.

## Findings

- **[fragile] R/fl_valley_attribute.R:298-301** (`fl_rbind_pairwise()` roxygen, @noRd) — states
  "21.2 s for MORR's 1,633 order >= 2 groups and 52.9 s for BULK's 2,391 ... `identical()` result in
  2.3 s on MORR". None of these is in the committed records: main_morr_a2_r1 rbind section is
  **24.50 s CPU / 24.57 s wall**, main_bulk_a2_r1 is **52.77 s CPU / 52.89 s wall** (the public roxygen
  above says 52.8, CPU), and branch_morr_a2_r1 is **2.40 s CPU / 2.41 s wall**. findings.md says 24.5 /
  2.4. The 21.2 and 2.3 appear to come from an earlier unrecorded probe (the 2c6a148 commit message
  carries the same figures). Use the recorded 24.5 / 52.8 / 2.4.

- **[fragile] CLAUDE.md:119-120** — "one input's wall time moved 5x with load while its CPU time
  held (#72)". The records do not support the CPU half. For that input (BULK coho, main), the
  contended planning probe recorded no CPU time ("—" in findings.md), and the only contended CPU
  figure is the Rprof run's 101 s sampled, which review-plan.md G3 identifies as Rprof's default
  CPU sampling, against 54.9-56.5 s CPU on the clean runs. So CPU nearly doubled under contention
  (some of it Rprof overhead), rather than holding. The floodplains `/usr/bin/time` table in
  findings.md likewise shows user time rising with contention (BULK arm 2: 8,528 s user). The rule
  "time with CPU, not wall" may still be the right one, but CLAUDE.md is read as settled guidance
  and its stated evidence is unmeasured. Either cite a contended run whose CPU was measured, or
  restate it as "wall time moved 5-6x with load; the clean runs' CPU ≈ wall".

- **[fragile] CLAUDE.md:120** — the harness is cited at
  `planning/archive/2026-10-issue-72-attribution-scale/bench_attribution.R`, which does not exist
  yet. It is correct only if `/planning-archive` picks exactly the slug `attribution-scale`. The
  branch name would derive `fl-valley-attribute-per-group-cost-grew`. Check the path after archiving,
  or the pointer dangles the way #71's line was the one it replaced.

- **[fragile, minor] planning/active/findings.md:157** — "polygonizing is 21-23% of the total on
  **every** input". bundled_300 branch is 0.17 / 0.96 = 17.7%, bundled main 0.21 / 0.91 = 23.1%. True for
  the four watershed networks, not every input. It is the rationale for the out-of-scope decision,
  so scope it to the watershed networks.

- **[fragile, minor] planning/active/task_plan.md** — two ticked boxes describe work that did not
  land as written. Phase 1, box 2: the harness has modes `e2e`, `rprof` and `steps`, not
  `cells` / `profile` (the cells table is written by `e2e`). Phase 2, box 2: "pins per-group membership
  to a pre-change snapshot" became an uncropped-oracle test. That is arguably stronger, but it is not
  a snapshot. Annotate both the way the Phase 1 box 3 replacement is annotated, so the Validation
  item "PWF checkboxes match landed work" can pass.

No bugs or security issues in the package change. `fl_rbind_pairwise()` is behaviour-preserving and
the tests guard it.
