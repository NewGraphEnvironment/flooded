# Code-check round 3 (branch 78, whole branch at ae0a340; round 2 fix diff reviewed closely)

Reviewer: general-purpose subagent. I ran the probes in a scratch copy of HEAD (`git archive` into
the session scratchpad, `rv3/`) and in mutated copies of it. The only repo file I wrote is this one.

## The mechanism

Rounds 1 and 2 found instances of one assumption: **what was observed in one configuration is
treated as the property itself.**

- **In the tests**, each #78 guard was written as a relation between two runs of the code under
  test: mocked sf against unmocked sf. The reference is produced by the thing being checked. Any
  error that is deterministic and does not pass through the mock gives the same answer both ways,
  so the guard passes. That is round 2's third-CRS gap.
- **In the prose and the fixtures**, a result measured on one toolchain or one call shape (sf on
  PROJ 9.5.1, an AOI in 3005) is stated with a wider quantifier. That is round 1's "flips", its
  attribution to "sf's default PROJ", and its WGS 84 sentence.

## Every #78 test and quantified claim, checked

### Tests

| test | what it asserts | verdict |
|---|---|---|
| mock reaches a cell boundary (meta) | precondition, measured on sf's PROJ 9.5.1 | **fails on PROJ 9.8.1** (finding 2) |
| reads the same source window | mocked = unmocked only | **invariance only** (finding 1) |
| crops on the source grid the same | mocked = unmocked only | **invariance only** (finding 1) |
| inverts a supplied pipeline | against an independently built expected value | OK |
| stops clearly when a pipeline cannot be applied in reverse | errors | OK (both branches have mutations that fire, round 2) |
| third CRS (round 2 fix) | extent = `pinned_grid_ext()`, more than 50% non-NA, plus invariance | OK |
| no pin for the source -> target pair (round 2 fix) | extent = `pinned_grid_ext()` | OK |
| `pipeline = ""` | the mock changes the result | OK |

**Round 2 fix, verified.** I applied round 2's own mutant: line 216 changed to
`pipeline = pipeline`. The third-CRS block and the WGS 84 block both turn red. A second mutant, a
pinned +1.3 m affine appended to `aoi_pipeline()` (which also moves the grid), turns the same two
blocks red. HEAD has 29 blocks, 0 failed and 0 errors under `NOT_CRAN=true`.
`pinned_grid_ext()` uses `dem_pipeline_nad83()` itself, but the #67 value test checks that builder
independently (`pipeline_3005_to_3979`), so this is acceptable.

### Prose

| claim | verdict |
|---|---|
| Roxygen, CLAUDE.md and research: "47–91 cells, 3 of 60, none inside the buffered AOI", and "0 of 60" | matches the logs (round 2 re-ran it) |
| CLAUDE.md: "Outside projected NAD83 pairs (a WGS 84 source, a geographic or northing-first AOI) ..." | OK |
| Test comment: "origin and plain window move together **on any PROJ**" | **false** for the `third` and `wgs84_source` sets (finding 2) |
| research/dem_reprojection.md: "Since #78 it holds for both **where the AOI's pairs are projected NAD83**" | too wide (finding 3) |

## Findings

