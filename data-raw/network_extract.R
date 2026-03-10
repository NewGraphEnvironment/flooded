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
#   - R packages: fresh, sf
#
# Output: inst/testdata/streams.gpkg
#   50 segments, order 4+, covering Bulkley River mainstem, Richfield Creek,
#   Cesford Creek, and Robert Hatch Creek near Topley, BC.
#
# To extract a different reach, change the blk, drm, and filter below.

library(fresh)
library(sf)

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

# --- Write to inst/testdata ---
out_path <- here::here("inst", "testdata", "streams.gpkg")
sf::st_write(network, out_path, delete_dsn = TRUE, quiet = TRUE)
message("Saved: ", out_path)
