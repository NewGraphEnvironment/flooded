## Outcome

`fl_patch_rm()` and `fl_patch_conn()` zeroed NA input cells on one code path and kept them on the
other. Both now keep NA on every path (`ifel(is.na(kept), x * 0L, x)`). In `fl_valley_confine()` that
alone would have left cells with a DEM value NA whenever cleanup took `fl_patch_rm()`'s early return
(ground a gap cuts off from every stream, slope-NA cells), so the function now zeroes every NA right
after `fl_patch_rm()`, before the majority filter, and `mask(dem)` restores NA where there is no DEM.
That is main's removal path made the only path: NA means only "no DEM" (user decision at the plan
gate). The fix went through two wrong placements, both found by review and kept here: a `mask_cost`
line (Phase 3) that missed slope-NA cells (plan review B1), then a post-mask guard that let the modal
filter skip cells main had counted as 0 votes (code-check round 3).

## Measurement

- Path dependence on main, bundled DEM with a hollow 3-cell NA ring around stream-free ground: the
  625-cell island came out 625 NA at `size_threshold = 1`, 625 zero at 5000. Branch: 0 on both.
- Final code vs main (6b5cd1d), 6 fixtures (rings of width 1, 2 on valley floor; 3-cell ring island;
  supplied-slope NA block on valley floor and on hillslope; bundled tile): identical at
  `size_threshold = 5000` on all; at 1 it differs where main left DEM-valid NA and, on the
  valley-floor slope-NA block, on 28 more cells (1 on main's early path, 0 now; 77 differ in all).
- Wrong turn measured: zeroing after the modal filter gave 120/169 ones on that block vs 92 on main's
  removal path; the island behind a 1-cell ring, 34/121 vs 2. The test pins 92.
- Bundled 10 m tile: output identical to main cell for cell, with and without `slope.tif`.
- stac-dem lidar cache rebuilt in a scratch copy (04:36-05:02 UTC 2026-10-13): both rasters identical
  to the committed cache (NA 115,385 / 11,020; ones 46,656 / 31,030). Not rewritten.
- Parsnip cache recomputed from cached inputs: 441,054 valley cells, 0 cells differ. Not rewritten.
  Its `pars_valleys.tif` has no NA against 10.18 M NA DEM cells (predates #63; outside #65).
- Review: plan review (1 agent) + code-check 4 rounds (ended by enumeration: 18 NA operations,
  33 prose claims).

Closed by: PR for #65 (branch `65-fl-patch-rm-and-fl-patch-conn-turn-na-in`)
