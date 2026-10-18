# Code-check round 1 — #87 branch diff (2026-10-18)

Reviewer: subagent, read-only on the repo; probes run in a scratchpad copy and read-only SQL.

## Findings

- **[severity: fragile]** `data-raw/wsg_vignette_data.R:248-253` (with `fetch_layer()` at :258) —
  the "carried" fallback fires only when `frs_db_conn()` *errors*. When the `PG_*_SHARE` variables
  are unset, each `e("PG_*_SHARE")` is `""`, `fresh:::.frs_is_set()` drops empty values, and
  `frs_db_conn()` connects to the standard `PG*` database instead, which is the local fwapg. Probed: local fwapg has no
  `whse_basemapping.gba_railway_tracks_sp` or `whse_tantalis.ta_park_ecores_pa_svw` (`to_regclass`
  NULL). `conn_ctx` then succeeds, so `context_source = "database"`, each context `st_read` errors
  inside `try()`, and `fetch_layer()` prints "0 features (skipping)" and writes nothing. The
  in-memory `carried` layers are discarded, and the gpkg was already removed at :409, so the rebuilt
  `pars.gpkg` ships with no railways, roads, reserves or parks layer. `pars_meta.rds` still records
  `context_source = "database"`, and the vignette's `load_layer()` returns NULL without complaint.
  fresh's own message calls `PG_*_SHARE` deprecated, so this is the setup a contributor following fresh's
  guidance will have. The same silent skip happens if the shared database is reachable but lacks
  one table. It fails toward pass. Fix: decide "carried" vs "database" by whether every context
  layer was actually fetched (or check the share variables are set and the tables exist), and fall
  back to `carried` per layer, or stop, when a fetch fails.

- **[severity: bug, prose]** `README.md:137-139` — "fwapg ... with upstream area and ClimateBC mean
  annual precipitation on every stream segment." This line is unchanged, but the branch now ships data that
  contradicts it. 8 of the 9,386 Parsnip segments have NA `upstream_area_ha`, because fwapg's
  `fwa_streams_watersheds_lut` has no row for them. Province-wide that is 160,877 of 4,699,005
  segments (findings.md; fwapg#33, OPEN), and the Parsnip vignette now says so. Precipitation has
  0 NA on the Parsnip, so the "every" fails only for upstream area. Scope it, for example "on almost
  every stream segment (some lack upstream area: fwapg#33)".

- **[severity: bug, prose, minor]** `CLAUDE.md:219` — the reference-docs line still describes
  `methodology.md` as "channel-width models (bcfishpass vs VCA)". This branch renamed that row
  to fwapg throughout `methodology.md`, after measuring that the bundled `channel_width` is fwapg's
  `fwa_stream_networks_channel_width`. Probed: 0 of 12,500 PARS order >= 3 segments differ between
  `fresh_default.streams` and that table. Should read "fwapg vs VCA".

## Checked and found correct

- Parsnip extent 40,969.3 ha (455,215 cells) vs old 40,888.2 ha (454,313): +0.20%. DEM 3,761 x
  3,749. 9,386 segments, 2,313.6 km, access 6,633 / 2,753, 8 NA area, and 9,386 / 8 after
  `frs_clip(streams, aoi)`, so the vignette's inline counts match the prose.
- `pars_meta.rds` fields: link 0.66.0, run ids and date as stated in NOTICE; `context_source =
  "carried"`, from `2ef5c89 2026-10-13`.
- Bundled tile: 50 segments, Bulkley 5.31 km ("~5 km"), Bulkley `channel_width` 31.3 m; the
  waterbodies run gives 30,480 cells, so 1,643 is 5.4% of it.
  `test-fl_valley_join.R` (123 expectations) and `test-fl_valley_attribute.R` (86) pass on the
  new data with `NOT_CRAN=true`.
- `` `r meta$link_config` `` inside double backticks knits to a code span `` `default` `` (tested).
- `fwapg#33` link resolves to an open issue on the public NewGraphEnvironment fork.
- SQL construction: interpolated values are constants, integers or `dbQuoteLiteral`. The removed
  top-level `on.exit()` never fired, and `conn` is now disconnected explicitly. `system2()` status is
  read via `attr(, "status")`.
