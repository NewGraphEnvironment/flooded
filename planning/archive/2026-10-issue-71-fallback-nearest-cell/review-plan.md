# Plan review — #71 (Plan agent, 2026-10-11)

The reviewer measured these on the bundled tile (10 m, 518,400 cells, 1,607 burned cells) with
read-only Rscript runs:

| grouping, thresholds | uncovered | differ | of which ties | old pass | new helper |
|---|---|---|---|---|---|
| gnis_name, ct = 300 | 9,904 | 1 | 1 | 2.5 s | 0.03 s |
| blue_line_key, ct = 300 | 9,904 | 1 | 1 | 2.5 s | 0.03 s |
| gnis_name, max_width = 10 | 27,336 | 22 | 22 | 2.5 s | 0.07 s |

Disposition of each finding:

1. **The plan said the per-group sets must "equal" the oracle's.** One cell differs at ct = 300,
   and it is a tie. Fixed: the plan now says "equal except for measured ties", which is what the
   test asserts.
2. **Ties depend on GEOS's STRtree walk.** terra picked the lowest burned-cell index in 39 of 39
   tie cells on the tile. *Not adopted.* A lowest-index re-selection needs every burned cell
   within the nearest distance, and on MORR that distance reaches kilometres for lake cells.
   That makes a window or within-distance search cost O(uncovered x d^2), which is the cost #71
   removes. The issue's acceptance allows a measured tie. GEOS is recorded in the bench JSON.
3. **MORR cells are not exactly square** (30.430771987308916 x ...923), so a tie there is equal
   only to within float noise. The bench reports the maximum distance gap in metres, judged
   against that noise.
4. **Max-of-overlap and cell order cannot be tested on this tile.** Noted as untested in
   findings.md. Both the old and new code read the same `idx_r`, so the overlap rule cannot
   diverge between them.
5. **The planned mutation was too weak.** Replaced with "nearest stream line instead of nearest
   burned cell", which differs in 10 cells at ct = 300.
6. **Bound the number of differing cells.** *Not adopted.* The gap check already rejects any cell
   that is not a tie, and a count bound would make the test depend on the GEOS version.
7. **CRS.** The helper's comment now states the projected-metres assumption, and that lon/lat
   follows `sf_use_s2()`.
8. **Threads.** Already set in `bench_fallback.R`. The runs are sequential.
9. **Check end-to-end equality on MORR.** e2e mode writes per-group counts, records warnings, and
   asserts the single warning names 360652838.
10. **The helper mode re-runs the 800 s pass.** Kept on purpose: it is the only per-cell
    comparison at MORR scale, and its timing isolates the pass.
11. **Inputs and timing hygiene.** Inputs are read outside the timer, and `dem =` is passed, as
    in the baseline.
12. **The remaining costs are minor.** Agreed. Phase 3 measures them.
13. **The docs depend on finding 2.** Since 2 was not adopted, the docs say ties may resolve
    either way.

Note: the reviewer's probe runs overlapped the first "before" timing run. That run was killed
and restarted once the reviewer had finished.
