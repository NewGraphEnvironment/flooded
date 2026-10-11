# Findings — fl_valley_attribute() per-group cost grew 5x from MORR to BULK at the same crop size (#72)

## Issue context

## Problem

The per-blue-line cost of `fl_valley_attribute()` grew about **5x** from MORR to BULK, but each
group's crop barely changed. So something other than crop size sets the per-group cost, and the
attribution model used to budget a region run does not transfer between watershed groups.

Measured in NewGraphEnvironment/floodplains#104 (order >= 2 network, `co_ff04`, 12 threads, by
`blue_line_key`). Evidence: floodplains `scripts/floodplain_lcc/logs/20261010_floodplain_probe-subset_{morr,bulk}.md`
and the arms' `timing.json`.

| | MORR | BULK |
|---|---|---|
| grid | 18.1 M cells | 38.3 M cells |
| blue lines (order >= 2) | 1,711 | 2,550 |
| attribution, order >= 2 | 33.0 min | 170.0 min |
| fit, seconds per blue line | 0.66 (five arms) | ~3.5 (arms 5 and 2) |
| summed crops, estimated | 69 M cells (~42 k per group) | 109 M cells (~46 k per group) |

The crop sums are estimates: each attributed polygon's bounding box plus the 2 km `crop_margin`,
standing in for the stream bounding box `fl_group_cells()` actually crops to. The fixed cost is
#71 and is separate from this.

So BULK's grid is 2.1x and its blue lines 1.5x, mean crop per group is about the same, and the cost
per blue line is about 5x. Attribution is now what decides whether a region run fits its 60 min
per-scenario bound: on BULK the order >= 2 floodplain takes 213 min per scenario, 170 of them here.

## What to do

1. **Profile first.** On BULK's order >= 2 network, time each group's steps in `fl_group_cells()`
   (crop, rasterize, `terra::distance`, `fl_cost_distance()` / `costDist`) and `fl_cells_poly()`,
   against its crop size. The 50 largest groups plus a random sample of small ones is enough. The
   question is what in a group's cost depends on the full grid (raster on disk under `memfrac`, a
   full-extent read or copy, threading) and not on the crop.
