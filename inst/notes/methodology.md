# Methodology — channel width + flood factor

Scientific reference for the two regressions and the scenario system that drive `flooded`'s outputs. Lives in `inst/notes/` (not `vignettes/`, and not `docs/` which is the gitignored pkgdown build target). The content is dense reference for understanding why the package chooses what it chooses, rather than a how-to for users running pipelines. `inst/` content travels with the installed package and is accessible via `system.file("notes/methodology.md", package = "flooded")`.

Parameter metadata + citations are also surfaced programmatically via `fl_params()`. Research provenance with verified citations: `inst/research/vca_parameter_rationale.md`.

## Channel width — two independent models

`flooded` uses two independent channel-width sources from different regressions. They give different widths for the same stream because they're built for different physical quantities. Users repeatedly ask which to trust — they're not interchangeable.

| Source | Used for | Formula | Input units |
|---|---|---|---|
| **bcfishpass** `channel_width` (Thorley et al. 2021) | `channel_buffer` polygon (DEM correction only) | `exp(0.307) * (area * precip / 100000) ^ 0.458` | area **ha**, precip **mm** |
| **VCA / Hall 2007 bankfull regression** | Flood depth modelling in `fl_flood_surface()` | `(area ^ 0.280) * 0.196 * (precip ^ 0.355)` | area **km2**, precip **cm/yr** |

