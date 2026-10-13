# Code review round 1: branch 67-fl-dem-aoi-lets-gdal-choose-the-output-g vs main

Reviewer probes ran from the scratchpad against `pkgload::load_all()` of the repo. No repo file
was edited apart from this one. Environment: terra 1.9.50 (GDAL 3.13.0 / PROJ 9.8.1), sf 1.1.2
(GDAL 3.8.5 / PROJ 9.5.1).

## Findings

- **[severity: bug]** R/fl_dem_aoi.R:225-238 and :206. **A geographic NAD83 source or target
  returns an all-NA raster, with no error.** `dem_pipeline_nad83()` writes the longlat end as a
  bare `unitconvert deg<->rad` in lon,lat order. GDAL's warper applies the CRS's data-axis
  mapping around a user-supplied operation, so the pipeline gets EPSG axis order (lat,lon).
  sf's `st_transform(pipeline=)` does not do this, so the same string gives the template-bbox
  path the right answer and gives terra the wrong one. Reproduced on the bundled data:
  - `fl_dem_aoi(streams, source = dem.tif, buffer = 100, target_crs = 4269, res = 1e-4)` has
    **0 non-NA cells**. With `pipeline = ""` it has 356,902 cells, mean 740 m.
  - The reverse case is a geographic NAD83 source, written in EPSG:4617 like CDEM:
    `fl_dem_aoi(streams, source = <4617 tif>, buffer = 100, target_crs = 3005, res = 10)` has
    **0 non-NA cells**. With `pipeline = ""` it has 257,715.
  - Appending `+step +proj=axisswap +order=2,1` makes `terra::project()` match PROJ's own
    answer exactly (max |d| = 0). The same string passed to sf then fails
    ("area of interest not accepted / Invalid dfSouthLatitudeDeg"). So no single string serves
    both calls, and the same goes for a user-supplied `pipeline` whenever `aoi_crs == r_crs`.

  This is reachable from documented use. A geographic `target_crs` with `res` is the advertised
  path, and an AOI in 4269 or 4617 makes it the default target. The simplest safe fix is to
  return `""` from `dem_pipeline_nad83()` when either side is longlat. Otherwise the terra and
  sf calls need separately built pipelines. No test covers a geographic NAD83 end: the 4326
  tests are not NAD83, so they get `""`.

- **[severity: bug]** DESCRIPTION `Imports: terra` (no version floor) against
  R/fl_dem_aoi.R:206. `terra::project(..., pipeline = )` exists from terra 1.9-25. It is absent
  in 1.9-11 and 1.8-80 (checked in the CRAN archive sources). On older terra the argument falls
  into `...`, and from there into `spatOptions()`, which raises `[write] unknown option(s):
  pipeline`. Every reprojecting call then errors, including the default MRDEM to BC Albers path
  and `pipeline = ""`. pak will not upgrade terra for a package with no floor. Needs
  `terra (>= 1.9-25)`.

