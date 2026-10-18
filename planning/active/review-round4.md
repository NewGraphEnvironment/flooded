# Code-check round 4: #87 branch diff (2026-10-18)

Reviewer: subagent, terminal verification of round 3. It did not modify the repo. Probes ran in a
`cp -r` copy (scratchpad `r4/repo`) and with read-only SQL against the local fwapg. **HEAD moved
during the review**: the final Parsnip re-run was committed as `99a1817` ("Rebuild the Parsnip meta
with the pinned recompute and fwapg state"), touching `pars.gpkg` and `pars_meta.rds`. Everything
below was checked against 99a1817.

## Enumeration check

Re-derived by grep over the five scripts (`st_write`, `writeRaster`, `saveRDS`, `file.copy`,
`file.rename`, `unlink`, `file.remove`, `png(`, `dir.create`, `write_layer(`) and by reading every
field of the committed `pars_meta.rds` and `stac_meta.rds` and every run id in `inst/NOTICE.md`.

**The set matches round 3's, plus the two writes the fixes introduced**: the `.new` copy
(`wsg_vignette_data.R:437`) and the `.partial` copy + rename (`:442`, replacing round 3's single
`file.copy`). New provenance fields: `link_recompute_id`, `link_recompute_sha`,
`link_recompute_date`, `fwapg_read`, `n_upstream_area_na`; NOTICE gained the two recompute ids.
Round 3's stac-dem line numbers (218, 241) are now 172/245 (`write_valleys()` and the native
raster); the script is unchanged on the branch. `testdata_bcdata.R` writes only into `data-raw/`
(out of scope). No `file.remove` remains anywhere.

### Writes

| Script:line | Write | Precondition | Holds now? |
|---|---|---|---|
| wsg:78 | `dir.create(out_dir)` | none | n/a |
| wsg:129 (`write_layer`, called 193/232/281/337/341/356/428) | layers into the tempfile gpkg | not the committed file | yes |
| wsg:356 | `named_streams` | query succeeded | yes: `st_read()` now raises on a query error (no `try`), before any write to `inst/` |
| wsg:396 | `pars_dem.tif` in place | guards passed | yes (accepted mid-run in-place write) |
| wsg:419 | `pars_valleys.tif` in place | same | yes (accepted) |
| wsg:437 | `file.copy(gpkg, <gpkg>.new)` on a lost layer | none | return value unchecked; see finding 4 |
| wsg:442 | copy to `<gpkg>.partial`, `file.rename()` onto `pars.gpkg` | no previous layer lost | yes. `stopifnot` evaluates in order, so a failed copy never reaches the rename; rename on one volume is atomic |
| wsg:443 | `unlink(tempfile)` | copy and rename succeeded | yes |
| wsg:445 | `saveRDS(meta)` | gpkg in place | yes |
| network_extract:178 | `streams.gpkg`, `delete_dsn` | schema, `run_id`, `recompute_id`, `setequal(ids)` | yes for both logs; see finding 2 for what "latest recompute" stands in for |
| network_extract:188 | `waterbodies.gpkg`, `delete_dsn` | same | yes (mixed pair on a stop between the two, low impact, as round 3) |
| stac_dem:172, 245, 282 | 5 m / 1 m site rasters, native raster (opt-in dir), meta | run so far / complete | unchanged; same verdicts as round 3 |
| readme_figure:56 | `readme-pars.png` | cache is one run's | yes, verified by hand: every layer of `pars.gpkg` (attributes and WKB) is identical between 09a5eeb and 99a1817, and `pars_valleys.tif` was last committed at 09a5eeb, so the PNG (d367030, rendered on that cache) still matches |
| testdata:65-66 | `dem.tif`, `slope.tif` | source DEM present | unchanged |

### Provenance fields

