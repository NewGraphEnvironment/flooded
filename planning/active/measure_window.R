# #78: how often does a datum step in the read-window transform change the DEM
# that fl_dem_aoi() returns, and does any changed cell lie inside the buffered
# AOI? Reproduces fl_dem_aoi()'s 0.7.0 reproject path with the window
# transformed (a) shift-free and (b) through PROJ 9.8.1's preferred
# NAD83 -> NAD83(CSRS) route via WGS 84 (`projinfo -s EPSG:3005 -t EPSG:3979`,
# operation 1, 5 m), written out so sf's PROJ 9.5.1 can run it.
#
# Run from the package root: Rscript planning/active/measure_window.R
pkgload::load_all(quiet = TRUE)

wgs84_route <- paste(
  "+proj=pipeline",
  "+step +inv +proj=aea +lat_0=45 +lon_0=-126 +lat_1=50 +lat_2=58.5 +x_0=1000000 +y_0=0 +ellps=GRS80",
  "+step +proj=push +v_3 +step +proj=cart +ellps=WGS84",
  "+step +inv +proj=helmert +x=-0.991 +y=1.9072 +z=0.5129 +rx=-0.0257899075194932",
  "+ry=-0.0096500989602704 +rz=-0.0116599432323421 +s=0 +convention=coordinate_frame",
  "+step +inv +proj=cart +ellps=GRS80 +step +proj=pop +v_3",
  "+step +proj=lcc +lat_0=49 +lon_0=-95 +lat_1=49 +lat_2=77 +x_0=0 +y_0=0 +ellps=GRS80"
)
crs_3979 <- sf::st_crs(3979)
pin_fwd <- dem_pipeline_nad83(sf::st_crs(3005), crs_3979)
pin_warp <- dem_pipeline_nad83(crs_3979, sf::st_crs(3005))

aoi0 <- sf::st_read(system.file("testdata/streams.gpkg", package = "flooded"), quiet = TRUE)
bb <- sf::st_bbox(sf::st_transform(sf::st_buffer(aoi0, 3000), 3979))
# 30 m source whose value is its own x, like MRDEM-30's grid
src <- terra::init(
  terra::rast(terra::ext(bb[c(1, 3, 2, 4)]), resolution = 30, crs = "EPSG:3979"), "x"
)
r_res <- terra::res(src)
pad <- 2 * max(r_res)
buffer <- 100
res <- 30

run <- function(aoi, window_pipeline) {
  ab <- sf::st_buffer(sf::st_zm(aoi), buffer)
  inr <- suppressWarnings(sf::st_transform(ab, crs_3979$wkt, pipeline = window_pipeline))
  b <- sf::st_bbox(ab)
  tmpl <- terra::rast(
    terra::ext(floor(b[["xmin"]] / res) * res, ceiling(b[["xmax"]] / res) * res,
               floor(b[["ymin"]] / res) * res, ceiling(b[["ymax"]] / res) * res),
    resolution = res, crs = sf::st_crs(3005)$wkt
  )
  bs <- sf::st_bbox(inr)
  rc <- terra::crop(src, terra::ext(bs[["xmin"]] - pad, bs[["xmax"]] + pad,
                                    bs[["ymin"]] - pad, bs[["ymax"]] + pad), snap = "out")
  list(out = terra::project(rc, tmpl, method = "bilinear", pipeline = pin_warp), ab = ab)
}

offs <- seq(0, 29.5, by = 0.5)
rows <- lapply(offs, function(dx) {
  aoi <- aoi0
  sf::st_geometry(aoi) <- sf::st_geometry(aoi0) + c(dx, dx * 0.7)
  sf::st_crs(aoi) <- 3005
  a <- run(aoi, pin_fwd)
  b <- run(aoi, wgs84_route)
  va <- terra::values(a$out, mat = FALSE)
  vb <- terra::values(b$out, mat = FALSE)
  diff <- xor(is.na(va), is.na(vb)) | (!is.na(va) & !is.na(vb) & va != vb)
  in_aoi <- !is.na(terra::values(terra::rasterize(terra::vect(a$ab), a$out, touches = TRUE), mat = FALSE))
  data.frame(dx = dx, cells = terra::ncell(a$out), changed = sum(diff),
             na_flips = sum(xor(is.na(va), is.na(vb))), changed_in_aoi = sum(diff & in_aoi))
})
rows <- do.call(rbind, rows)

cat("sf:", sf::sf_extSoftVersion()[["PROJ"]], " terra:", terra::gdal(lib = "proj"), "\n")
cat("offsets:", nrow(rows), " changed:", sum(rows$changed > 0), "\n")
print(rows[rows$changed > 0, ], row.names = FALSE)