- **[severity: fragile]** tests/testthat/test-fl_dem_aoi.R:349-369 ("reads the same source window
  ..." and "crops on the source grid the same ..."), guarding R/fl_dem_aoi.R:174.
  - **The gap.** This is round 2's mechanism on the read window itself, which is the subject of
    #78. Both blocks assert only that the mocked and unmocked runs agree. No #78 test checks where
    the read window lands. The pre-existing crop test has the AOI in the source CRS, so no
    transform is involved.
  - **Mutation.** Line 174 now pins the window to a deterministic 1.3 m datum step:
    `paste(p, "+step +proj=affine +xoff=1.3 +yoff=1.3")`. This is what hard-coding PROJ 9.8.1's
    route would do, or a regression in the pin builder for the AOI pair.
  - **Result.** All 29 blocks stay green (0 red).
  - **What the mutant changes.** Measured against HEAD at the test's own offsets:
    - On the crop path (`target_crs = 3979`), the returned extent differs at all three offsets
      (12, 21 and 22).
    - On the reproject path, 49, 179 and 94 cells change.
  - **Why it matters.** The window's defect class goes unseen whenever it is the same under both
    PROJ choices: a wrong DEM extent or wrong edge cells.
  - **Fix.** As round 2 did for the grid, also assert against a window computed in the test:
    - Crop path: `terra::crop(r, terra::vect(<buffered AOI carried shift-free to 3979>), snap = "out")`.
    - Reproject path: the template-and-crop construction already used in "inverts a supplied
      pipeline", with the pin in place of `given`.

- **[severity: fragile]** tests/testthat/test-fl_dem_aoi.R:270-282 (the `window_offsets` comment)
  and :327-342 (meta test "the mock shifts an unpinned transform ...").
  - **The false claim.** The comment says "The fixture's origin comes from a plain transform on
    purpose, so origin and plain window move together on any PROJ". That holds for `reproject` and
    `crop`, where the AOI is in 3005. It does not hold for `third` or `wgs84_source`:
    - The AOI there is NAD83(CSRS) / UTM 10N, so its window into 3979 (CSRS to CSRS) has no datum
      step.
    - The 3005 grid snap does not depend on the fixture's origin.
    - So those offsets were found against sf's PROJ 9.5.1, not against any PROJ.
  - **Probe.** I re-ran the file with every pipeline-free `sf::st_transform()` routed through
    terra's PROJ 9.8.1, via `assignInNamespace`. The measured split was +0.706 / −1.054 m, the
    documented one.
  - **Result.** The meta test goes red with 4 failures: `third` at offsets 8 and 18, and
    `wgs84_source` at offsets 1 and 18. "moved || window_moved" and "moved" are FALSE there. All
    other blocks stay green.
  - **Why it matters.** sf on this machine already lags terra's PROJ, and an sf binary rebuilt
    against PROJ 9.8.x fails the suite red with no defect in `fl_dem_aoi()`. On that toolchain the
    third-CRS and WGS 84 invariance assertions also stop reaching a cell boundary. They become
    vacuous, though the round 2 extent assertions still hold.
  - **Fix.** Either:
    - derive those offsets from a shift-free transform, so they do not depend on sf's PROJ; or
    - skip or condition the `third` / `wgs84_source` part of the meta test on sf's PROJ version,
      and correct the comment.

- **[severity: fragile, prose]** research/dem_reprojection.md, the reproduces-across-toolchains
  bullet.
  - **The claim.** "Since #78 it holds for both where the AOI's pairs are projected NAD83."
  - **Why it is too wide.** The pin also requires easting-then-northing axes (`east_north()` in
    `dem_pipeline_nad83()`). A northing-first projected NAD83 AOI, such as an ICS83 zone, going to
    a CSRS source gets an unpinned window, so its edges still follow sf's PROJ.
  - **Mitigation.** The very next bullet and CLAUDE.md both name northing-first as unpinned, so a
    reader can recover the qualification.
  - **Fix.** Say "projected NAD83 with easting-then-northing axes".

## Parent session: disposition and enumeration (2026-10-14)

All three findings fixed in the next commit: `expected_window_dem()` gives the reproject, crop and
supplied-pipeline tests a result built from a stated window operation; the guard's CSRS checks
measure from the shift-free position, so they no longer depend on sf's PROJ; research wording adds
easting-then-northing. Checks: branch 108 pass; round 3's window mutant (pinned +1.3 m affine)
red (6 failed, 3 errors); whole file with sf's plain transforms routed through terra's PROJ 9.8.1
green (108 pass).

Enumeration that ends the loop (mechanism: a guard comparing two runs of the same code):
every transform call site in `R/fl_dem_aoi.R` that decides cells, and the #78 test that pins its
output independently of the mock.

| call site | independent assertion |
|---|---|
| :190 read window, supplied pipeline (reverse) | "inverts a supplied pipeline" (expected_window_dem with the string) |
| :194 read window, default pin (also the early-return crop) | "reads the same source window", "crops on the source grid" (expected_window_dem) |
| :214 grid, AOI -> target | third-CRS and WGS 84 blocks (pinned_grid_ext + non-NA share) |
| :305 dem_res_default, AOI centre to 4326 | message text only; decides no cell |

The two remaining mock-only blocks are by design: the guard (test power) and `pipeline = ""`
(asserts the escape hatch does follow sf).
