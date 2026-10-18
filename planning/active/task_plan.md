# Task: Build the bundled and vignette data from our link-built tables, not bcfishpass (#87)

**If we do it:** the stream data flooded ships comes from tables we build with link, so its attributes and access flags follow our own model and its provenance is ours to state. fwapg and bcfishpass stay credited for what they provide and for the adapted code. **If we never do:** the bundled data stays a copy of bcfishpass output, with bcfishpass's ODbL attribution in `inst/NOTICE.md`, and the README figure's access model is described by reference to bcfishpass.

## Context

The stream data flooded ships (`inst/testdata/streams.gpkg`, the `streams` layer of
`inst/vignette-data/pars.gpkg`) is copied from bcfishpass views, so its access and habitat
flags follow bcfishpass's model and `inst/NOTICE.md` carries bcfishpass's ODbL attribution.
#87 moves it to tables link builds. **Decided:** read link's `default` config (`fresh_default`
schema in local fwapg; BULK and PARS both run 2026-10-17 on link 0.66.0), and ship link's own
column names and types (`id_segment`, TRUE/FALSE `spawning`/`rearing`).

### What exploration measured (read-only probes, 2026-10-18)

- **BULK test reach:** with the same network (`blue_line_key` 360873822, drm 216733–222000,
  order >= 4, coho `access IN (1,2)`, clipped to `dem.tif`), `fresh_default` gives **the same 50
  segments**: identical geometry, bbox, `gnis_name` groups (Bulkley 18, Cesford 9, Richfield 15,
  Robert Hatch 2, NA 6), orders, `channel_width` and `upstream_area_ha`. What moves:
  - `map_upstream`: fwapg's `fwa_stream_networks_mean_annual_precip` differs from bcfishpass's
    copy on 28 of 50 segments, by −17 to +1 mm. Flood depths and therefore cell counts will shift
    a little.
  - `access`: 1 segment goes 1 → 2. `mapping_code` and spawning/rearing (49 TRUE/TRUE, 1
    FALSE/FALSE) match.
- **Parsnip:** order >= 3 bull-trout accessible, 9,386 segments / 2,314 km against today's
  8,436 / 2,310 km (link segments more finely). The floodplain and every Parsnip figure will move.
- `fresh_default.streams` has `channel_width` but no `upstream_area_ha` or `map_upstream`: those
  join from fwapg (`fwa_streams_watersheds_lut` → `fwa_watersheds_upstream_area`; MAP on
  `wscode_ltree`/`localcode_ltree`), the joins fresh documents in `frs_col_join()`.
- The link tables live only in local fwapg (localhost:5432). The Parsnip context layers (roads,
  railways, reserves, parks) live only in the remote newgraph database, so the Parsnip script
  needs both connections, as link's own `data-raw/wsg_vignette_data.R` already does.
- `fresh_default.log` carries `run_id`, `date_end`, `config_name`, `link_version`, `link_sha`,
  `fresh_version`, `fwapg_sha` per WSG: that replaces `bcfishpass.log`.
- **Boolean columns change one test:** `fl_valley_join(cols = NULL)` takes every logical column,
  so `test-fl_valley_join.R:384`'s `expect_named()` will see `spawning`/`rearing`.
- `pars_meta.rds` is written but read nowhere.

## Phase 1: Bundled test data from link (BULK)
- [x] Rewrite `data-raw/network_extract.R`: local fwapg connection; `fresh::frs_network()` over
      `fresh_default.streams` (`wscode_ltree`/`localcode_ltree`, same blk/drm, `stream_order >= 4`);
      join `streams_access.access_co`, `streams_habitat_co` spawning/rearing and
      `streams_mapping_code.mapping_code_co` by `id_segment`; `upstream_area_ha` and `map_upstream`
      from fwapg; keep `access IN (1,2)` and the clip to `dem.tif`; stop if BULK is not persisted in
      `fresh_default`; print the `fresh_default.log` run it read
- [x] Columns: `id_segment`, `linear_feature_id`, `blue_line_key`, `waterbody_key`,
      `downstream_route_measure`, `upstream_area_ha`, `map_upstream`, `gnis_name`, `stream_order`,
      `channel_width`, `mapping_code`, `access`, `spawning`, `rearing`
