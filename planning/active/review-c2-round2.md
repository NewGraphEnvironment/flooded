# Code-check commit 2 (#63), round 2

Scope: every sentence with an absolute or quantifier in the shipped text (NEWS entry, CLAUDE.md #63
bullet, stac-dem.Rmd edits, test-vignette_data.R comment, data-raw comment, fl_valley_confine.R
roxygen and comments). Probes ran on a `git archive HEAD` copy in the scratchpad, never in the repo.

## Findings

All four are low. Each is the branch's mechanism again: an absolute written from one code path.

- **[low] R/fl_valley_confine.R:50-52 (`@return`, committed in 1ea1ae5).** The text now lists NA only as
  "wherever `dem` is `NA`", and the old catch-all "`NA` = outside analysis extent" is gone. So a reader
  concludes that a valid DEM cell always gives 0 or 1. That is false on `fl_patch_rm()`'s early return:
  cells cut off from every stream by a gap get NaN cost, and that NaN survives the cleanup.
  - **Probe** (`scratchpad/probe65.R`): bundled DEM, a 2-cell NA band fencing off the 40x40 corner (no
    streams in it), `max_width = 1e6`, `cost_threshold = 1e9`, `channel_buffer = FALSE`.
    - `size_threshold = 5000` gives **0** valid-DEM cells NA.
    - `size_threshold = 1` gives **1,600** valid-DEM cells NA, the whole corner.
  - `test-fl_valley_confine.R:390` already says "(exception: #65)". The roxygen does not.
  - Suggested: add "Cells with DEM values that a gap cuts off from every stream can also be `NA` (#65)."
    NEWS ("now returns `NA` where the DEM is `NA`") is fine, because it makes no "only" claim.

- **[low] NEWS.md:5-6.** The phrase "read as measured hillslope or valley" is right. The colon clause that
  follows covers only the 0 path: "a plot drew it grey like hillslope, and any share taken over
  non-`NA` cells counted it as not-floodplain". It misses the 1s the focal filters smeared into the gap.
  The task plan's own probe found 43 of 961 gap cells were 1 with no buffer, and 146 with it. Those
  cells drew green and counted as floodplain. Suggested: "a plot drew it as hillslope or valley, and
  any share taken over non-`NA` cells counted it as measured".

