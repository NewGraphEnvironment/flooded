# Code-check review, round 1 (#63 staged diff, 2026-10-08)

## Clean

No issues found.

What I checked:

- **Fix placement.** `terra::mask(valleys, dem)` sits after the final `ifel()` and before both
  overlays. The overlays are `ifel(buf_r == 1L, 1L, valleys)` and the same for waterbodies, so a
  gap cell with buffer or waterbody 0 keeps its NA, and one covered by either becomes 1. That
  matches the new `@return`. A raster mask with the default `maskvalues = NA` is not the
  polygon-mask `touches = TRUE` trap. The geometry always matches `dem`, because `valleys`
  derives from the dem grid (a mismatched user `slope` already fails at the mask product).
- **Consumers of the new NA.** `fl_valley_attribute()` uses `which(values == 1L)` and
  `fl_valley_poly()` drops non-1 cells, so neither breaks. Every count in the vignettes,
  `data-raw/` and `test-vignette_data.R` uses `== 1` with `na.rm = TRUE`. The pop-up
  `!= 1` expressions in `stac-dem.Rmd` will drop gap cells, which is the accepted Phase 4 rebuild.
- **Tests.** I ran `NOT_CRAN=true test_file(test-fl_valley_confine.R)` against the staged tree:
  53 pass, 0 fail. The fixture's `f$buf` and `lake_r` are rasterized exactly as the function
  does it (same `channel_width > 0` filter, same grid), so cell membership agrees. The
  `expect_gt` guards show that the buffer and the lake both reach inside the block, and that
  the buffer does not cover all of it. The block bounds are checked, and the lake (±3 cells)
  sits inside the block (±15 cells). The progress log records that moving the mask after the
  overlays turns tests 2 and 3 red. The second assertion in test 1 (`!anyNA(v[-block])`)
  would catch a mask keyed on `is.na(slope)` instead of `dem`.
- **Tree state.** No `_problems/` or `testthat-problems.rds`, and nothing unstaged.

## Non-blocking notes (prose accuracy, not bugs)

1. **The code comment at `R/fl_valley_confine.R:269` and the test header comment** both say
   `fl_patch_rm()` turns NA into 0 ("every NA reaching it" in the test). It does so only when at
   least one small patch exists; with none, it returns early at `R/fl_patch_rm.R:41` and keeps
   the NA. The plan review's own item #7 records this. It is harmless to the fix, which masks
   whatever arrives, but the sentence is stronger than the code.
2. **`@return` "NA = no DEM" has a reachable exception.** `costDist` returns NaN for valid-DEM
   cells cut off from every stream by an NA gap (probed: a 5x5 friction grid with an NA column
   gives NaN beyond it). Such cells reach `fl_patch_rm()` as NA. If it early-returns, they stay
   NA after the mask, so NA is not *only* "no DEM" in that case. On realistic data there are
   small patches, so these cells become 0 instead. The fix lies in the accepted
   `fl_patch_rm()` follow-up, so this is worth one clause in that issue, not a change here.
