## Outcome

`fl_valley_attribute(complete = TRUE)` placed the valley cells no group reached with one full-grid
`terra::distance(values = TRUE)`, a pass whose cost was set by the grid and not by the handful of
cells it placed. The internal `fl_nearest_group()` now takes the same nearest-burned-cell rule
straight from those cells: `sf::st_nearest_feature()` from their centres to the burned stream
cells' centres in the same `idx_r`. The count, the message and the seed raster are unchanged.
Two groups whose burned cells are equally near may now resolve the other way (accepted in #71).
The plan review measured that tie on 1 cell of 9,904 on the bundled tile. A lowest-index
tie-break that reproduces terra exactly was considered and rejected: on MORR the nearest
distance reaches kilometres, so the candidate search would cost what the fix removes
(`review-plan.md`). An oracle test rebuilds the old assignment from exported primitives and
fails when the rule is swapped for the tempting wrong one, the nearest stream *line*.

## Measurement

MORR arm 5 (floodplains#110 cache, coho network, 340 blue lines, 18.1 M cells, co_ff04), host m1,
12 terra threads, terra 1.9.50, GEOS 3.13.0. Runs were sequential, before and after on the same
machine:

- Attribution with `complete = TRUE`: **855.8 s on main -> 37.8 s**. With `complete = FALSE` it
  takes 35.2 s, so the fallback now adds about 2.6 s.
- The fallback step alone: **805.6 s -> 0.4 s** (42,615 burned cells, 14,170 queries).
- Assignments are identical: 0 of 14,170 cells differ, and 0 of 339 groups differ in cell count.
- The issue's ~790 s intercept is gone. The remaining attribution cost is per-group (#72).

One wrong turn: the first "before" run overlapped the plan reviewer's R probes, so it was killed
and re-run clean. The 855.8 s figure is from the clean run, close to the probe's 829.9 s at 0.6.0.

## Evidence

`planning/archive/2026-10-issue-71-fallback-nearest-cell/bench_fallback.*` (script and log).
Reviews: `review-plan.md`, `review-round*.md`.

Closed by: PR for #71