- **[low] tests/testthat/test-vignette_data.R:59-60 (new comment), with the same nuance at
  vignettes/stac-dem.Rmd:292** ("Cells with no lidar are NA").
  - (a) "the 2019 lidar gap was cached as 0". The channel buffer was 1 inside the gap in both caches. In
    the new `stac_valleys_5m.tif`, 1-cells by NA-neighbour count: 6 cells have 8, 17 have 7, 12 have 6,
    1 has 5, and 2 have 1. The 1 m site has none. NEWS was already fixed for this ("outside the channel
    buffer"). These two comments were not. Suggested: "(outside the channel buffer)" or "except under the
    channel buffer".
  - (b) "a cache built before it, or by a regression, has no NA at all". The "by a regression" half
    assumes `fl_patch_rm()` does not return early. With the mask removed, NA survives wherever the early
    return is taken (round 1: 729 of 961 block cells). On this data the guard works today, because the
    old cache had 0 NA, so `fl_patch_rm()` did not return early. As a general claim it is false, and
    `expect_gt(NA, 0)` would pass a partial regression.
    - Suggested: scope the comment ("on this data"), or pin the measured counts:
      `expect_equal(sum(is.na(v5)), 115385)` and `11020`. A cache rebuild is already deliberate and
      re-pins.

- **[low] CLAUDE.md:126-130 (dev note, not shipped; also the body of #65).**
  - "(`fl_patch_rm()` / `fl_patch_conn()` turn NA into 0)". The bullet qualifies `fl_patch_rm()`'s
    early return, but `fl_patch_conn()` has one too. When no patch touches the anchor it returns
    `x * 0L`, which keeps NA (measured: terra `NA * 0L` = NA). Issue #65's body says the same and
    proposes covering "both paths of `fl_patch_rm()`" only.
  - The bullet also says "the bundled DEM ... still hides #65" and that no-data work "needs a synthetic NA
    block". But the bundled `slope.tif` has **2,892 NA cells**, its border ring.
    `test-fl_patch_conn.R:42-50` already feeds `fl_mask(slope.tif)` into `fl_patch_conn()`, and the
    `fl_patch_rm()` example does the same. So the bundled data reaches #65; it just asserts nothing.
  - Worth one clause in the bullet and in the #65 body, so whoever fixes #65 covers
    `fl_patch_conn()`'s no-anchor path and knows `slope.tif` is a ready NA fixture.

## Enumerated and verified

- **NEWS "as its documentation already said".** The old `@return` said "NA = outside analysis extent".
  Close enough.
- **NEWS "NA survived only when no valley patch was small enough for `fl_patch_rm()` to remove".**
  Verified from the code. Without the early return, `ifel(is.na(masked) | is.na(patches), 0, x)` zeroes
  every NA. The modal focal then has no NA input, and `ifel` and the overlays create none.
- **NEWS "channel buffer and waterbodies are still added inside a gap, because neither depends on the
  DEM".** Verified at R/fl_valley_confine.R:289 and :302: rasterized on the `dem` grid only, OR'd after
  the mask at :274.
- **NEWS "Results on the bundled tile do not change, because it has no NA cells".** Verified. `mask()`
  is a no-op on a DEM with no NA, and the guard counts (28727 / 20586) hold.
- **NEWS "115,385 ... 11,020 ... outside the channel buffer, were all 0 and are now NA".** Verified,
  given resample `method = "near"` (data-raw:211, :229). A 10 m cell is uncovered exactly when its
  nearest 5 m or 1 m cell is. Every new NA was an old 0. No waterbodies are passed to the run (no
  `waterbod` in data-raw).
- **NEWS "No valley cell moved".** Verified. After the fix the 1-set is (old 1-set ∩ valid DEM) ∪
  overlays, a subset of the old 1-set. `n_5m` and `n_1m` are identical, so the sets are equal.
- **NEWS "none of the vignette's areas or shares changed".** Verified from the identical `stac_meta`
  counts and the rendered numbers. `fp_25m_lidar` equals `fp_25m` (20,586) here.
- **NEWS "The cached Parsnip result has no valley cells on NA DEM, so its hectares hold".** Re-measured:
  `pars_dem.tif` and `pars_valleys.tif` share a grid. Valley = 441,054; valley on NA DEM = 0. A rebuild
  gives the same 1-set by the subset argument above.
- **NEWS "can still turn NA input cells into 0 (#65)".** Hedged, and correct.
- **Roxygen :67-71 ("can differ").** Hedged, and correct.
- **Roxygen :73-74 ("apply inside NA gaps too").** Verified.
- **Code comment :270-273 ("can turn", "smear 1s into a gap's edge").** Hedged, and correct.
- **CLAUDE.md "usually returned 0 or 1"; "fixed by masking with the DEM before the overlays";
  "22% of the tile NA" (`na_frac_5m` 0.2229); "`fl_patch_rm()` only zeroes NA when some patch is small
  enough to remove".** All verified.
- **data-raw:152-155.** "~22%" and "~8%" are verified (0.2229 / 0.0789). "returns NA there since #63,
  except under the channel buffer; the cache built before that held 0 there" is verified: the `except`
  scopes both clauses, and no waterbodies are passed.
- **Vignette captions "tan ... has no 2019 lidar, so it was not assessed" and "Tan in the bottom panel
  has no 2019 lidar".** Verified. NA in the cache means DEM NA and not buffer. The claim runs tan to
  no-lidar, not the reverse.
- **Vignette "no-lidar cells included".** Verified: `ncell()` counts NA.
- **Vignette pop-up comment "Cells with no 1 m lidar are NA and drop out".** Verified for the site:
  0 valley cells border NA, so no buffer sits in the gap. `fp_25m_lidar` and the `na.rm` drop in
  `popups` agree.
