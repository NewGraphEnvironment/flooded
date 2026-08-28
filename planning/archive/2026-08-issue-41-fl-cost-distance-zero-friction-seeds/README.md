# Issue #41 — fl_cost_distance() seeds every zero-friction cell

`fl_cost_distance()` documented stream cells as its seed points and did not deliver that: seeds are
encoded by setting stream cells to `0` and calling `terra::costDist(target = 0)`, which matches
*every* zero cell, so any cell whose friction was already exactly zero acted as a free cost source.
Fixed by flooring `friction == 0` to `1e-6` before seeding. Two things changed from the plan under
measurement — the issue's proposed `<= 0` floor would have disabled terra's own rejection of a
negative cost surface, and a first over-correction guard turned out too weak to catch a floor of 1.

The fix strictly removes cells from the cost mask and never adds. On both DEMs this package ships
the delineation is unmoved (bundled 53,635 cells; Parsnip 521,028, with 2,289 cost-mask cells
absorbed by the other three criteria and cleanup) — so no shipped artifact needed regenerating. That
is a property of these datasets, not a guarantee.

Closed by PR #45, released as v0.4.1.
