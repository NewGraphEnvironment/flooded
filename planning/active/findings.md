# Findings — fl_flood_depth() pools every stream's flood level; max-per-watercourse fix over-floods, needs drainage-based ownership (#68)

## Issue context

**Status (2026-10-09):** the mechanism is confirmed, but the candidate fix (one surface per watercourse, keep the highest) was built, measured and **rejected**. It roughly doubles the floodplain and makes `flood_factor` nearly irrelevant. No code has changed. The next candidate is drainage-based ownership (below). Measurements and the rejected implementation: PR for #68, `planning/archive/2026-10-issue-68-flood-surface-blend/` (implementation at commit d71bbb5).

## Problem

`fl_flood_depth()` builds the water surface away from the streams as an inverse-distance-squared average (`terra::interpIDW(power = 2, radius = max_width / 2)`). The average runs over **every** stream cell within 1 km, whatever stream it belongs to. Each stream cell's level comes from `fl_flood_surface()`: bed elevation + `flood_factor` × bankfull depth.

So a spot between a big river and a small creek gets a weighted blend of a deep flood and a shallow one. A creek crossing a big river's valley floor pulls the river's waterline down around itself, and adding streams to a run can **remove** floodplain.

**Measured symptom (floodplains#110, MORR `co_ff04`, one common DEM):**
- Delineating from all FWA streams instead of the coho network loses **451.9 ha (1.27%)** of the coho network's floodplain. That reproduces exactly on flooded main.
- Order ≥ 2 loses 444 ha.

## What was measured

**1. The blend is what loses the ground.** Slope doesn't depend on the streams, and the distance and cost masks only loosen as streams are added. So a lost cell is dropped either by the flood mask or by cleanup. Recomputing the flood mask for both networks:
- **78.6%** of the lost cells are wet with the coho streams and dry with all streams.
- Only 4.8% survive the all-streams run's pre-cleanup masks.
- Over the whole grid, 1,256 ha of flood-mask cells go from wet to dry when streams are added.
- The coho flood depth on the lost cells has a median of 2.2 m, so these cells are not marginal.

The diagnostic first proposed here, "do the lost cells sit next to added streams", **cannot separate the cases**. The added network is dense enough that the median floodplain cell is already 185 m from an added stream, and the lost cells' median is 213 m.

**2. Lineage.**
- Nagel et al. (2014) set the flood height "for each stream segment" and do not say how neighbouring segments' heights combine laterally.
- The Python VCA (BlueGeo, carried in bcfishpass `valley_confinement.py`) pools every stream cell into one `scipy griddata` interpolation.
- So the blend is inherited from the Python port, not from the published method.

**3. The candidate fix over-floods.** It was implemented as per-`blue_line_key` IDW surfaces merged by cell-wise max, with confluence cells shared by every watercourse that crosses them. It passed every property test, including "adding a blue line never removes floodplain". But the extent (bundled tile, valley cells):

| flood_factor | pooled (today) | max per blue line | max per stream order |
|---|---|---|---|
| ff2 | 18,543 | 45,101 (+143%) | 37,209 (+101%) |
| ff4 | 23,192 | 46,758 (+102%) | 40,610 (+75%) |
| ff6 | 28,727 | 48,027 (+67%) | 43,764 (+52%) |

- **Per-blue-line ff2 exceeds today's ff6.** The extent is set by where the tributaries sit, not by flood height.
- **The steep tributaries win all the gained ground, not the Bulkley.** Each tributary's own waterline, carried from its steeper upper reach (17–43 m/km), sits metres above the Bulkley's valley floor beside it. Median depth on the gained cells is 4.9 m.
- **IDW's reach is not the main cause.** With each tributary's nearest-cell level instead of IDW, 72% of the gain stays wet.
- **Per-order grouping does not avoid it.**

**So the pooled blend has two errors that partly cancel:**
- it lowers a river's waterline near small streams (the 1.3% loss above);
- it hides steep tributaries carrying their waterline sideways onto the mainstem floor, which is a much larger effect.

Removing the first error exposes the second. Any fix has to handle both.

## Next candidate: drainage-based ownership

A cell takes the waterline of the stream it *drains to*, not of every stream within 1 km. A Bulkley valley-floor cell then gets the Bulkley's level, even beside a tributary mouth. Ground on a tributary's own fan gets the tributary's level. This is HAND-style (height above nearest drainage) assignment, a different interpolation domain rather than a tweak to the IDW.

**Acceptance for any fix:**
- Monotone in added watercourses on the bundled tile. The test from the rejected implementation (d71bbb5) can be reused.
- `flood_factor` ordering and sensitivity preserved: ff2 < ff4 < ff6, with gaps of the same order as today's.
- Bounded change against today on fixed streams: report the bundled tile, MORR arm 5 and the Parsnip A/B, not just arm 1 vs arm 5.
- An audit of gained cells covering which stream owns each cell, the depth, and the height above the owner's bed.

A rejected mitigation, for the record: "no flooding below the group's own bed at its nearest cell" brings the ff6 gain down to +21%. But it loses 7,067 cells the blend had, so it is not a drop-in fix.

**Results change:** only once a fix passes the acceptance above. Then add a NEWS entry, and have floodplains re-run, timed with flooded#67.

Relates: floodplains#104, floodplains#110, flooded#67, flooded#40.

## Errors Encountered

| Error | Resolution |
|-------|------------|

## Phase 1 — Can a conditioned D8 path reach the streams? (2026-10-09)

Scripts and logs: `measure_drainage_reach.R/.log`, `measure_drainage_window.R/.log` (this
directory). Bundled tile; reference set = today's 28,727 valley cells (`upstream_area_ha` +
precip, ff6). "Reached" = some cell on the D8 path lies in the 3x3 window of a stream cell.

