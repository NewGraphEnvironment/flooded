# Pre-compute the network-dependent results for vignettes/stac-dem.Rmd.
#
# The vignette compares the bundled 10 m DEM (25 m TRIM resampled) against
# BC provincial lidar fetched from the stac-elevation-bc STAC catalog. The 10 m runs
# need no network and run live in the vignette; the two lidar runs below need
# the STAC endpoint and (for 1 m) several minutes, so they run here once.
#
# Generates (under inst/vignette-data/):
#   stac_valleys_5m.tif       5 m lidar VCA, resampled (near) onto the bundled
#                             10 m DEM grid
#   stac_valleys_1m_site.tif  1 m lidar VCA over the site extent, resampled
#                             (near) onto the 10 m DEM cropped to that extent
#   stac_meta.rds             STAC item ids, lidar grid dims, native-resolution
#                             cell counts, the 10 m guard counts, and the
#                             flooded version / date the cache was built
#
# Every use the vignette makes of the lidar results goes through the 10 m
# grids, so only those are cached — the native 5 m (2.1 M cells) and 1 m
# (14 M cells) rasters are not shipped. Native-resolution counts are stored
# as scalars.
#
# The guard: `n_10m` and `n_site_10m` are the 10 m cell counts this run
# produced with the same flooded code. The vignette recomputes them live and
# flags the cache as stale when they differ — i.e. when fl_valley_confine()
# has changed since the lidar results were built.
#
# Configuration matches the vignette exactly. Change one, change both.
#
# Prerequisites:
#   - Outbound HTTPS to https://images.a11s.one/ (stac-elevation-bc) and its COGs
#   - rstac, gdalcubes (Suggests)
#   - Run from package root so devtools::load_all() finds the source tree

# ---- params -------------------------------------------------------------

stac_url <- "https://images.a11s.one/"
stac_datetime <- "2019-01-01T00:00:00Z/2019-12-31T23:59:59Z"
stac_res <- 5                                     # watershed-scale lidar run
site_ext <- terra::ext(976560, 980060, 1055808, 1059808)  # Robert Hatch / Richfield

vca_args <- list(
  area_field = "upstream_area_ha",
  slope_threshold = 9,
  max_width = 2000,
  cost_threshold = 2500,
  flood_factor = 6
)

# ---- env ----------------------------------------------------------------

devtools::load_all(quiet = TRUE)
library(terra)
library(sf)
library(rstac)
library(gdalcubes)

terra::terraOptions(threads = max(1L, parallel::detectCores() - 2L))

out_dir <- file.path("inst", "vignette-data")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
out <- function(name) file.path(out_dir, name)

t_start <- Sys.time()

