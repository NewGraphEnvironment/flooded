#!/usr/bin/env Rscript
#
# network_extract.R
#
# Documents how inst/testdata/streams.gpkg and waterbodies.gpkg were created.
# The outputs are committed to the package so this script does NOT need to be
# run by package users.
#
# Extracts coho potential habitat (order 4+) between two points on a mainstem
# using fresh::frs_network() with network subtraction. Lakes and wetlands are
# clipped to DEM extent.
#
# The order 4+ filter focuses on streams most relevant to restoration planning
# and higher-value salmon habitat. It also constrains the floodplain AOI for
# practical applications like orthophoto acquisition and review. All watershed
# tributaries contribute to floodplain health, but the vignette demonstrates
# the pipeline on the mainstem corridor where investment has the most impact.
#
# Requires:
#   - SSH tunnel to the remote newgraph DB forwarding to localhost:63333
#     (do NOT hardcode the remote IP — use your SSH config)
#   - R packages: fresh, sf, terra

library(fresh)
library(sf)
library(terra)

# --- Boundary points on Bulkley mainstem ---
blk <- 360873822
mouth_drm <- 216733
cutoff_drm <- 222000

# --- DEM extent for clipping ---
dem <- terra::rast(here::here("inst", "testdata", "dem.tif"))
dem_bbox <- sf::st_as_sfc(sf::st_bbox(dem))

# --- Extract coho potential habitat (order 4+) + waterbodies ---
# streams_co_vw: access_co > 0. We filter to stream_order >= 4 to focus on
# the mainstem corridor and major tributaries — this keeps the test data
# compact and the floodplain AOI manageable for downstream applications.
#
# frs_clip() doesn't handle XYM/XYZM geometries yet so we clip manually
# after st_zm(). TODO: fix in fresh, then use clip param directly.
message("Querying co habitat (order 4+) and waterbodies between drm ", mouth_drm,
        " and ", cutoff_drm, " on blk ", blk, "...")

results <- frs_network(
  blue_line_key = blk,
  downstream_route_measure = mouth_drm,
  upstream_measure = cutoff_drm,
  tables = list(
    streams = list(
      table = "bcfishpass.streams_co_vw",
      cols = c(
        "segmented_stream_id", "blue_line_key", "waterbody_key",
        "downstream_route_measure", "upstream_area_ha",
        "map_upstream", "gnis_name",
        "stream_order", "channel_width", "mapping_code", "rearing",
        "spawning", "access", "geom"
      ),
      wscode_col = "wscode",
      localcode_col = "localcode",
      extra_where = "stream_order >= 4"
    ),
    lakes = "whse_basemapping.fwa_lakes_poly",
    wetlands = "whse_basemapping.fwa_wetlands_poly"
  )
) |>
  lapply(sf::st_zm, drop = TRUE)

# Clip to DEM extent
results <- lapply(results, function(x) {
  if (inherits(x, "sf") && nrow(x) > 0L) frs_clip(x, dem_bbox) else x
})

streams <- results$streams
lakes <- results$lakes
wetlands <- results$wetlands

message("  Streams: ", nrow(streams), " segments")
message("  Orders: ", paste(sort(unique(streams$stream_order)), collapse = ", "))
message("  Lakes: ", nrow(lakes))
message("  Wetlands: ", nrow(wetlands))

# --- Write streams ---
out_path <- here::here("inst", "testdata", "streams.gpkg")
sf::st_write(streams, out_path, delete_dsn = TRUE, quiet = TRUE)
message("Saved: ", out_path)

# --- Combine waterbodies ---
waterbodies <- rbind(
  lakes[, c("waterbody_key", "waterbody_type", "area_ha", "geom")],
  wetlands[, c("waterbody_key", "waterbody_type", "area_ha", "geom")]
)

wb_path <- here::here("inst", "testdata", "waterbodies.gpkg")
sf::st_write(waterbodies, wb_path, delete_dsn = TRUE, quiet = TRUE)
message("Saved: ", wb_path, " (", nrow(waterbodies), " features)")
