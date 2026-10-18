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
