#!/usr/bin/env Rscript
#
# network_extract.R
#
# Documents how inst/testdata/streams.gpkg was created. The output is committed
# to the package so this script does NOT need to be run by package users.
#
# Extracts a stream network between two points on a mainstem using FWA linear
# referencing: upstream_of(mouth) - upstream_of(cutoff). Source view is
# bcfishpass.streams_co_vw (coho habitat, access_co > 0).
#
# Requires:
#   - SSH tunnel to the remote newgraph DB forwarding to localhost:63333
#     (do NOT hardcode the remote IP — use your SSH config)
#   - R packages: sf, DBI, RPostgres, glue
#
# Output: inst/testdata/streams.gpkg
#   50 segments, order 4+, covering Bulkley River mainstem, Richfield Creek,
#   Cesford Creek, and Robert Hatch Creek near Topley, BC.
#
# To extract a different reach, change mouth_blk, mouth_drm, cutoff_blk,
# cutoff_drm, and min_order below.
#
# Adapted from NewGraphEnvironment/airbc scripts/network_extract.R

library(sf)
library(DBI)
library(RPostgres)

# --- Boundary points on Bulkley mainstem ---
mouth_blk <- 360873822
mouth_drm <- 216733

cutoff_blk <- 360873822
cutoff_drm <- 222000

min_order <- 4

# --- Connect to newgraph DB via SSH tunnel ---
conn <- DBI::dbConnect(
  RPostgres::Postgres(),
  host = "localhost", port = 63333,
  dbname = "bcfishpass", user = "newgraph"
)

# --- Extract network between two points ---
# Mainstem: simple DRM range filter on the blue_line_key
# Tributaries: FWA_Upstream() from mouth minus FWA_Upstream() from cutoff
#   → only tribs joining between the two boundary points
#
# Note: streams_co_vw filters WHERE access_co > 0, so streams behind
# barriers (like upper Richfield Creek) are excluded. The species-specific
# views (streams_co_vw, streams_bt_vw, etc.) have simpler columns than
# streams_vw — mapping_code instead of mapping_code_co, access instead
# of access_co, etc.
sql <- glue::glue("
  WITH mouth AS (
    SELECT wscode, localcode
    FROM bcfishpass.streams_co_vw
    WHERE blue_line_key = {mouth_blk}
      AND downstream_route_measure <= {mouth_drm}
    ORDER BY downstream_route_measure DESC
    LIMIT 1
  ),
  cutoff AS (
    SELECT wscode, localcode
    FROM bcfishpass.streams_co_vw
    WHERE blue_line_key = {cutoff_blk}
      AND downstream_route_measure <= {cutoff_drm}
    ORDER BY downstream_route_measure DESC
    LIMIT 1
  )
  -- Mainstem: DRM range
  SELECT s.segmented_stream_id, s.blue_line_key, s.waterbody_key,
         s.downstream_route_measure, s.gnis_name, s.stream_order,
         s.channel_width, s.mapping_code, s.rearing, s.spawning, s.access,
         s.geom
  FROM bcfishpass.streams_co_vw s
  WHERE s.blue_line_key = {mouth_blk}
    AND s.downstream_route_measure >= {mouth_drm}
    AND s.downstream_route_measure <= {cutoff_drm}
    AND s.stream_order >= {min_order}

  UNION ALL

  -- Tributaries: upstream of mouth, not upstream of cutoff
  SELECT s.segmented_stream_id, s.blue_line_key, s.waterbody_key,
         s.downstream_route_measure, s.gnis_name, s.stream_order,
         s.channel_width, s.mapping_code, s.rearing, s.spawning, s.access,
         s.geom
  FROM bcfishpass.streams_co_vw s, mouth m
  WHERE s.watershed_group_code = 'BULK'
    AND s.blue_line_key != {mouth_blk}
    AND s.stream_order >= {min_order}
    AND FWA_Upstream(
      m.wscode, m.localcode,
      s.wscode, s.localcode
    )
    AND NOT EXISTS (
      SELECT 1 FROM cutoff c
      WHERE FWA_Upstream(
        c.wscode, c.localcode,
        s.wscode, s.localcode
      )
    )
")

message("Querying network between drm ", mouth_drm, " and ", cutoff_drm,
        " on blk ", mouth_blk, " (order >= ", min_order, ")...")
network <- sf::st_read(conn, query = sql) |>
  sf::st_zm(drop = TRUE)

DBI::dbDisconnect(conn)

message("  ", nrow(network), " segments")
message("  Streams: ", paste(unique(na.omit(network$gnis_name)), collapse = ", "))
message("  Orders: ", paste(sort(unique(network$stream_order)), collapse = ", "))

# --- Write to inst/testdata ---
out_path <- here::here("inst", "testdata", "streams.gpkg")
sf::st_write(network, out_path, delete_dsn = TRUE, quiet = TRUE)
message("Saved: ", out_path)
