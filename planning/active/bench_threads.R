# Wall and CPU time of fl_valley_confine() on the cached Parsnip River grid,
# for one terra thread count. One Rscript per repeat (#81).
#   Rscript bench_threads.R <pkg_dir> <threads> <repeat_label>
args <- commandArgs(trailingOnly = TRUE)
pkg <- args[1]; threads <- as.integer(args[2]); lab <- args[3]
suppressMessages(pkgload::load_all(pkg, quiet = TRUE))
vd <- file.path(pkg, "inst", "vignette-data")
dem <- terra::rast(file.path(vd, "pars_dem.tif"))
streams <- sf::st_read(file.path(vd, "pars.gpkg"), "streams", quiet = TRUE)
waterbodies <- sf::st_read(file.path(vd, "pars.gpkg"), "waterbodies", quiet = TRUE)
terra::terraOptions(threads = threads, progress = 0)
la <- system("sysctl -n vm.loadavg", intern = TRUE)
t <- system.time({
  valleys <- fl_valley_confine(
    dem = dem, streams = streams, area_field = "upstream_area_ha",
    precip = fl_stream_rasterize(streams, dem, field = "map_upstream"),
    waterbodies = waterbodies, flood_factor = 4
  )
})
cells <- sum(terra::values(valleys) == 1, na.rm = TRUE)
cat(sprintf("RESULT label=%s threads=%d wall=%.1f cpu=%.1f cells=%d grid=%dx%d loadavg_before=%s\n",
            lab, threads, t[["elapsed"]], t[["user.self"]] + t[["sys.self"]],
            cells, terra::nrow(dem), terra::ncol(dem), gsub("[{}]", "", la)))
