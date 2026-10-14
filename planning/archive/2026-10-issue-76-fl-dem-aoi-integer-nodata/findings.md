# Findings — fl_dem_aoi(): a whole-file UInt32 source reprojects its nodata as 4294967296, not NA (#76)

## Issue context

**If we do it:** `fl_dem_aoi()` returns NA, not 4,294,967,296 m, for cells beyond a UInt32 source, so a DEM that does not cover the buffered AOI cannot hand `fl_valley_confine()` a 4,300 km cliff.
**If we never do:** any UInt32 DEM with a nodata of 4294967295 whose crop covers the whole file returns 2^32 wherever the output reaches past the source, and nothing warns.

## Problem

`inst/testdata/dem.tif` is UInt32 with nodata 4294967295. When `terra::crop()` covers the whole source it returns the file-backed raster unchanged, and `terra::project()` of that raster fills cells beyond the source with **4294967296** instead of NA. A Float32 nodata of 4294967295 rounds to 2^32, so the nodata test probably compares against the rounded value. A crop that is a real subset is in memory and comes back NA.

```r
r <- terra::rast(system.file("testdata/dem.tif", package = "flooded"))
terra::minmax(terra::project(r, "EPSG:3157"))            # max 4294967296
terra::minmax(terra::project(r * 1, "EPSG:3157"))        # max 1062 (in memory)
```

Measured with terra 1.9.50 / GDAL 3.13.0. It is not new: `fl_dem_aoi(streams, source = dem.tif, buffer = 2000, target_crs = 3157)` gives max 4294967296 on 0.6.6 and on the #67 branch alike. MRDEM-30 is Float32, so the default source is unaffected.

## Proposal

Reproduce it in terra alone, and report upstream if it is terra's (draft first). Until then, `fl_dem_aoi()` could read through an in-memory copy for integer sources, or set the source's NAflag explicitly. Add a test with a UInt32 source whose crop covers the whole file.

Found while working on #67.

## Errors Encountered

| Error | Resolution |
|-------|------------|
| `sf::gdal_utils("warp")` as the "GDAL alone" contrast | sf links GDAL 3.8.5, terra 3.13.0: a cross-version comparison. Use the `gdalwarp` CLI (3.13.0, same as terra) |
| `reprex::reprex(outfile = NA)` re-run produced no new output | reprex refuses to overwrite `reprex_reprex.*`; delete them first |

## Phase 1 — upstream search (2026-10-14)

No rspatial/terra issue covers this (searched: nodata project, INT4U, NAflag, UInt32, 2^32,
warp nodata NaN). Nearest: rspatial/terra#2207 (crop to disk treats INT2U 65535 as NoData, fixed),
rspatial/terra#2030 (`values()` coerces INT4U > 2^31-1), rspatial/terra#2166 / rspatial/terra#2074 (`NAflag()` disagrees with the header;
here `NAflag()` reports NaN while `describe()` shows 4294967295).
| New tests errored "could not find function expect_same_dem" | the helper is defined later in the file; #76 block moved to the end |
| INT8U test copy passed on main | `NAflag = NA` gave it nodata 0; `dem_as()` now passes NAflag only when given (terra's INT8U default is 18446744073709550514) |

## Plan review (2026-10-14)

`review-plan.md`. Confirmed by probe: multi-layer `datatype()` is length 2 (the `if` would error);
the same-CRS `res = 30` path gives 2^32 with 0 NA; INT4S with nodata 2^31 - 1 gives 2147483648.
So the trigger is an integer NoData Float32 cannot hold exactly, not UInt32 as such.
