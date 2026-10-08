# Code-check review, round 4 (#63 staged diff, 2026-10-08)

Scope: the round-3 rewordings. The shipped prose is clean. That covers the roxygen `@return`
and `@details`, the `man/` page (it matches the roxygen), the code comment above
`terra::mask(valleys, dem)`, the test header block and the `data-raw` comment. The remaining
false or unbacked sentences are all in the planning record. One of them feeds the Phase 5 NEWS
entry.

Test run: I copied the staged tree (`git checkout-index`) to scratchpad `r4/pkg` and ran
`NOT_CRAN=true Rscript -e 'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-fl_valley_confine.R")'`.
Result: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 53 ]`.

## Findings

- **[medium, wrong claim → NEWS]** `planning/active/task_plan.md:31-33` and
  `planning/active/findings.md:39-43`. Both present 679 as the `channel_buffer = FALSE` version
  of the 1,028 measurement. task_plan.md has "1,028 … (679 with `channel_buffer = FALSE` …)".
  findings.md has "1,028 … (channel buffer on). Code-check round 3 measured the
  `channel_buffer = FALSE` case: 679". In fact the two numbers come from **different gaps**:
  - 1,028 comes from the plan-mode block ("centred on a valley cell", which gave 918/43 in the
    block without the buffer).
  - 679 comes from `na_block_fixture()`, which gave 901/60 before the fix.
  - The buffer is applied as an OR overlay only after cleanup (`R/fl_valley_confine.R:276+`).
    So turning it on cannot increase the number of cells that differ outside the gap.
  - Measured (`r4/probe.R`): the fixture gives **679 with `channel_buffer = FALSE` and 679 with
    `TRUE`**.

  Two consequences follow. First, the 1,028 → 679 gap is caused by where the block sits, not by
  the buffer. Second, the round-3 breakdown (flood 488, 659 cells 0→1, max 940 m) describes the
  fixture's gap, not the 1,028 one. The fix is to give each number its own gap, and to drop
  "(channel buffer on)" as the thing that separates them.
- **[low, wrong number]** `planning/active/findings.md:41`, "slope and cost on only the 25-cell
  ring". The ring around the 31x31 gap has **128** cells (round 3: "128 of 128 ring cells have NA
  slope"). Round 3's 25 is the number of *changed* cells that lie on the ring. Suggested wording:
  "slope and cost on only 25, all on the ring next to the gap".
- **[low, unbacked; same claim round 3 removed from the R comment]** `planning/active/task_plan.md:21`,
  "Lidar is often NA over open water". Nothing in the repo measures this. The only lidar NA on
  record is the 2019 flight footprint. The overlays-win decision does not depend on this claim.
- **[low, same class as round 2]** `planning/active/task_plan.md:10` ("returns `0` on NA DEM
  cells"), `task_plan.md:4` and `findings.md:7` ("it actually returns **0**"). The probe two
  lines below says 815 zeros and 146 ones, and round 2 measured 901/60 on the fixture. The
  correct statement is "0 or 1". Lines 4 and 7 copy the issue body, and the title of #63 says the
  same. If you fix it, fix it in the issue body too.
- **[low, optional]** `tests/testthat/test-fl_valley_confine.R:389`, "a cell with a DEM value is
  **always** measured". This holds on this fixture only. Round 1 probed a reachable exception:
  `costDist` gives NaN on valid cells that are cut off from every stream, and these stay NA when
  `fl_patch_rm()` early-returns (#65). The assertion is correct, but the comment generalises.
  Suggested wording: "here, every cell with a DEM value is measured".

## Checked and true

- `@return`: the mask runs before both overlays, and both overlays use `background = 0L`, so the
  claim holds in one direction. It does not say NA appears *only* there.
- `@details`: "set to `NA` wherever `dem` is `NA`" holds. "Enters the slope, cost-distance and
  flood steps" holds: `fl_flood_model(dem, …)` and slope from `dem`, round 3 counts 25/25/488,
  distance 0, correctly not listed. "Not only at its edge" holds: median 670 m, max 940 m. "Do
  not depend on the DEM": the overlays are rasterized onto the grid only.
- Code comment: "`fl_patch_rm()` can turn NA into 0 (#65)". `R/fl_patch_rm.R:41` (early return)
  and `:46` confirm it, and #65 is titled "fl_patch_rm() and fl_patch_conn() turn NA input cells
  into 0". The focal smear is from round 3 (60 cells, 59 on the outer ring).
- Test header ("came back as measured hillslope and valley"): round 2 and round 3 measured
  901/60.
- `data-raw` comment: NA where there is no lidar, except under the channel buffer. `vca_args`
  passes no `waterbodies`, and the auto-detected buffer is TRUE. "Before that 0 or 1": the cached
  tifs have 0 NA.
- `task_plan.md` Context, "about 43 focal smear, remaining 103 (by subtraction) with the buffer".
  The buffer is overlay-only, so the buffer-off run's ones are a subset of the buffer-on run's
  ones, and the subtraction is exact.
- Phase 1 items: they match the three tests as written.
- `R/fl_patch_rm.R:46` is the `ifel(is.na(masked) | is.na(patches), 0L, x)` line, as cited.

The working tree was not modified. All runs used scratchpad copies.
