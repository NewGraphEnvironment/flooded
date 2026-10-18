# Findings — Build the bundled and vignette data from our link-built tables, not bcfishpass (#87)

## Issue context

**If we do it:** the stream data flooded ships comes from tables we build with link, so its attributes and access flags follow our own model and its provenance is ours to state. fwapg and bcfishpass stay credited for what they provide and for the adapted code. **If we never do:** the bundled data stays a copy of bcfishpass output, with bcfishpass's ODbL attribution in `inst/NOTICE.md`, and the README figure's access model is described by reference to bcfishpass.

## Where bcfishpass is read today

- `data-raw/network_extract.R:53` reads `bcfishpass.streams_co_vw` for the bundled test reach (`inst/testdata/streams.gpkg`).
- `data-raw/wsg_vignette_data.R:106` reads `bcfishpass.streams_bt_vw` (bull trout accessible, order >= 3) for the Parsnip vignette and the README figure; line 225 reads `bcfishpass.log` for run provenance.
- `data-raw/stac_dem_vignette_data.R` reuses the bundled test streams.

## Tasks

- [ ] Point each script at link's output tables, with the same network and filters and the columns `upstream_area_ha`, `map_upstream`, `channel_width`, `access`, spawning and rearing.
- [ ] Re-run the scripts to regenerate `inst/testdata/`, `inst/vignette-data/` and `man/figures/readme-pars.png`.
- [ ] Update every number that moves: the README example output, the vignette figures, and the stac-dem cell-count guard in `test-vignette_data.R`.
- [ ] Rewrite `inst/NOTICE.md` and the README's data lines for the new source. fwapg (Freshwater Atlas, upstream area, ClimateBC precipitation) and bcfishpass (adapted code in `LICENSE.note`) stay credited.
- [ ] Record link's version and run as provenance, in place of `bcfishpass.log`.

Relates to #81, #85.



## Exploration probes (2026-10-18, read-only)

Probe scripts: `probe_bulk.R`, `probe_bulk2.R` (scratchpad, not committed); the queries are what
Phase 1 commits as `data-raw/network_extract.R`.

- GitHub was unreachable from this machine 2026-10-17 18:07Z to roughly 19:05Z (TLS handshake
  timeouts on api.github.com, github.com, githubstatus.com; other hosts fine). Planning waited.
- link persists to `fresh` (bcfishpass config) and `fresh_default` (default config) in local
  fwapg. Chosen: `fresh_default`. `fresh_default.log`: PARS run `cypherjob2-20261017T034533.534-1b8d39`,
  BULK run `cypherjob3-20261017T034609.698-65b431`, both link 0.66.0
  (`ee21eb1371cbc4d7a2d598f8bbeeaeb0534d7994`), fresh 0.39.0, 2026-10-17.
- access encoding in link: 0 / 1 (modelled) / 2 (observed), same as bcfishpass; habitat is boolean
  in `streams_habitat_<sp>`.
- BULK reach from `fresh_default`: same 50 segments, geometry, groups, `channel_width`,
  `upstream_area_ha` (max diff 2.9e-11). `map_upstream` differs on 28 of 50 (−17 to +1 mm);
  access 1 → 2 on one segment; mapping_code and spawning/rearing match.
- PARS order >= 3 bull-trout accessible: 9,386 segments / 2,314 km vs bundled 8,436 / 2,310 km.
- Inventory of pinned numbers, columns and bcfishpass mentions: Explore agent report, summarised
  in the plan's phases (tests, vignettes, README, roxygen, CLAUDE.md, inst/notes, research).

## Errors Encountered

| Error | Resolution |
|-------|------------|
| `gh`: TLS handshake timeout (all GitHub hosts) | Background waiter retried every minute; resumed when it answered |

## Phase 1: regenerated test data, old vs new (2026-10-18)

`data-raw/network_extract.R` against link run `cypherjob3-20261017T034609.698-65b431`:

| | old (bcfishpass `streams_co_vw`) | new (link `fresh_default`) |
|---|---|---|
| segments | 50 | 50, same WKT for every segment (matched on blk + drm) |
| columns | 13, `segmented_stream_id` | 14, `id_segment` + `linear_feature_id` |
| spawning/rearing | integer 1/0 | logical TRUE/FALSE, same pattern (49 / 1) |
| access | 1 ×14, 2 ×36 | 1 ×13, 2 ×37 |
| `map_upstream` | bcfishpass's copy | fwapg's; 28 of 50 differ, −17 to +1 mm |
| `upstream_area_ha` | | max diff 2.9e-11 |
| `channel_width`, `stream_order`, `gnis_name`, `waterbody_key`, `mapping_code` | | identical |
| row order | frs_network's | `blue_line_key`, `downstream_route_measure` |

`waterbodies.gpkg` regenerated with identical attributes and 0 m vertex distance (only ring
order differed), so the committed file is kept rather than churned.

`data-raw/testdata.R` used to write `streams.gpkg` too, from an airbc geojson; it now writes only
the DEM and slope, so `streams.gpkg` has one producer.

## Plan review and its fixes (2026-10-18)

