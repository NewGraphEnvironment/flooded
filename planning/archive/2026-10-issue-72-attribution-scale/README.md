## Outcome

#72 reported that `fl_valley_attribute()`'s cost per blue line grew about 5x from MORR to BULK at
the same crop size, and that BULK's order >= 2 attribution took 170 min. Re-measured at 0.6.4, with
#71 in, the premise did not hold: per group, BULK and MORR are within 20%. The 0.6.0 figures were
mostly #71's full-grid fallback, whose cost grew with network size, so a fit across networks read
it as a per-group cost. The BULK order >= 2 run was also contended (about 2,000 s more wall than
CPU). The profile is per section of one timed call. It found no full-grid work repeated per group.
The one step worth changing was `do.call(rbind, parts)`, now `fl_rbind_pairwise()`, whose result is
`identical()` on MORR's captured parts and in the unit test.

Two things were not built, because the 60 min per-scenario bound is already met: parallel groups
(a `workers` argument, agreed at the plan gate if needed) and the buffer-shaped crop. Polygonizing
is about a fifth of the total, so a cell-table output was not added either. The plan review's
Phase 3 design (`review-plan.md`, B1 and P1-P7) is kept here for when a network needs it.

**What was learned:** timings on the bench machine vary from run to run, CPU time included. An
unchanged section took 216 s in one run and 174-178 s in two later ones. The first probes of
this issue were about 5x slower than later runs of the same input, and their cause was never
established. They produced a "130 s unexplained" gap that did not exist. The harness records
CPU time and load averages and repeats runs, and only the rbind delta is credited to the change.

`/code-check branch` ran four rounds. None found a code defect. All 25 findings were prose claims
(5, 4, 5 and 11 of a 94-claim enumeration) whose records did not support the number, run, cause,
scope or growth law stated. Round 3 named the mechanism: a figure that appears in some record was
treated as licensing the sentence around it. Round 4's enumeration ended the loop.

## Measurement

CPU s, `complete = TRUE`, 12 terra threads, in-memory valleys. Inputs are floodplains' cached
probe data (`co_ff04`). The "0.6.4" columns are runs at 1077e17, the "branch" columns at 2c6a148:

| input | blue lines | 0.6.4 | branch | rbind 0.6.4 -> branch |
|---|---|---|---|---|
| MORR coho | 340 | 39.3-40.0 | 38.2 | 1.7-1.8 -> 0.9 |
| MORR order >= 2 | 1,711 | 190.7 | 155.1 | 24.5 -> 2.4 |
| BULK coho | 428 | 52.1-54.7 | 49.5 | 2.2-2.5 -> 0.9 |
| BULK order >= 2 | 2,550 | 332.9 | 238.2-240.2 | 52.8 -> 5.0 |

- **BULK order >= 2 against the 60 min bound:** DEM 37.2 min + delineation 5.9 min (wall,
  floodplains' 0.6.0 probe) + attribution 4.0 min (CPU, branch) = 47.1 min. At 0.6.4 it was already
  48.7 min, so #71 met the bound.
- **Per group, the per-group pass** took 0.072 s (MORR) and 0.085 s (BULK) per group on order >= 2
  in the 0.6.4 runs, and 0.067 and 0.068-0.070 s in the branch runs.
- **Membership:** every group's cells are identical between 0.6.4 and the branch on all six
  inputs (bundled at the default and at `cost_threshold = 300`, plus the four networks).
- **What changed because of it:** the issue body was revised (its premise did not hold), Phase 3
  was gated out, and the Performance section of `fl_valley_attribute()` now carries these figures.

Wrong turns kept in `findings.md`:
- the planning probes and their "130 s gap";
- an unsupported contention cause and an unsupported "square of the group count" growth law, both
  withdrawn in review;
- the section tracer that recorded only its last checkpoint;
- a bench marker that broke on the fix it was measuring.

## Evidence

- `bench/{main,branch}_*.json`, `bench/*_sections.csv`, `bench/figures.csv`
- `bench/rbind_identity_morr_a2.log`, `bench/bundled_delineation.log`
- Harness: `bench_attribution.R`. The arm 2 networks were extracted with `extract_arm2.R` into
  floodplains' `data/<area>/probe_whole_fwa/arm2_streams.gpkg`.
- Reviews: `review-plan.md`, `review-round*.md`.

The `bench/*_cells.rds` cell tables are gitignored (20 MB) and live only on the machine that ran
them.

Closed by: PR for #72
