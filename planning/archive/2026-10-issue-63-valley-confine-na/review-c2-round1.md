# Code-check commit 2 (#63), round 1

## Findings

- **[medium]** NEWS.md:4 ("It used to return 0 or 1 there") and CLAUDE.md:125-126 ("returned 0 or 1,
  never NA, on NA DEM cells"): false as a universal claim. The old code returned NA inside a gap whenever
  `fl_patch_rm()` took its early return. Measured on the pre-fix function
  (`scratchpad/old_vc.R`, no `mask()`), using the bundled DEM with a 31x31 NA block at rows/cols
  100:130 and `channel_buffer = FALSE`:
  - `size_threshold = 5000` gives 0 of 961 block cells NA
  - `size_threshold = 1` (no patch is small enough, so the early return is taken) gives **729 of 961 NA**

  The focal filters keep an all-NA neighbourhood as NA (`focal(fun = "max", na.rm = TRUE)` on an all-NA
  window returns NA, measured), and `ifel(NA >= 1, 1, 0)` keeps NA. The CLAUDE.md bullet contradicts
  itself: its last sentence says the early return hides the NA->0 behaviour, which means NA survived.
  The NEWS sentence ships to users. Suggested wording: "it usually returned 0 or 1 there (NA survived
  only when no valley patch was small enough for `fl_patch_rm()` to remove)", and in CLAUDE.md, "usually
  0 or 1". Commit 1's message says "never NA" too, but commit messages are immutable, so leave it.

- **[low]** NEWS.md:13-14 says the stac-dem cache's "uncovered cells ... (115,385 for the 5 m run ...)
  were all 0 and are now `NA`". The 115,385 are the uncovered cells **outside the channel buffer**. In
  `stac_valleys_5m.tif` the channel buffer is still 1 inside the gap: 23 valley cells have 6-8 NA
  neighbours (12 with 6, 17 with 7, 6 with 8), and 42 rasterized stream cells fall in the NA region. So
  not every uncovered cell was 0, and 115,385 is not the full uncovered count. The fix only applies to the
  5 m clause. The 1 m site has no valley cell adjacent to NA, so its clause is exact. Suggested wording:
  "its uncovered cells outside the channel buffer (115,385 ...) were 0 and are now NA". The same nuance
  applies to the caption at vignettes/stac-dem.Rmd:286 ("tan ... has no 2019 lidar"). That caption is
  true as written: it only says tan has no lidar, not that every no-lidar cell is tan. No change needed
  there.

## Checked and clean

- `colNA = "tan"` works in `terra::plot` for these 0/1/NA rasters. Both rendered PNGs show the tan gap,
  with grey and green unchanged.
- The pop-up denominator `fp_25m_lidar` is logically right (25 m valley cells whose 1 m value is not NA),
  matches the `na.rm` drop in `popups`, and matches the new label.
- The test comment holds: 22% (115,385 / 518,400 = 22.26%) and ~8% (11,020 / 140,000 = 7.87%). The
  `system.file()` paths survive R CMD check (`inst/vignette-data` is not in `.Rbuildignore`, and the
  existing tests use the same pattern).
- CLAUDE.md "fixed by masking with the DEM before the overlays" matches the code at R/fl_valley_confine.R:274.
  `na_block_fixture()` exists, and the `fl_patch_rm()` early-return sentence matches R/fl_patch_rm.R.
- NEWS: the overlays are still added inside a gap (code). The gap feeds slope, cost and flood (the
  documented behaviour). "No valley cell moved" matches the stated 1-counts. The vignette shares are
  unchanged (stac_meta counts identical). "draw the uncovered area in its own colour" holds, apart from
  the ~23 channel-buffer cells noted above.
- Vignette "no-lidar cells included" labels are accurate, because `ncell()` counts NA cells.
