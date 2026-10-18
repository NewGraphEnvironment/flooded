# Plan review — #87 (Plan agent, 2026-10-18; findings returned as reply text, written here)

Reviewed `task_plan.md` and `findings.md` at HEAD 80cf2d1 against flooded and link. Read-only.
Verdicts are mine after probing (V = verified, A = accepted as stated, P = partly).

## Blocker
- **B1 (V).** Dropping the bcfishpass ODbL data row is wrong: link's `default` config applies the
  bcfishpass override CSVs (barrier corrections, PSCIS status, observation exclusions, habitat
  confirmations; `link/inst/extdata/configs/default/README.md:34`, `link/NOTICE.md:13`), so
  access/habitat/mapping code still contain bcfishpass information. Channel width is fwapg's
  `fwa_stream_networks_channel_width` (FISS/PSCIS measured, rivers polygons, ClimateBC-modelled;
  PARS sources FIELD_MEASURMENT / FWA_RIVERS_POLY / MODELLED). `dam_dnstr_ind` from CABD.
  NOTICE should go per attribute and keep a scoped ODbL credit; re-date "Licences were checked".
  Wording calling the width "bcfishpass's" also at `R/fl_flood_surface.R:45`,
  `inst/notes/floodplain_interpretation.md:252,258,265`.

## Gaps
- **G1 (A).** README caption links link's Parsnip article, which uses link's *bcfishpass* config.
- **G2 (A).** `valley-confinement.Rmd:22` "~8 km" (bundled segments: 5.31 km of Bulkley) and :26
  "coho potential habitat".
- **G3 (A).** Present-tense tile numbers in `methodology.md:137-138, 152, 167`.
- **G4 (A).** `pars-floodplain.Rmd:74` (ff04–ff07 span 6.3%) has no script: keep as a dated record.
- **G5 (A).** Breaking change to shipped data (`segmented_stream_id` -> `id_segment`, int ->
  logical, new column, row order) needs a NEWS line.
- **G6 (A).** Nothing shipped records the BULK run; don't add a gpkg layer (unqualified `st_read`
  would warn). `stac_meta` `r_dirty` checks only `R/`.
- **G7 (V).** `pars_meta.rds` is the right place; add `run_uid`/`run_label`
  (`provincial-241-default-246`), `config_hash`, dirty flags, `crate_version`; record where the
  carried context layers came from.
- **G8 (A).** `id_segment` is unique only with `watershed_group_code`; ship it in `streams.gpkg`.
- **G9 (V).** 8 PARS segments have NA `upstream_area_ha` (lookup gap; fwapg#33).

## Ordering
- **O1 (A).** Timings (83–122 s) must not be re-measured on a loaded machine: keep as dated records.
- **O2 (A).** Commit PARS outputs together after the run ends.
- **O3 (A).** Change the PARS source sentence in the same commit that reads `pars_meta`.
- **O4 (A).** `test-vignette_data.R` red between Phase 1 and Phase 3; full suite after Phase 3.

## Assumptions
- **A1 (V).** Guard checks a log row, not data: count rows too.
- **A2 (A).** `fresh_default` is overwritten by the next provincial run: pin the expected `run_id`.
- **A3 (V).** Connection target depends on `~/.Renviron` (`PGHOST`/`PGDATABASE`): check the
  database has `fresh_default` and say so if not.
- **A4/A5 (V).** Compare by id/geometry, not row; precip-free results should be bit-identical
  (`92L` held: 575 of 576 passed on the new streams).

## Scope
- **S1 (A).** `fl_dem_aoi.R:90-91` uses only stream geometry: verify identity, no re-measure.
- **S2 (A).** BULK whole-network figures (16,705 / 572 ha) are from floodplains, not the tile.
- **S3 (A).** Delete the untracked root `Rplots.pdf` before `R CMD check`.

## Acceptance
- **R1 (A).** A claim naming the version, issue or date it was measured at is a record; else
  present tense. `pars-floodplain.Rmd:77-84` history: past tense + "regenerated from link (#87)".
- **R2 (A).** One dated note per section, not per number.
- **R3 (A).** Pairs that will diverge: README 287 ha vs 287.3 ha records; "~2.5 m" vs §9 2.50 m;
  §9 Cesford 576 mm (now <= 559 mm).
- **R4–R6 (A).** Diff by id; list expected-to-hold pins (stac NA counts, bijection, 49 of 50);
  the `test-fl_valley_join.R:384` fix is right.