Review in `review-plan.md`. Verified before acting: link's `default` config applies the bcfishpass
override tables under ODbL (link `inst/extdata/configs/default/README.md:34`, `NOTICE.md:13`),
so NOTICE keeps a scoped bcfishpass credit; `fresh_default.log` carries `run_uid`/`run_label`
(`20261017_004619-3f4c713b` / `provincial-241-default-246`, the same provincial run for BULK and
PARS) and `config_hash`.

Guards proven to fire (each stops before any write; `streams.gpkg` md5 unchanged):
- `run_id` set to a run fresh_default does not hold → "fresh_default holds BULK run …, not …"
- database without the schema (`Sys.setenv(PGDATABASE = "postgres")` inside R; a shell
  `PGDATABASE=` is overridden by `~/.Renviron`, so the first attempt ran the script normally and
  rewrote `streams.gpkg` with identical content) → "Database 'postgres' has no fresh_default schema"

## Present-tense numbers re-measured on the new bundled streams

| claim | old data | new data |
|---|---|---|
| README example areas (ha) | 264 / 112 / 130 / 50 / 99 | unchanged |
| README total | 287.27 ha (28,727 cells) | 287.26 ha (28,726 cells) |
| mean precip depth multiplier over stream cells (`fl_flood_surface.R:41` says 2.366) | 2.368 | 2.363 |
| Bulkley `map_upstream` (blk 360873822) | 531 | 531 (depth ~1.1 vs ~2.5 m at ff6 holds) |
| overlap ratio, defaults (test comment says 2.45x) | 2.28 | 2.28 |
| overlap ratio, vignette run with waterbodies (vignette says ~2.4) | 2.21 | 2.21 |
| fallback cells, vignette run | 1,643 | 1,643 |
| Bulkley length in the bundled reach | 5.31 km | 5.31 km (README "5 km" right, vignette "~8 km" wrong) |

The 2.45x and ~2.4 overlap claims were already stale before #87: both data sets give 2.28 / 2.21.

## Parsnip, old vs new (`data-raw/wsg_vignette_data.R`, run `cypherjob2-…1b8d39`)

- 9,386 segments (6,633 modelled, 2,753 observed) against 8,436; 2,313.6 km against 2,310 km.
- Floodplain 40,888.2 ha → 40,969.3 ha (+0.20%); 454,264 cells in both, 49 only old, 951 only new.
- `pars_dem.tif` byte-identical in values and grid (3,761 x 3,749, 14.1 Mcells).
- Waterbodies 664 → 668 (204 lakes, 464 wetlands).
- Context layers carried over identical (shared database unreachable; user chose carry-over).
- `aoi` and `named_streams` now from local fwapg: same attributes for the boundary (area equal to
  3e-6 m²); named streams differ in 7 names and some keys/orders (FWA vintage of the local build).
- 8 segments have NA `upstream_area_ha`: their `linear_feature_id` has no row in local fwapg's
  `fwa_streams_watersheds_lut` (edge types 1250/1450, three on the Parsnip River main stem).
  bcfishpass's `load_streams.sql` uses the same left join and had values, so its lookup had rows
  these lack. Province-wide 160,877 of 4,699,005 segments lack a row. Filed fwapg#33; shipped as NA.
- README figure re-rendered at the same 980 x 976 px.

## Phase 4/5 measurements (2026-10-18)

- Suite on the new bundled streams (stac-dem test excluded while its cache rebuilt): 575 passed,
  1 failed, `test-fl_valley_join.R:384`, the expected `cols = NULL` pick-up of the logical
  `spawning`/`rearing`. Every pinned number held, including `92L`, the island and no-stream
  fixtures, and the `cost_threshold = 300` fallback tests.
- CLAUDE.md test-data facts hold on the new data: 48 ties (old 48), 49 of 50 flags, 5-group
  `gnis_name`/`blue_line_key` bijection; the 69-patch count comes from `vc_both_paths()`, which
  passes no precipitation, so its inputs are unchanged.
- Channel width in the bundled streams was always fwapg's `fwa_stream_networks_channel_width`
  (bcfishpass's `load_streams.sql` joins the same table), so the notes now name fwapg as the source
  and keep Thorley et al. 2021 as the model. Order 1 NA holds: 19,184 of 19,740 PARS order-1
  segments have no width in fwapg; 61,863 of 64,653 in link.
- Stale before #87 and corrected: overlap ratio "~2.4" / "2.45x" (2.21 / 2.28 on both data sets);
  "1,643 cells (3.0%)" (3.0% was of the pre-0.5.0 53,635; it is 5.4% of 30,480 now); vignette
  "~8 km" of mainstem (5.31 km).

## Code-check round 1 (`review-round1.md`)

1. Context fallback fired only on a connection error. With `PG_*_SHARE` empty, `frs_db_conn()`
   falls through to the standard `PG*` database (fwapg), the four queries fail inside `try()`,
   and the old code dropped all four layers while recording `"database"`. Reproduced with a
   harness (script copies writing to scratch, stopping after section 4): old version, empty
   variables and variables pointed at fwapg → layers `aoi streams waterbodies named_streams`
   only. Fixed: per-layer source, a query error falls back to the carried layer, no carried layer
   stops; empty variables skip the connection. New version: all four carried in both scenarios,
   `context_source` per layer; no previous gpkg → stops.
2. README "upstream area … on every stream segment" was false (fwapg#33); reworded.
3. CLAUDE.md reference-docs line still said "bcfishpass vs VCA"; now fwapg/Thorley.