| conditioning | valley cells reached | time |
|---|---|---|
| raw `terra::terrain(v = "flowdir")` (3,932 code-0, 8.5% cyclic) | 29.2% | <1 s |
| raw WBT D8, no conditioning | 17.8% | <1 s |
| WBT breach least-cost, dist 10 cells (+fill) | 67.9% | 1.3 s |
| **WBT breach least-cost, dist 50 cells (+fill)** | **79.1%** | 4.2 s |
| WBT breach least-cost, dist 200 cells (+fill) | 68.0% (11,627 code-0 cells) | 8.3 s |
| WBT fill depressions (fix_flats) | 67.1% | 0.9 s |

Rejected without a number: `terra::flowDir()` (experimental) did not finish in 10 min on 518k
cells; `terra::pitfiller()` (experimental PEM4PIT) was killed by a 15 min timeout. Stream burning
(5-50 m) moved raw D8 from 29% to <=30% and would make flow directions depend on the streams,
which breaks monotonicity.

**The gate as written (>= 90%) fails at 79.1%, and the misses are not what the gate was for.** It
was meant to catch D8 paths missing streams through misalignment or diagonal leaks. That is not
what happens:
- Widening the window barely moves it: 79.1% at 10 m, 79.3% at 50 m, 79.5% at 100 m.
- **Every one** of the 5,991 missed valley cells drains off the tile edge, never within 15 m of a
  seeded stream.
- The missed cells are themselves a median **582 m** from a stream. Pooled IDW wets them because
  its 1 km radius reaches across the valley.

These are cells whose drainage leaves the bundled tile before meeting a seeded stream (down-valley
swales and side drainage running parallel to the river), so the bundled tile is a worst case. On a
watershed-clipped DEM (MORR, a WSG) every path reaches the outlet through the network. Re-measure
there in Phase 4 rather than assume it. Decision: proceed; window 3x3; breach dist 50 cells.

WBT ESRI pointer convention confirmed on synthetic planes: east-falling 1, south-falling 4,
northeast-falling 128; NA DEM gives an NA pointer, and neighbours do not point into it.
