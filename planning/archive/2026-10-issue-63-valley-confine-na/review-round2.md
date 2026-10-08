# Code-check review, round 2 (#63 staged diff, 2026-10-08)

## Findings

- **[severity: fragile, prose]** `data-raw/stac_dem_vignette_data.R:154-155` and
  `tests/testthat/test-fl_valley_confine.R` (header comment of the `# --- NA DEM cells (#63)`
  block). Both describe the pre-fix behaviour as the gap coming back **0**: "before that it
  returned 0, as if measured" and "a coverage gap came back as measured hillslope". Measured,
  not inferred: I ran the HEAD (`git show HEAD:R/fl_valley_confine.R`) version of the function
  on the test's own `na_block_fixture()` in a scratch copy. With `channel_buffer = FALSE`, the
  961 block cells came back as **901 `0` and 60 `1`**. With `channel_buffer = TRUE`, **50
  non-buffer block cells were `1`**, and all 191 buffer cells were `1`. So before the fix a gap
  came back as a mix of hillslope and *valley*, with no `NA`. That is the "focal filters smear 1s
  into a gap's edge" which the new R comment itself names. The function is correct and the tests
  are right. Only these two sentences state model output that the code does not produce. A
  suggested wording is "returned 0 or 1, as if measured". The same imprecision appears in
  `planning/active/progress.md` ("all fail on main (block cells 0, not NA)").

No code defects found.

## What I checked

- **Fix and placement.** `terra::mask(valleys, dem)` comes after the final binary `ifel` and
  before both overlays. The overlays are `ifel(x == 1L, 1L, valleys)`, so a gap cell that is
  NA stays NA unless the buffer or a waterbody covers it. That matches the new `@return`,
  which is now a one-direction claim. `valleys` is always on the `dem` grid, because
  `stream_r` is rasterized to `dem` and a mismatched `slope`/streams raster already fails at
  the mask product, so `mask()` cannot hit a geometry mismatch. A raster mask is not the
  polygon `touches = TRUE` trap.
- **Tests run.** I ran `NOT_CRAN=true testthat::test_file("tests/testthat/test-fl_valley_confine.R")`
  on the staged tree, and all passed. Mutation (the HEAD function on the same fixture): the
  block holds 0 and 1 with no NA, so test 1's `all(is.na(v[f$block]))` fails. The guard fires.
  Cells outside the block are identical between HEAD and the staged version (0 differ, 0 NA),
  so the mask changes nothing on valid DEM cells in this fixture.
- **Consumers of the new NA.** `fl_valley_attribute()` uses `which(values == 1L)` and
  `fl_valley_poly()` uses `ifel(x == 1, 1, NA)`, so neither breaks. In
  `data-raw/stac_dem_vignette_data.R`, `n_valley()` and `n_10m_no_lidar` use `na.rm = TRUE`.
  `write_valleys()` writes INT1U from memory, and terra writes NA there as nodata 255, not 0.
  `popup` (`!= 1` on `valleys_1m_on_10m`) now drops lidar-NA cells where it used to count
  them as pop-ups. That changes `popup_steep_share` on the rebuild, which is the accepted
  Phase 4 work.
- **data-raw comment, rest of the sentence.** "except under the channel buffer" is complete
  for this script, because `vca_args` passes no `waterbodies` and `channel_buffer` auto-detects
  TRUE from `streams$channel_width`.