- [x] Run it; regenerate `streams.gpkg` and `waterbodies.gpkg`; record the old-vs-new diff per
      column in `findings.md`
- [x] Correct `data-raw/testdata.R`'s header, which names an airbc geojson as the streams source

## Phase 2: Parsnip vignette data from link
- [ ] `data-raw/wsg_vignette_data.R`: streams from `fresh_default` PARS (`access_bt IN (1,2)`,
      order >= 3, the Phase 1 columns plus `gradient`, `dam_dnstr_ind`, `watershed_group_code`);
      boundary, waterbodies and named streams from local fwapg; context layers from the remote
      database on an explicit connection; persisted-run guard; fix the swapped assessed/modelled
      labels in its message (1 = modelled, 2 = observed)
- [ ] Replace the `bcfishpass.log` stamp: `pars_meta.rds` holds the `fresh_default.log` fields
      for the PARS run, and `pars-floodplain.Rmd` reads it to state the data's source
- [ ] Run it; regenerate `pars.gpkg`, `pars_dem.tif`, `pars_valleys.tif`; re-run
      `data-raw/readme_figure.R` for `man/figures/readme-pars.png` and check it at published width

## Phase 3: stac-dem cache
- [ ] Re-run `data-raw/stac_dem_vignette_data.R` (it reads the new bundled streams); confirm
      `test-vignette_data.R` passes against the rebuilt cache

## Phase 4: Tests
- [ ] Full suite; for each failure take the file:line, re-measure the pinned value on the new
      data, never loosen a tolerance. Includes the stac-dem cell counts
- [ ] `test-fl_valley_join.R:384`: account for the logical `spawning`/`rearing` columns
- [ ] Confirm the geometry fixtures still hold (no-stream block `311:323, 229:241`, island
      `340:370, 570:600`) — geometry did not change, so expected to

## Phase 5: Numbers and prose that move
Rule: a present-tense claim (example output, "on this tile", captions, roxygen) is re-measured;
a dated measurement record (§9 tables in `inst/notes/`, `research/`, CLAUDE.md's design-decision
history, NEWS) stays, with one line saying it was measured on the bcfishpass-sourced data
before this change.
- [ ] README: example output table and the 287 ha total; the "5 km reach" claim (measure it)
- [ ] `valley-confinement.Rmd`: source sentence (line 27) and numbers at 96-98, 188, 331, 447, 499
- [ ] `pars-floodplain.Rmd`: source sentence (214-215) and numbers at 74, 83-84, 227
- [ ] Roxygen numbers: `fl_flood_surface.R:40-45`, `fl_valley_attribute.R:76-87`,
      `fl_valley_confine.R:89-91`, `fl_dem_aoi.R:90-91`; `devtools::document()`
- [ ] CLAUDE.md test-data traps: the bijection, "49 of 50", "48 ties", "69 patches",
      "300 works" — re-measure each

## Phase 6: Provenance and licences
- [ ] `inst/NOTICE.md`: stream attributes and access from link (version, `default` config, run
      ids) over fwapg; upstream area and ClimateBC precipitation via fwapg; drop the bcfishpass
      ODbL data row and its sentence under "Data flooded produces"
- [ ] README "Data and methods": rewrite the bundled-data line, drop the #87 pointer; bcfishpass
      stays credited for adapted code (`LICENSE.note`, DESCRIPTION, README:134 unchanged)
- [ ] `inst/notes/methodology.md` lines that name bcfishpass as the *data source* (13, 22, 40-45);
      the model comparison (Thorley vs Hall) stays

## Validation

- [ ] Tests pass (`devtools::test()`), `R CMD check` clean, `pkgdown::check_pkgdown()`, lintr
- [ ] `/code-check` clean (each commit, or once over the branch with `/code-check branch`)
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion

## Out of scope (noted, not done)
- `dem.tif` itself (`data-raw/testdata.R` crops it from a bcfishpass lateral-habitat working
  file; its licence is #85's question). #87 is the stream data.