2. **Then the fixes, by expected payoff.** Each must give identical membership to today's on the
   bundled tile and on MORR, or the difference is measured and accepted:
   - **Groups in parallel.** Groups are independent, so the answer cannot change. Bounded by cores
     and by per-worker memory (GDAL reserves ~3 GB per process; PSOCK workers, not forks, on
     macOS). Expect 4-6x on 12 cores, not 12x.
   - **Buffer-shaped crop** (#44's option 1): mask the crop to a `crop_margin` buffer around the
     group's lines instead of its bounding box. Same margin, fewer cells for a long diagonal river.
   - **Whatever the profile names**, if it is a full-grid operation repeated per group.
   - **Optional cell-table output.** For habitat joins a group -> cell table is enough
     (floodplains#104's join takes polygons back to cells), so polygonizing every group may be
     wasted. That adds to the interface, so only if the profile shows `fl_cells_poly()` matters.

## Acceptance

- [ ] Profile recorded (per step, per group, against crop cells) for BULK.
- [ ] Order >= 2 attribution on BULK measured after the fix, with #71 in, against the 60 min
      per-scenario bound (DEM fetch and delineation included, ~43 min of the 213 today).
- [ ] Membership identical to today's on the bundled tile and MORR (per group, per cell).
- [ ] Performance section of `fl_valley_attribute()` revised with measured figures.

## Related

- #44: the first scale measurement (MORR, k = 340). Its comment found crop efficiency improved at
  scale and the cost was k-independent; at order >= 2 and on BULK the per-group part is no longer
  small.
- #71: the `complete = TRUE` fallback, the fixed half of the cost.

## Run-to-run variation: the planning probes are not usable, and their cause is not established

The planning probes on BULK coho (main, file-backed valleys) took 323.7 s wall (`complete =
TRUE`, slope supplied) and, in a later Rprof run, 338.1 s. Later runs of the same configuration
took 52.7-57.7 s wall (`bench/main_filebacked_bulk_co_r*.json`). **Neither slow run has a committed
record** (session output only; the Rprof run's files were discarded), and the load averages do not
separate the slow runs from the fast ones: about 7 / 24 / 31 (1/5/15 min) during the planning
probes against 6.2-7.7 / 15.6-17.0 / 25.8-27.0 at the start of the fast ones. Other sessions do run
R jobs on this machine, so contention is a candidate, not a finding. What follows from it either
way: the planning-time split (108 s group work + 37 s polygonize + "130 s unexplained") came from
three different slow runs and is discarded, and the bench records CPU time and load averages and
repeats runs.

floodplains' probe logs (`/usr/bin/time -l` in `data/<area>/probe_whole_fwa/logs/<arm>.log`) do
carry a direct sign of contention for two of the 0.6.0 BULK runs, wall well above CPU:

| run | real s | user s | involuntary ctx switches |
|---|---|---|---|
| MORR arm 2 | 2,100.8 | 2,123.8 | 247,309 |
| MORR coho | 910.4 | 915.2 | 106,169 |
| BULK coho | 3,016.5 | 3,004.3 | 356,396 |
| BULK arm 3 | 4,857.5 | 4,549.3 | 1,867,073 |
| BULK arm 2 | 10,573.9 | 8,527.8 | 4,820,490 |

BULK arm 2 spent ~2,000 s more wall than CPU; its 8,528 s of CPU is still real work (the DEM was a
separate mode; delineation ~356 s). BULK coho was not contended.

## Session probes not kept as records

Recorded here so their use is visible; none of them carries a decision on its own.

- 80 small BULK coho groups through `fl_group_cells()` at main: 11.8 s wall / 9.5 s CPU at 12
  threads, 10.2 / 9.9 at 1 thread, 8.9 / 8.9 at memfrac 0.8; no temp files written. Read as: thread
  count does not set the per-group cost.
- The slow Rprof run put 28% of its CPU samples under terra's `spatOptions()` (built on every terra
  call). Not repeated on a quiet run, so not a finding.
- Bundled delineation re-timed at 1.32-1.47 s wall (6 s CPU), for the roxygen's 1.4 s.

## Plan review

`review-plan.md`: B1 (PSOCK workers would load the installed flooded 0.6.0), A3 (bench valleys
were file-backed LZW one-row strips; production attributes the in-memory raster — bench now uses
`terra::toMemory()`), G1/G2 (one run with section checkpoints — bench e2e now traces
`fl_valley_attribute()` at its top-level statements), M1 (bundled crops mostly clamp to tile
edges — oracle test carries a non-vacuity check).

## Baselines and result (in-memory valleys, 12 threads, CPU s, `complete = TRUE`)

Per-section CPU s from the e2e checkpoints (`bench/*_sections.csv`). Membership (per group, per
cell) identical main vs branch on all six inputs (`*_cells.rds`, not committed — 20 MB).

| input | groups | main total | main: groups / polygonize / rbind | branch total | branch: groups / polygonize / rbind |
|---|---|---|---|---|---|
| bundled | 5 | 0.91 | 0.62 / 0.21 / 0.00 | 0.91 | 0.64 / 0.19 / 0.01 |
| bundled_300 | 5 | 0.94, 1.05 | — | 0.96 | 0.65 / 0.17 / 0.01 |
| MORR coho | 340 | 40.0, 39.3 | 27.8 / 8.6 / 1.7 | 38.2 | 26.8 / 8.5 / 0.9 |
| BULK coho | 428 | 52.1, 54.7 | 35.8 / 10.7 / 2.5 | 49.5 | 35.1 / 10.5 / 0.9 |
| MORR order >= 2 | 1,711 | 190.7 | 123.4 / 40.1 / 24.5 | 155.1 | 114.1 / 36.1 / 2.4 |
| BULK order >= 2 | 2,550 | 332.9 | 215.9 / 59.3 / 52.8 | 240.2, 238.2 | 178.2, 174.0 / 52.9, 55.2 / 5.0, 5.0 |

- **The issue's premise does not survive at 0.6.4.** Per group, BULK and MORR are within 20%, not
  5x. The groups pass is unchanged between the trees; per group it took 0.085 vs 0.072 s (order
  >= 2) and 0.084-0.091 vs 0.078-0.082 s (coho) in the 0.6.4 runs, 0.068-0.070 vs 0.067 s and
  0.082 vs 0.079 s in the branch runs (`bench/figures.csv`). The 0.6.0 figures
  (MORR order >= 2 33 min, BULK 170 min) were the old full-grid fallback, which grew with network
  size, plus contention on the BULK arm 2 and 3 runs. On one grid (MORR) attribution fell 1,791 s
  from 0.6.0 to 0.6.4 on order >= 2 (1,981.9 -> 190.7 s) against ~791 s on coho (829.9 -> 39.3-40.0 s),
  with the per-group pass about equal per group, so the old pass cost about 2.3x more on the larger
  network. BULK coho: 2,842.4 -> 52.1-54.7 s, ~2,790 s. (0.6.0 figures: the probe's
  `arm*_timing.json` `t_attr_blk_s`.)
- **BULK order >= 2 against the 60 min per-scenario bound:** DEM 37.2 + delineation 5.9 (probe,
  0.6.0) + attribution 4.0 (branch) = **47.1 min**. Main was already 48.7 min, so #71 did most of
  this; the gate for Phase 3 (over ~17 min) is not reached.
- **`do.call(rbind, parts)` was the one step worth changing:** 24.5 s at 1,633 rows, 52.8 s at
  2,391; pairwise binding 2.4 / 5.0 s. The pairwise bind also grows 2.1x between the two, so these
  data do not isolate a growth law in the group count; the 10x is what is claimed. `identical()`
  to `do.call(rbind)` on MORR order >= 2's 1,633 captured parts (`bench/rbind_identity_morr_a2.log`)
  and in the unit test; on BULK only membership was compared.
- The groups pass, unchanged between the trees, took 215.9 s CPU in the one 0.6.4 run on BULK
  order >= 2 and 178.2 / 174.0 s in the two branch runs (which agree within 2.4%). The 1-min load
  does not explain it (7.64 at the 0.6.4 start, 7.66 at the faster branch repeat); the 5- and
  15-min loads were higher during the 0.6.4 run (8.06 / 16.83 against 4.93-5.97 / 7.80-8.19), which
  fits contention but does not prove it. Only the rbind delta (52.8 -> 5.0 s) is credited to the
  change.
- Rows and fallback counts match the floodplains probe's own (BULK order >= 2: 2,391 rows,
  2,218 fallback cells; MORR: 1,633 / 6,988).

## Out of scope, with the numbers behind it

- **Parallel groups (`workers`):** not built. BULK order >= 2 is 4.0 min serial against ~17 min of
  budget. The design (PSOCK, B1's installed-package trap, review P1-P7) is in `review-plan.md` if
  arm 1 (all FWA, 6,753 blue lines) ever needs it; extrapolating order >= 2's 0.07 s/group at
  73% of the total gives roughly 11 min, unmeasured.
- **Buffer-shaped crop (#44 option 1):** nothing here isolates crop size, and the issue estimated
  similar mean crops on both grids (~42 k vs ~46 k cells). With the bound met at 47.1 min there is
  no case for a change that risks membership.
- **Cell-table output:** on the branch, polygonizing is 21-23% of the total on all four watershed
  networks (18-23% in the 0.6.4 runs, where rbind took up to 16%; 18% on the bundled tile at
  `cost_threshold = 300`); not worth an interface addition on these numbers.

## Claims audit (code-check round 2 enumeration)

Round 2 found defects inside round 1's fixes, both from one mechanism: a number quoted without the
tree or run it came from, or a subset generalised to "every". Every figure in each prose surface
written on this branch, checked against `bench/figures.csv`, the run jsons, the #71 archive and the
floodplains probe logs:

| surface | figures | verdict |
|---|---|---|
| roxygen Performance | bundled 0.9 s / 1.4 s (wall; delineation re-timed 1.32-1.47 s); table 38 / 155 / 50 / 240 s and 18.1 M / 38.3 M cells; 70-75%; 0.07 / 0.08 s per group; 805.6 / 855.8 / 0.4 s (#71); 52.8 -> 5.0 s; cells unchanged | all branch-run or #71 records; 0.7 s corrected to 0.9 s |
| `fl_rbind_pairwise()` note | 24.5 / 52.8 / 2.4 / 5.0 s; 1,633 / 2,391 groups | section CSVs (CPU) |
| CLAUDE.md | 805.6 / 855.8 s; about 55 -> 324 s wall; 216 vs 174-178 s | #71 archive; clean runs 52.7-57.7 s vs planning probe 323.7 s; figures.csv |
| issue body, quote | 0.085 vs 0.072, 0.068-0.070 vs 0.067; coho 0.084-0.091 vs 0.078-0.082, 0.082 vs 0.079; 2,790 of 2,842 s; 10,574 / 8,528 s | figures.csv per_group; arm5 0.6.0 2,842.4 - 52.1; probe log 2 |
| issue body, Outcome | table (0.6.4 39.3-40.0 / 190.7 / 52.1-54.7 / 332.9; branch 38.2 / 155.1 / 49.5 / 238.2-240.2); 47.1 and 48.7 min; 70-75% / 21-23% branch, 65-71% / 18-23% at 0.6.4, rbind up to 16%; 4.0 min | figures.csv; probe dem/delineation 37.2 / 5.9 min |
| findings.md results | as above, each now labelled 0.6.4 run or branch run | figures.csv |

Nothing left that names a figure without its run.

## Errors Encountered

| Error | Resolution |
|-------|------------|
| `identical(cells, real)` failed in `steps` | empty groups: `integer(0)` vs `numeric(0)`; compare `as.numeric()` |
| issue body posted with backticked code missing | an unquoted heredoc ran the backticks as command substitutions; build bodies from a quoted-heredoc script, grep the file, then post |
| bench section marker failed on the branch | it matched the `do.call(rbind` line the fix removed; marker matches either form |
| only the last section checkpoint fired | a second `trace()` replaces the first; one call with an ordered counter |
