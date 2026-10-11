# extract_arm2.R — cache the order >= 2 network (floodplains' probe arm 2) for #72's bench
#
# The probe reads its arms from the database and caches only their outputs, so the order >= 2
# streams have to be read again. This uses floodplains' own read and filter (fp_wf_read_network(),
# fp_wf_keep()), so the network is the one the arm 2 timings were measured on, and asserts the
# probe's recorded segment and blue-line counts (arm2_timing.json).
#
# usage (from the floodplains checkout, which `here` resolves):
#   Rscript <this file> <area>
# writes data/<area>/probe_whole_fwa/arm2_streams.gpkg (gitignored there)

area <- commandArgs(trailingOnly = TRUE)[1]
stopifnot(!is.na(area), area %in% c("bulk", "morr"))
suppressMessages({library(sf); library(DBI); library(RPostgres)})
sf::sf_use_s2(FALSE)
source(here::here("scripts", "floodplain_lcc", "fp_whole_fwa.R"))

cfg <- yaml::read_yaml(here::here("config", area, "area.yml"))
read_schema <- if (!is.null(cfg$network_source) && nzchar(cfg$network_source)) cfg$network_source else cfg$schema
sc <- utils::read.csv(here::here("config", area, "flood_scenarios.csv"))
sc <- sc[sc$scenario_id == "co_ff04", ]
stopifnot(nrow(sc) == 1L)

conn <- DBI::dbConnect(RPostgres::Postgres())
all <- fp_wf_read_network(conn, read_schema, cfg$watershed_group, cfg$species)
DBI::dbDisconnect(conn)
s <- all[fp_wf_keep(all, 2L, as.integer(sc$min_order)), ]

dir_out <- here::here("data", area, "probe_whole_fwa")
rec <- jsonlite::read_json(file.path(dir_out, "arm2_timing.json"))
cat(area, ":", nrow(s), "segments,", length(unique(s$blue_line_key)), "blue lines; probe recorded",
    rec$n_segments, "/", rec$n_blk, "\n")
stopifnot(nrow(s) == rec$n_segments, length(unique(s$blue_line_key)) == rec$n_blk)
sf::st_write(s, file.path(dir_out, "arm2_streams.gpkg"), layer = "streams", delete_dsn = TRUE, quiet = TRUE)
