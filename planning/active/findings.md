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

Measured on bundled Bulkley data, grouping by `gnis_name`. The exact call matters — recording it
so the numbers stay falsifiable, because bare `fl_valley_confine(dem, streams)` gives 16,268 cells,
not 53,635:

```r
precip_r <- fl_stream_rasterize(streams, dem, field = "map_upstream")
valleys  <- fl_valley_confine(dem, streams, field = "upstream_area_ha", precip = precip_r)
```


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

## Coverage guarantee — as first stated it was FALSE

The original argument: every valley cell belongs to >=1 group. A valley cell passed the global criteria, so its nearest
seed is within `max_width/2` and its global cost is under threshold; that seed belongs to some group
`g`, and cost from `g`'s seeds alone reproduces the global cost exactly (the min over a subset
containing the argmin equals the global min).

The premise is wrong for real `fl_valley_confine()` output. That function returns the mask
intersection **plus** morphological cleanup, the channel buffer, and waterbodies — and waterbodies
get no spatial filter at all (`fl_valley_confine.R:213-220`), so a lake can sit outside every
group's distance and cost thresholds. Measured with `inst/testdata/waterbodies.gpkg`:

```
valley cells   orphans under the strict criteria
53,635         0        # no waterbodies
55,345         1,643    # + waterbodies            -> 3.0% orphaned
```

Cleanup does it too, but only where the thresholds bind — at `cost_threshold = 300`, 56 cells
(0.53%); at defaults on this tile, 0. So a coverage test written only at defaults passes for the
wrong reason.

Resolution: `complete = TRUE` (default) assigns leftover valley cells to the group with the nearest
streams, so coverage holds by construction rather than by an argument about an input the function
does not control. The count is reported and exposed as `attr(x, "fl_fallback_cells")`.
`complete = FALSE` exposes the strict cover for testing.

## Performance baseline (bundled tile, 648x800 = 518,400 cells)

- `fl_valley_confine()`: 1.36 s
- `fl_cost_distance()`: 0.13 s
- `fl_valley_attribute()` by `gnis_name` (k=5): 0.74 s — cheaper than the delineation itself

The saving comes from the corridor crop, and it shrinks as a group's bounding box approaches the
full grid. On this tile the crops are already 39-74% of the grid, and a long sinuous mainstem is the
worst case — the Morice's bbox is close to its whole AOI. k=340 by `blue_line_key` on a 27M-cell
raster is therefore NOT claimed; it needs measuring on a production tile before the driver leans on
it.

## Crop margin is an approximation, not a bound

Per-group cost on a bbox+margin crop vs the full grid, unnamed-group streams:

```
margin = 1000 m (= max_width/2) : 200 corridor cells differ, max delta 216.9 cost units
margin = 2000 m (= max_width)   : 0 cells differ
```

Least-cost paths really are truncated at `max_width/2`. No finite margin is a bound in general —
across near-flat ground a detour of arbitrary length costs arbitrarily little. Hence `crop_margin`
is an argument (default `max_width`) documented as an approximation.

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

## Pre-existing bug found during review — filed as #41, not fixed here

`fl_cost_distance()` sets stream cells to 0 and calls `costDist(target = 0)`, so **every** cell whose
friction is exactly 0 becomes a seed, not just stream cells — and the roxygen claims otherwise. On a
synthetic grid a flat patch 380 m from the only stream cell reported cost 0 instead of ~1400.

The bundled DEM hides it (0 cells exactly zero; min slope 1.42e-14), but hydro-flattened or
integer-metre DEMs do not. It matters more under attribution than under the global VCA: a flat patch
is a free zero-cost source for whichever group's crop contains it, so cost stops discriminating
between groups exactly where floodplains are. Filed as #41 because the fix changes VCA output on
affected DEMs and deserves its own diff.

## Unrelated defect noticed (not fixed on this branch)

`vignettes/valley-confinement.Rmd` uses `\@ref(fig:...)` in 8 places. Under `bookdown::html_vignette2`
these do not resolve — the live site renders literal text:

```
<p>Burn the stream network onto the DEM grid (Figure @ref(fig:plot-dem))
```

Confirmed against https://newgraphenvironment.github.io/flooded/articles/valley-confinement.html on
2026-08-27. Pre-existing and out of scope here (surgical changes); wants its own issue. The new
section added by this branch uses natural language instead.
