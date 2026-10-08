## Outcome

`fl_valley_confine()` now returns `NA` where the DEM is `NA`, as its roxygen already promised.
Before, it usually returned 0 or 1 there. `fl_patch_rm()` zeroes NA whenever some patch is small
enough to remove, and the focal filters smear 1s into a gap. The fix masks by the DEM after
cleanup and *before* the channel-buffer and waterbody overlays (user decision: the overlays do not
depend on the DEM, so a channel or lake in a gap stays valley). Three tests punch a synthetic NA
block into the bundled DEM, which has none. The stac-dem lidar cache was rebuilt and its NA counts
are pinned by a test. The vignette draws the lidar gap in tan.

What was learned: nearly every finding across seven code-check rounds on two commits was one
mechanism. A sentence about model output was written from one code path, with an absolute
("never", "all", "always"), and missed `fl_patch_rm()`'s early return, the focal smear, the
overlays, or the flood model reading the DEM directly. The root-cause helpers are filed as
[#65](https://github.com/NewGraphEnvironment/flooded/issues/65).

## Measurement

- Bundled tile, 31x31 NA block over a valley: before the fix, 815 zeros / 146 ones / 0 NA in the
  block (918 / 43 / 0 without the buffer). After, all NA except buffer and waterbody cells.
- With `size_threshold = 1` (no small patch, so `fl_patch_rm()` returns early), 729 of 961 block
  cells came back NA before the fix. That is why "never NA" was wrong.
- Valid cells outside a gap change too: 1,028 for the plan-mode block, 679 for the test fixture.
  For the fixture, 659 went 0->1 and 488 of those via the flood criterion, up to 940 m from the gap.
  The first explanation, a cost-distance "barrier", was unmeasured and wrong in direction.
- stac-dem rebuild: 115,385 (5 m run, 10 m grid) and 11,020 (1 m site) cells went 0 -> NA. No
  valley cell moved; `n_5m`, `n_1m` and `popup_steep_share` are identical. The plan review predicted
  `popup_steep_share` would jump. It did not, because no 25 m floodplain sits in the 1 m site's gap.
- Parsnip cache: 0 of 441,054 valley cells on NA DEM. Not rebuilt; hectares unaffected.

## Evidence

Review records: `planning/archive/2026-10-issue-63-valley-confine-na/review-*.md`. Rebuild log was
scratch-only; its result is the `inst/vignette-data/stac_*` diff in commit 319126d.

Closed by: PR (to follow)