| Field | Written from | Source of truth | Holds now? |
|---|---|---|---|
| `link_run_id`, `run_uid`, `run_label`, `config_*`, `link_version`, `link_sha`, `link_dirty`, `link_run_date`, `fresh_*`, `crate_version` | `fresh_default.log`, guarded to the pinned run | the modelling run | yes; values match the DB (`ee21eb1`, 03:53:58Z) |
| `link_recompute_id`, `_sha`, `_date` | latest `log_recompute` row, guarded to the pin and to a non-NULL `date_end` | the recompute that last rewrote `streams_access` / `streams_mapping_code` | yes today (`m1-…1b04b0`, `a17e917`, after the run). The guard does not tie the recompute to the run (finding 2). link inserts the row at start with NULL `date_end` (`R/lnk_log.R:1215-1281`), so an in-flight recompute is caught |
| comment on those fields | hand-written | what the recompute rewrites | **no**: it names habitat flags (finding 3) |
| `fwapg_sha` | `log` | annotated "as recorded by the link run" | yes, as a record |
| `fwapg_read` | `count(*)` at extraction | the fwapg tables joined | yes as a record (4,538,224 / 3,245,453 / 3,075,336; matches a live count). `integer64` → numeric is correct because RPostgres loads bit64. `read_at` is stamped when the meta list is built, a few minutes after the counts; immaterial |
| `n_upstream_area_na` | the streams read | the data | yes (8; vignette recomputes it live from the clipped layer, also 8 of 9,386) |
| `context_source` | this run's loop | branch taken | yes |
| `context_carried_from`, commit branch | `git log -1` when gpkg and meta are clean and share their last commit | commit that fetched the layer | yes for the case round 3 reproduced |
| `context_carried_from`, inherit branch | previous meta when it says "carried" | same | **no** when the previous meta says "carried" with an NA origin: the commit is recorded instead (finding 1, reproduced) |
| `stac_meta.rds` fields | unchanged script | — | accepted scope, as round 3 |
| NOTICE run ids, link 0.66.0, 2026-10-17 | hand-typed; both scripts now say "change them together" | constants and DB | yes: both run ids and both recompute ids match the constants and `log` / `log_recompute`, in Bulkley-then-Parsnip order |

## Findings

- **[severity: fragile]** `data-raw/wsg_vignette_data.R:122-124`. This defect is in round 2's fix
  for the inherit branch, and round 3's fix did not touch it.
  `carried_from <- if (prev source == "carried" && !is.na(inherited)) inherited else commit`. When
  the previous committed meta says a layer was **carried with unknown origin** (`NA`), this falls
  through to `commit` and records that commit as having fetched the layer. But that commit's own
  meta says it carried the layer. Reproduced in the copy at 99a1817: I set
  `context_carried_from` to NA for all four layers, committed the meta and gpkg together (clean,
  same commit) and ran lines 77-126. The result was `"a413351 2026-10-17"` for railways, roads,
  reserves and parks.

  The route is ordinary. A run whose origin is unknown writes NA for every carried layer: re-running
  before committing makes the tree dirty, which this branch did between runs 4 and 5. Commit that
  output, run again from a clean tree, and the commit is named. Round 2's harness could not reach
  this because its scratch directory was outside git, so `commit` was NA there anyway.
  Fix: `if (identical(prev_value(pm$context_source, nm), "carried")) inherited else commit`, so a
  carried layer with an NA origin stays NA.

- **[severity: fragile]** `data-raw/wsg_vignette_data.R:159-169`, `data-raw/network_extract.R:82-92`.
  The recompute guard checks that the latest `log_recompute` row is the pinned one. It never checks
  that this recompute came **after** the pinned modelling run. Suppose a WSG is re-modelled with no
  recompute after it: a single-WSG `lnk_pipeline_run()`, which persists `streams_access` and
  mapping codes afresh. The `run_id` guard fires, and the maintainer updates `run_id` as its message
  says. The latest recompute is still the old one, which predates the new run, so the recompute
  guard passes. The meta then records `link_recompute_*` and the NOTICE credits a recompute whose
  output the new run overwrote. The guard fails toward pass here: "latest recompute" stands in for
  "the recompute applied to this run". It holds today (09:20Z recompute after the 03:53Z run, same
  `run_uid`). Fix: also stop unless `rc$date_start > run$date_end`. A run with no later recompute
  would then need an explicit `recompute_id <- NA` path that records NA.