- **[severity: fragile]** R/fl_dem_aoi.R:216-222 (`is_nad83`). The datum regex
  `"(North American Datum 1983|NAD83[^"]*)"$` misses the EPSG realizations named "North
  American Datum **of** 1983 (...)":
  - EPSG datums 1193-1198 and 1365: NAD83(CSRS) versions 2 to 8. For example, EPSG:22209 has
    datum "North American Datum of 1983 (CSRS) version 2".
  - 1192 (CSRS96), 1221 (MARP00) and 1249 (PACP00).

  For these pairs the pin quietly falls back to PROJ's choice, which is the toolchain-dependent
  behaviour the PR removes elsewhere. The Rd `pipeline` text ("two NAD83 realizations on GRS80
  (NAD83, NAD83(CSRS), ...)") and the CLAUDE.md bullet ("Between NAD83 realizations on GRS80
  the datum step is pinned") claim more than the code does. Combined with the first finding,
  the claim is false for longlat CRSs as well.

- **[severity: bug (false claim)]** tests/testthat/test-fl_dem_aoi.R:206-208, repeated in
  planning/active/findings.md ("median 3 cm, p99 6 cm = warp approximation"). The test comment
  says "The residual is GDAL's warp approximation (median 3 cm, p99 6 cm)". It is not. It is
  the **Float32 rounding of terra's output**:
  - The x-field values are about -1.9e6, where a Float32 step is 0.125 m, so rounding is at most
    6.25 cm with a median of about 3.1 cm.
  - Every output value is Float32-representable, measured on the test's own setup.
  - Measured: |result - exact| has median 0.0313, p99 0.0619. After rounding the exact value to
    Float32 first, the median and p99 are both **0**.

  The comment also contradicts the branch's own CLAUDE.md and findings, which say terra's warper
  uses an exact transformer. The same mechanism probably explains the "0.12 mm" terra vs
  gdalwarp `-et 0` residual: MRDEM values near 1,000 m have a Float32 step of about 1.2e-4. That
  number stays true as an upper bound, but its cause is the output type.

- **[severity: fragile (test passes for the wrong reason)]**
  tests/testthat/test-fl_dem_aoi.R:213-229. The `given` arm passes
  `dem_pipeline_nad83(3979, 3005)`, which is byte-identical to the default pin. So
  `expect_identical(values(given), values(pinned))` stays green under a mutation that ignores a
  user string and always pins, such as `if (is.null(pipeline) || nzchar(pipeline)) pipeline <-
  dem_pipeline_nad83(...)`. "a string is used as given" in the test title is not guarded. A
  distinguishable string, such as the PROJ 9.8.1 WGS 84 route, or a deliberately offset
  `+proj=affine +xoff=...` step, would discriminate.

- **[severity: low, false generalisation in user docs]** R/fl_dem_aoi.R:53-55 /
  man/fl_dem_aoi.Rd. The text says "MRDEM-30 came out at about 30.43 m". That is MORR's value.
  The same branch's vignette and methodology.md record 30.54 m for Parsnip. The cell size GDAL
  chose depended on the AOI, so the sentence should say so or name the AOI.

- **[severity: low, evidence provenance]**
  planning/active/logs/20261013_measure_grid_morr.log. Its lines name commits that do not
  contain the code that was measured:
  - "flooded 0.6.6 (load_all, git cbeaa79)": cbeaa79 has no `res` argument, yet the harness
    calls `fl_dem_aoi(res = )`. The run was at 16:48Z, and cb53fb7 was committed at 16:49Z.
  - "(d) pinned (default): git a08c094": a08c094 has no `dem_pipeline_nad83`. The pin landed in
    30df085 at 17:24Z, and the log line is 17:20Z.

  Both runs measured uncommitted working-tree code, so the recorded SHA cannot reproduce them.

## Checked and found sound

These were checked against the diff and are not issues:
- Projected NAD83 pairs give the same pipeline result as PROJ 9.5.1's shift-free default:
  2227 (US-ft), 2955, 3979 and 26910.
- `+units=us-ft` is carried correctly.
- Compound (`+vunits`) sources and targets work.
- A BOUNDCRS whose first DATUM is NAD83 is handled.
- ESRI "Meter" WKT normalises to `metre` in `units_gdal`.
- MRDEM's own WKT is recognised and pinned.
- The same-CRS short-circuit is unchanged.
- floor/ceiling at `res = 30` gives exact multiples.
- The pin test discriminates (about 0.7 m shift against a 0.1/0.2 m threshold).
- Numeric prose re-derives from the logs:
  - 6.3% = 43,460.1 / 40,888.2
  - 4.4%
  - 0.6% = 40,888.2 / 41,142.9
  - 14.1 vs 20.9 Mcell
  - +0.02%
  - 1.13 / -0.61 m, which is about 1.3 m
