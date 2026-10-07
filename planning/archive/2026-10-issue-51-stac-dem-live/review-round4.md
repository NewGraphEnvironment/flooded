# Review round 4 — #51 stac-dem (round-3 fixes + completeness of the E/C enumeration)

Reviewer: code-check subagent, 2026-10-07. Repo untouched except this file. Probes in
`scratchpad/r4/` (`p1.R`, `p2.R`). The 10 m site run was re-run live (20,586 cells, equal to the
cache). The 1 m slope was taken from round 3's independently built DEM (`scratchpad/r3/dem1.tif`,
projected bilinear from the two local tiles, NA 0.07892221 = `na_frac_1m`). The per-criterion
masks came from `scratchpad/r3/m1_on10.tif`.

## Findings

- **[bug] `vignettes/stac-dem.Rmd:531-534`.** This is the round-3 "blocking" claim reworded, and it
  is still false. Inside a previous fix: **y**. Round 3 named `:521-526`, *"these raised features
  are blocking it"*. The fix changed "blocking it" to "are in the way" and kept the claim. The
  sentence is not in E1–E10. The text reads:
  > The 25 m DEM says "this is all floodplain" because it cannot see the barriers. The 1 m DEM says
  > "this would be floodplain, except these raised features are in the way."

  Measured at the 1,984 pop-up cells, with the 1 m masks sampled at the 10 m centres:
  - the **cost mask passes for 100%** of them, and so does the distance mask;
  - **73.8%** fail only slope and sit below the 1 m flood surface;
  - **14.6%** pass all four criteria and are removed by cleanup;
  - **11.6%** fail flood.

  So no pop-up is excluded because something cuts it off from the stream. Three quarters are the
  steep ground itself, and one in seven has no feature involved at all. "In the way" is the
  connectivity mechanism the page's own `:480-483` now disclaims.

  The first sentence has two more problems:
  - "Cannot see the barriers" asserts that pop-ups *are* barriers. C5 softened that to "candidate
    barriers" at `:487`.
  - "This is all floodplain" contradicts `:501-502` and `:510-511` ("shows broad gaps", "where
    the 25 m DEM registers a raised grade at all, it shows a broad gap"). It is the third copy of
    the C7/C11 "one continuous surface" claim. The enumeration fixed the other two.

  The same "the rest is still in place" pattern caught "invisible at 25 m" in round 3.

- **[bug] `README.md:57` (unchanged line, beside the rewritten `:55`).** The README still says *"The
  gap between coarse and fine results is a diagnostic: it shows **what is preventing floodplain
  from functioning**"*, but this branch retracts that claim everywhere else:
  - `NEWS.md:19-20`: *"the gap between resolutions is no longer described as mostly the
    anthropogenic footprint: the coarse DEM gets the floodplain's shape wrong in both
    directions"*;
  - the vignette now confines the diagnostic reading to the pop-ups (`:529-531`).

  At the site the gap is 144.1 ha. 124.3 ha of it (86%) is floodplain found **only at 1 m**, which
  is margin the coarse DEM missed, not something preventing function. Inside a previous fix: **n**.
  The line predates the branch, but the vignette version of the same claim ("the gap ... is
  largely the anthropogenic footprint") was rewritten in this diff and this copy was not. E9 covers
  README:55 only.

- **[fragile] `vignettes/stac-dem.Rmd:486-487`, *"which a 25 m pixel smooths nearly flat"*, and
  `NEWS.md:23-24`, *"embankment sides and banks that a 25 m pixel smooths flat"*.** Inside a
  previous fix: **y**, since both sentences are new in round 3's fix. Neither is in E1–E10: E1
  measures the 1 m steep share, not the 25 m side.

  On the bundled 10 m slope, the pop-up cells have a **median of 5.0%** (10th/90th/99th
  percentiles 0 / 8.8 / 11.9%), and **7.1% exceed the 9% threshold even at 10 m**. The whole 25 m
  site floodplain has a median of 3.95%. So the coarse DEM registers these cells as *steeper than
  the rest of its floodplain*, just under the threshold, not flat. A true statement would be
  "smooths below the 9% threshold". The README's "smooths away" (`:55`) is acceptable as written.

## Enumeration completeness (a)

E1–E10 and C1–C11 miss three claims about these results: the two vignette sentences at
`:531-534`, the mechanism clause at `:486-487` / `NEWS:23-24`, and `README.md:57`. Every other
causal, extent or numeric sentence I found in the files listed (vignette, README :55-57, NEWS top
entry, CLAUDE.md bullets, methodology.md costDist paragraph, data-raw comments) is either in the
tables or is an accepted interpretive list. `:539-541` ("a diagnostic tool for identifying what is
preventing floodplain from functioning") is generic about running at 1 m. I left it as accepted
framing, but it is the same sentence family as README:57.

## Round-3 fix sentences (b), verified

- `:483-485` / E1: `popup_steep_share` 0.7737 and `site_steep_share` 0.2357 reproduce exactly from
  the independently built 1 m DEM. The slope-only share is 73.8% and flood-fail is 11.6%, so
  NEWS's "the slope criterion, not flood depth, is what mostly removes them" holds.
- `:502-505`, `:507-513`, `:529-531` ("mostly on steep ground") hold as worded.
- `:187` "25x more cells" is correct, and `:300` "smeared or lost" holds.
- `methodology.md`: the cached `warnings_1m` is empty, and round 3's independent rerun raised none.

## Data-raw code and inline R (c), verified

- `popup` and `steep` use the same nearest-neighbour sampling as the cached valley raster.
- **No pop-up has an NA steep value.** No 25 m floodplain cell falls in the 1 m lidar gap. So the
  `na.rm` handling (NA dropped from the numerator but kept in the denominator) cannot bias either
  share, and `na_frac_1m` does not affect the site table.
- `n_10m_no_lidar` = `valleys_10m == 1 & resample(is.na(dem_5m), near) == 1`. The cube extent
  equals `ext(dem_10m)`, so the grids align. The value is 32, matching round 3.
- The inline R reads the right fields: `na_frac_5m` (test area), `n_10m_no_lidar`, `n_10m`,
  `popup_steep_share`, `site_steep_share`.
- `test-vignette_data.R` compares integer counts with `expect_equal`. Its relative tolerance is
  about 1.5e-8, which is under one cell at 28,727, so an off-by-one fails.
- The NEWS numbers reproduce:
  - 4.67 / 2.87 km2, 310.3 / 205.9 ha, 19.8 ha, 9.6% and 124.3 ha;
  - the previous 6.26 / 5.46 and 36.1 ha / 9.7% (taken from `main`);
  - the cache is 13.1 KB;
  - rtj#229's title matches the rename.

## Notes (not defects in this diff)

- `fl_valley_confine()` returns **0, not NA**, where the DEM is NA. The cached 5 m and 1 m rasters,
  and the native 1 m raster, have no NA cells. So the 5 m panel draws the 22% lidar gap in the
  same grey as non-valley ground. The prose at `:277-282` explains the coverage, so nothing on
  the page is false. However, the roxygen says "`NA` = outside analysis extent", and the comment
  at `data-raw/stac_dem_vignette_data.R:154`, "the VCA treats NA as outside", is true only in the
  sense of "outside the floodplain". Both the function and its roxygen predate this branch.
- `:21` and `:54` say the lidar steps take "several minutes". The build took 21.3 min, and NEWS
  says ~20.
