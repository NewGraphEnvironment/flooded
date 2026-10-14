# Task: fl_dem_aoi(): a whole-file UInt32 source reprojects its nodata as 4294967296, not NA (#76)

## Problem

`inst/testdata/dem.tif` is UInt32 with nodata 4294967295. When `terra::crop()` covers the whole source it returns the file-backed raster unchanged, and `terra::project()` of that raster fills cells beyond the source with **4294967296** instead of NA. A Float32 nodata of 4294967295 rounds to 2^32, so the nodata test probably compares against the rounded value. A crop that is a real subset is in memory and comes back NA.

```r
r <- terra::rast(system.file("testdata/dem.tif", package = "flooded"))
terra::minmax(terra::project(r, "EPSG:3157"))            # max 4294967296
terra::minmax(terra::project(r * 1, "EPSG:3157"))        # max 1062 (in memory)
```

Measured with terra 1.9.50 / GDAL 3.13.0. It is not new: `fl_dem_aoi(streams, source = dem.tif, buffer = 2000, target_crs = 3157)` gives max 4294967296 on 0.6.6 and on the #67 branch alike. MRDEM-30 is Float32, so the default source is unaffected.


## Context (from plan-mode exploration)

`inst/testdata/dem.tif` is UInt32, nodata 4294967295. When `fl_dem_aoi()` reprojects it,
cells beyond the source come back **4294967296** (2^32) instead of NA, so a DEM that does not
cover the buffered AOI hands `fl_valley_confine()` a 4,300 km cliff. MRDEM-30 (Float32) is
unaffected.

Measured during planning (terra 1.9.50, GDAL 3.13.0 / PROJ 9.8.1):

| case | max |
|---|---|
| `project(r, "EPSG:3157")`, whole file | 4294967296 (45,116 cells) |
| `project(r * 1, ...)` | 1062 |
| `fl_dem_aoi(streams, dem.tif, buffer = 2000, target_crs = 3157)` | 4294967296 |
| same, `buffer = 100` (subset crop, in memory) | 905 |
| **same `buffer = 100` under `terraOptions(todisk = TRUE)`** | **4294967296** |
| `project(..., datatype = "FLT8S")` | 1061.93 |
| source rewritten INT2U / INT4S / FLT4S | fine |
| source rewritten INT8U | 1.8e19 (same bug) |
| `gdalwarp -ot Float32` of dem.tif (no terra) | nodata honoured, max 1062 |
| setting `NAflag(r) <- 4294967295` first | still 2^32 |

So: it is **terra's**, not GDAL's — terra writes a Float32 output tagged `NoData=nan` but fills
unmapped cells with the source nodata cast to Float32 (2^32). It hits any file-backed raster
whose integer nodata is not exactly representable in Float32. The issue's "whole-file crop"
framing is one trigger; a real subset crop that terra writes to disk (large AOI, low memory)
is another, so the fix must key on **datatype**, not on whether the crop is in memory.
terra's NEWS through 1.9-54 (GitHub HEAD) lists no fix; no existing upstream issue found for
4294967295.

**Approach:** in `fl_dem_aoi()`, before `terra::project()`, read an integer-typed source crop
through a float copy (`r_clip * 1`): terra maps the nodata to NA on read, and the copy (in
memory or a Float32 temp file with NaN nodata) projects correctly — verified under
`todisk = TRUE` and for INT8U. Integer types only, so MRDEM-30 and other float sources take
exactly today's path. The same-CRS crop path (`return(terra::crop(...))`) never fills beyond the
source, so it is untouched. Report upstream as a draft only.

## Phase 1: Reproduce and draft upstream report
- [x] Minimal terra-only reprex (synthetic UInt32 GeoTIFF with nodata 4294967295, no flooded):
      `project()` file-backed vs `* 1`, plus the `gdalwarp` contrast and the `datatype = "FLT8S"`
      and INT8U observations; record versions
- [x] Search rspatial/terra issues once more (open + closed: nodata / UInt32 / project / Float32)
- [x] Write the draft issue to `planning/active/upstream_terra_draft.md` (reprex in
      `reprex_terra_uint32.R`; what discriminates terra from GDAL). **Not posted** — shown to the
      user for approval. *Revised:* the verdict goes in the existing topic file
      `research/dem_reprojection.md` (§4), which already cited #76, not a new research file
      (planning.md, "one topic file, revised in place"); lands with the Phase 3 fix it describes

## Phase 2: Tests first (fail on main)
- [x] `test-fl_dem_aoi.R`: whole-file UInt32 source (`dem.tif`, `buffer = 2000`,
      `target_crs = 3157`) returns NA beyond the source — some NA cells, max below 2000
- [x] Same with a subset crop under `terra::terraOptions(todisk = TRUE)` (restored on exit) —
      the case the in-memory-copy idea would miss
- [x] *Revised (review #3, #5):* values unchanged where data exist — every test compares, cell for
      cell, against the same DEM stored as Float32 (`dem_as("FLT4S")`), a source that never takes
      the cast. Replaces the buffer-100 vs buffer-2000 comparison, which was green on main and
      needed an AOI mask
- [x] *Added (review #2):* the same-CRS, `res`-differs path (`res = 30`, `buffer = 2000`)
- [x] *Added (review #4):* INT8U (terra's default nodata) and INT4S with nodata 2^31 - 1
- [x] Confirm all new tests red on main (`NOT_CRAN=true`, count `failed | error`): 8 failures,
      0 errors, in all 4 blocks

## Phase 3: Fix
- [x] `R/fl_dem_aoi.R`: before `terra::project()`, `if (any(grepl("^INT", terra::datatype(r_clip))))
      r_clip <- r_clip * 1` (`any()`: review #1, multi-layer sources), comment citing #76
- [x] *Added (review #1):* multi-layer INT4U test; without `any()` it errors
- [x] Mutation check (in a copy of the tree): cast removed -> all 5 #76 blocks red; `any()`
      removed -> multi-layer block errors; restored -> 34/34 blocks green
- [x] Existing `fl_dem_aoi` tests and full suite green (`devtools::test()`: FAIL 0, WARN 0, SKIP 0,
      PASS 461); `lintr::lint_package()` clean
      (`fl_dem_aoi` tests: 34/34; lint: nothing new beyond the `testdata_path` false positive
      the other test files already carry)
- [x] `devtools::document()`: one `@details` sentence on integer sources

## Phase 4: Docs
- [x] *Revised:* no NEWS edit on the branch. `/gh-pr-merge` writes the NEWS entry from the PR
      body at release (0.7.1's came that way), and a dev heading would trip its
      development-header path. NEWS-ready text goes in the PR body's Summary
- [x] CLAUDE.md "Test-data traps": bundled `dem.tif` is UInt32 / nodata 4294967295, and terra
      projects a file-backed one with 2^32 fill (#76) — so a reprojection test on it must look
      beyond the source footprint
- [x] `research/README.md` index row: the existing `dem_reprojection.md` row now names #76
      (§4 added; landed with the Phase 3 fix it describes)

## Validation
- [x] Tests pass
- [ ] `/code-check` clean (each commit, or once over the branch with `/code-check branch`)
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion

