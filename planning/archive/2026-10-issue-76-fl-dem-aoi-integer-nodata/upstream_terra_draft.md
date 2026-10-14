# DRAFT — upstream issue for rspatial/terra (not posted)

**Status:** draft for review. Nothing has been posted. Venue: https://github.com/rspatial/terra/issues

---

**Title:** `project()` of a file-backed INT4U raster fills unmapped cells with the nodata cast to Float32 (4294967296), not NA

When the source of `project()` is a file-backed raster with datatype `INT4U` and NoData
4294967295, the cells of the output that no source cell maps to come back as **4294967296**
instead of `NA`. 4294967296 is 4294967295 rounded to Float32. The output is tagged
`NoData Value=nan`, so the fill is read back as data.

The same values held in memory (`x * 1`), or a `datatype = "FLT8S"` output, give `NA`. GDAL's own
`gdalwarp` of the same file, from the same GDAL build, with a Float32 output, writes
`NoData Value=4.2949673e+09` and the fill is masked on read.

With a file-backed `INT2U` source (NoData 65535) the same call writes those cells as NaN. So it
looks as though cells equal to the source NoData are converted to NaN by value, and with a
NoData that Float32 cannot hold exactly the stored value (4294967296) no longer equals it
(4294967295) and survives as data. I have not read the code, so that is inferred from the
outputs.

The same happens with an `INT8U` source at terra's default NoData (fill 18446744073709551616)
and with an `INT4S` source whose NoData is 2147483647 (fill 2147483648). `INT2U` (65535) and
`INT4S` with NoData -2147483648 are unaffected; those NoData values are exact in Float32. Setting `NAflag(x) <- 4294967295` first
does not change it. `NAflag(x)` reports `NaN` for this file, though `describe()` shows
`NoData Value=4294967295` (possibly related to #2166 / #2074).

``` r
library(terra)
#> terra 1.9.50
# A 100 x 100 UInt32 GeoTIFF in UTM 10N with nodata 4294967295
f <- tempfile(fileext = ".tif")
r <- rast(nrows = 100, ncols = 100, xmin = 500000, xmax = 503000,
          ymin = 6000000, ymax = 6003000, crs = "EPSG:26910")
values(r) <- 1000 + seq_len(ncell(r)) %% 50
writeRaster(r, f, datatype = "INT4U", NAflag = 4294967295)
x <- rast(f)
datatype(x)
#> [1] "INT4U"

# File-backed source: cells beyond the source are 2^32, not NA
minmax(project(x, "EPSG:3005"))
#>          lyr.1
#> min       1000
#> max 4294967296
# The same values held in memory: NA, as expected
minmax(project(x * 1, "EPSG:3005"))
#>     lyr.1
#> min  1000
#> max  1049
# A Float64 output also comes back NA
minmax(project(x, "EPSG:3005", datatype = "FLT8S"))
#>     lyr.1
#> min  1000
#> max  1049

# Written to file: tagged NoData = NaN, filled with 4294967296
g <- tempfile(fileext = ".tif")
p <- project(x, "EPSG:3005", filename = g)
describe(g)[grep("NoData|Type=", describe(g))]
#> [1] "Band 1 Block=104x19 Type=Float32, ColorInterp=Gray"
#> [2] "  NoData Value=nan"
global(rast(g) == 2^32, "sum", na.rm = TRUE)
#>       sum
#> lyr.1 815

# The gdalwarp utility of the same GDAL as terra, Float32 output, does not do this
system2("gdalwarp", "--version", stdout = TRUE)
#> [1] "GDAL 3.13.0 \"Iowa City\", released 2026/05/04"
h <- tempfile(fileext = ".tif")
system2("gdalwarp", c("-q", "-t_srs", "EPSG:3005", "-ot", "Float32", f, h))
global(rast(h), "max", na.rm = TRUE)
#>        max
#> lyr.1 1049
describe(h)[grep("NoData", describe(h))]
#> [1] "  NoData Value=4.2949673e+09"

gdal(lib = "all"); packageVersion("terra")
#>     gdal  proj   geos  TBB
#> 1 3.13.0 9.8.1 3.14.1 TRUE
#> [1] '1.9.50'
```

<sup>Created on 2026-10-14 with [reprex v2.1.1](https://reprex.tidyverse.org)</sup>

terra 1.9.50, GDAL 3.13.0, PROJ 9.8.1, macOS (arm64). I have not tested 1.9-54; its NEWS does not
mention this.
