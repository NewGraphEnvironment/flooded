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

## Contention: the planning probes and the 0.6.0 BULK arm 2 run were measured on a busy machine

Other sessions run R jobs on this machine, and a VM and `mediaanalysisd` hold about two cores
steadily. Load averages during the planning probes were 7 / 24 / 31 (1/5/15 min) on 10 cores. Wall
time on one input moved 5x with it:

| BULK coho, main (0.6.4), `complete = TRUE` | wall s | CPU s |
|---|---|---|
| planning probe (slope supplied) | 323.7 | — |
| contended Rprof run | 338.1 | 101 sampled |
| clean, file-backed valleys, r1 / r2 | 57.7 / 54.9 | 56.5 / 54.9 |

So the planning-time split (108 s group work + 37 s polygonize + "130 s unexplained") came from
three different contended runs and is an artefact. The bench now records CPU time and the load
average at start and end of every run, and repeats the e2e runs.

floodplains' own probe shows the same for the 0.6.0 BULK arm 2 run behind the issue's 170 min
(`/usr/bin/time -l` in `data/<area>/probe_whole_fwa/logs/<arm>.log`):

| run | real s | user s | involuntary ctx switches |
|---|---|---|---|
| MORR arm 2 | 2,100.8 | 2,123.8 | 247,309 |
| MORR coho | 910.4 | 915.2 | 106,169 |
| BULK coho | 3,016.5 | 3,004.3 | 356,396 |
| BULK arm 3 | 4,857.5 | 4,549.3 | 1,867,073 |
| BULK arm 2 | 10,573.9 | 8,527.8 | 4,820,490 |

BULK arm 2 lost ~2,000 s of wall to contention; its 8,528 s of CPU is still real work (DEM
excluded — it was a separate mode; delineation ~356 s).

## Per group, BULK coho is not 5x MORR coho at 0.6.4

Clean, main, `complete = TRUE`, file-backed valleys: MORR coho 38.75 / 38.63 s for 340 blue lines
(0.11 s/group), BULK coho 57.7 / 54.9 s for 428 (0.13 s/group). The 0.6.0 BULK coho run was
2,842 s, so the old full-grid fallback cost ~2,790 s on BULK against 805.6 s on MORR (#71). Whether
the arm 2 gap is the same story — the old fallback growing with burned stream cells, which the
issue's cross-arm fit read as a per-blue-line slope — is what the arm 2 baselines answer.

## Per-group cost is R-level overhead, not crop work or threads (BULK coho, 80 small groups)

80 small groups through the real `fl_group_cells()`: 11.8 s wall / 9.5 s CPU at 12 threads,
10.2 / 9.9 at 1 thread, 8.9 / 8.9 at 12 threads with memfrac 0.8 (load ~7). No temp files written
(`mem_info`: slope 0.29 GB needed, fits in memory). So ~0.12 s per small group, CPU-bound in one
thread. The contended Rprof (`by.total`, discarded for wall time but its proportions are CPU) put
28% under terra's `spatOptions()` — terra builds an options object (incl. a `tempfile()` name) on
every call, and a group makes ~35 terra calls.

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

- **The issue's premise does not survive at 0.6.4.** Per group, BULK and MORR cost the same
  (groups pass 0.070 vs 0.067 s on order >= 2, 0.082 vs 0.079 s on coho). The 0.6.0 figures
  (MORR order >= 2 33 min, BULK 170 min) were the old full-grid fallback, which grew with network
  size (BULK coho alone: ~2,790 s), plus contention on the BULK runs.
- **BULK order >= 2 against the 60 min per-scenario bound:** DEM 37.2 + delineation 5.9 (probe,
  0.6.0) + attribution 4.0 (branch) = **47.1 min**. Main was already 48.7 min, so #71 did most of
  this; the gate for Phase 3 (over ~17 min) is not reached.
- **The one superlinear term left was `do.call(rbind, parts)`:** 24.5 s at 1,633 rows -> 52.8 s at
  2,391 (1.46x rows, 2.16x time). Pairwise binding: 2.4 / 5.0 s, `identical()` output.
- The groups pass moved 216 -> 174-178 s on BULK order >= 2 with no change to it: load (main ran at
  1-min load 7.6, the branch at 4.3-7.7). Only the rbind delta is attributable to the change.
- Rows and fallback counts match the floodplains probe's own (BULK order >= 2: 2,391 rows,
  2,218 fallback cells; MORR: 1,633 / 6,988).

## Out of scope, with the numbers behind it

- **Parallel groups (`workers`):** not built. BULK order >= 2 is 4.0 min serial against ~17 min of
  budget. The design (PSOCK, B1's installed-package trap, review P1-P7) is in `review-plan.md` if
  arm 1 (all FWA, 6,753 blue lines; ~8 min at 0.07 s/group) or a larger group ever needs it.
- **Buffer-shaped crop (#44 option 1):** the per-group pass is per-group overhead, not crop size,
  on these networks; no measured payoff.
- **Cell-table output:** polygonizing is 21-23% of the total on every input; not worth an
  interface addition on these numbers.

## Errors Encountered

| Error | Resolution |
|-------|------------|
| `identical(cells, real)` failed in `steps` | empty groups: `integer(0)` vs `numeric(0)`; compare `as.numeric()` |
| issue body posted with backticked code missing | an unquoted heredoc ran the backticks as command substitutions; build bodies from a quoted-heredoc script, grep the file, then post |
| bench section marker failed on the branch | it matched the `do.call(rbind` line the fix removed; marker matches either form |
| only the last section checkpoint fired | a second `trace()` replaces the first; one call with an ordered counter |
