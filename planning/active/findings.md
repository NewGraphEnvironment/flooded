# Findings — fl_flood_depth() averages every stream's flood level (#68)

## Issue context

**If we do it:** each spot's flood level is set by the stream that floods it highest, not by a blend of every stream within 1 km. Adding small streams then only adds floodplain around those streams and never takes ground away from a big river. A whole-network floodplain contains a species-network one.
**If we never do:** a small creek crossing a big river's valley floor pulls the river's flood level down around itself, and ground the river would cover comes out dry. The more small streams are seeded, the bigger the error. That is exactly the direction floodplains#104 is heading.

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

## Proposal

1. **Measure first.** On the floodplains#110 outputs, already on one grid:
   - take the cells in arm 5 and not in arm 1;
   - measure how many lie within 1 km of an added (non-coho) stream, and how far they are from it;
   - compare against the same shares for arm 5's floodplain as a whole.

   If the lost cells concentrate next to added small streams crossing big valley floors, this mechanism is the explanation. If they don't, something else (hole filling, morphology, waterbodies) is, and this issue should be rewritten.
   **Data for step 1** (on m1 only; the files are gitignored in floodplains, not in any PR):
   - **Rasters:** `~/Projects/repo/floodplains/data/morr/probe_whole_fwa/`. They are
     `arm1_floodplain.tif` … `arm5_floodplain.tif` (1 = floodplain, 0/NA = not),
     `arm<k>_waterbody.tif` and `dem_common.tif`. All are on one grid (~30.43 m, EPSG:3005), so
     cells compare directly.
   - **Arms:**
     - 1: every segment of `fresh.streams` in MORR (58,613 segments, 9,033 km);
     - 2: order ≥ 2;
     - 3: order ≥ 3;
     - 4: order ≥ 3 + first-order with `stream_order_parent >= 5`;
     - 5: the coho network (`access_co IN (1, 2)`, order ≥ 3), the baseline.

     "Added streams" for this test are arm 1's segments not in arm 5.
   - **Each arm's streams:** source
     `~/Projects/repo/floodplains/scripts/floodplain_lcc/fp_whole_fwa.R`, then
     `all <- fp_wf_read_network(conn, "fresh", "MORR", "co")` and `all[fp_wf_keep(all, k, 3L), ]`.
     That is one database read with each arm as a filter, the same frame the probe delineated
     from.
   - **Database:** the local fwapg (`fresh-db` docker container on `localhost:5432`).
     - Connect with `DBI::dbConnect(RPostgres::Postgres())`. The `PG*` variables are in
       `~/.Renviron`, which R reads and bash does not.
     - From bash, export them first:
       `eval "$(grep -E '^PG(HOST|PORT|DATABASE|USER|PASSWORD)=' ~/.Renviron | sed 's/^/export /')"`.
   - **Read-only:** write nothing into `~/Projects/repo/floodplains/data/morr/`. Work on copies or
     in memory.

2. **Check the method's lineage.** Find whether the blend mirrors the original VCA (Nagel et al. 2014), or is this package's interpolation choice. If it is the published method, the fix is a documented departure and needs saying so.
3. **Candidate fix: per-watercourse surfaces, then the highest.** Interpolate each `blue_line_key`'s surface separately, from that blue line's own stream cells, and take the cell-wise maximum. Then test the floodplain against the ground as now. `fl_valley_attribute()` already groups by blue line, so the grouping exists. Cost is one IDW per group, bounded by its crop; measure it against floodplains#110's attribution timings before choosing it.
   - A cheaper variant: interpolate per stream order and take the max across orders.
4. **Results change.** Every floodplain gains the ground it was losing, so the change needs a NEWS entry, and floodplains re-runs to pick it up. Time it with flooded#67 (the grid pin) so the republish carries both changes at once.

Relates: floodplains#104, floodplains#110, flooded#67, flooded#40.

## Errors Encountered

| Error | Resolution |
|-------|------------|

## Phase 2 — Lineage of the pooled blend (2026-10-09)

**Verdict: the blend is inherited from the Python port, not from Nagel et al. (2014). Max-of-surfaces
departs from the Python VCA and from this package's own earlier behaviour; Nagel's text is silent on
how the waterline is carried laterally.**

- **Nagel et al. 2014 (RMRS-GTR-321), p. 19, "Variable 2—Flood factor":** *"The flood factor variable
  is multiplied by the predicted bankfull depth to determine the flood height for each stream
  segment. Stream segments are defined by the NHDPlus data model."* p. 20: *"the unconfined valley
  bottom is defined by the 'flooded' area below the elevation where the flooded height intersects
  the valley side slope."* No interpolation, allocation or pooling rule is stated anywhere in the
  report (grep of `pdftotext` output for interpolat/allocation/Euclidean/surface: only unrelated
  hits). The flood height is a **per-segment** quantity; how one segment's height meets another's
  is not specified. The ArcGIS VCA toolbox itself (`VCA_Toolbox.zip`, fs.fed.us) was not read.
  Source: Zotero attachment `TFBBPKGI`, `Nagel_et_al_2014_RMRS-GTR-321.pdf`.
- **Python VCA** (Blue Geosimulation 2020, after `bluegeo/water.py`; carried in bcfishpass
  `model/03_habitat_lateral/valley_confinement.py:485-500`, last change ceda0b5, 2025-01-27):
  pools every stream cell's `DEM + flood depth` and fills the corridor with
  `scipy.interpolate.griddata(..., "linear")` — a Delaunay-linear blend across all streams, the same
  pooling `fl_flood_depth()` does with IDW. So the defect predates flooded; flooded inherited it
  with the method swap (IDW for linear) noted in `fl_flood_depth()`'s @details.
- **Consequence for docs:** state it as a departure from the Python VCA's pooled interpolation, and
  as consistent with Nagel's per-segment flood height (each watercourse floods to its own height;
  where two overlap, the higher wins). Do not claim Nagel prescribes the max — the text does not.
