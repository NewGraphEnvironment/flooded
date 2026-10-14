# #76 — fl_dem_aoi(): integer NoData reprojected as data

## Outcome

`fl_dem_aoi()` returned 4294967296 m (2^32) instead of NA wherever its output reached past a
file-backed crop of a UInt32 source, such as the bundled `dem.tif`. The defect is terra's:
`terra::project()` of a file-backed integer raster writes NaN only where the cells still match
the NoData in Float32. A NoData that Float32 cannot hold exactly, such as UInt32 4294967295,
INT4S 2147483647 or INT8U's default, is stored rounded and survives as a value. `gdalwarp` from
the same GDAL build does not do this. The fix keys on datatype: an integer crop is read through
a float copy (`r_clip * 1`) before `project()`. MRDEM-30 and other float sources are untouched.

The issue framed the trigger as "the crop covers the whole file". Measurement showed it is
"file-backed", and a subset crop that terra writes to disk takes the same path. A fix keyed on
"in memory", which the issue proposed, would have missed large AOIs. The tests compare each
integer source against the same DEM written as Float32. That reference never takes the cast, so
it does not read the fix's own output.

The upstream report is drafted in `upstream_terra_draft.md`, with its reprex in
`reprex_terra_uint32.R`. **Nothing has been posted.** The verdict lives in
`research/dem_reprojection.md` §4.

## Measurement

All measured on terra 1.9.50, GDAL 3.13.0, PROJ 9.8.1.

- Bundled `dem.tif`, `buffer = 2000`, `target_crs = 3157`:
  - main gives max 4294967296 with 0 NA. The branch gives max 1061.94 with 290,432 NA.
  - The raw `project(dem.tif, "EPSG:3157")` had 45,116 cells at 2^32.
- Subset crop (`buffer = 100`) under `todisk = TRUE`:
  - main has 9,533 cells at 2^32, all inside dem.tif's footprint (past the crop, not the file).
  - The branch gives NA there.
- NoData values the bug hits and misses:
  - Rounded and kept as data: 16777217, 1e8+1, 2147483647, 4294967295, and INT8U's default.
  - Exact, so written NaN: 65535, 4294967040, and −2^31.
- `datatype = "FLT8S"` also avoids the bug, but its values differ from the in-memory path by up
  to 6e-5 m. `datatype = "FLT4S"` does not fix the fill. So the fix uses the float copy.
- Full suite: FAIL 0, WARN 0, SKIP 0, PASS 461. The test file went from 29 to 34 blocks.
  - Mutation, cast removed: all 5 #76 blocks go red.
  - Mutation, `any()` removed: the multi-layer block errors.

Wrong turns, kept:

- The first mechanism ("fill = NoData cast, tag = NaN, independently") was disproved in review
  round 1 by an INT2U source written NaN.
- The plan's buffer-100 vs buffer-2000 equal-cells test was green on main, so it was replaced by
  the Float32 reference.
- `sf::gdal_utils()` was first used as the "GDAL alone" contrast. sf links GDAL 3.8.5, not 3.13.0.
- Review: the plan review, then `/code-check branch` rounds 1–4 (`review-*.md`), with 6 findings
  fixed, all in prose. Round 4 found a defect inside round 3's fix. "Source" meant the file in our
  prose and the projected raster in terra's sense. The loop ended by enumerating every extent
  phrase in the published diff (16 hits).

Closed by: PR for branch `76-fl-dem-aoi-a-whole-file-uint32-source-re`
