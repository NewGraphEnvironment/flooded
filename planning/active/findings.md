# Findings — Bankfull regression units (#49)

## Verified arithmetic (2026-08-31, this session, independent of the issue body)

Computed from the published coefficients directly:

```
width  ha,mm -> km2,cm : 8.2224x
depth  ha,mm -> km2,cm : 3.5926x
ff equivalence: as-coded ff04 == corrected ff14.37
```

Bulkley, 110,337 ha / 531 mm:

| | width | depth |
|---|---|---|
| as coded (ha, mm) | 46.95 m | 1.4998 m |
| corrected (km², cm) | 5.71 m | 0.4175 m |

Every figure in the issue body reproduces exactly.

## Trap 1 — Nagel's combined form cannot be the units oracle

`h_bf = 0.054 A^0.170 P^0.215` is an **algebraic identity** of the two-step form:

```
0.145 * 0.196^0.607 = 0.05393  ~ 0.054
0.280 * 0.607       = 0.16996  ~ 0.170
0.355 * 0.607       = 0.21549  ~ 0.215
```

Confirmed numerically — on km²/cm the two agree to 4 decimals (0.4174 vs 0.4175, rounding in the
published coefficients). Because it is an identity it holds in **any** units, so a test asserting
agreement between the two forms passes for the buggy code exactly as it does for the fixed code.

This is the "fixture that cannot reach the failure mode" class. The oracle has to be a **hard
literal** computed from the published equation with explicitly stated km²/cm inputs.

## Test anchor for Phase 1

Area 10,000 ha (= 100 km²), precip 500 mm (= 50 cm), `flood_factor = 1`:

| | width | depth |
|---|---|---|
| **correct** (km², cm) | 2.8535824338 m | **0.2740248754 m** |
| buggy (ha, mm) | 23.4633718224 m | **0.9844530049 m** |

Separated by 259%. Ratio 3.5926, as expected.

## Trap 2 — the existing suite cannot catch this

- No test file anywhere mentions `bankfull`, `0.196`, `0.280`, `0.355`, `0.145` or `0.607`.
- Every assertion in `test-fl_flood_surface.R` and `test-fl_flood_model.R` is **relational**: NA
  masking, surface > DEM, monotonic in `flood_factor`, `> 100` on a flat synthetic DEM.
- `tests/testthat/_snaps/` is **empty**.

So the units fix changes no existing expectation and would be silently accepted by `R CMD check`.
That is why the defect survived.

Note `test-fl_flood_surface.R` rasterizes `field = "channel_width"` in three of its five blocks —
that is #47's defect, not this one, and is deliberately left alone.

## `precip = 1` default breaks under the conversion

Current default is documented as "the precipitation term drops out" (`1^0.355 = 1`). Read as mm and
converted, `1` becomes 0.1 cm and the multiplier is **0.4416** — so the default would gain a second
silent behaviour change on top of the units fix.

Resolved: default becomes `NULL`, multiplier exactly 1. Any supplied value is mm.

## Precipitation sensitivity — README figure is stale post-fix

Depth ratio with real precip (53.1 cm) vs the term omitted:

| | ratio |
|---|---|
| as-coded | 3.87x (README says "~4x") |
| corrected | **2.35x** |

## Corrected flood stages are physically sensible

At P = 60 cm:

| A (km²) | width | bankfull depth | ff06 flood height |
|---|---|---|---|
| 10 | 1.60 m | 0.193 m | 1.16 m |
| 100 | 3.04 m | 0.285 m | 1.71 m |
| 1,000 | 5.80 m | 0.422 m | 2.53 m |
| 5,000 | 9.10 m | 0.554 m | 3.32 m |

As-coded, that 1,000 km² river got ~9 m at ff06. Note the corrected bankfull *widths* run well below
bcfishpass's independent estimate (5.8 m vs 31.3 m for the Bulkley) — expected, since the VCA
regression is a fitted index that `flood_factor` scales, not a physical channel-width estimate
(Hall's R² = 0.47). Worth stating in the docs, not a blocker.

## Where the defect lives

Exactly one place: `R/fl_flood_surface.R:72-81`. Roxygen restates the formulas at `:24-26`.

`fl_flood_model()` and `fl_valley_confine()` only pass through, but both carry `precip = 1` defaults
that must move with it.

## Documentation ledger — three docs at three states of truth

| file | state |
|---|---|
| `inst/research/vca_parameter_rationale.md:28` | **correct** — states km²/cm, never mentions ha/mm |
| `inst/notes/floodplain_interpretation.md:88-96` | correct, and flags the bug as pending |
| `inst/notes/methodology.md:14` | states the formula with **no units at all**, silent about #49 |

`methodology.md` is the one that reads as wrong once the code is fixed. It also quotes live cell
counts (53,635 / 521,028) that will move.

## Downstream consumers found

- `floodplains/scripts/floodplain_lcc/02_floodplain_model.R` — the driver; `run_region.R:57` sweeps
  `flood_factor = c(1, 2, 4, 6, 8, 12)`
- `stac_floodplains_bc` — publishes `<wsg>_<sp>_ff0N` products (e.g. `morr_co_ff04`); the species
  prefix is a downstream convention absent from this package's CSV
- `restoration_wedzin_kwa_2024#138` — recalibrated ff **on top of** this bug

## Artifact regeneration is possible offline

`data-raw/wsg_vignette_data.R` steps 1–5 need a bcfishpass DB tunnel and an MRDEM fetch. Steps 6–7
(the VCA run and polygonize) read only the cached `inst/vignette-data/pars_dem.tif` and the
`streams` / `waterbodies` layers of `pars.gpkg`, so `pars_valleys.tif` and the `floodplain` layer
can be regenerated with no network.

## Errors Encountered

| Error | Resolution |
|-------|------------|
