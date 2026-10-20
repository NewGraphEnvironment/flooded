# Research

Durable findings: what is known, revised in place. The story of each issue is in
`planning/archive/`; this directory holds the verdict.

| File | Covers |
|---|---|
| [flood_surface_interpolation.md](flood_surface_interpolation.md) | Pooled IDW flood surface vs per-watercourse maxima (rejected, over-floods) and drainage ownership (opt-in, under-floods) (#68) |
| [dem_reprojection.md](dem_reprojection.md) | Reprojecting a DEM: the grid GDAL picks, the PROJ datum step (pinned for NAD83 pairs), terra-vs-gdalwarp warp settings (#67), and integer nodata through terra's warp (#76) |
| [bundled_stream_data.md](bundled_stream_data.md) | Where each column of the bundled streams comes from (link's modelling run, its recompute, fwapg), what pins a rebuild, the fwapg lookup gap, and why NOTICE keeps a bcfishpass credit (#87) |

Older durable notes live in `inst/notes/` and `inst/research/` (they ship with the package).

Naming: `<topic>.md`, revised in place, from 2026-10-09.
