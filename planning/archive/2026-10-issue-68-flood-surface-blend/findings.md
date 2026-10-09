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

## Phase 1 — Is the pooled blend what loses the 452 ha? (2026-10-09)

Script `planning/active/measure_lost_cells.R`, output `planning/active/measure_lost_cells.log`
(flooded main @ 6498d49 via `load_all`, terra 12 threads, MORR `co_ff04`, floodplains#110 probe
rasters on `dem_common.tif`, network from `fp_wf_read_network(conn, "fresh", "MORR", "co")`).

**Reproduced:** arm 5 floodplain 385,021 cells (35,654 ha); 4,880 cells (**451.9 ha, 1.27%**) are
floodplain in arm 5 and not in arm 1 — the issue's 452 ha exactly. Arm 1 = 58,613 segments,
arm 5 = 4,877, added = 53,736.

**The distance signature the issue predicted did not appear.** Lost cells are *not* closer to an
added stream than arm 5's floodplain as a whole (median 213 m vs 185 m; within 120 m: 26.9% vs
35.0%; within 1 km: 100% vs 98.8%). Why that test cannot discriminate here: the added network is
so dense that the median arm 5 floodplain cell is already 185 m from an added stream, and IDW's
radius is 1 km, so every lost cell has added cells in its interpolation window regardless of
distance. The test the issue proposed is a proxy; the criterion itself can be asked directly.

**The direct test confirms the mechanism.** Slope is seed-independent and the distance and cost
masks only loosen as seeds are added, so a lost cell was dropped by the flood mask or by cleanup.
Recomputing the flood mask for both arms:

| lost cells (4,880) | share |
|---|---|
| wet in arm 5's flood mask | 86.9% |
| wet in arm 1's flood mask | 8.3% |
| **dropped by arm 1's flood mask** (wet with arm 5 seeds, dry with arm 1) | **78.6%** |
| kept by arm 1's pre-cleanup mask (slope × distance × cost × flood) | 4.8% |

Over the whole grid, **13,569 flood-mask cells (1,256.5 ha)** are wet with the coho seeds and dry
with every seed — the flood mask alone is not monotone in its seeds, by nearly 3x the floodplain
loss (the rest are removed by other criteria in both arms anyway). Arm 5's flood depth on the lost
cells is not marginal: median 2.16 m, upper quartile 5.41 m — these are cells well under the
river's waterline that the blend pulls dry.

Remaining ~13% of lost cells were not in arm 5's flood mask at all (added to arm 5 by cleanup,
channel buffer or waterbodies), and ~4.8% are lost to cleanup in arm 1 — the "apart from
waterbody and hole-filling effects" residual the issue anticipated.

**Gate: proceed.** The mechanism holds; the issue's proposed *diagnostic* was the weak part. The
issue body gets a Measured section saying so (at PR time).

Flood model timings (whole MORR grid 4,431 x 4,082, single pooled IDW): arm 1 21.6 s, arm 5 8.7 s.

## Phase 3 — Tests written first (2026-10-09)

- **Exact monotonicity needs multi-membership at confluences.** `terra::cells(dem, vect(lines),
  touches = FALSE)` returns exactly the cells `rasterize(touches = FALSE)` burns (1,607 = 1,607 on
  the bundled tile) with the line each came from; 4 cells are shared by two blue lines. Giving a
  shared cell to *every* watercourse that crosses it keeps the run exactly monotone: an added
  watercourse never removes a point from another's interpolation, and the shared cell's surface
  value (from `max` area and `max` precip) can only rise. Assigning each cell to one winner would
  let an added river steal a tributary's mouth cell.
- **Bundled tile fails the superset property on main** (default parameters, no waterbodies):
  dropping one blue line *gains* valley cells — 360873822 (Bulkley mainstem) 12,220;
  360237077 1,753; 360788426 732; 360872999 67; 360765936 0. Flood-mask cells gained by the same
  drops: 13,782 / 2,063 / 907 / 175 / 2.
- **Synthetic creek fixture** loses 46 cells under the pooled IDW (river alone vs river + creek).
- Pins taken on main (6498d49) for the opt-out path: `fl_flood_depth()` on the bundled tile,
  `upstream_area_ha` + precip, ff 6 — 32,178 non-NA, 30,571 > 0, sum 65,162.334854;
  `fl_valley_confine(precip = ...)` 28,727 valley cells.

## Phase 4 — the fix over-floods (2026-10-09)

Implemented as planned (`fl_flood_depth(groups =)`, `fl_valley_confine(group_field =
"blue_line_key", groups =)`, multi-membership via `fl_stream_groups()`). Every #68 test passes,
including the exact superset property for every blue line on the bundled tile. **But the extent it
produces is not defensible**, first reported by the concurrent Plan review and then re-measured on
this implementation (bundled tile, `upstream_area_ha` + precip, defaults otherwise):

| flood_factor | pooled (`group_field = NULL`) | per blue line (max) | per stream order (max) |
|---|---|---|---|
| ff2 | 18,543 | 45,101 (+143%) | 37,209 (+101%) |
| ff4 | 23,192 | 46,758 (+102%) | 40,610 (+75%) |
| ff6 | 28,727 | 48,027 (+67%) | 43,764 (+52%) |

- **Grouped ff2 exceeds pooled ff6**, so `flood_factor` nearly stops mattering: the extent is set
  by where tributaries sit, not by flood height. Flood-mask gain at ff4: 25,799 cells.
- **Reviewer's attribution of the gain (ff6, its own prototype, consistent with the above):** of
  21,863 gained flood-mask cells, 18,651 pass slope x distance x cost, and *all* are won by the
  three tributaries, none by the Bulkley — Cesford Cr 7,345 (surface rises 43 m/km), Robert Hatch
  Cr 6,668 (18 m/km), Richfield Cr 4,638 (17 m/km). Median depth on gained cells 4.9 m (p90 11.6).
  Not mainly IDW reach: with each group's *nearest-cell* level instead of IDW, 72% stay wet.
- **Mechanism:** a tributary's own surface, interpolated from cells up its steeper reach, sits
  well above the mainstem's valley floor beside it. The pooled blend was diluting that with the
  mainstem's many lower cells. So the pooled blend has two errors that partly cancel: it lowers a
  river's waterline near small streams (the #68 loss, ~1.3% on MORR) and it *suppresses* steep
  tributaries projecting their waterline laterally onto the mainstem floor (much larger). Removing
  the first exposes the second.
- **Per-order grouping does not avoid it** (table above).
- Reviewer's tried mitigation, "no flooding below the group's own bed at its nearest cell": ff6
  gain +21% but loses 7,067 cells the blend had — not a drop-in fix.
- **The issue's Proposal 4 premise ("every floodplain gains the ground it was losing") is wrong in
  magnitude**: the gain is ~50-100x the loss.

Full suite on the grouped default: FAIL 4 — `test-fl_valley_attribute.R:114` (pinned against the
pooled delineation) and `test-vignette_data.R:31,41` (stac 10 m cell-count pins). Expected under the
default change; not fixed, pending the decision.