**The two formulas do not take the same units, and that mattered.** Until 0.5.0 `fl_flood_surface()`
fed the Hall regression the hectares and millimetres the stream network carries, over-estimating
bankfull depth by **3.5926x** in every result this package produced (flooded#49). `fl_flood_surface()`
now converts internally — callers still pass `upstream_area_ha` and `map_upstream` in mm.

A consequence worth stating: the Hall regression predicts a **fitted index**, not a surveyed
channel. Its widths run well below bcfishpass's — 5.7 m against 31.3 m for the Bulkley — and its
R2 is 0.47. `flood_factor` is what scales that index onto a mapped footprint, which is why the two
rows above are not comparable as width estimates even after the units agree.

### Why the two formulas differ

- **bcfishpass (Poisson)** uses a single exponent on a discharge proxy (`area × precip`)
- **VCA (Hall 2007)** uses independent exponents for area (`0.280`) and precip (`0.355`)

### What each is for

- **bcfishpass width** → a channel polygon for DEM gap-fill at coarse resolutions. The buffer is a coarse-DEM correction, not an ecological feature.
- **VCA regression** → flood depth, a physical-process input to the cost-distance surface

They are not substitutes. Different physical quantities, both needed.

### Order 1 handling

Order 1 streams have `NA` `channel_width` in bcfishpass. `flooded` handles this by:

- Skipping the bcfishpass-derived buffer for these streams
- Still including them in the flood model via stream rasterization

`channel_buffer = FALSE` disables only the bcfishpass-derived buffer; the VCA flood model still runs.

### See also

- `fl_valley_confine()` roxygen `@details` — partial documentation as of 2026-05-13
- flooded#25 / fresh#29 — open issues asking for this distinction to be fully surfaced

## Flood factor scenarios — `ff02` / `ff04` / `ff06`

`fl_scenarios()` ships three pre-defined scenarios. All hold every parameter constant except `flood_factor` so output differences isolate the ecological signal.

| Scenario | `flood_factor` | Ecological footprint |
|---|---|---|
| `ff02` | 2 | Active channel margin (~50-yr flood, Rosgen) |
| `ff04` | 4 | Functional floodplain — recurrent inundation (Hall et al. 2007, calibrated on field-mapped sites) |
| `ff06` | 6 | Valley bottom including terraces (Nagel et al. 2014 recommend `ff = 5–7`) |

These three values are unchanged across the 0.5.0 units fix, because they were chosen from the
literature ladder in the first place. What changed is that they now *behave* as their labels claim.
Before the fix the shipped `ff02` / `ff04` / `ff06` were really **7.19 / 14.37 / 21.56** times
bankfull depth — past Hall's 3, past Nagel's 5–7, and past any defensible reading of "flood".

### Critical: `flood_factor` is DEM compensation, NOT an ecological threshold

Users repeatedly conflate "higher ff = wetter scenario" with "higher ff = larger ecological footprint." It's actually **compensation for DEM coarseness** — same ecology, different multiplier needed at different resolutions.

| DEM resolution | Equivalent `ff` for functional floodplain |
|---|---|
| 1 m lidar | `ff = 2–3` |
| 10 m | `ff = 3` reasonable |
| 25 m TRIM | `ff = 4` |
| 30 m (MRDEM) | `ff = 7` may be needed for equivalent footprint |

### Selecting a scenario

For a watershed: **look at the DEM resolution first, then choose `ff`.** For watershed-scale work on MRDEM-30 (the `fl_dem_aoi()` default), `ff04` is the functional-floodplain default — see the `pars-floodplain` vignette.

**Post-0.5.0 caveat on that default.** With the units corrected, `ff04` on MRDEM-30 sits *below*
Nagel's resolution equivalent of ~7, so it is a conservative functional-floodplain footprint rather
than a centred one. The shipped scenario values and the Parsnip / `restoration_wedzin_kwa_2024` runs
are deliberately left at `ff04` — moving them is a calibration decision for the consuming project,
not something this package should do silently.

**But at 30 m it barely matters, and that is worth knowing before anyone re-runs a watershed.**
Measured on the Parsnip WSG (MRDEM-30, 20.9 Mcell, 8,436 streams, 664 waterbodies):

| run | cells | ha | vs as-coded `ff04` |
|---|---|---|---|
| `ff04` as-coded (the 0.4.1 artifact) | 521,028 | 48,603.1 | 100% |
| `ff04` corrected | 441,054 | **41,142.9** | 84.7% |
| `ff06` corrected | 461,129 | 43,015.6 | 88.5% |
| `ff07` corrected | 469,333 | 43,780.8 | 90.1% |

Corrected `ff04` to `ff07` spans only **6.4%** of area, against a 1.75-fold range in flood depth —
at 30 m the slope and cost-distance criteria bind first and the flood mask is nearly non-binding.
So raising `ff` to chase Nagel's resolution equivalent does **not** recover the old extent: even
`ff07` lands at 90% of the as-coded `ff04`. Every corrected run is a strict subset of the as-coded
one (0 cells gained), so the fix only ever removes ground.

### See also

- `fl_params()` — parameter metadata + citations
- `inst/research/vca_parameter_rationale.md` — research provenance verified via ragnar against source papers
- `pars-floodplain` vignette — Parsnip River Watershed Group worked example on MRDEM-30

## Attributing a floodplain to a watercourse

`fl_valley_attribute()` answers "where is *this river's* floodplain?" by attributing a single
whole-network delineation, not by re-running the VCA per watercourse.

### Why per-group runs are wrong, not merely expensive

Of the four VCA criteria, only the slope mask is independent of which streams are supplied. The
distance mask and cost distance both loosen as seeds are added; the flood model interpolates its
surface from *every* seed cell; and morphological cleanup couples patches globally. So a subset run
is not that subset's share of the whole run.

Measured on `inst/testdata/` (Bulkley), grouping by `gnis_name`:

```
FULL network:              53,635 cells (536.4 ha)
UNION of per-group runs:   54,123   |  510 cells in a group run but NOT in the full run
                                    |   22 full-run cells in no group run
```

> **Cell counts above predate the 0.5.0 units fix** (flooded#49) and were measured with bankfull
> depth 3.5926x too large. Corrected, the same full-network run returns **28,727 cells (287.3 ha)**.
> The per-group union has not been re-measured, so it is left as recorded rather than restated. The
> argument is unaffected either way: it turns on per-group runs disagreeing with the whole-network
> run in both directions, which a uniform change in flood depth does not remove.

Disagreement runs in both directions and is worst on the small tributaries (Robert Hatch Creek,
2.1%). The consequence is not a rounding error: "the Morice floodplain" would depend on which other
streams happened to be in the run.

### Overlap is real and large

Per-group areas sum to 2.1-2.45x the whole on this tile. Near a confluence, ground genuinely belongs
to both floodplains, so the output is overlapping rows rather than a partition. A representation
that assigns each cell to exactly one watercourse discards a lot of real ground, and discards it
worst exactly where sampling designs care most.

### Membership definition

```
member(cell, g) <=> valley(cell)                                  # the delineation, unchanged
                    AND distance(cell, streams_g) <= max_width/2
                    AND cost(cell, streams_g)     <  cost_threshold
```

The flood mask stays global — recomputing it per group is what makes per-group runs unstable.

### Coverage caveat

`fl_valley_confine()` ORs in cleanup, the channel buffer, and waterbody polygons *after* the mask
intersection, and waterbodies get no spatial filter, so those cells can satisfy no group's criteria
— 1,643 cells (3.0%) with the bundled waterbodies. `complete = TRUE` assigns them to the nearest
group; `attr(x, "fl_fallback_cells")` reports how many. An unusually large count is also the signal
that `max_width` / `cost_threshold` do not match the values the delineation was built with.

### Only stream cells seed the cost surface

`fl_cost_distance()` encodes seeds by setting stream cells to zero and calling
`terra::costDist(target = 0)`, which seeds on *every* zero cell. Until 0.4.1 that included any cell
whose friction was already exactly zero, so flat ground acted as a free cost source. Fixed by
flooring `friction == 0` to `1e-6` before seeding (flooded#41).

Flat ground stays cheap to *cross* — the floor accumulates 0.1 over a 100 km path at 10 m against a
default `cost_threshold` of 2500 — it just stops being a *source*. Negative friction is deliberately
not floored, so `costDist()`'s own rejection of a negative cost surface is left intact.

Which DEMs contain exact zeros, and what changes when they do — measured on both datasets this
package ships:

| DEM | exact-zero slope cells | cost mask (`< 2500`) | valley cells |
|---|---|---|---|
| bundled `dem.tif` / `slope.tif`, 10 m | 0 of 45,726 (min 1.42e-14) | unchanged | 53,635 -> 53,635 |
| `pars_dem.tif` (MRDEM-30, 30 m, 20.9 Mcell) | 80 of 10.7 M | -2,289 cells (214 ha), 0 added | 521,028 -> 521,028 |

> This table records what the **0.4.1** `fl_cost_distance()` fix did, measured under the units
> defect that 0.5.0 later corrected (flooded#49). The valley-cell counts are therefore no longer
> current absolute figures. They are left as measured — the finding is about the *change* the #41
> fix produced, and re-stating it against different inputs would not be the same measurement.

Two things worth separating. MRDEM-30 — the package default source — **does** produce exact zeros
at watershed scale, so a small clip returning none is not evidence about the source. And the fix
only ever *removes* cells from the cost mask, never adds, because it can only raise a cost that was
spuriously zero.

But a change in the cost mask is not a change in the delineation. Both shipped datasets come out
bit-identical, because `fl_valley_confine()` intersects cost with slope, distance and flood and then
runs morphological cleanup — enough to absorb all 2,289 Parsnip cells. That is a property of these
two datasets, not a guarantee: wherever cost is the binding criterion (flat terrain, a lax
`slope_threshold`, a large `flood_factor`) the delineation will move.

The 1 m lidar run in `vignettes/stac-dem.Rmd` emits `[costDist] distance algorithm did not
converge`, which is the shape of large zero-cost plateaus — suggestive, not confirmed, since that
vignette is pre-baked and was not re-run.

It matters most under attribution. Cost is what separates one watercourse's floodplain from
another's, so a flat patch inside a group's corridor would spread that group's mask across ground
its own streams never reach — cost failing to discriminate exactly where floodplains are, on flat
ground.

### See also

- `fl_valley_attribute()` docs — corridor cropping (`crop_margin`) is an approximation, not a bound
- flooded#44 — production-scale timing is unmeasured; the k=5 figure does not establish k=340
- NewGraphEnvironment/floodplains#40 — driver-side half (config surface, key column on the gpkg)

## Cross-refs

- Issues: flooded#25 (channel-width clarification), fresh#29 (related, network-side perspective)
- Vignettes: `valley-confinement`, `stac-dem`, `pars-floodplain`
- Source-code anchors: `fl_valley_confine()`, `fl_flood_model()`, `fl_flood_surface()`, `fl_scenarios()`, `fl_params()`
- Soul recipe for this doc: [NewGraphEnvironment/soul#47](https://github.com/NewGraphEnvironment/soul/issues/47)
