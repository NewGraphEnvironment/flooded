# Findings — fl_valley_attribute() (#40)

## Why attribution rather than per-group VCA runs (measured 2026-08-27)

Of the four criteria in `R/fl_valley_confine.R:140-160`, only the slope mask is independent of which
streams are supplied:

| step | depends on stream set? | effect of dropping tributaries |
|---|---|---|
| slope mask | no | — |
| distance mask (`max_width/2`) | yes | corridor shrinks to the mainstem |
| cost distance | yes | more seeds can only lower cost, so a subset's cost is >= |
| flood model | yes | IDW interpolates the surface from *all* seed cells (`fl_flood_depth.R:68-80`) |
| cleanup (patch removal, hole fill) | yes, globally coupled | a sub-`size_threshold` patch may survive when merged |

Measured on bundled Bulkley data, grouping by `gnis_name`:

```
FULL network:              53,635 cells (536.4 ha)
  Bulkley River            37,837   |    0 cells outside the full run
  Cesford Creek            20,169   |  127 outside (0.6%)
  Richfield Creek          25,436   |  318 outside (1.3%)
  Robert Hatch Creek       12,789   |  274 outside (2.1%)
  unnamed                  17,885   |   28 outside (0.2%)
UNION of per-group runs:   54,123   |  510 cells in a group run but NOT in the full run
                                    |   22 full-run cells in no group run
```

Two conclusions:

1. Per-group runs are not a decomposition of the whole-network run — they disagree in both
   directions, worst on small tributaries (Robert Hatch 2.1%). "The Morice floodplain" would depend
   on what else was in the run. This is the argument against floodplains#40's approach B.
2. Per-group areas sum to 1,141 ha against a 536 ha whole (2.1x). Confluence overlap is large, not a
   thin seam — it must be represented, not resolved away.

## Coverage guarantee

Every valley cell belongs to >=1 group. A valley cell passed the global criteria, so its nearest
seed is within `max_width/2` and its global cost is under threshold; that seed belongs to some group
`g`, and cost from `g`'s seeds alone reproduces the global cost exactly (the min over a subset
containing the argmin equals the global min). Hence no orphans — provided the corridor crop is large
enough to contain the least-cost path, which the crop-safety test pins down.

## Performance baseline (bundled tile, 648x800 = 518,400 cells)

- `fl_valley_confine()`: 1.36 s
- `fl_cost_distance()`: 0.13 s

Test suite stays fast; no `skip_on_ci()` needed. (Note the convention that `skip_on_cran()` does not
skip on CI — `NOT_CRAN=true` is set there.)

## Field requirement driving the output shape

The need is to filter polygons by watercourse and click a point to see whether it is in the Morice.
Overlapping per-group rows with the key column deliver both: an identify in the confluence band
returns both rows, and an attribute filter toggles a watercourse. The Morice polygon terminating
where the Morice mainstem does is what gives the longitudinal "within vs upstream of" boundary the
sampling frame needs.

## Deferred — not built here

- **Primary / contested split** — splitting each group's polygon into "primary" and "shared" parts.
  The overlapping cover already answers the field question by filter-and-click; add only if a
  sampling design needs a hard partition.
- **Converging `subset` / `break_points.csv` with this grouping abstraction** — driver-side, raised
  in floodplains#40's design notes, a separate decision.

## Unrelated defect noticed (not fixed on this branch)

`vignettes/valley-confinement.Rmd` uses `\@ref(fig:...)` in 8 places. Under `bookdown::html_vignette2`
these do not resolve — the live site renders literal text:

```
<p>Burn the stream network onto the DEM grid (Figure @ref(fig:plot-dem))
```

Confirmed against https://newgraphenvironment.github.io/flooded/articles/valley-confinement.html on
2026-08-27. Pre-existing and out of scope here (surgical changes); wants its own issue. The new
section added by this branch uses natural language instead.
