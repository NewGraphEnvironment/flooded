# Bundled stream data: where it comes from and what pins it

**Verified:** 2026-10-19 · **Issues:** #87, #92, #85, fwapg#33 · **Produced by:** `data-raw/network_extract.R`,
`data-raw/wsg_vignette_data.R`, read-only SQL against the fwapg database link persists to
(`planning/archive/2026-10-issue-87-link-sourced-data/`).

## Sources, per column

The bundled streams (`inst/testdata/streams.gpkg`, layer `streams` of `inst/vignette-data/pars.gpkg`)
come from link's `default` configuration, schema `fresh_default`:

| columns | written by |
|---|---|
| geometry, `id_segment`, `gnis_name`, `stream_order`, `gradient`, `channel_width` | link's modelling run (`fresh_default.streams`; `channel_width` is fwapg's `fwa_stream_networks_channel_width`) |
| `spawning`, `rearing` | the modelling run (`fresh_default.streams_habitat_<sp>`) |
| `access`, `mapping_code`, `dam_dnstr_ind` | link's **recompute** (`fresh_default.streams_access`, `streams_mapping_code`), which runs after the provincial consolidate |
| `upstream_area_ha`, `map_upstream` | fwapg, joined live by the scripts (`fwa_streams_watersheds_lut` → `fwa_watersheds_upstream_area`; MAP on `wscode_ltree`/`localcode_ltree`) |

`id_segment` is unique only with `watershed_group_code`, and only within one link run.

## Three things a rebuild must not assume

- **`fresh_default.log` is not the last writer.** link's `data-raw/wsg_recompute_one.R` rewrites
  access and mapping codes afterwards and logs to `fresh_default.log_recompute`. For the 2026-10-17
  provincial run, modelling was link `ee21eb1` and the recompute link `a17e917`. Both scripts pin
  `run_id` and `recompute_id`, and require the recompute to start after the run ends.
- **`fresh_default` holds one provincial run at a time**; the next overwrites it. A pinned id that
  no longer matches stops the script: update it deliberately, with `inst/NOTICE.md`.
- **The fwapg tables carry no load stamp** (`provenance.source_artifact` stamps only the channel-width
  table), so nothing pins them. `pars_meta.rds` records the row counts read, and a digest of the rows
  of every fwapg query that reaches the bundle, which `tests/testthat/test-vignette_data.R` checks
  against the database when it can reach it (#92).

## The lookup gap (fwapg#33)

`fwa_streams_watersheds_lut` has no row for 160,877 of 4,699,005 stream segments (mostly edge types
1450, 1100, 1350), so upstream area joins as NA for them. bcfishpass's `load_streams.sql` uses the
same left join and its build had values, so the gap is in this fwapg build's lookup. On the Parsnip
it leaves 8 of 9,386 order 3+ segments without area, three on the Parsnip River main stem. Every other
segment matched bcfishpass's area exactly. The watershed-code-pair maximum that fresh documents does
not reproduce bcfishpass's values for these 8 (1,249 ha against 29,830 ha for one), so it is not a
substitute.

## Licence consequence

link's `default` config applies bcfishpass's barrier, crossing-status, observation and
habitat-confirmation override tables, so `access`/habitat/mapping code still contain bcfishpass
information (ODbL): `inst/NOTICE.md` keeps a scoped credit. CABD (dams) and the ClimateBC-derived
columns are open questions in #85.

## Where the Parsnip floodplain is measured (#92)

`inst/vignette-data/pars_valleys.tif` covers the streams plus 2 km, which reaches past the watershed
group's boundary. The article measures the floodplain inside the boundary: 451,557 cells (40,640.1
ha) at flood factor 4. The whole grid holds 40,969.3 ha, the figure #87 recorded. `pars_meta.rds`
stores the inside-boundary cell counts at flood factors 2, 4, 6 and 7.

