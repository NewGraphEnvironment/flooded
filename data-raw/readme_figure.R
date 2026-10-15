# README figure: the modelled floodplain of the Parsnip River watershed group.
#
# Reads only the cached vignette artifacts in inst/vignette-data/ (made by
# data-raw/wsg_vignette_data.R), so it needs no database or network. Layer
# symbology comes from the gq style registry.
#
#   Rscript data-raw/readme_figure.R
#
# Writes man/figures/readme-pars.png.

sf::sf_use_s2(FALSE)

gpkg <- "inst/vignette-data/pars.gpkg"
out  <- "man/figures/readme-pars.png"

aoi         <- sf::st_read(gpkg, layer = "aoi", quiet = TRUE)
streams     <- sf::st_read(gpkg, layer = "streams", quiet = TRUE)
waterbodies <- sf::st_read(gpkg, layer = "waterbodies", quiet = TRUE)
dem     <- terra::rast("inst/vignette-data/pars_dem.tif")
valleys <- terra::rast("inst/vignette-data/pars_valleys.tif")

# Everything is drawn inside the watershed group only, so the basin reads as
# the subject against a blank page.
v_aoi   <- terra::vect(aoi)
dem     <- terra::mask(terra::crop(dem, v_aoi), v_aoi)
valleys <- terra::mask(terra::crop(valleys, v_aoi), v_aoi)
streams     <- suppressWarnings(sf::st_intersection(streams, sf::st_geometry(aoi)))
waterbodies <- suppressWarnings(sf::st_intersection(waterbodies, sf::st_geometry(aoi)))

hill <- terra::shade(
  terra::terrain(dem, "slope", unit = "radians"),
  terra::terrain(dem, "aspect", unit = "radians")
)
hill <- terra::clamp(hill, 0, 1)

reg <- gq::gq_reg_main()
alpha <- function(col, a) grDevices::adjustcolor(col, alpha.f = a)
st_fp   <- gq::gq_tmap_style(reg$layers$floodplains)
st_lake <- gq::gq_tmap_style(reg$layers$lake)
st_wet  <- gq::gq_tmap_style(reg$layers$wetland)
st_wsg  <- gq::gq_tmap_style(reg$layers$watershed_group_boundary)
cls_str <- gq::gq_tmap_classes(reg$layers$streams_all)
col_stream <- unname(cls_str$values[["GA24850000"]])  # FWA single-line stream
lwd_stream <- unname(cls_str$widths[["GA24850000"]])

col_fp   <- alpha(st_fp$fill, st_fp$fill_alpha)
col_lake <- alpha(st_lake$fill, st_lake$fill_alpha)
col_wet  <- alpha(st_wet$fill, st_wet$fill_alpha)

bb <- sf::st_bbox(aoi)
pad <- 0.01 * (bb[["xmax"]] - bb[["xmin"]])
xlim <- c(bb[["xmin"]] - pad, bb[["xmax"]] + pad)
ylim <- c(bb[["ymin"]] - pad, bb[["ymax"]] + pad)
asp  <- diff(ylim) / diff(xlim)

png(out, width = 7, height = 7 * asp, units = "in", res = 140, bg = "white",
    type = "cairo")  # cairo writes no alpha channel; quartz does
op <- par(mar = c(0, 0, 0, 0))
plot(sf::st_geometry(aoi), col = NA, border = NA, xlim = xlim, ylim = ylim,
     xaxs = "i", yaxs = "i")
terra::plot(hill, col = grDevices::grey(seq(0.55, 1, length.out = 100)),
            legend = FALSE, axes = FALSE, add = TRUE)
# Non-valley cells to NA: a colour vector with NA for 0 paints them white over
# the hillshade rather than leaving them transparent.
terra::plot(terra::ifel(valleys == 1, 1, NA), col = col_fp, legend = FALSE,
            axes = FALSE, add = TRUE)
plot(sf::st_geometry(streams), col = col_stream, lwd = lwd_stream * 2.5,
     add = TRUE)
wb_col <- ifelse(waterbodies$waterbody_type == "L", col_lake, col_wet)
plot(sf::st_geometry(waterbodies), col = wb_col, border = NA, add = TRUE)
lakes <- waterbodies[waterbodies$waterbody_type == "L", ]
plot(sf::st_geometry(lakes), col = NA, border = st_lake$col,
     lwd = st_lake$lwd * 2, add = TRUE)
plot(sf::st_geometry(aoi), col = NA, border = st_wsg$col, lwd = st_wsg$lwd,
     add = TRUE)

legend("topright", inset = c(0.015, 0.02), bty = "o", bg = "white",
       box.col = NA, cex = 0.9,
       legend = c("Floodplain (functional, ff04)", "Lake", "Wetland",
                  "Stream, order 3+ accessible to bull trout",
                  "Parsnip River watershed group"),
       fill = c(col_fp, col_lake, col_wet, NA, NA),
       border = c(NA, st_lake$col, NA, NA, NA),
       col = c(NA, NA, NA, col_stream, st_wsg$col),
       lwd = c(NA, NA, NA, 2, 2), seg.len = 1.6, x.intersp = 0.8)

# 20 km scale bar, bottom left.
x0 <- xlim[1] + 0.04 * diff(xlim)
y0 <- ylim[1] + 0.04 * diff(ylim)
rect(x0 - 1500, y0 - 2500, x0 + 23500, y0 + 4800, col = "white", border = NA)
segments(x0, y0, x0 + 20000, y0, lwd = 3, lend = 1)
segments(c(x0, x0 + 20000), y0, c(x0, x0 + 20000), y0 + 1200, lwd = 2)
text(x0 + 10000, y0 + 1600, "20 km", pos = 3, cex = 0.9)
par(op)
invisible(dev.off())
message("wrote ", out)
