# Flood surface interpolation: pooled blend, per-watercourse maxima, drainage ownership

**Verified:** 2026-10-09 · **Issues:** flooded#68 (open), floodplains#110 · **Produced by:**
round 1 `planning/archive/2026-10-issue-68-flood-surface-blend/measure_lost_cells.R` (MORR) and
that archive's `findings.md`, rejected implementation at commit d71bbb5; round 2
`planning/archive/2026-10-issue-68-drainage-ownership/measure_*.R` with their logs
(bundled tile, Parsnip WSG, MORR).

`fl_flood_depth()` carries the waterline sideways with one IDW over every stream cell (the
default, `method = "pooled"`). That blend has **two errors that partly cancel**, and fixing one
exposes the other.

1. **It lowers a river's waterline near small streams.** On MORR `co_ff04`, seeding all FWA streams
   instead of the coho network loses 451.9 ha (1.27%) of the coho floodplain. 78.6% of the lost
   cells are dropped by the flood mask itself: wet with the coho seeds, dry with all seeds.
2. **It hides steep tributaries' waterlines on the mainstem floor.** Round 1 interpolated each
   `blue_line_key` separately and kept the highest, which is exactly monotone in added
   watercourses.
   - The bundled-tile floodplain grew by +67% (ff6) to +143% (ff2); per stream order, +52% to +101%.
   - Per-blue-line ff2 exceeds pooled ff6, so `flood_factor` nearly stops mattering.
   - The gain belongs to the tributaries (17–43 m/km), whose own waterline sits metres above
     the Bulkley's floor.

## Round 2: drainage ownership (opt-in, `method = "drainage"`)

**The rule.**
- WhiteboxTools conditions the DEM: least-cost breaching, then `BreachDepressions`, single thread.
- Each cell follows its D8 path downstream.
- Each path cell has a candidate level: the lowest original ground in its 3x3 window, plus the
  deepest `flood_factor` x bankfull depth among the stream cells in that window.
- A cell's waterline is the highest candidate level on its path.

**Measured:**

| | pooled, ff4 | drainage, ff4 | gaps ff2->4 / ff4->6, pooled vs drainage |
|---|---|---|---|
| MORR arm 5 (30 m) | 32,470 ha | 24,145 ha (−25.6%) | 6.8/5.2% vs 9.9/8.4% |
| Parsnip WSG (MRDEM-30) | 441,054 cells | 314,772 (−28.6%) | 5.6/4.6% vs 13.4/13.2% |
| bundled tile (10 m) | 23,192 cells | 11,096 (−52.2%; 43% of the loss drains off the tile) | 25/24% vs 60/37% |

- **Monotone, as designed.** Adding every FWA stream to MORR's coho network loses 0 ha (pooled:
  451.9 ha). Exact for every blue line on the bundled tile.
- **But it under-floods by about a quarter.** On Parsnip, 98.4% of the lost cells *do* drain to
  a stream, and 94.7% come out dry under their own waterline.
  - On the dry ones, the waterline comes out a median 5.9 m lower than pooled's.
  - It is set a median 590 m away (straight line) against 156 m to the nearest stream: a cell
    takes the level of the reach where its path joins the network, not the reach beside it.
- **Verdict: not a replacement for pooled.** It passes monotonicity and `flood_factor` ordering
  and fails "bounded change against today". The default stays `pooled`.

**The two rejected candidates bracket pooled from opposite sides for one reason.** Neither has a
rule for *which point along a watercourse* sets a cell's level:
- max-of-IDW takes a tributary's level from its steep upper reach;
- drainage takes it from the downstream junction.

**The level must not come from the conditioned DEM.** Breaching cuts trenches, and a level read
from the conditioned surface moved the bundled ff4 extent from −50% to −75% of pooled with the
pit-removal algorithm alone. A level read from the stream cell's own DEM value ("raw", −7.4% on
Parsnip) carries bed noise upstream through the path maximum: the plan review measured a p90
downstream excess of 7 m on Parsnip.

**WhiteboxTools 2.4.0 traps:**
- multi-threaded `BreachDepressionsLeastCost` and `FillDepressions` are not deterministic:
  36,000–60,000 of 518,400 cells differ between identical runs;
- their fill branch panics intermittently ("Error unwrapping 'output'", an `Arc::try_unwrap`
  race).

## Lineage

Nagel et al. (2014) set flood height per stream segment and are silent on how neighbours
combine. The Python VCA (BlueGeo / bcfishpass `valley_confinement.py`) pools every stream cell
into one `scipy griddata`. The blend is the port's choice, not the published method.

## Do not re-try

- Max of per-watercourse (or per-order) IDW surfaces: over-floods.
- Drainage ownership with the level taken where the path joins: under-floods by about a quarter.
- Any drainage level read from a conditioned DEM.

**Next candidate (unmeasured):** drainage decides *which* watercourses may flood a cell (those
on its downstream path), proximity decides *where* along each (that watercourse's level at its
nearest point to the cell), and the waterline is the max over them. Still monotone.

**A proxy that does not discriminate:** "lost cells sit near added streams" fails on a dense
network (median floodplain cell already 185 m from an added stream). Ask the criterion directly
by recomputing each mask for both seed sets.
