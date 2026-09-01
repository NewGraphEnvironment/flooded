# #49 — Bankfull regression fed hectares and mm where Hall 2007 specifies km2 and cm/yr

`fl_flood_surface()` passed hectares (`upstream_area_ha`) and millimetres (`map_upstream`) into
verbatim Hall et al. (2007) coefficients that take drainage area in km2 and mean annual
precipitation in cm/yr. Bankfull width was 8.2224x too large and depth 3.5926x too large in every
result the package had ever produced, so the shipped `ff02` / `ff04` / `ff06` were really 7.19 /
14.37 / 21.56 times bankfull depth. Fixed by converting inside the function; scenario values stay
at 2 / 4 / 6 because they came off the literature ladder to begin with and now finally behave as
labelled. `precip` gained a `NULL` default, since a literal `1` read as millimetres scales depth by
0.6089 rather than 1.

Area cost is dataset-dependent, not a fixed ratio — the error only reaches the boundary where the
flood mask is the binding criterion. Roughly half the extent on the bundled 10 m tile; ~15% on
MRDEM-30, where slope and cost bind first. Every corrected run is a strict subset (0 cells gained).

Three things worth carrying forward:

1. **Nagel's combined form cannot be a units oracle.** `h_bf = 0.054 A^0.170 P^0.215` is an
   algebraic identity of the two-step form, so it agrees in any units. The guard had to be a hard
   literal computed from the published equation.
2. **The as-coded baseline came from the fixed code**, by pre-scaling inputs (area x100, precip x10)
   so the new conversion cancels — no hand-rewritten "previous version" that could differ from the
   real one. It reproduced the documented figures and the shipped artifact exactly (521,028 cells,
   0 difference).
3. **Round 3 caught a fix that was itself wrong.** Round 2 flagged a "1.95x" ratio as stale; the
   correction to 1.99x changed the basis (both streams at 531 mm) rather than fixing an error —
   1.95 was right on each stream's own precipitation, and the ratio is units-invariant either way.

Closed by PR on branch `49-bankfull-regression-is-fed-hectares-and`; released as 0.5.0.