- **[severity: fragile]** `data-raw/wsg_vignette_data.R:370`. The comment that defines the new meta
  fields says "access, habitat flags and mapping codes were rewritten by this recompute". link's
  recompute does not reclassify habitat. `data-raw/wsg_recompute_one.R:1-15` says it reuses the
  persisted `streams_habitat` and rewrites only `streams_access` (cross-WSG columns, via
  `lnk_access(merge = TRUE)`) and `streams_mapping_code`. So `spawning` and `rearing` come from the
  modelling run's code (`ee21eb1`), not from `link_recompute_sha` (`a17e917`). NOTICE says this
  correctly ("access and mapping codes recomputed"). The comment is the only description of what
  the field means, so a later NOTICE or vignette edit taken from it would credit habitat to the
  wrong commit. Fix: change "habitat flags" to "dam flags", or drop it.

- **[severity: fragile]** `data-raw/wsg_vignette_data.R:436-439`, which round 3's fix 4 added in
  0823eba. On a lost-layer stop the rejected 13 MB gpkg is written to
  `inst/vignette-data/pars.gpkg.new`, and a failed `rename` leaves `pars.gpkg.partial` there. Nothing
  removes either. A later successful run leaves the file behind. `R CMD build` ships every file
  under `inst/` (neither `.Rbuildignore` nor `.gitignore` covers it), and `git add -A` commits it.
  The `file.copy()` return at `:437` is also unchecked, so the error can say "the new one is at
  `…new`" when no file was written. Fix: keep the rejected copy outside `inst/`, for example
  `data-raw/` or a named directory under `tempdir()` that is not removed, or ignore
  `^inst/vignette-data/.*\.(new|partial)$` in both ignore files. Also check the copy's return value
  before naming the file.

## Round 3 fixes, verified

1. Recompute pin: both scripts select `log_recompute` by WSG, `ORDER BY date_start DESC`
   (0 NULL `date_start` in 243 rows; the column is `NOT NULL`), and stop on a different id, no row,
   or a NULL `date_end`. That covers in-flight and failed recomputes, since link writes `date_end`
   only on success. Meta and NOTICE carry the ids. Residual: finding 2.
2. fwapg state: recorded in the meta, and printed by `network_extract.R` (console only, as
   accepted). Correct values.
3. Origin fallback: correct for the case round 3 reproduced. A residual sits one axis over on the
   inherit branch (finding 1). Being clean and sharing a last commit still stands in for "the same
   run". That fails only if a commit pairs a gpkg and a meta from different runs, which needs a stop
   inside the three statements at `:442-445` or a hand restore before committing. Not flagged.
4. `named_streams`: now raises on a query error. The lost-layer check also stops when the database
   legitimately returns 0 features for a layer the previous gpkg had. That is conservative and fine.
   Residual: finding 4.
5. `.partial` + `file.rename`: correct, and atomic on one volume.

## Rest of the diff (brief)

- Vignette, README, NOTICE, notes, roxygen/Rd and test edits match the data. The clipped Parsnip
  streams are 9,386 with 8 NA areas, as the prose computes. HEAD's `pars.gpkg` is layer-for-layer
  identical to 09a5eeb's, so the recompute pin changed no data.
- Not a finding: the guards run before the reads, so a link recompute or provincial run that starts
  during the roughly one-minute extraction is not seen. Each read is one statement-level snapshot,
  but `lnk_access(merge = TRUE)` commits in several statements. Re-checking both log ids after the
  last read would close it. The window is small, and the state is the same as round 3's.
