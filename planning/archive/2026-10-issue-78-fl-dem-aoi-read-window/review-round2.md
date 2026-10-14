# Code-check round 2 (branch 78, whole branch at 1cb2b3b; round 1 fix diff reviewed closely)

Reviewer: general-purpose subagent. Probes ran in a scratch copy of HEAD (`git archive` into the
session scratchpad, `rv2/`) and in mutated copies of it (`m_*`). The only repo file written is this one.

## Verified clean

- **Round 1 fix, test comments.** "Valid forward, but urm5 has no inverse: the reverse returns NaN"
  is true. Forward, `no_inverse` gives finite coordinates. In reverse, `dem_st_transform()` returns an
  sf whose bbox is all NA, so the call takes the non-finite branch. "sf errors, and PROJ's own reason
  arrives as GDAL warnings" is also true for `invalid`: the warnings are "Mismatched units between
  step 2 and 3", then the error "OGRCreateCoordinateTransformation(): transformation not available",
  so the call takes the `tryCatch` branch.
- **The two guards fire.** Mutation `if (FALSE && !all(is.finite(...)))` turns "stops clearly ...
  cannot be applied in reverse" red. So does mutation `error = function(e) stop(e)`. Each branch now
  has its own expectation, which round 1 asked for.
- **Error wording.** "could not be applied in reverse ... must be valid, invertible, and run between
  CRSs whose axes are easting then northing" fits both branches.
- **Prose in the round 1 fix, checked against the logs and a re-run.**
  - `measure_window_real_proj.R .` on the HEAD copy reproduces "positions: 60 DEM changed under
    terra's PROJ: 0", with the split at +0.706 / −1.054 m.
  - The 0.7.0 log gives 3 of 60, at dx = 3.5, 21.5 and 28.5.
  - `measure_window.log` gives 49, 91 and 47 changed cells, of which 32, 60 and 31 are NA/value
    flips, and changed_in_aoi = 0. The CLAUDE.md "47–91 ... none inside the buffered AOI", the
    roxygen and research all match.
  - The rewritten research sentence on WGS 84 sources matches the code. With a NAD83 AOI in its own
    CRS, the grid goes through `aoi_pipeline(target_crs)`. With the AOI in the 32610 source CRS, the
    grid uses `dem_pipeline_nad83(32610, 3005)`, which is `""`.
- **The logs are still current.** They were committed in ff0e53b. The code change after it (8387f56,
  `pipeline_arg`) does not touch the measured path (AOI in target, 3979 → 3005 pin is non-empty), and
  the re-run above confirms it.
- **"On sf's own PROJ 9.5.1 the fix is output-neutral".** Probed: on 9.5.1 the pinned transform
  and sf's default agree to 0 m from 3005 to 3979, 3157, 26910 and 6339 (1.9e-9 m to 2927) on the
  bundled buffered streams.
- **Test file on the HEAD copy, `NOT_CRAN=true`:** 29 blocks, 0 failed, 0 errors, 0 skipped.
- **Mutations that do fire:**
  - `aoi_pipeline()` reading `pipeline` rather than `pipeline_arg` turns the "no pin" block red.
  - `aoi_pipeline()` always returning `""` turns 4 blocks red.

## Findings

- **[severity: fragile]** tests/testthat/test-fl_dem_aoi.R:425-435 ("places the grid the same for an
  AOI in a third CRS ..."), guarding R/fl_dem_aoi.R:213-216.
  - **The gap.** The branch adds a new pinned path for an AOI in a third CRS:
    `aoi_pipeline(target_crs)`, i.e. `dem_pipeline_nad83(aoi_crs, target_crs)`. The only test that
    exercises it checks *invariance* (mocked sf against unmocked sf). It never checks that the grid
    lands in the right place. No pre-existing test has an AOI in a CRS that is neither the source's
    nor the target's: every `expected_ext()` test has the AOI in the source CRS or in `target_crs`.
  - **Mutation.** Line 216 was changed to `pipeline = pipeline`, so a 3157 AOI gets the 3979 → 3005
    pin, which is the wrong input CRS.
  - **Result.** The "third CRS" block stays green. Only the WGS 84 "no pin" block fails, and only
    because there the source → target pin is `""`.
  - **What the mutant returns.** For a CSRS UTM 10N AOI with a 3979 source and target 3005, it
    returns a raster at x ≈ −851,200, y ≈ 6,486,146 with 0 non-NA cells. HEAD returns
    976,616–982,836 / 1,055,490–1,059,666 with 26,181 non-NA cells. Both mocked and unmocked runs
    produce the same all-NA raster, so `expect_same_dem()` passes.
  - **Why it matters.** This is the failure the package's own notes warn about: an all-NA or
    misplaced raster with no error. Any wrong-pipeline regression on the third-CRS path (wrong
    `from`, wrong direction, the source pin passed through) is therefore invisible to the suite.
  - **Fix.** In that block, also assert where the grid lands, for example
    `terra::global(out, "notNA") > 0`, or an extent within one cell of the buffered AOI's bbox in
    3005.
