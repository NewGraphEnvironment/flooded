# Code review round 2: branch 67-fl-dem-aoi-lets-gdal-choose-the-output-g vs main (HEAD 8bb1d66)

Reviewer probes ran from the scratchpad against `pkgload::load_all()` of the repo, and the one
mutation ran against a `git archive HEAD` copy. No repo file was edited apart from this one.
Environment: terra 1.9.50 (GDAL 3.13.0 / PROJ 9.8.1), sf (GDAL 3.8.5 / PROJ 9.5.1).

## Findings

- **[severity: bug]** R/fl_dem_aoi.R:230 (`dem_pipeline_nad83()`), with :174-185 and :206.
  **The round-1 fix guards the wrong property.** Round 1's fix tests `st_is_longlat()`, but what
  breaks the pin is CRS axis order. Any CRS whose first axis is not easting has the same defect,
  and projected NAD83 CRSs with northing first are still pinned. In EPSG's proj.db there are
  **35** non-deprecated NAD83/GRS80 projected CRSs with northing as their first axis, out of
  1,920. They include **EPSG:2953 "NAD83(CSRS) / New Brunswick Stereographic"**, New Brunswick's
  provincial CRS, and its v2 twin 22240. The other 33 are ICS83 Illinois ftUS zones (23301 to
  23333). The pin fails silently in both directions:

  - **Target northing-first gives an all-NA raster.** The source is a 3979 x-field over New
    Brunswick, and the call is `target_crs = 2953, res = 10`. Pinned: **0 non-NA cells of
    574,000**. With `pipeline = ""`: 406,380. The template extent is right here, so sf handled
    it, but GDAL's warper swapped the axes. The same holds with the AOI in 3979, where the bbox
    goes through sf with the pin, and for 22240.
  - **Source northing-first gives data at the wrong place.** The source is a 2953 raster and the
    AOI is in 2953, with `target_crs = 3979`. `sf::st_transform(pipeline = pin)` also swaps the
    *input* axes. A point at PROJ 3979 (2157195, 157297) lands at **(9854581, -1378097)** with
    the pin. So the template sits about 7,700 km from the AOI, at x 9.85e6. terra then fills
    **323,666 cells with data** there, because its warper makes the same swap. Nothing errors.
    The DEM comes back with values and is georeferenced nowhere near the AOI.

  Three passages state the round-1 mechanism as "GDAL's warper applies the CRS's lat/lon axis
  order around a supplied pipeline and sf::st_transform() does not": the code comment at
  R/fl_dem_aoi.R:216-219, the `CLAUDE.md` bullet, and the round-1 section of `findings.md`.
  That is wrong for a northing-first source, where sf swaps too. The `@param pipeline`
  advice in R/fl_dem_aoi.R:38-39 and man/fl_dem_aoi.Rd:50-51, "supply one only between projected
  CRSs, because GDAL applies a geographic CRS's lat/lon axis order", does not protect a user,
  because 2953 is projected. The same goes for "between projected CRSs on NAD83 realizations the
  operation is pinned" (Rd details, CLAUDE.md).

  Suggested fix: return `""` unless both CRSs' first two axes are east, north. Test the
  property itself, for example the first `AXIS[...]` in each WKT naming `east`, rather than
  longlat-ness. Then cover it with a 2953 case. The existing
  tests cannot see this, because every CRS in them is east-north or geographic.

  Probes: `scratchpad/r2/probe_ne.R` (target side) and `scratchpad/r2/probe_ne_src.R` (source
  side).

## Checked and found sound

- **Step builder, every pinned CRS.** For all 1,920 EPSG NAD83/GRS80 projected CRSs, I compared
  `dem_pipeline_nad83(3979, C)` with PROJ's own same-datum projection, at each CRS's
  area-of-use centre. The comparison ran through sf, which reads east-north and so does not see
  the axis issue above. All 1,920 pin, and the maximum difference is **1.7e-8 m**. That covers
  `+units=us-ft`, `+k`, sterea, omerc and every other method EPSG uses with NAD83. None has an
  empty `proj4string`.
- **Compound CRSs.** `st_is_longlat()` is TRUE for 4617+6647 and 4269+5703, so they get `""`.
  It is FALSE for 3979+6647, which pins correctly with `+vunits` dropped.
- **ESRI WKT1.** NAD83 and NAD83(CSRS) WKT1 (`D_North_American_1983[_CSRS]`, `GRS_1980`) is
  normalised by GDAL to "North American Datum 1983" and "NAD83 Canadian Spatial Reference
  System", whether read through sf or through a terra round trip. Both are recognised and pinned.
- **DESCRIPTION `terra (>= 1.9-25)`.** The string is valid, and terra numbers its CRAN releases
  1.9-1, 1.9-11, 1.9-25, 1.9-27, 1.9-34, 1.9-46 and 1.9-50. In the CRAN archive sources,
  `project(..., pipeline = "")` is present in 1.9-25 and absent from 1.9-11.
- **The round-1 tests discriminate.** I deleted the longlat guard in a temp copy and ran the
  file: 3 expectations failed, in "leaves the operation to PROJ outside projected NAD83 pairs"
  (2) and "returns data for a geographic NAD83 target" (1). The shifted-pipeline arm reddens
  under an "always pin a non-empty string" mutation, because the difference is 50 m against a
  10 m threshold. The `pipeline = ""` arm reddens if the pin is applied anyway, because 0.7 m
  over a mean of 1.9e6 is above the relative tolerance of 1e-9. That relies on the
  already-accepted local-PROJ dependence.
- **The remaining paths.** A geographic AOI with a projected source and target goes through
  plain `st_transform`. A geographic target with the pin returns `""` and takes the `else`
  branch. A user pipeline with `aoi_crs == r_crs` is documented as projected-only, and that
  advice is wrong only as described in the finding above.
- **The doc numbers.** 6.3%, 4.4% and 0.6% are consistent with the round-1 rederivation. The
  14.1 vs 20.9 Mcell figures are consistent with the tighter crop.
