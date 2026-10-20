# Code-check round 3: #87 branch diff (2026-10-18)

Reviewer: subagent. It did not modify the repo. Probes ran in a `cp -r` copy under the scratchpad
(`r3/repo`) and in scratch files, plus read-only SQL against the local fwapg. HEAD moved to
541cd59 during the review (the final Parsnip re-run, from a frozen copy of the script). Everything
below was checked against 541cd59.

## Mechanism

**Provenance by proxy.** Each script identifies the state of an artifact by a record that a
different writer keeps, and never checks that the record describes those bytes:

- git's history stands in for the file on disk (round 2, finding 2: the commit of the gpkg was
  named while the working copy was not that commit's);
- the previous `pars_meta.rds` stands in for the previous `pars.gpkg`;
- `fresh_default.log` stands in for the contents of the `fresh_default` tables;
- a successful connection stood in for the tables being present (round 1).

The destructive half is the same assumption read the other way: the artifact was treated as
regenerable from its record, so deleting it was safe (round 2, finding 1: the gpkg holding the only
copy of the carried layers was wiped before the guards). Wherever two writers, or two files, have to
agree and nothing compares them, the defect class reaches.

## Enumeration (every place, verdict each)

### Destructive writes and deletes

| Script:line | Write | Condition that must hold first | Holds? |
|---|---|---|---|
| wsg_vignette_data.R:77 | `dir.create(out_dir)` | none | n/a |
| wsg_vignette_data.R:123 (`write_layer`) | layers into a tempfile gpkg | none (not the committed file) | yes |
| wsg_vignette_data.R:374 | `pars_dem.tif` in place | guards passed; streams final | yes. Mid-run in-place write, accepted (derived) |
| wsg_vignette_data.R:397 | `pars_valleys.tif` in place | same | yes. Accepted; a stop after it leaves valleys new, gpkg/meta old |
| wsg_vignette_data.R:410 | `file.copy(gpkg, gpkg_final, overwrite = TRUE)` | every expected layer is in the tempfile | **no**: `named_streams` can be missing (finding 4). The copy itself truncates first (finding 5) |
| wsg_vignette_data.R:411 | `unlink(gpkg)` (tempfile) | copy succeeded | yes (`stopifnot` before it) |
| wsg_vignette_data.R:413 | `saveRDS(meta, meta_path)` | gpkg in place | yes |
| network_extract.R:157 | `streams.gpkg`, `delete_dsn = TRUE` | schema + `run_id` guards, `setequal(ids)` | yes for the log; **no** for the tables, which have a second writer (finding 1) |
| network_extract.R:167 | `waterbodies.gpkg`, `delete_dsn = TRUE` | as above | yes. A stop between the two writes leaves the pair mixed; waterbodies are FWA-only, so low impact |
| stac_dem_vignette_data.R:218 | `stac_valleys_5m.tif` in place | none beyond the run so far | same shape as the accepted Parsnip rasters: a stop in section 4 (STAC endpoint, 1 m run) leaves a new 5 m raster beside the old `stac_meta.rds`. Unchanged on this branch; not flagged |
| stac_dem_vignette_data.R:241, 282 | 1 m raster, meta | run complete | yes |
| readme_figure.R:56 | `man/figures/readme-pars.png` | the Parsnip cache is one run's | not checked by the script; verified by hand: `aoi`, `streams`, `waterbodies`, `floodplain` and `named_streams` are identical between 09a5eeb and 541cd59, and `pars_valleys.tif` did not change, so the committed PNG matches the committed cache |
| testdata.R:65-66 | `dem.tif`, `slope.tif` | source DEM present | unconditional, unchanged on the branch; no longer writes `streams.gpkg` (correct) |

### Provenance fields and their sources of truth

