## Outcome

flooded#68 asked whether `fl_flood_depth()`'s pooled IDW (every stream cell in one interpolation)
is why adding streams removes floodplain, and proposed per-watercourse surfaces merged by maximum.
The mechanism is confirmed. The fix was built and passed every property test, including exact
monotonicity in added blue lines, but it over-floods badly and makes `flood_factor` nearly
irrelevant. The user chose no code: the implementation was reverted (kept at d71bbb5) and the
issue was rewritten around drainage-based ownership as the next candidate. Durable verdict:
[`research/flood_surface_interpolation.md`](../../../research/flood_surface_interpolation.md).

## Measurement

- **MORR `co_ff04` (floodplains#110 rasters):** the 451.9 ha (1.27%) loss reproduced exactly on
  main. 78.6% of lost cells are dropped by the all-streams flood mask; 1,256 ha of flood-mask
  cells go wet to dry when streams are added. This settled the mechanism.
- **A wrong turn, kept:** the issue's proposed diagnostic ("lost cells sit near added streams")
  came back negative (median 213 m vs 185 m for all floodplain). It would have said "rewrite the
  issue". The added network is too dense for distance to discriminate; asking the flood mask
  directly settled it.
- **Rejected fix, bundled tile, valley cells:** pooled 18,543 / 23,192 / 28,727 at ff2/4/6;
  per blue line 45,101 / 46,758 / 48,027 (+143% / +102% / +67%); per order +101% / +75% / +52%.
  Found first by the concurrent Plan review on its own prototype, then re-measured on this
  implementation. Changed the decision from "on by default" to "no code".
- **Lineage:** the blend comes from the Python VCA's pooled `griddata`; Nagel 2014 is silent.

## Evidence

`measure_lost_cells.R` and `measure_lost_cells.log` in this directory; the bundled-tile numbers
and the reviewer's attribution of the gain are in `findings.md`.

Closed by: PR for #68 (no code; issue stays open for the drainage-based candidate)