# Run the VCA with the vignette's configuration on any DEM grid
# Warnings (e.g. `[costDist] distance algorithm did not converge`) are
# collected and returned, so they land in stac_meta.rds rather than scrolling
# past in a console.
vca <- function(dem, streams, slope) {
  precip <- fl_stream_rasterize(streams, dem, field = "map_upstream")
  warns <- character()
  r <- withCallingHandlers(
    do.call(fl_valley_confine, c(
      list(dem = dem, streams = streams, slope = slope, precip = precip),
      vca_args
    )),
    warning = function(w) {
      warns <<- c(warns, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  list(valleys = r, warnings = unique(warns))
}

# Percent slope from a DEM, matching the bundled slope.tif convention
slope_pct <- function(dem) {
  s <- terra::terrain(dem, v = "slope", unit = "degrees")
  tan(s * pi / 180) * 100
}

n_valley <- function(r) sum(terra::values(r) == 1, na.rm = TRUE)

# Query stac-elevation-bc for 2019 1 m lidar tiles over an EPSG:3005 extent and
# mosaic them onto a cube at `res` m. Returns the SpatRaster and item ids.
stac_dem <- function(e, res) {
  e_wgs <- terra::ext(terra::project(terra::rast(e, crs = "EPSG:3005"), "EPSG:4326"))
  items <- stac(stac_url) |>
    stac_search(
      collections = "stac-elevation-bc",
      bbox = c(e_wgs$xmin, e_wgs$ymin, e_wgs$xmax, e_wgs$ymax),
      datetime = stac_datetime
    ) |>
    post_request() |>
    items_fetch()
  # An unknown collection returns zero items, not an error
  if (length(items$features) == 0L) {
    stop("No STAC items over this extent - check the collection name.", call. = FALSE)
  }
  col <- stac_image_collection(items$features, asset_names = "dem")
  v <- cube_view(
    srs = "EPSG:3005",
    extent = list(
      left = e$xmin, right = e$xmax, bottom = e$ymin, top = e$ymax,
      t0 = "2019-01-01", t1 = "2019-12-31"
    ),
    dx = res, dy = res, dt = "P1Y",
    aggregation = "first",
    resampling = "bilinear"
  )
  d <- tempfile()
  write_tif(raster_cube(col, v), d)
  dem <- terra::rast(list.files(d, "\\.tif$", full.names = TRUE)[1])
  # gdalcubes reports failed chunk reads only on stderr, so a partial mosaic
  # looks complete. Both extents sit wholly inside lidar coverage, so any NA
  # beyond a sliver means tiles failed to read.
  na_frac <- terra::global(is.na(dem), "mean")[[1]]
  if (na_frac > 0.001) {
    stop(sprintf("Lidar mosaic is %.2f%% NA - partial read?", 100 * na_frac), call. = FALSE)
  }
  list(
    dem = dem,
    ids = vapply(items$features, function(f) f$id, character(1)),
    na_frac = na_frac
  )
}

# Write a 0/1 valley raster compactly and without tempfile names in its
# metadata. Built in memory first: rasterize(filename =) with an integer
# datatype writes the background as 0, so never write through filename.
write_valleys <- function(r, name) {
  r <- r * 1
  names(r) <- "valley"
  terra::varnames(r) <- "valley"
  terra::longnames(r) <- ""
  terra::writeRaster(
    r, out(name),
    overwrite = TRUE,
    datatype = "INT1U",
    gdal = c("COMPRESS=DEFLATE", "TILED=YES")
  )
}

# ---- 1. Bundled 10 m inputs ---------------------------------------------

dem_10m <- terra::rast(system.file("testdata/dem.tif", package = "flooded"))
slope_10m <- terra::rast(system.file("testdata/slope.tif", package = "flooded"))
streams <- sf::st_read(
  system.file("testdata/streams.gpkg", package = "flooded"),
  quiet = TRUE
)

# ---- 2. 10 m guard counts -----------------------------------------------

message("Running 10 m baseline (guard) ...")
valleys_10m <- vca(dem_10m, streams, slope_10m)$valleys
n_10m <- n_valley(valleys_10m)

streams_site <- sf::st_crop(streams, sf::st_as_sfc(sf::st_bbox(c(
  xmin = 976560, ymin = 1055808, xmax = 980060, ymax = 1059808
), crs = sf::st_crs(streams))))
dem_site_10m <- terra::crop(dem_10m, site_ext)
valleys_site_10m <- vca(dem_site_10m, streams_site, terra::crop(slope_10m, site_ext))$valleys
n_site_10m <- n_valley(valleys_site_10m)

# ---- 3. 5 m lidar over the bundled DEM extent ---------------------------

message("Fetching ", stac_res, " m lidar mosaic ...")
lidar_5m <- stac_dem(terra::ext(dem_10m), stac_res)
dem_5m <- lidar_5m$dem

message("Running VCA at ", stac_res, " m ...")
run_5m <- vca(dem_5m, streams, slope_pct(dem_5m))
valleys_5m <- run_5m$valleys
valleys_5m_on_10m <- terra::resample(valleys_5m, dem_10m, method = "near")
write_valleys(valleys_5m_on_10m, "stac_valleys_5m.tif")

# ---- 4. 1 m lidar over the site -----------------------------------------

message("Fetching 1 m lidar mosaic for the site ...")
lidar_1m <- stac_dem(site_ext, 1)
dem_1m <- lidar_1m$dem

message("Running VCA at 1 m (slow) ...")
run_1m <- vca(dem_1m, streams_site, slope_pct(dem_1m))
valleys_1m <- run_1m$valleys
valleys_1m_on_10m <- terra::resample(valleys_1m, dem_site_10m, method = "near")
write_valleys(valleys_1m_on_10m, "stac_valleys_1m_site.tif")

# Native 1 m result for inspection only - 14 M cells, not shipped
if (nzchar(Sys.getenv("STAC_DEM_NATIVE_DIR"))) {
  terra::writeRaster(
    valleys_1m * 1, file.path(Sys.getenv("STAC_DEM_NATIVE_DIR"), "stac_valleys_1m_native.tif"),
    overwrite = TRUE, datatype = "INT1U", gdal = c("COMPRESS=DEFLATE", "TILED=YES")
  )
}

# ---- 5. Metadata --------------------------------------------------------

git_sha <- system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE)
git_dirty <- length(system2("git", c("status", "--porcelain", "--", "R"), stdout = TRUE)) > 0

meta <- list(
  flooded_version = as.character(utils::packageVersion("flooded")),
  git_sha = git_sha,
  r_dirty = git_dirty,
  date_built = format(Sys.Date(), "%Y-%m-%d"),
  stac_url = stac_url,
  stac_datetime = stac_datetime,
  stac_res = stac_res,
  items_5m = lidar_5m$ids,
  items_1m = lidar_1m$ids,
  dim_5m = c(ncol = terra::ncol(dem_5m), nrow = terra::nrow(dem_5m)),
  dim_1m = c(ncol = terra::ncol(dem_1m), nrow = terra::nrow(dem_1m)),
  na_frac_5m = lidar_5m$na_frac,
  na_frac_1m = lidar_1m$na_frac,
  warnings_5m = run_5m$warnings,
  warnings_1m = run_1m$warnings,
  n_5m = n_valley(valleys_5m),
  ncell_5m = terra::ncell(valleys_5m),
  n_1m = n_valley(valleys_1m),
  ncell_1m = terra::ncell(valleys_1m),
  n_10m = n_10m,
  n_site_10m = n_site_10m
)
saveRDS(meta, out("stac_meta.rds"))

# ---- 6. Report ----------------------------------------------------------

message(sprintf("Done in %.1f min", as.numeric(difftime(Sys.time(), t_start, units = "mins"))))
str(meta)
cache_files <- out(c("stac_valleys_5m.tif", "stac_valleys_1m_site.tif", "stac_meta.rds"))
for (f in cache_files) {
  message(sprintf("  %-28s %.3f MB", basename(f), file.info(f)$size / 1024^2))
}