| Field | Written from | Source of truth | Can they disagree? |
|---|---|---|---|
| `pars_meta.rds` `link_run_id`, `run_uid`, `run_label`, `config_*`, `link_run_date` | `fresh_default.log` latest row for PARS | the run that modelled the streams | agree today. `link_run_date` is UTC (read back in UTC, round 2) |
| `pars_meta.rds` `link_sha`, `link_version`, `link_dirty`, `fresh_*`, `crate_version` | `fresh_default.log` | the code that wrote the shipped columns | **yes**: `access`, `mapping_code` and `dam_dnstr_ind` were last written by link's recompute, a different link commit (finding 1). Version and date coincide |
| `pars_meta.rds` `fwapg_sha` | `fresh_default.log` | the fwapg tables `upstream_area_ha` and `map_upstream` are joined from at extraction time | **yes**: no pin covers those tables (finding 2) |
| `pars_meta.rds` `context_source` | this run's loop | which branch each layer took | agree (each layer assigns one or stops) |
| `pars_meta.rds` `context_carried_from`, inherited branch | previous meta | the commit whose gpkg last fetched the layer | agree today: all four layers in 541cd59 are identical to 2ef5c89's (and to b1ca690's), and 2ef5c89's script had no carry path, so it fetched them. Breaks only if the previous meta does not describe the previous gpkg (finding 3) |
| `pars_meta.rds` `context_carried_from`, commit branch | `git log -1 -- pars.gpkg` when `pars.gpkg` is clean | same | **yes**: the branch is chosen from the working meta, which the clean check does not cover. Reproduced (finding 3) |
| `stac_meta.rds` `git_sha`, `r_dirty` | HEAD at end of run; `git status -- R` | the code and the inputs the run read | `git_sha` timing accepted. `r_dirty` does not cover `inst/testdata/streams.gpkg`, the input this branch changed; that was committed (5dc6e8e/95b0d5b) before the 2d5644d run, so the record is right this time. Pre-existing scope; not flagged |
| `stac_meta.rds` counts (`n_10m`, `n_site_10m`, ...) | the same run | the cached rasters | agree; the test recomputes `n_10m` live |
| `inst/NOTICE.md` run ids, link 0.66.0, 2026-10-17 | typed by hand; the uncommitted-then-541cd59 comment beside each `run_id` | the `run_id` constants and the DB | ids, version and date match the log today. Nothing checks them. The access/mapping_code row names the modelling runs only, not the recompute runs that last wrote those columns (finding 1) |
| console: "Reading link run …" (both scripts) | `fresh_default.log` | same as meta | same limits as the meta |
| console: "named streams: 0 features (skipping)" | `fetch_layer` | the query result | **yes**: printed for a query error too (finding 4) |
| console: "carried over from the previous …" | `gpkg_final`, the error text | correct path and cause | agree |
| vignette prose (`link_config`, `link_version`, `link_run_date`, NA count) | `pars_meta.rds`, the gpkg | link run, data | agree today (version and date are the same for the model run and the recompute) |

## Findings

