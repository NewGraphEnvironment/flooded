# Methodology — channel width + flood factor

Scientific reference for the two regressions and the scenario system that drive `flooded`'s outputs. Lives in `inst/notes/` (not `vignettes/`, and not `docs/` which is the gitignored pkgdown build target). The content is dense reference for understanding why the package chooses what it chooses, rather than a how-to for users running pipelines. `inst/` content travels with the installed package and is accessible via `system.file("notes/methodology.md", package = "flooded")`.

Parameter metadata + citations are also surfaced programmatically via `fl_params()`. Research provenance with verified citations: `inst/research/vca_parameter_rationale.md`.

## Channel width — two independent models

`flooded` uses two independent channel-width sources from different regressions. They give different widths for the same stream because they're built for different physical quantities. Users repeatedly ask which to trust — they're not interchangeable.

| Source | Used for | Formula |
|---|---|---|
| **bcfishpass** `channel_width` (Thorley et al. 2021) | `channel_buffer` polygon (DEM correction only) | `exp(0.307) * (area * precip / 100000) ^ 0.458` |
| **VCA / Hall 2007 bankfull regression** | Flood depth modelling in `fl_flood_surface()` | `(area ^ 0.280) * 0.196 * (precip ^ 0.355)` |

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

### Critical: `flood_factor` is DEM compensation, NOT an ecological threshold

Users repeatedly conflate "higher ff = wetter scenario" with "higher ff = larger ecological footprint." It's actually **compensation for DEM coarseness** — same ecology, different multiplier needed at different resolutions.

| DEM resolution | Equivalent `ff` for functional floodplain |
|---|---|
| 10 m | `ff = 3` reasonable |
| 30 m (MRDEM) | `ff = 7` may be needed for equivalent footprint |

### Selecting a scenario

For a watershed: **look at the DEM resolution first, then choose `ff`.** For watershed-scale work on MRDEM-30 (the `fl_dem_aoi()` default), `ff04` is the functional-floodplain default — see the `pars-floodplain` vignette.

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

### See also

- `fl_valley_attribute()` docs — corridor cropping (`crop_margin`) is an approximation, not a bound
- flooded#41 — `fl_cost_distance()` seeds every zero-friction cell; matters more per-group
- flooded#44 — production-scale timing is unmeasured; the k=5 figure does not establish k=340
- NewGraphEnvironment/floodplains#40 — driver-side half (config surface, key column on the gpkg)

## Cross-refs

- Issues: flooded#25 (channel-width clarification), fresh#29 (related, network-side perspective)
- Vignettes: `valley-confinement`, `stac-dem`, `pars-floodplain`
- Source-code anchors: `fl_valley_confine()`, `fl_flood_model()`, `fl_flood_surface()`, `fl_scenarios()`, `fl_params()`
- Soul recipe for this doc: [NewGraphEnvironment/soul#47](https://github.com/NewGraphEnvironment/soul/issues/47)
