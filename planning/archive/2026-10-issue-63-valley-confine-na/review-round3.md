# Code-check review, round 3 (#63 staged diff, 2026-10-08)

## Mechanism behind the round 1 and round 2 findings

All three earlier findings were prose describing **what the pipeline does to cells**. Each was
written from the code path the author had in mind, then stated with an unqualified quantifier
("always", "every", "0") or a closed list. Nobody ran the pipeline on the fixture and counted.
`fl_valley_confine()` has an early return (`fl_patch_rm()`), neighbourhood operations (the focal
smear) and steps that carry NA forward (`costDist`, the flood surface). Prose written from intent
picks up the first path that comes to mind and misses the rest. This is the CLAUDE.md rule "a
non-valley cell has no single cause", applied to a gap.

Below, every prose claim in the diff is checked against a measurement on the test's own
`na_block_fixture()` (31x31 gap, 10 m bundled tile, 648x800 cells). The scripts are in the
scratchpad (`r3/probe.R`, `r3/trace.R`, `r3/attrib.R`) and loaded the staged tree read-only.

## Findings

- **[fragile, prose — wrong mechanism, ships in the man page]** `R/fl_valley_confine.R:69-70`
  (`@details`), mirrored at `man/fl_valley_confine.Rd:110-111`: *"The gap still feeds the slope,
  cost-distance and patch steps, so valid cells near it can differ from a run on a complete
  DEM."* The list leaves out the step that does most of the work, and "near" is not supported.
  Measured with the fixture against the complete DEM, `channel_buffer = FALSE`:
  - **679** valid cells outside the gap change.
  - The **flood** criterion differs on **488** of them. `fl_flood_model(dem, …)` reads the DEM
    directly, and the sentence does not name it. **Slope** and **cost** differ on only **25**
    each, which is the ring next to the gap where slope becomes NA. **Distance** differs on 0.
    The remaining ~166 come from cleanup acting on those changes.
  - The change mostly *adds* valley: **659** cells go 0->1 and **20** go 1->0. The listed steps
    suggest a barrier, which would shrink valley, but that is the minority effect.
  - Distance from the gap edge: median **67 cells (670 m)**, max **94 (940 m)**. 455 of the 679
    lie 30-100 cells out, and 25 are adjacent. "Near" undersells this.

  A suggested wording: *"The gap still feeds every step that reads the DEM (slope, cost distance
  and the flood model) and the cleanup filters, so valid cells can differ from a run on a
  complete DEM, and not only next to the gap."* Phase 5 (NEWS, item #13) will reuse the same
  attribution. Its source is the plan text, "the NA acting as a barrier (cost distance, patch
  connectivity)" in `task_plan.md` Context and `findings.md`, which was not measured either.

- **[fragile, prose — same class as round 2]** `R/fl_valley_confine.R:67-68`,
  `man/fl_valley_confine.Rd:108-109`: *"reads as unmeasured rather than as hillslope"*. This
  implies the old output was hillslope. Measured on this fixture before the fix, the gap came
  back as **901 `0` and 60 `1`** (round 2 found the same, and `trace.R` reproduces it). For a gap
  inside the data, the old output was "hillslope or valley". The wording holds for a DEM clipped
  to a watershed (Parsnip: 0 of 441,054 valley cells on NA). Suggested wording: "rather than as
  measured ground".

- **[unmeasured]** `R/fl_valley_confine.R:272` comment: *"lidar is often NA over open water,
  exactly where they matter."* Nothing in the repo measures this. The repo's only lidar case gets
  its NA from the **flight footprint** (`data-raw/stac_dem_vignette_data.R:152-153`: "the 2019
  flight footprint leaves ~22%"), not from water. The overlay-wins placement is the user's
  decision at the plan gate and the code is fine. Only the factual "often" lacks a source.
  Either say "can be NA over open water" or cite where it was observed.

- **[planning note certifies a test that does not exist]** `planning/active/task_plan.md`,
  Phase 1, first item, flipped to `[x]`: *"an NA block **away from streams** and waterbodies
  (`channel_buffer = FALSE`)"*. The test as written uses `na_block_fixture()`, which centres the
  gap on a buffered-stream cell. That centre cell is valley in the complete run, and **681 of
  961** gap cells are valley. So the gap sits *on* a stream. The test is stronger than the plan
  described, but the ticked text describes a different test. Reword the item to match.

## Outside the diff (residuals of round 1, in the planning record)

- `task_plan.md` Context: "it sets **every** NA cell to 0". `findings.md` says "converts
  **every** NA reaching it". Both still carry the round 1 overstatement. `fl_patch_rm()`
  returns early when there are no small patches.
- `task_plan.md` Context: "Of the 146 ones, about 43 are focal smear … and about 103 are the
  channel buffer". This is 146 - 43 by subtraction, and it assumes the two sets are disjoint. It
  was never counted.

## Claims checked and found true (measured)

- R comment, "`fl_patch_rm()` **can** turn NA into 0": on the fixture, 841 NA gap cells reach it
  and leave as 0. The non-early-return path ran, because 74 small patches exist.
- R comment and test header, "the focal filters smear 1s into a gap's edge": the closing filter
  puts **67** 1s into the gap and the modal filter leaves **60**. Of those 60, 59 are on the gap's
  outermost ring and 1 is one cell in. The hole-fill step adds none.
- Test header, "fl_patch_rm() turned NA reaching it into 0 … came back as measured hillslope and
  valley": true on this fixture, because the non-early-return path ran.
- Fixture comment, "on the floodplain rather than on hillslope": the centre cell is `1` in the
  complete-DEM run. It is not a burned stream cell, it is a buffer cell. "The gap also overlaps
  valley floor": 681 of 961.
- Test 1 comment, "the ring next to the gap where slope is undefined": 128 of 128 ring cells
  have NA slope.
- `@return`: the code bears it out. The mask comes before both overlays, and both overlay rasters
  use `background = 0L`, so `ifel(x == 1L, 1L, valleys)` leaves NA alone unless a cell is
  covered.
- "They do not depend on the DEM": the buffer and the waterbodies use only the `dem` grid, never
  its values.
- `data-raw` comment, "before that it returned 0 or 1": the cached pre-fix `stac_valleys_5m.tif`
  and `stac_valleys_1m_site.tif` both have 0 NA. No `waterbodies` are passed, so "except under
  the channel buffer" is complete.
- `progress.md`, "full suite 289 pass": reproduced. 18 files, 289 expectations, 0 fail, 0 skip,
  `NOT_CRAN=true`. "Lint clean": the only lints are the accepted `testdata_path` lints.
- The working tree was unchanged by this review (`git status` was identical before and after).

No code defects found.
