# Code-check round 4: #65 (diff 6b5cd1d...HEAD at ef8d757, planning/ and man/ skipped)

Reviewer worked in a copy (`scratchpad/r4/head` = HEAD tree, `scratchpad/r4/main` = `git archive 6b5cd1d`);
nothing under the repo was edited except this file. Probes: `scratchpad/r4/probe1.R` (HEAD vs main on 5
fixtures x 2 paths), `probe2.R` (which cells differ at `size_threshold = 1`), `probe3.R` (cut-off cells
on valley floor). Tests run with `NOT_CRAN=true testthat::test_file()` on the copy: fl_patch_rm 7/0 fail,
fl_patch_conn 7/0, fl_valley_confine 29/0, vignette_data 3/0 (no errors, no skips).

## Findings

Nothing false in the diff's code or shipped prose (roxygen, R comments, test titles/comments, CLAUDE.md).
One false claim sits outside the review scope, in planning/, and is load-bearing for the PR body and NEWS:

- **[fragile] planning/active/progress.md:28-29** (also restated in this round's brief) — "at 1, differs
  only where main left DEM-valid NA" is false. On the valley-floor supplied-slope NA fixture
  (`slope.tif` NA on rows 311:323, cols 229:241, the last test's fixture) at `size_threshold = 1`, HEAD
  differs from main on **28 DEM-valid cells where main gave a value**: all 28 were 1 on main and are 0 on
  HEAD, all inside the block, on its depth-3 ring (rows 313-321 x cols 231-239 perimeter). They were NA
  going *into* the modal filter, and main's early-return path let `focal(modal, na.rm = TRUE)` fill them
  from their non-NA neighbours; HEAD zeroes them first so they vote 0. This is the decided behaviour
  (HEAD = main's removal path, and the test pins it: 92 vs main-p1's 120), so the code is right; the
  sentence is not. Correct form: "at 1, differs only on DEM-valid cells that were NA going into the
  majority filter (main left some of them NA and filled others from their neighbours)". Whoever writes the
  NEWS line for #65 should not say outputs change only where they used to be NA: on a DEM with gaps, a run
  that took `fl_patch_rm()`'s early return can also lose 1s next to NA regions.

## Table A: every operation that can create, propagate or remove NA/NaN

"Main" = 6b5cd1d on its removal path (some patch < `size_threshold`) unless stated. Agreement on the
removal path measured cell for cell (probe1): HEAD p5000 vs main p5000 differ on **0** cells on all five
fixtures (bundled; island behind 3-cell ring; 2x2 speck in a 31x31 gap; slope-NA hillslope 31x31;
slope-NA valley-floor 13x13); main's `fl_patch_rm()` saw 69 small patches on each, so the removal path was
taken. HEAD p1 vs p5000 differ on 192 cells, on every fixture.

### fl_valley_confine()

| # | operation (line) | NA/NaN effect | main | HEAD | agree |
|---|---|---|---|---|---|
| 1 | `terra::terrain()` -> `tan(...)` slope (221-222), or supplied `slope` | creates NA at DEM NA, the DEM's outer ring, and every cell with an NA neighbour; supplied slope carries its own NA | same | same | yes |
| 2 | `fl_mask(slope, <=)` (226) | propagates slope NA (`NA <= t` is NA, `* 1L` keeps it) | same | same | yes |
| 3 | `fl_mask_distance(stream_r)` (229) | none on any grid with a stream cell (distance to non-NA cells) | same | same | yes |
| 4 | `fl_cost_distance()` (232): `ifel(friction == 0, 1e-6, friction)`, `ifel(!is.na(streams), 0, friction)`, `costDist` | NA where slope NA (except stream cells, set to 0) and where no path reaches a stream (cut-off ground; probe: island interior all NA) | same | same | yes |
| 5 | `fl_mask(cost, <)` (233) | propagates cost NA | same | same | yes |
| 6 | flood mask (236-242): `ifel(!is.na(stream_r), 1, .)`, `ifel(is.na(.), 0, .)` | removes all NA | same | same | yes |
| 7 | product of four masks (245) | NA wherever slope or cost mask NA (`NA * 0` is NA) | same | same | yes |
| 8 | `focal(max, na.rm = TRUE)` (249) | NA cell with any non-NA neighbour gets a value; NA region shrinks 1 cell; all-NA window stays NA | same | same | yes |
| 9 | `focal(min, na.rm = TRUE)` (250) | shrinks NA another cell | same | same | yes |
| 10 | hole fill (254-264): `ifel(valleys == 1, 0, 1)`, `patches`, `classify`, `ifel(is.na(holes) & !is.na(hp), 1, .)` | propagates NA (NA cond -> NA; NA cells never in a hole patch) | same | same | yes |
| 11 | `fl_patch_rm()` (267), early return (no patch < threshold) | returns `x`, NA kept | NA kept | NA kept | yes |
| 12 | `fl_patch_rm()` (267), removal path | main: `ifel(is.na(masked) \| is.na(patches), 0, x)` zeroes every NA; HEAD: `ifel(is.na(masked), x * 0L, x)` keeps NA | NA -> 0 | NA kept | no, by itself; restored by 13 |
| 13 | `ifel(is.na(valleys), 0L, valleys)` (273), HEAD only | removes all NA (and NaN) before the modal | (removal path: already 0 from 12) | NA -> 0 on both paths | removal path: yes (0 cells differ). Early-return path: no, by decision — main let 14 skip these cells, HEAD counts them as 0 votes (28 DEM-valid cells flip 1 -> 0 on the valley-floor fixture; 625/4/625/49 cells main left NA on DEM-valid ground are now 0) |
| 14 | `focal(modal, na.rm = TRUE)` (276) | main early path: NA cell with non-NA neighbours gets their modal, all-NA window stays NA; after 13, nothing NA reaches it | removal path: no NA in | no NA in | yes on removal path |
| 15 | `ifel(valleys >= 1, 1, 0)` (279) | propagates NA (main early path only) | removal: none | none | yes |
| 16 | `mask(valleys, dem)` (285) | creates NA exactly where DEM is NA (NaN counts as NA) | same | same | yes |
| 17 | channel buffer `ifel(buf_r == 1, 1, .)` (300-302); `rasterize(background = 0)` | removes NA under the buffer; buf_r has no NA | same | same | yes |
| 18 | waterbodies `ifel(wb_r == 1, 1, .)` (313-315) | removes NA under a polygon | same | same | yes |

Net: after 13 nothing is NA; 16 puts NA exactly on DEM NA; 17-18 set 1 inside gaps under a feature. So the
output is NA iff DEM NA and no feature covers it, which is what `@return` says.

### fl_patch_rm()

| # | operation | NA effect | main | HEAD | agree |
|---|---|---|---|---|---|
| 1 | `patches(zeroAsNA = TRUE)` | NA for NA and 0 cells | same | same | yes |
| 2 | `freq()` / `small_ids` / early return | early return keeps NA | same | same | yes |
| 3 | `classify(patches, cbind(small_ids, NA))` | NA off kept patches (NA, 0, small) | same | same | yes |
| 4 | final `ifel` | main: NA -> 0; HEAD: `x * 0L` gives NA for NA, 0 for 0 and small-patch 1 (NaN only for Inf, accepted) | NA -> 0 | NA kept | no — this is the #65 fix; both HEAD paths now keep NA (tests pin both) |

### fl_patch_conn()

| # | operation | NA effect | main | HEAD | agree |
|---|---|---|---|---|---|
| 1 | `patches(zeroAsNA = TRUE)` | NA for NA and 0 | same | same | yes |
| 2 | `anchor_mask`, `mask(maskvalues = FALSE)`, `values(na.rm = TRUE)` | anchor NA is not an anchor (connected-path test would fail otherwise; it passes) | same | same | yes |
| 3 | no-anchor early return `x * 0L` | keeps NA | same | same | yes |
| 4 | `classify(drop_ids -> NA)` or `kept <- patches` | NA off kept patches | same | same | yes |
| 5 | final `ifel` | main `ifel(!is.na(kept), x, 0)`: NA -> 0; HEAD `ifel(is.na(kept), x * 0L, x)`: NA kept | NA -> 0 | NA kept | no — the #65 fix; matches step 3 |

Only other caller of either helper: `vignettes/valley-confinement.Rmd:222` (`fl_patch_conn()` on a
bundled-tile result, no NA, counts with `na.rm = TRUE`) — unaffected.

## Table B: every sentence in the diff that claims an NA/0/1 outcome

| where | claim | verdict | evidence |
|---|---|---|---|
| R/fl_patch_rm.R:12-13 `@return` | small patches set to 0; all other values unchanged; NA stays NA | true | A-rm 2,4; tests at both paths |
| R/fl_patch_rm.R:43-45 | `masked` NA off kept patches incl. NA input; `x * 0L` zeroes the rest without turning NA into 0, matching the early return | true | `classify` keeps NA; `NA * 0L` = NA |
| R/fl_patch_conn.R:64-65 `@return` | only anchor-touching patches retained; NA stays NA | true | A-conn 3,5, on all three branches (no anchor, drop_ids empty, drop_ids non-empty) |
| R/fl_patch_conn.R:119-120 | NA input NA in `kept` too, must stay NA as on the no-anchor path | true | A-conn 1,3 |
| R/fl_valley_confine.R:50-52 `@return` | NA wherever dem NA unless channel buffer/waterbody covers it, then 1 | true | A-vc 13,16,17,18 |
| :52-53 | every cell with a DEM value is 0 or 1 | true | A-vc 13-16; probe1: 0 NA on DEM-valid ground on every fixture, both paths |
| :53-55 | cut-off cell has no cost distance; NA-slope cell; neither can pass the criterion it cannot be tested on | true | A-vc 4,5,7 (NA, not pass) |
| :55-57 | cleanup can still mark one 1 when within a few cells of valley floor | true | probe3: 11x11 island behind a 1-cell ring on valley floor, 2 of 121 island cells are 1, both cost NA, both on the island's edge next to the ring, on both paths |
| :268-270 comment | cells still NA here (gap, cut-off, NA slope) count as 0 in the majority filter; DEM mask then restores NA where no DEM | true | A-vc 13,14,16 |
| :270-272 | before #65 fl_patch_rm() did this zeroing only when it had a patch to remove; this is that path made the only one | true | A-vc 12,13; HEAD p5000 = main p5000 on 5 fixtures |
| :272 | "so the output no longer depends on whether some patch was small" | true in its intended sense (NA handling no longer switches on the existence of any small patch); a literal reader could take it as "removal changes nothing", which the 192-cell p1/p5000 difference contradicts. Not reported. | |
| :281-282 | the zeroing fills a gap with 0s and the focal filters smear 1s into its edge, so restore NA | true | A-vc 8,9,13,14 |
| test-fl_patch_rm.R:69-70 | NA used to survive only on the early return and come back 0 otherwise | true | main A-rm 4 |
| :71-75 | 6-cell 600 m2, 2-cell 200 m2, NA block clear, NA touching small patch | true | 10 m cells; geometry checked |
| tests at :80, :92 titles | keeps NA on removal / no-removal path | true | pass on HEAD |
| test-fl_patch_conn.R:70 | connected path used to set NA to 0; no-anchor path kept it | true | main A-conn 3,5 |
| :74-75 | NA block clear of both patches; NA touching Patch B | true | (5:6,5:6) vs patches at 2:3/8:9; (7,8) adjacent to (8,8) |
| :109 title, :115-116 | slope.tif ring stays NA; ring (2,892) is there to be zeroed | true | test passes; main's connected path zeroes it |
| test-fl_valley_confine.R:357-360 | fl_patch_rm() turned NA into 0 (fixed in #65) and focal smeared 1s | true (as history of fl_patch_rm; the zeroing now lives at fl_valley_confine.R:273 by design) | |
| :389-390 | on this fixture every DEM-valued cell is measured, incl. slope-undefined ring | true | test passes |
| :434-437 | cut-off ground has DEM but no cost (costDist cannot cross NA); before #65 NA on no-removal path, 0 on removal path | true | probe1 island: main p1 625 DEM-valid NA, main p5000 0 |
| :437-438 | island on hillslope behind a 3-cell ring is all 0; near valley floor cleanup can mark cut-off cells 1 | true | test asserts 0; probe3 for the second half |
| :441-442 | 31x31 window more than 200 m from any stream; 3-cell ring encloses 25x25 island | true | min distance 202.5 m; rows[4:28] |
| :454-457 | size_threshold = 1 removes no patch; default removes some on this tile; size_threshold read only by fl_patch_rm(), so outputs differ only if it removed one | true | probe1: 0 vs 69 small patches; `size_threshold` used only at R:267 |
| :471 | island interior has slope but no cost distance | true | asserted in the test |
| :492-493 | 2x2 speck: no slope anywhere in it, no measured neighbour within a focal window | true | every speck cell has an NA neighbour; nearest valid DEM ~14 cells away |
| :502 title, :510 | DEM complete, so no cell may be NA | true | A-vc 13,16; probe1 |
| :512-513 | hillslope block all 0; on valley floor cleanup marks cells near its edge 1 | true | probe1 floor: 92/169 ones, all within 3 cells of the block edge (depth-3 ring partly) |
| :519 title, :520-524 | NA before the modal votes as 0; old removal path zeroed them; zeroing after the filter gives 120 vs 92; block has no stream cell | true | probe1: main p5000 92, main p1 (modal skips NA, same mechanism) 120, HEAD 92 both paths; 0 stream cells in block |
| test-vignette_data.R:62-63 | before #65 fl_patch_rm() kept NA on its early return, so "any NA" would not catch a partial regression | true (historical) | main A-rm 2 |
| CLAUDE.md:153-155 | #65: helpers turned NA into 0 on one path, kept it on the other; fixed in both | true | A-rm 4, A-conn 5 |
| CLAUDE.md:158-161 | both helpers have an early return, and so does fl_valley_confine()'s cleanup through fl_patch_rm(); size_threshold = 1 removes no patch and the default removes some on this tile | true for the bundled tile (0 vs 69 small patches). Anchor note: the nearest antecedent of "this tile" in that sentence is the stac-dem lidar tile, not the bundled DEM the bullet is about; not measured on the lidar. Not reported. | |

## Out of scope, noted only

- `NEWS.md:36` (0.6.3 section) still says the helpers "can still turn NA input cells into 0 (#65)";
  that is release history, and the 0.6.6 entry is written at merge. See the Findings item for what that
  entry must not claim.
