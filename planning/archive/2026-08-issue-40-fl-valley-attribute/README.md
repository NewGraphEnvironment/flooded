# fl_valley_attribute() — per-watercourse floodplain attribution (#40)

**Outcome:** shipped `fl_valley_attribute()`, which takes a finished `fl_valley_confine()`
delineation and returns one overlapping `sf` row per stream group, so "where is the Morice River's
floodplain?" is answerable and a field point can be tested against a single watercourse. The
delineation is never recomputed — grouping changes relabel without moving a boundary. The mechanism
was chosen on measurement: per-group VCA runs disagree with the whole-network run in both directions
(510 cells present in a group run and absent from the full run, 22 the reverse), so approach B would
have made "the Morice floodplain" depend on what else was in the run. Coverage is total by
construction via a nearest-group fallback, because `fl_valley_confine()` adds cells after
intersecting its masks — waterbodies orphan 1,643 cells (3.0%) on the bundled tile with no spatial
filter at all.

**Reviews earned their keep.** A concurrent Plan agent returned 19 findings (`review-40.md`),
independently confirming the waterbody coverage hole and killing two tests that were vacuous —
`gnis_name` and `blue_line_key` are a bijection on the test tile, so the "grouping invariance" test
would have passed for any implementation. Three code-check rounds (`review-round{1,2,3}.md`) found
4 + 3 + 2 issues; round 2 found a bug *inside* round 1's fix, and round 3 converged and named the
mechanism — renaming an `sf` column by position — which turned up a latent corrupt-`sf` bug in
`fl_valley_poly()` on an empty delineation. An internal assert on the return path now closes that
family.

**Also filed:** #41 — `fl_cost_distance()` seeds every zero-friction cell, not just stream cells.
Pre-existing, deliberately not fixed here because it changes VCA output on any DEM with exact zeros.

**Driver half:** NewGraphEnvironment/floodplains#40, body updated with the shipped API and the
measurement that rules out per-group runs.

**Closing commits:** `74a7919` (implementation), PR to follow. 233 tests green;
`R CMD check` 0 errors / 0 warnings / 1 pre-existing NOTE (`pkgdown/` at top level).
