# Code-check commit 2 (#63), round 3

Scope: the current wording of every fix from rounds 1 and 2, plus every remaining absolute or
quantified sentence in the shipped text of the staged diff. Probes ran on a `git checkout-index`
export of the index (`scratchpad/r5`), never in the repo.

## Clean

No sentence in the shipped text is still false or unbacked.

## Round 1 and 2 fixes, re-checked as worded now

- **NEWS "usually returned 0 or 1 ... (NA survived only when no valley patch was small enough for
  `fl_patch_rm()` to remove)".** This is a necessary condition, and it is stated as one. Without the
  early return, `ifel(is.na(masked) | is.na(patches), 0L, x)` zeroes every NA (R/fl_patch_rm.R). The
  modal focal (`na.rm = TRUE`) and `ifel(>= 1)` then create none. So the claim holds.
- **NEWS "a plot drew it as hillslope or valley ... counted it as measured".** Covers both the 0
  path and the smeared-1 path.
- **NEWS "(115,385 ... 11,020 ..., outside the channel buffer), were all 0 and are now NA" and "No
  valley cell moved".** Re-measured against the `*_old.tif` copies:
  - 5 m: new 0/1/NA = 356,359 / 46,656 / 115,385; old = 471,744 / 46,656 / 0.
  - 1 m site: new = 97,950 / 31,030 / 11,020; old = 108,970 / 31,030 / 0.
  - No new NA was an old non-zero, and no non-NA cell changed.
- **`@return` "A cell with a DEM value can also be `NA` when a gap cuts it off from every stream
  (#65)".** Hedged ("can also"), not exclusive, so it no longer implies valid DEM cells are never
  NA. Not a finding, just a note: a user-supplied `slope` with an NA block where the DEM is valid is
  another way to reach the same early-return NA. The sentence does not claim to be complete.
- **Test comment and assertions (test-vignette_data.R:58-69).** "outside the channel buffer" is now
  scoped. The exact counts 115,385 and 11,020 match the cache. The "partial regression" rationale is
  correct, because `expect_gt(..., 0)` would pass the early-return case. The test would fail on the
  old cache (0 NA).
- **CLAUDE.md #63/#65 bullet.**
  - "`fl_patch_rm()` / `fl_patch_conn()` can turn NA into 0" is hedged.
  - "its 2,892-cell border ring is NA": verified. `slope.tif` is 648x800, its NA count is 2,892,
    which equals 2·648 + 2·800 − 4, and it has 0 NA in the interior. `dem.tif` has 0 NA.
  - `na_block_fixture()` exists (test-fl_valley_confine.R:362).
  - "only zeroes NA when some patch is small enough to remove" matches the code.
- **data-raw:152-155.** "returns NA there since #63, except under the channel buffer; the cache
  built before that held 0 there" is consistent with the counts above. No waterbodies are passed.

## Other quantified sentences in the diff

- **NEWS "none of the vignette's areas or shares changed".** The tile and site percentages use
  `ncell()` and the unchanged `n_5m` / `n_1m`. The pop-up % denominator changed from `fp_25m` to
  `fp_25m_lidar`, but both are 20,586 here (findings).
- **Vignette chunk labels "no-lidar cells included".** Correct, because `ncell()` counts NA.
- **Vignette captions "tan ... has no 2019 lidar".** Correct in that direction: cache NA means DEM
  NA and not buffer. The plot comment at :292 says "NA outside the channel buffer". The pop-up
  comment at :460-462 is correct for the site, which has no buffer cells in its gap.
- **Pre-existing "white features" prose at :517-537** refers to grey90 not-floodplain cells. Tan
  does not change what it describes, and it is outside this diff.

## Test run

In the staged-tree copy: `NOT_CRAN=true Rscript -e 'devtools::load_all(quiet=TRUE);
testthat::test_file("tests/testthat/test-vignette_data.R")'` gives `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 8 ]`.
