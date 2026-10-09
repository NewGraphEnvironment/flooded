# Task: fl_flood_depth() averages every stream's flood level, so small streams lower a big river's floodplain (#68)

## Problem

`fl_flood_depth()` builds the water surface away from the streams as an inverse-distance-squared average (`terra::interpIDW(power = 2, radius = max_width / 2)`). The average runs over **every** stream cell within 1 km, whatever stream it belongs to. Each stream cell's level comes from `fl_flood_surface()`: bed elevation + `flood_factor` × bankfull depth, which scales with upstream area.

So a spot between a big river and a small creek gets a weighted blend of a deep flood and a shallow one, with the nearer stream counting more. Real floods don't blend; the higher one wins. A spot is wet if either stream floods it, and at a confluence the big river backs water *up* the tributary. Both of the things the floodplain is meant to represent say the blend is wrong:
- extreme-event extent;
- the channel migration zone, which is set by the big river working across its own valley floor.

**Measured symptom (floodplains#110, MORR `co_ff04`, one common DEM):**
- Delineating from all streams instead of the coho network gains a lot of floodplain but also **loses 452 ha (1.3%)** of the coho network's floodplain.
- Order ≥ 2 loses 444 ha.
- Floodplains are not monotone in their seeds. With a max-of-surfaces model they would be, apart from waterbody and hole-filling effects.
- Evidence: floodplains `scripts/floodplain_lcc/logs/20261009_floodplain_probe-whole-fwa_morr.md` (pairs `1_vs_5`, `2_vs_5`), and the hillshade panels in `~/Projects/repo/floodplains/data/morr/probe_whole_fwa/` on m1. Grey cells inside the bypass outline in `panel_bypass_1.png` are floodplain lost when streams were added.

**The bias is not new.** Today's species-network floodplains already blend each order-3 tributary into its mainstem. Adding small streams only makes it larger.

## Plan context (from plan-mode exploration)

`fl_flood_depth()` (R/fl_flood_depth.R:68-71) drapes the waterline with one
`terra::interpIDW(power = 2, radius = max_width / 2)` over **every** stream cell. A small creek
crossing a big river's valley floor pulls the river's waterline down, so adding seeds can *remove*
floodplain: floodplains#110 measured 452 ha (1.3%) of the MORR coho floodplain lost when all FWA
streams were seeded. Fix candidate: interpolate each watercourse's surface from its own cells and
take the cell-wise maximum. Measure the mechanism first; the issue says to rewrite it if the lost
cells do not sit next to added streams.

Exploration notes that shape the phases:
- Data for step 1 is on this machine (m1): `~/Projects/repo/floodplains/data/morr/probe_whole_fwa/`
  (arm1..5 floodplain/waterbody tifs, `dem_common.tif`). Arm 1 = 6,753 BLKs, whole delineation 169 s.
- Group ids must come from the same segment that set the area value at a shared cell:
  `fl_stream_rasterize()` uses `fun = "max"` on area, so burning `blue_line_key` with `max` would
  mismatch at confluences. Burn groups ordered by area (`fun = "last"` after sorting ascending —
  verify terra honours feature order) or derive from the area winner.
- Every step downstream of the flood mask is monotone in its input (AND of masks; closing, hole
  fill, patch removal, modal are increasing operators), so max-of-surfaces makes the whole run
  monotone in *added watercourses*. Not strictly for a BLK extended upstream (same group gains
  cells), and not for per-order grouping (added streams join an existing order group).
- Risk to measure, not assume: a steep tributary's own IDW is no longer diluted by the river's
  cells, so its upslope reaches can lift the waterline across the valley floor near its mouth
  (over-flooding, the opposite error). Slope + cost masks should contain it; Phase 3 checks gains.
- Cached outputs that will move: `inst/vignette-data/stac_*` (pinned by
  `test-vignette_data.R`), `pars_*` (Parsnip), and prose figures in `inst/notes/` and CLAUDE.md
  (Parsnip ff06–ff04 4.6%, bundled-tile scenario gaps). Prose claiming "interpolates from every
  seed cell": `fl_valley_attribute.R:54`, `methodology.md:118`, `floodplain_interpretation.md:41`.
- Zotero MCP is unconfigured here; lineage check uses the local Zotero PDF + `pdftotext`.

## Decisions taken at the plan gate

- Per-watercourse surfaces are **on by default**: `fl_valley_confine(group_field = "blue_line_key")`; `NULL` opts back into the blend.
- Raster `streams` input: new `groups` SpatRaster argument; absent, fall back to the blend with a warning naming #68.

## Phase 1: Measure the mechanism (read-only on floodplains data)
- [x] Script `planning/active/measure_lost_cells.R`: load arm1/arm5 floodplain on the common grid
      (copies / in memory only — write nothing into `floodplains/data/morr/`)
- [x] Rebuild arm 1 and arm 5 streams via `fp_whole_fwa.R` (`fp_wf_read_network()` +
      `fp_wf_keep()`); added streams = arm 1 segments not in arm 5
- [x] Lost cells = arm 5 floodplain ∧ ¬arm 1; distance of each to the nearest added stream;
      share within 1 km and distance distribution vs the same for all arm 5 floodplain cells
- [x] Split lost cells by cause where computable: in arm-1 waterbody/hole-fill vs flood-surface
- [x] Record in `findings.md` with numbers + units. **Gate:** if lost cells do not concentrate
      near added streams, stop, rewrite the issue body, report — no code phases

## Phase 2: Lineage
- [x] Read Nagel et al. 2014 (RMRS-GTR-321) for how the VCA drapes the flood surface
      (interpolation vs allocation; per-stream or pooled) and what the Python VCA does
- [x] Record verdict in `findings.md`; if the blend is the published method, the fix is a
      documented departure (roxygen @details + `inst/notes/methodology.md`)

## Phase 3: Tests first (fail on main)
- [x] Synthetic grid in `test-fl_flood_depth.R`: big river + small creek crossing its valley
      floor; assert depth with both streams ≥ depth with river alone at every cell (fails today)
- [x] Monotonicity at `fl_valley_confine()` level on bundled data: valleys(all streams) ⊇
      valleys(subset of blue lines), waterbodies off (fails or passes vacuously today — record which)
- [x] `groups = NULL` reproduces current `fl_flood_depth()` output exactly (backward path)
- [x] Group raster at a confluence cell carries the larger-area segment's key

## Phase 4: Implement

> **Halted 2026-10-09 — awaiting user decision.** Per-watercourse max over-floods by +67% to
> +143% on the bundled tile and flattens `flood_factor` (see findings, "Phase 4 — the fix
> over-floods"). The on-by-default decision is disproved; options are with the user.

- [x] `fl_flood_depth(..., groups = NULL)`: `groups` SpatRaster of integer ids on the stream
      cells; per group crop to bbox + `max_width / 2`, IDW from that group's cells, `pmax`-merge
      into one values vector (no per-group full-grid rasters — memory)
- [x] `fl_flood_model()` passes `groups` through
- [x] `fl_valley_confine(group_field = "blue_line_key")`, **on by default** (`NULL` = old blend):
      rasterize group ids consistently with area (see Context); missing column errors naming it
- [x] Raster path: new `groups` SpatRaster argument on `fl_valley_confine()`; raster `streams`
      without `groups` falls back to the single-surface blend with a warning naming #68
- [ ] Timing on MORR arm 1 vs the 169 s delineation; if per-BLK cost is unacceptable, measure the
      per-order variant and record the monotonicity it gives up
- [ ] `devtools::document()`, lintr, `pkgdown::check_pkgdown()`

## Phase 5: Re-measure and results change
- [ ] Re-run arms 1 and 5 on MORR in scratch: lost cells (expect ~0 apart from waterbody /
      hole fill), and floodplain *gained* near tributary mouths (the over-flooding check)
- [ ] Re-run `data-raw/stac_dem_vignette_data.R` (10 m cell counts) and update
      `test-vignette_data.R` pins; re-run `data-raw/wsg_vignette_data.R` (Parsnip)
- [ ] Recompute stale prose numbers (bundled-tile scenario gaps, Parsnip gap) by measurement
- [ ] Update roxygen @details, `methodology.md` (seeds paragraph + new section), 
      `floodplain_interpretation.md` step 4, `fl_valley_attribute.R:54`, CLAUDE.md design decision
- [ ] NEWS entry (results change; floodplains re-runs to pick it up; pair with flooded#67)

## Validation
- [ ] Tests pass
- [ ] `/code-check` clean (each commit, or once over the branch with `/code-check branch`)
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
