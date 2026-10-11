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

## Errors Encountered

| Error | Resolution |
|-------|------------|
