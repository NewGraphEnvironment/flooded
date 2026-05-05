# Progress — Add DEM source helpers (file, STAC) for AOI-driven workflows (#34)

## Session 2026-05-05

- Plan-mode exploration:
  - Surveyed flooded `fl_*` conventions, STAC vignette pattern, test scaffolding via Explore agent
  - Surveyed wedzin DEM handling pattern (`02_floodplain_model.R`) via Explore agent
  - Read `Projects/repo/rtj/docs/dem-sources.md` to ground architecture in settled rtj decisions
  - Discussed scope/architecture with user: rejected fresh-as-DEM-grabber, rejected new package, settled on single `fl_dem_aoi()` in flooded with MRDEM-30 inline default
  - Confirmed PARS vignette deliverable feasible (cd cache pattern proves region-scale at <1 MB)
- Phases approved by user
- Created branch `34-add-dem-source-helpers-file-stac-for-aoi` off main
- Scaffolded PWF baseline (`task_plan.md`, `findings.md`, `progress.md`) with approved phases
- Phase 1 complete: `fl_dem_aoi()` implemented with MRDEM-30 default, file/`/vsicurl/`/`/vsis3/` source dispatch, CRS-safe crop-before-reproject. 8 tests pass including live MRDEM range read; lintr clean; full suite 172 PASS.
- Phase 2a complete: `data-raw/wsg_vignette_data.R` is generic (any WSG via `wsg <- "PARS"`), pulls boundary from `whse_basemapping.fwa_watershed_groups_poly` and streams from `bcfishpass.streams_vw` (carries channel_width / upstream_area_ha / map_upstream), runs `fl_dem_aoi()` against MRDEM-30 via /vsicurl/, runs `fl_valley_confine()` end-to-end, polygonizes. Two XYZM bugs surfaced: fixed in `fl_dem_aoi()` itself, worked around for `fl_valley_confine()` via `sf::st_zm()` in the script (logged as follow-up).
- Cache for PARS: 11 MB total — `pars_aoi.gpkg` 0.31 MB, `pars_streams.gpkg` 2.7 MB, `pars_dem.tif` 6.2 MB (INT2S, was 29 MB FLT4S), `pars_valleys.tif` 88 KB, `pars_floodplain.gpkg` 1.2 MB.
- Next: Phase 2b — write `vignettes/pars-floodplain.Rmd` loading from cache
