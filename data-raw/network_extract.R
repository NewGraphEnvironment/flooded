#!/usr/bin/env Rscript
#
# network_extract.R
#
# Documents how inst/testdata/streams.gpkg was created. The output is committed
# to the package so this script does NOT need to be run by package users.
#
# Extracts a stream network between two points on a mainstem using
# fresh::frs_network() with network subtraction (upstream_measure). Source view
# is bcfishpass.streams_co_vw (coho habitat, access_co > 0).
#
# Requires:
#   - SSH tunnel to the remote newgraph DB forwarding to localhost:63333
#     (do NOT hardcode the remote IP — use your SSH config)
#   - R packages: fresh, sf, terra
#
# Output:
#   inst/testdata/streams.gpkg      — 50 segments, order 4+, Bulkley mainstem,
#     Richfield, Cesford, Robert Hatch Creeks near Topley, BC
#   inst/testdata/waterbodies.gpkg  — lakes and wetlands in the DEM extent
#
# To extract a different reach, change the blk, drm, and filter below.

library(fresh)
library(sf)
library(terra)

# --- Boundary points on Bulkley mainstem ---
blk <- 360873822
mouth_drm <- 216733
cutoff_drm <- 222000
min_order <- 4

# --- Extract network between two points ---
# frs_network() with upstream_measure does network subtraction:
#   upstream_of(mouth) minus upstream_of(cutoff)
# Only streams joining between the two boundary points are returned.
#
# Note: streams_co_vw filters WHERE access_co > 0, so streams behind
# barriers (like upper Richfield Creek) are excluded. The species-specific
# views (streams_co_vw, streams_bt_vw, etc.) have simpler columns than
# streams_vw — mapping_code instead of mapping_code_co, access instead
# of access_co, etc.
message("Querying network between drm ", mouth_drm, " and ", cutoff_drm,
        " on blk ", blk, " (order >= ", min_order, ")...")

network <- frs_network(
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
      extra_where = paste0("stream_order >= ", min_order)
    )
  )
) |>
  sf::st_zm(drop = TRUE)

message("  ", nrow(network), " segments")
message("  Streams: ", paste(unique(na.omit(network$gnis_name)), collapse = ", "))
message("  Orders: ", paste(sort(unique(network$stream_order)), collapse = ", "))

# --- Write streams to inst/testdata ---
out_path <- here::here("inst", "testdata", "streams.gpkg")
sf::st_write(network, out_path, delete_dsn = TRUE, quiet = TRUE)
message("Saved: ", out_path)

# --- Extract waterbodies (lakes + wetlands) ---
# frs_network() uses the waterbody_key bridge for polygon tables.
# Results extend beyond the DEM extent so we crop with st_intersection.
# TODO: replace st_intersection crop with fresh clip helper once
# NewGraphEnvironment/fresh#12 is implemented.
message("Querying waterbodies...")

dem <- terra::rast(here::here("inst", "testdata", "dem.tif"))
dem_bbox <- sf::st_as_sfc(sf::st_bbox(dem))

wb <- frs_network(
  blue_line_key = blk,
  downstream_route_measure = mouth_drm,
  upstream_measure = cutoff_drm,
  tables = list(
    lakes = "whse_basemapping.fwa_lakes_poly",
    wetlands = "whse_basemapping.fwa_wetlands_poly"
  )
)

lakes <- sf::st_intersection(wb$lakes, dem_bbox)
wetlands <- sf::st_intersection(wb$wetlands, dem_bbox)

message("  Lakes in DEM extent: ", nrow(lakes))
message("  Wetlands in DEM extent: ", nrow(wetlands))

# Combine into single waterbodies layer
waterbodies <- rbind(
  lakes[, c("waterbody_key", "waterbody_type", "area_ha", "geom")],
  wetlands[, c("waterbody_key", "waterbody_type", "area_ha", "geom")]
)

wb_path <- here::here("inst", "testdata", "waterbodies.gpkg")
sf::st_write(waterbodies, wb_path, delete_dsn = TRUE, quiet = TRUE)
message("Saved: ", wb_path, " (", nrow(waterbodies), " features)")
