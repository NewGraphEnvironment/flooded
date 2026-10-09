# Flood surface interpolation: pooled blend vs per-watercourse surfaces

**Verified:** 2026-10-09 · **Issues:** flooded#68 (open), floodplains#110 · **Produced by:**
`planning/archive/2026-10-issue-68-flood-surface-blend/measure_lost_cells.R` (MORR), bundled-tile
runs recorded in that archive's `findings.md`; rejected implementation at commit d71bbb5.

`fl_flood_depth()` carries the waterline sideways with one IDW over every stream cell. That blend
has **two errors that partly cancel**, and a fix for one exposes the other.

1. **It lowers a river's waterline near small streams.** On MORR `co_ff04`, seeding all FWA streams
   instead of the coho network loses 451.9 ha (1.27%) of the coho floodplain. 78.6% of the lost
   cells are dropped by the flood mask itself (wet with coho seeds, dry with all seeds).
2. **It hides steep tributaries' waterlines on the mainstem floor.** Interpolating each
   `blue_line_key` separately and keeping the highest (exactly monotone in added watercourses)
   grows the bundled-tile floodplain by +67% (ff6) to +143% (ff2); per stream order, +52% to
   +101%. Per-blue-line ff2 exceeds pooled ff6, so `flood_factor` nearly stops mattering. The
   gain belongs to the tributaries (17–43 m/km), whose own waterline sits metres above the
   Bulkley's floor; 72% of it survives even with nearest-cell levels instead of IDW.

**Lineage:** Nagel et al. (2014) set flood height per stream segment and are silent on how
neighbours combine; the Python VCA (BlueGeo / bcfishpass `valley_confinement.py`) pools every
stream cell into one `scipy griddata`. The blend is the port's choice, not the published method.

**Do not re-try:** max of per-watercourse (or per-order) IDW surfaces. **Next candidate:**
drainage-based ownership: a cell takes the waterline of the stream it drains to. The acceptance
criteria are in the flooded#68 body.

**A proxy that does not discriminate:** "lost cells sit near added streams" fails on a dense
network (median floodplain cell already 185 m from an added stream). Ask the criterion directly
by recomputing each mask for both seed sets.
