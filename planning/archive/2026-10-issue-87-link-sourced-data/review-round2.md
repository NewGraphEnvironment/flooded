# Code-check round 2: #87 branch diff (2026-10-18)

Reviewer: subagent. It did not modify the repo. Probes ran in a `git archive HEAD` copy under the
scratchpad, plus read-only SQL. Scope: the round-1 fix (407ee26), the whole branch diff, and the
uncommitted edit to `data-raw/wsg_vignette_data.R` that appeared on disk during the review (the
`prev_meta` inheritance of `context_carried_from`), because that edit will land.

## Findings

- **[severity: bug]** `data-raw/wsg_vignette_data.R:90-107` (the wipe) against `:110-133` (the guards).
  The script deletes `inst/vignette-data/pars.gpkg` (`file.remove(gpkg)`) and holds the context
  layers only in memory. Only after that does it connect and run the schema and `run_id` guards.
  So any stop between the wipe and section 4 deletes the committed cache and the only copy of the
  layers the fallback depends on. Stops in that window include the `run_id` guard, the "no
  fresh_default schema" guard, a failed `frs_db_conn()`, `stopifnot(!anyDuplicated(...))`, and a
  failed streams query.
  Reproduced in a copy with `run_id <- "not-the-run"`: the script printed "fresh_default holds PARS
  run cypherjob2-…, not not-the-run" and stopped, and `inst/vignette-data/pars.gpkg` no longer
  existed.
  The `run_id` guard exists for exactly this case: the next provincial link run. After it fires,
  the corrected re-run has no previous gpkg. With the shared database unreachable (the current
  situation), it stops at "Could not fetch railways and the previous … has no such layer to carry
  over". So the guard that CLAUDE.md describes as "stop unless …" destroys the input it is
  protecting, and the round-1 fallback cannot recover from it. `git checkout` can restore a
  committed gpkg. A gpkg holding freshly fetched, uncommitted layers is lost.
  `network_extract.R` does not have this problem: its guards run before any write, as findings.md
  records.
  Fix: run the connection and the guards before reading `carried` and removing the gpkg. Better
  still, build into a temp gpkg and move it into place at the end.

- **[severity: fragile]** `data-raw/wsg_vignette_data.R:97-103` (the uncommitted working-tree
  edit) and `:347`. The new code inherits the previous meta's `context_carried_from` as one scalar
  for the whole file. Since round 1, though, `context_source` is per layer, and mixed sources are
  exactly the case the round-1 fix was written for: a shared database that has some tables and not
  others.
  Example: run A fetches `roads` from the database and carries the other three from 2ef5c89, so its
  meta records `context_carried_from = "2ef5c89 …"`. Run B, with no shared database, carries all
  four and inherits "2ef5c89" for `roads` too. But `roads` was last fetched in run A, not in
  2ef5c89.
  The reverse case also goes wrong. If the previous run fetched all four (`prev_from` NA), the code
  falls back to `git log -1 -- gpkg`, which names the last commit. When the gpkg on disk is
  uncommitted (it is `M` in `git status` now), that commit's file is not the file the layers were
  read from.
  The meta field then states a wrong origin with no sign that it is wrong.
  Fix: record the origin per layer. Keep a named `context_carried_from` beside `context_source`,
  and for each carried layer inherit the previous meta's entry for that layer. For a layer the
  previous run fetched, use the commit of a clean gpkg (`git diff --quiet -- gpkg`), or NA.
  (The scalar version gives the right value for the PARS run now in progress, where all four layers
  are carried. The run-5 meta reads "2ef5c89 2026-10-13", after the "09a5eeb 2026-10-17" that run 4
  wrote was restored. Only mixed or uncommitted states go wrong.)

## Checked and found correct

- Round-1 fix, connection path: `fresh:::.frs_conn_resolve()` (fresh 0.39.0) drops empty
  arguments. When any standard `PG*` variable is set, it uses the explicit arguments and lets
  libpq fill in the rest. When only `PG_*_SHARE` is set, `frs_db_conn()` with no arguments
  resolves to the share database. Skipping the connection when every `PG_*_SHARE` (except the
  password) is empty therefore closes the round-1 fall-through. A partly set share falls back to
  the standard values, and its query errors send each layer to the carried copy, with a message
  and `"carried"` in the meta, so nothing is silent.
- The per-layer loop: a try-error, or a database without the table, goes to the carried copy or
  stops. A successful empty result is recorded as `"database"` and skipped, which is the
  behaviour the code had before the branch. `conn_ctx` is disconnected only when it is a real
  connection. `context_source` always holds four entries (each layer either assigns one or stops).
  `any(context_source == "carried")` is well defined.
- `fresh_default.log` has one row each for BULK and PARS. Both are link 0.66.0, with `date_end`
  2026-10-17 03:53/03:58 UTC (timestamptz, read back in UTC), which matches the NOTICE row and
  `link_run_date`.
- fwapg's `fwa_stream_networks_channel_width.channel_width_source` takes the values
  FIELD_MEASURMENT, FWA_RIVERS_POLY, MODELLED and NA, which matches the NOTICE row's three
  sources. README's "channel width on its stream segments" carries no quantifier, and it is
  accurate.
- Bundled `streams.gpkg` holds 16 columns, access 1 x13 and 2 x37, and the Bulkley, Cesford,
  Richfield and Robert Hatch creeks are present. The valley-confinement vignette's named
  tributaries and "order 4+ streams that coho can reach" both hold.
- `pars-floodplain.Rmd` and `valley-confinement.Rmd` keep their dated records ("measured on the
  0.7.0 inputs", "before flooded#87"). The remaining `bcfishpass` mentions in the diffed files are
  credits for the ported VCA code, the scoped override credit, or history.
- The per-group ratio (2.28 / 2.21), 1,643 = 5.4% of 30,480, 28,726 cells, the 2.36 multiplier,
  and "28 of 50 segments" all match findings.md.
