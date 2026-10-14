library(terra)
# A 100 x 100 UInt32 GeoTIFF in UTM 10N with nodata 4294967295
f <- tempfile(fileext = ".tif")
r <- rast(nrows = 100, ncols = 100, xmin = 500000, xmax = 503000,
          ymin = 6000000, ymax = 6003000, crs = "EPSG:26910")
values(r) <- 1000 + seq_len(ncell(r)) %% 50
writeRaster(r, f, datatype = "INT4U", NAflag = 4294967295)
x <- rast(f)
datatype(x)

# File-backed source: cells beyond the source are 2^32, not NA
minmax(project(x, "EPSG:3005"))
# The same values held in memory: NA, as expected
minmax(project(x * 1, "EPSG:3005"))
# A Float64 output also comes back NA
minmax(project(x, "EPSG:3005", datatype = "FLT8S"))

# Written to file: tagged NoData = NaN, filled with 4294967296
g <- tempfile(fileext = ".tif")
p <- project(x, "EPSG:3005", filename = g)
describe(g)[grep("NoData|Type=", describe(g))]
global(rast(g) == 2^32, "sum", na.rm = TRUE)

# The gdalwarp utility of the same GDAL as terra, Float32 output, does not do this
system2("gdalwarp", "--version", stdout = TRUE)
h <- tempfile(fileext = ".tif")
system2("gdalwarp", c("-q", "-t_srs", "EPSG:3005", "-ot", "Float32", f, h))
global(rast(h), "max", na.rm = TRUE)
describe(h)[grep("NoData", describe(h))]

gdal(lib = "all"); packageVersion("terra")
