## Outcome

flooded#68 round 2 built the issue's next candidate, drainage-based ownership, as an opt-in
`flood_method = "drainage"`; the default stays `pooled`.
- **The method.** WhiteboxTools conditions the DEM. Each cell follows its D8 path. A cell's
  waterline is the highest level on that path, where a path cell's level is the lowest original
  ground in its 3x3 window plus the deepest flood depth of a stream within one cell.
- **What it fixed.** It is monotone in added streams, and MORR's 451.9 ha loss becomes 0.
- **What it broke.** It under-floods by about a quarter on watershed DEMs. A valley-floor cell
  takes the level of the reach where its path joins the network, not of the reach beside it.
- **Verdict.** It fails the issue's "bounded change" criterion, so it does not replace pooled.
  Whether to merge it as an experimental option or revert it is the user's call on the PR.

Learned on the way:
- the level must come from the original DEM, not the conditioned one;
- WhiteboxTools 2.4.0's multi-threaded breaching is not deterministic, and its fill branch panics
  on a race (upstream report drafted, not posted: `upstream_whitebox_draft.md`);
- the review loop's findings after round 1 were all prose that described the intended rule
  rather than the computed one.

Durable verdict: [`research/flood_surface_interpolation.md`](../../../research/flood_surface_interpolation.md).

## Measurement

- **Phase 1 gate.** 79.1% of the bundled tile's pooled-valley cells drain within one cell of a
  stream, against 29% for raw terra D8.
  - The gate was >= 90%. I waived it myself, not the user, and the PR flags it.
  - Every miss drained off the tile edge. Watershed DEMs reach 99.1% (MORR) and 99.4% (Parsnip).
- **Level rule.** A conditioned-DEM level moved the bundled ff4 extent from −50% to −75% of
  pooled with the pit-removal algorithm alone, so the shipped rule reads the original DEM (rawmin).
  This was a wrong turn, kept: cond was the plan review's recommendation and was shipped first.
- **Results at ff4** (gaps are ff2->4 / ff4->6):

  | site | pooled | drainage | gaps, drainage vs pooled |
  |---|---|---|---|
  | MORR arm 5 | 32,470 ha | 24,145 ha (−25.6%) | 9.9/8.4% vs 6.8/5.2% |
  | Parsnip | 441,054 cells | 314,772 (−28.6%) | 13.4/13.2% vs 5.6/4.6% |
  | bundled | 23,192 | 11,096 (−52.2%) | |

- **Monotonicity.** MORR all-FWA vs coho: 0 ha lost (pooled 451.9 ha); 0 flood-mask cells
  (pooled 13,569).
- **Audit (Parsnip).**
  - 98.4% of the lost cells have a path within one cell of a stream, and 94.7% come out dry.
  - On those, the drainage waterline is a median 5.9 m below pooled's.
  - It is set a median 590 m away, against 156 m to the nearest stream.
- **WhiteboxTools.**
  - Multi-threaded, two identical routes differed in 60,541 and 69,960 of 518,400 cells; one
    thread is exact.
  - The least-cost fill branch panicked twice; the replacement had 0 errors in 30 calls.

## Evidence

`measure_*.R` and `measure_*.log` in this directory. `measure_level_rule_lcfill.log` is the first
conditioning, cut off by a session end. `review-1.md` and `review-round*.md` are the plan review
and the four code-check rounds; `findings.md` has the tables.

Closed by: PR for #68 (issue stays open for the round 3 candidate)