- **[severity: fragile]** `data-raw/wsg_vignette_data.R:136-152`, `data-raw/network_extract.R:61-80`,
  and the meta (`:347-359`) and NOTICE row that copy them. The `run_id` pin and every `link_*`
  provenance field come from `fresh_default.log`. But link has a second writer for the columns
  that ship. `data-raw/wsg_recompute_one.R` rewrites `streams_access` and `streams_mapping_code`
  ("the values that actually ship", link's `R/lnk_log.R:1181`) and records itself in
  `fresh_default.log_recompute`, not in `log`. That is deliberate: link's comment at
  `R/lnk_log.R:344-350` explains why. Measured:
  - PARS was recomputed `m1-20261017T092007.555-1b04b0` (09:20-09:24Z), after its modelling run
    ended at 03:53Z. BULK was recomputed `m1-20261017T071424.051-24a90b`.
  - Both recomputes ran link 0.66.0 at `a17e917`. Both modelling runs, which are what
    `pars_meta.rds` records as `link_sha`, ran `ee21eb1`.
  So the bundled `access`, `mapping_code` and `dam_dnstr_ind` came from code the meta does not
  name, and the NOTICE row credits them to the modelling run ids only.

  More importantly, a standalone recompute changes those columns and adds no `log` row, so both
  guards pass and the rebuild silently ships different access than the pinned run produced.
  `recompute_sweep.sh` runs it repeatedly. Fix: also select the latest `log_recompute` row per
  WSG. Pin its `recompute_id` beside `run_id`, and stop if a newer row exists or one has a NULL
  `date_end`. Record `recompute_id` and its `link_sha` in the meta, and name the recompute runs in
  NOTICE. The PARS recompute is `m1-20261017T092007.555-1b04b0`; I did not establish whether it
  runs DELETE+INSERT inside a transaction, so I make no claim about reads that overlap one.

- **[severity: fragile]** `data-raw/wsg_vignette_data.R:188-193`, `:359`; `network_extract.R:121-126`.
  The script joins `upstream_area_ha` and `map_upstream` live from fwapg's
  `fwa_streams_watersheds_lut`, `fwa_watersheds_upstream_area` and
  `fwa_stream_networks_mean_annual_precip`. No guard covers those tables. `fwapg_sha` in the meta
  is the link run's record of fwapg at 03:45Z, not the state of the tables at extraction. When
  fwapg#33 is fixed (the lookup rows these 8 segments lack), a re-run passes the `run_id` guard,
  fills the 8 NA areas, moves the floodplain, and still records the same `fwapg_sha`. Fix: record
  something measured at extraction (for example the NA count, or the row count of
  `fwa_streams_watersheds_lut`), or say in the meta comment that `fwapg_sha` is the link run's.

- **[severity: fragile]** `data-raw/wsg_vignette_data.R:110-118` (round 2's own fix). The commit
  fallback checks that `pars.gpkg` is clean, but it picks between "inherit" and "commit" from the
  working `pars_meta.rds`, which may not be the commit's. Reproduced in the copy at 541cd59: I
  rewrote the working meta to `context_source = "database"` for all four layers (what a run with the
  shared database reachable writes) and left the gpkg at HEAD. The provenance block then gave
  `clean: TRUE`, `commit: 541cd59 2026-10-17`, and `carried_from = "541cd59 2026-10-17"` for every
  layer. In fact those layers were carried in 541cd59; they were last fetched at 2ef5c89. The
  trigger is restoring one of the pair and not the other, as this branch already did once (run 4's
  meta was restored before run 5, round 2). Fix: require `git status --porcelain -- <gpkg> <meta>`
  to be empty and both to have the same last commit, or read the previous meta with
  `git show <commit>:<meta>` on the commit path. Otherwise record NA.

- **[severity: fragile]** `data-raw/wsg_vignette_data.R:339-343` with `:408-410`. `named_streams`
  still goes through `fetch_layer()`, which turns a query error into
  "named streams: 0 features (skipping)". The section-6 copy then replaces the previous gpkg, which
  has the layer, with one that lacks it. `pars-floodplain.Rmd:175` (`load_layer` returns NULL) and
  `:410` render without the labels, so nothing fails. This is round 1's defect (an error read as an
  empty result, with a layer dropped silently) on the one layer round 1's fix did not cover. The
  comment "Every layer is written" at `:408` is asserted, never checked. Fix: stop on a try-error for
  `named_streams` (it comes from fwapg, which the script already requires), or check before the copy
  that the tempfile's layers include `aoi`, `streams`, `waterbodies`, `floodplain`, `named_streams`
  and every context layer that is not "database"-empty.

- **[severity: fragile]** `data-raw/wsg_vignette_data.R:410-411`. In R 4.5.2, `file.copy()` is
  `file.create(to)` (which truncates to 0 bytes) followed by `file.append(to, from)`. If the append
  fails (disk full, I/O error, an interrupt), `pars.gpkg` is left truncated and `stopifnot` stops
  the run. Rscript's exit then deletes `tempdir()`, which holds the only complete new copy. So the
  guarantee in the comment at `:82-85` ("a run that stops part-way leaves the previous <wsg>.gpkg …
  untouched") fails in exactly this window. That is recoverable through git when the previous gpkg
  is committed, but not when it holds uncommitted database fetches, which is the case the fix was
  written for. The probability is low. Fix: copy to a sibling in `out_dir`
  (`paste0(gpkg_final, ".partial")`), then `file.rename()` it onto `gpkg_final`, which is the same
  volume and atomic.

## Checked and found correct

- No write to `inst/vignette-data/` or `inst/testdata/` precedes the guards in either script.
  `carried` is read-only.
- In `fresh_default.log`, `date_end` is NULL until a run finishes (link `R/lnk_log.R:1013-1029`),
  and PostgreSQL's `ORDER BY date_end DESC` puts NULLs first. So an in-flight or failed modelling
  run is what the guard selects, and it stops there. That is the safe direction. The log has
  0 NULL rows today.
- `prev_value()` handles the old single-value format, named vectors and absent names. Assigning a
  logical `NA` into `carried_from` coerces it to character. `git1()` maps a non-zero exit to NA;
  an ignored path or one outside the repo gives NA, not a commit.
- 541cd59's meta: four layers carried from `2ef5c89 2026-10-13`. Their content is identical to
  2ef5c89's gpkg, and 2ef5c89's script had no carry path. Correct.
- 8 NA `upstream_area_ha`, 0 NA `mapping_code` and 0 NA `map_upstream` in 541cd59's streams. Every
  accessible PARS segment has a `streams_mapping_code` row. The fwapg#33 link resolves to the right
  issue.
