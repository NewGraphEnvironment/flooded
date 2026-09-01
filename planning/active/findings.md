# Findings — fl_valley_confine(): default field= is wrong for the flood model (#47)

## Issue context

`fl_valley_confine(field = "channel_width")` defaults to a column that is **wrong for the flood
model**, and produces a smaller floodplain silently.

`field` names the column rasterized into `stream_r`. That raster is then handed to
`fl_flood_model()` -> `fl_flood_surface()`, where it is used as the **drainage-area term** in the
Hall bankfull regression. So `field` must be upstream area. The default supplies channel width
instead — a valid number that means something else entirely, raised to the 0.280 power without
complaint.

Column ranges in `inst/testdata/streams.gpkg` show why nothing catches it — both are plain positive
numerics:

| column | range |
|---|---|
| `upstream_area_ha` | 1,928.8 .. 110,337.4 |
| `channel_width` | 4.1 .. 31.3 |

Issue recommendation: **(1) make it required, plus (3) rename to `area_field`**, with the roxygen
stating units (ha) and naming the regression that consumes it. Option (2), a magnitude guard, is
rejected — a genuinely small headwater basin (~10 ha) overlaps the channel-width range, so the
guard cannot separate its two inputs.

## Decisions taken at planning time

- **Deprecation shim, not a hard rename.** The issue's audit covers only the unused *default*; a
  straight rename also breaks every *working* explicit caller, including
  `floodplains/scripts/floodplain_lcc/02_floodplain_model.R:148`. `field` moves to the end of the
  signature, defaults to `NULL`, warns and forwards for one release.
- **Requirement scoped to the `sf` branch.** A pre-rasterized `SpatRaster` `streams` never reaches
  `fl_stream_rasterize()`, so `area_field` is irrelevant there; requiring it unconditionally would
  break two valid calls (`test-fl_valley_confine.R:35, :94`) for no benefit.
- **`fl_stream_rasterize()` keeps `field` and its `"channel_width"` default.** It is deliberately
  generic — it rasterizes precip (`map_upstream`), `stream_order`, and internal seed indices
  (`fl_group_idx`, `fl_seed`). The hazard is the *composition*, addressed with `@seealso` in both
  directions.
- **Downstream docs in scope: soul + this repo.** `soul/conventions/cartography.md:120` publishes
  `flooded::fl_valley_confine(dem, streams)` — the two-argument form this change makes an error —
  and it propagates into every repo's CLAUDE.md (this repo at `CLAUDE.md:273`).

## Call-site sweep (Explore agent, 2026-09-01)

All `fl_valley_confine()` calls in the repo are named-argument; **no positional third argument
anywhere**.

**Passes `field = "upstream_area_ha"`** — `README.md:22`, `R/fl_valley_confine.R:89, :101`
(examples), `R/fl_valley_attribute.R:101` (example), `vignettes/valley-confinement.Rmd` (4 calls),
`vignettes/stac-dem.Rmd` + `.Rmd.orig` (4 each), `vignettes/pars-floodplain.Rmd:229`,
`data-raw/wsg_vignette_data.R:255`, `tests/testthat/test-fl_valley_attribute.R:10, :186`.

**Omits `field`, relying on the `"channel_width"` default** — `tests/testthat/test-fl_valley_confine.R`,
20 calls of which 18 omit it. 13 pass an `sf` streams object (these become the missing-argument
error set); 2 (`:35`, `:94`) pass a `SpatRaster` and bypass rasterization entirely.

**Lockstep hazard:** `test-fl_valley_confine.R:91-101` asserts the `SpatRaster` path equals the `sf`
path. It works today only because `:91` rasterizes on `"channel_width"` *and* the `sf` call uses the
same default. Both sides must move to `"upstream_area_ha"` together or the equality breaks.

**`fl_stream_rasterize(field = "channel_width")` in tests** — `test-fl_stream_rasterize.R`,
`test-fl_cost_distance.R`, `test-fl_mask_distance.R`, `test-fl_flood_surface.R`,
`test-fl_flood_depth.R`, `test-fl_flood_model.R`, `test-fl_patch_conn.R`. These feed channel width
into functions documented as taking upstream area; flagged in
`planning/archive/2026-08-issue-49-bankfull-units/findings.md:60-61` as "#47's defect, deliberately
left alone". Out of scope here except where they compose into `fl_valley_confine()`.

**No `hold/` directory.** `inst/extdata/flood_params.csv` / `fl_params()` carry no `field` row, so
no data change is needed.

## Prior art in this repo

`planning/archive/2026-08-issue-49-bankfull-units/task_plan.md:26` — "**#47 stays a separate issue**
— one breaking change per release." The 0.5.0 units fix deliberately left this one alone and added
the interim roxygen warning at `R/fl_valley_confine.R:14` ("tracked in flooded#47"), which this work
replaces.

## Errors Encountered

| Error | Resolution |
|-------|------------|
