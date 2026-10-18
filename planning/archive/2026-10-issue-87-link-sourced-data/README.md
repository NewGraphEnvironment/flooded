# #87 — Build the bundled and vignette data from link-built tables, not bcfishpass

## Outcome

The bundled test streams and the Parsnip vignette streams now come from link's `default`
configuration (`fresh_default`), with upstream area and precipitation joined from fwapg, and ship
link's column names and types (`id_segment`, logical `spawning`/`rearing`, plus
`linear_feature_id` and `watershed_group_code`). Both data-raw scripts pin the link modelling run
*and* the recompute that later rewrote access and mapping codes, stop before writing when either
has moved, and record the fwapg state they read. The Parsnip context layers were carried over from
the previous gpkg (the shared database was unreachable; the user chose this), with per-layer
provenance. NOTICE goes per attribute and keeps a scoped bcfishpass ODbL credit, because link's
default config applies bcfishpass's override tables, which the plan review found and the issue had
assumed away. Durable facts: [`research/bundled_stream_data.md`](../../../research/bundled_stream_data.md).

## Measurement

- **Bulkley test reach:** same 50 segments and geometry; `map_upstream` differs on 28 of 50
  (−17 to +1 mm); one access value 1 → 2. Every pinned test number held. The bundled floodplain
  moves by one cell (28,727 → 28,726) and the README example is unchanged.
- **Parsnip:** 9,386 segments against 8,436 (2,313.6 km against 2,310); floodplain
  40,888.2 → 40,969.3 ha (+0.20%) on a byte-identical DEM.
- **stac-dem cache:** `n_10m` 28,727 → 28,726, lidar counts −0.04%; shares unchanged.
- **Stale claims corrected, stale before #87:** the overlap ratio (2.28 / 2.21, not ~2.4 / 2.45x),
  the fallback share (5.4%, not 3.0%) and the vignette's reach length (5.31 km, not ~8).
- **fwapg lookup gap:** 160,877 of 4,699,005 segments have no `fwa_streams_watersheds_lut` row,
  so 8 Parsnip segments ship NA area (fwapg#33).
- **Review:** plan review, then code-check over 4 rounds. Rounds 2–4 each found a defect inside an
  earlier fix, in the data-raw scripts' failure and provenance paths: dropped context layers,
  deletion before guards, origin from the wrong record, an unpinned recompute. The mechanism was
  named "provenance by proxy"; the loop ended on round 4's enumeration of every write and
  provenance field, with each fix proven by harness (findings.md has the A/B runs, including one
  harness that tested nothing and was redone).

Closed by: PR for branch `87-build-the-bundled-and-vignette-data-from`
