# Phase 3 diagnosis (#68 round 2): which step of fl_valley_confine() breaks monotonicity
# under flood_method = "drainage"? Masks recomputed for the full network and each
# one-blue-line-dropped subset; count cells on in the subset and off in the full run.
pkgload::load_all(quiet = TRUE)
dem <- terra::rast(system.file("testdata/dem.tif", package = "flooded"))
st <- sf::st_read(system.file("testdata/streams.gpkg", package = "flooded"), quiet = TRUE)
slope <- tan(terra::terrain(dem, "slope", unit = "degrees") * pi / 180) * 100
masks <- function(s) {
  sr <- fl_stream_rasterize(s, dem, field = "upstream_area_ha")
  fl <- fl_flood_model(dem, sr, method = "drainage")[["flooded"]]
  fl <- terra::ifel(!is.na(sr), 1L, fl); fl <- terra::ifel(is.na(fl), 0L, fl)
  list(dist = fl_mask_distance(sr, threshold = 1000),
       cost = fl_mask(fl_cost_distance(slope, sr), threshold = 2500, operator = "<"),
       flood = fl,
       valley = fl_valley_confine(dem, s, area_field = "upstream_area_ha", flood_method = "drainage"),
       valley_nobuf = fl_valley_confine(dem, s, area_field = "upstream_area_ha", flood_method = "drainage",
                                        channel_buffer = FALSE))
}
full <- masks(st)
for (b in unique(st$blue_line_key)) {
  sub <- masks(st[st$blue_line_key != b, ])
  gained <- vapply(names(full), function(k)
    sum(terra::values(sub[[k]] == 1 & full[[k]] != 1, mat = FALSE), na.rm = TRUE), numeric(1))
  cat(b, ":", paste(names(gained), gained, sep = "=", collapse = "  "), "\n")
}
