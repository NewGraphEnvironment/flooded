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
