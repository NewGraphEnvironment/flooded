#!/usr/bin/env Rscript
#
# network_extract.R
#
# Documents how inst/testdata/streams.gpkg and waterbodies.gpkg were created.
# The outputs are committed to the package so this script does NOT need to be
# run by package users.
#
# Extracts all coho potential habitat (all orders) between two points on a
# mainstem using fresh::frs_network() with network subtraction. Lakes and
# wetlands are clipped to DEM extent.
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

# --- Extract all coho potential habitat + waterbodies ---
# streams_co_vw: all orders, access_co > 0 (no order filter — small tribs
# matter for floodplain health and connect waterbodies to the network).
#
# frs_clip() doesn't handle XYM/XYZM geometries yet so we clip manually
# after st_zm(). TODO: fix in fresh, then use clip param directly.
message("Querying co habitat and waterbodies between drm ", mouth_drm,
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
      localcode_col = "localcode"
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
