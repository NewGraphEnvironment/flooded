# Code-check round 4 (branch 78 at 2d71375; round 3 fix reviewed closely)

Reviewer: general-purpose subagent. All probes ran in a `git archive HEAD` copy
(`scratchpad/rv4/`) and mutated copies of it (`scratchpad/mut_*`). The only repo file I wrote
is this one. "Routed" below means every pipeline-free `sf::st_transform()` on an sfc goes through
`terra::project(terra::vect(x), crs)` (terra links PROJ 9.8.1; sf links 9.5.1). The sf method
still calls the namespace generic for its geometry, so `mock_sf_datum_shift()` still reaches it.
The measured 3005 -> 3979 split under routing was (+0.706, -1.054) m, the documented one.

Baseline: HEAD has 29 blocks and 108 passing expectations, 0 failed and 0 errors, both plain
and routed. That matches the parent's claim.

## Mutants (fails = expectations failing; blocks in brackets)

| mutant in R/fl_dem_aoi.R | plain sf (9.5.1) | routed (9.8.1) |
|---|---|---|
| M1 `aoi_pipeline()` returns `""` (0.7.0's AOI transforms) | red: window, crop, third, wgs84 | red: window, crop only; **third and wgs84 green** |
| M2 round 3's mutant: the pin + `affine +xoff=1.3 +yoff=1.3` | red: window, crop, third, wgs84 | red: crop, third, wgs84; **window (reproject) green** |
| M3 the pin + `affine +xoff=0.7 +yoff=-1.05` | red: 4 blocks | red: 4 blocks |
| M4 line 216 `pipeline = pipeline` (round 2's defect) | red: third, wgs84 | red: third only; **wgs84 green** |
| M5 line 216 grid for a third-CRS AOI left to sf (`""`) | red: third, wgs84 | **all 29 blocks green** |
| M6 line 194 read window left to sf (`""`) | red: window, crop | red: window, crop |
| M7 line 216, AOI-in-source branch, + 13 m affine | red in 3 #67 blocks | (not run) |

**M2 on routed sf, compared with HEAD output.**
- Reproject path: the mutant's values are identical to HEAD at offsets 12 and 21, which are the
  offsets the test uses. Offset 22 differs in 29 cells, but the test does not use it.
- Crop path: the extent is identical at offset 12 and differs only at offset 22.

## Findings

- **[severity: fragile]** tests/testthat/test-fl_dem_aoi.R:168-176 (`x_field_3979()`) with
  :270-290 (`window_offsets` and its comment), :400-424 (the window and crop blocks) and :350-357
  (the guard's first loop).
  - **The new assertions depend on sf's PROJ.** Round 3 added `expected_window_dem()` assertions,
    and their power depends on sf's PROJ. The guard does not measure that power.
  - **Why.** The fixture's origin comes from a plain `sf::st_transform()`, so it moves with sf's
    PROJ. The expected window is pinned, so it does not. The offsets 12/21/22 were searched on
    PROJ 9.5.1, where plain and pinned coincide.
  - **What routing does.** On an sf linking PROJ 9.8.1 the pinned window sits (−0.7, +1.05) m
    from where it sat relative to the fixture grid. Round 3's own window mutant (M2) then:
    - is undetectable on the reproject path: the output is identical to HEAD at offsets 12 and 21;
    - is caught on the crop path at offset 22 only.
  - **The guard stays green.** Its first loop compares the plain transform with the mocked plain
    transform. Those move together with the fixture on any PROJ, so it measures only the
    invariance assertions' power against 0.7.0, not the new `expected_window_dem()` assertions.
  - **The comment overstates.** "For `reproject` and `crop` ... the two move together on any
    PROJ" holds for 0.7.0's window. It does not hold for the pinned window those blocks now
    assert against.
  - **Consequence.** The disposition in review-round3.md says "round 3's window mutant ... red".
    That was measured on sf 9.5.1 only.

- **[severity: fragile]** tests/testthat/test-fl_dem_aoi.R:358-385 (the guard's CSRS half, the
  round 3 rework), :470-501 (the third-CRS and WGS 84 blocks).
  - **The rework.** The guard now measures `pinned` against `pinned + 1.3`. That is
    PROJ-independent, and it is the power against a deterministic offset of the pin (M2).
  - **What it no longer measures.** It no longer measures the power of the two assertion kinds
    these blocks rely on against the regression #78 fixes: the AOI's transforms left to sf's PROJ
    (M1, M5). That power is:
    - the invariance assertion: `snapped(plain_X)` against `snapped(plain_X + 1.3)`;
    - the extent assertion: `snapped(plain_X)` against `snapped(pinned)`.
    Both depend on what sf's PROJ does (`plain_X`).
  - **What routing shows.** Routed through PROJ 9.8.1:
    - M5, a third-CRS grid left to sf (round 1's and round 2's defect class), passes **all 29
      blocks**;
    - M1 (full 0.7.0 AOI transforms) passes the third-CRS and WGS 84 blocks;
    - M4 (round 2's line-216 defect) passes the WGS 84 block, "pins an AOI's grid when the
      source -> target pair has no pin", whose subject is exactly that defect.
  - **The guard passes in every one of these cases.**
  - **Before and after.** Round 3 found the guard going red on that toolchain. The rework turned
    it green without restoring the power it reported was missing, so it now fails toward pass.
  - **The title is now false for its CSRS half.** "the mock shifts an unpinned transform, so the
    offsets reach a cell boundary": that half involves neither the mock nor an unpinned
    transform.
  - **Fix for both findings.** Make every position the offsets are measured against
    PROJ-independent:
    - build `x_field_3979()`'s origin through `dem_pipeline_nad83(aoi crs, crs)` when it is
      non-empty;
    - have `mock_sf_datum_shift()` substitute the pinned transform plus 1.3 m for pipeline-free
      sfc calls between pinnable pairs, instead of adding 1.3 m to sf's own answer;
    - compare the pinned transform with the mocked one in the guard's first loop.
  - **Trial in a copy (`scratchpad/rv4fix/`).**
    - On HEAD it stays at 108 passing plain.
    - Routed, M1, M2, M4 and M5 all go red: window, crop, third and WGS 84 as applicable.
    - It breaks one block on routed sf: `pipeline = ""` "leaves the read window to sf's PROJ too"
      (2 failures). That block asserts that the mock moves sf's plain answer, and under a
      substituting mock the unmocked `""` result is `plain_X` while the mocked one is
      `pinned + 1.3`. It would need its own offset, or a plain window computed in the test.
  - **Alternative.** Detect a datum-taking sf (plain against pinned on a probe point) and
    `skip()` the CSRS and window-power parts with a message, so the loss is visible rather than
    green.

## Checked and fine

- **`expected_window_dem()` against `fl_dem_aoi()`.** It reproduces the code's operations:
  - the buffer;
  - the crop path's `terra::crop(r, terra::vect(win), snap = "out")`;
  - the template from the buffered bbox snapped to `res(r)[1]`, matching `dem_res_default()`'s
    `r_res[1]`;
  - pad = 2 * max(res), with `snap = "out"`;
  - bilinear with the 3979 -> 3005 pin.

  Using `dem_pipeline_nad83()` for both window and warp is acceptable: a builder defect shows in
  the #67 value test (`cell_x_3979()` against the literal `pipeline_3005_to_3979`). Comparing ext
  and values but not CRS WKT is fine: the gpkg WKT and EPSG:3005 differ only textually. With a
  supplied pipeline (`window = given, reverse = TRUE, warp = given`) the expected value is
  correct.
- **`pinned()`, `plus_shift()`, `moved()`.** They compute what their comment says: shift-free
  position against shift-free + 1.3 m. `st_set_crs` on the shifted geometry is needed and
  correct. They hold whatever PROJ sf links (green routed). The problem is what they are used to
  vouch for (finding 2), not their arithmetic.
- **Enumeration in review-round3.md.**
  - It is complete for R/fl_dem_aoi.R's cell-deciding transforms: :190, :194 (also the :204 early
    return), :214–217, the warp at :241 (#67 value test) and :305 (message only).
  - Row :214 does not separate the `aoi_crs == r_crs` branch of :216. That branch is covered by
    #67 blocks: M7 turns 3 of them red.
  - The enumeration names an assertion per call site. It does not show that the assertion has
    power on every PROJ, which is what both findings are about.

/Users/airvine/Projects/repo/flooded/planning/active/review-round4.md

## Parent session: disposition and terminating enumeration (2026-10-14)

Both findings real (inside round 3's fix): the fixture origin and the mock followed sf's PROJ while
the expectations were pinned, so on an sf linked to PROJ 9.8.1 the tests lost power and the guard
stayed green. Fixed as trialled: `pin_transform()` drives the fixture origin, the mock (pin + 1.3 m
on any PROJ) and the guard; mocked runs are asserted equal to independently built results; the
`pipeline = ""` block asserts the mocked run equals a window of pin + 1.3 m and differs from the pin.

Enumeration that ends the loop: every cell-deciding transform site in `R/fl_dem_aoi.R` mutated, on
both toolchains (sf PROJ 9.5.1 as installed; sf's pipeline-free transforms routed through terra's
PROJ 9.8.1), `test-fl_dem_aoi.R` failures:

| tree | sf 9.5.1 | routed 9.8.1 |
|---|---|---|
| branch HEAD | 0 (112 pass) | 0 (112 pass) |
| M1 0.7.0's `R/fl_dem_aoi.R` | 17 + 2 err | 20 + 2 err |
| M2 read window pinned + 1.3 m (:194) | 12 + 3 err | 12 + 3 err |
| M4 third-CRS grid gets the source->target pin (:216) | 6 | 6 |
| M5 third-CRS grid left to sf (:216) | 6 | 6 |

The supplied-pipeline window (:190) is guarded by the `reverse = FALSE` mutation recorded in
progress.md (Phase 2) and the independent expected result.
