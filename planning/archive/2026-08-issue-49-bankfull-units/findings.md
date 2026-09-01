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
converted, `1` becomes 0.1 cm/yr, scaling width by **0.4416** and depth by **0.6089** — so the
default would gain a second silent behaviour change on top of the units fix, and in the direction
that makes the result *shallower* than dropping the term.

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

## Phase 1 measured — the tests fail on unmodified code

Run 2026-08-31 against `HEAD` before any `R/` edit:

```
[ FAIL 4 | WARN 0 | SKIP 0 | PASS 11 ]
test-fl_flood_surface.R:117  actual 0.98   expected 0.27   (units, scalar precip)
test-fl_flood_surface.R:130  actual 0.98   expected 0.27   (units, raster precip)
test-fl_flood_surface.R:141  ERROR: is.numeric(precip) is not TRUE   (precip = NULL)
test-fl_flood_surface.R:159  actual 5.9    expected 1.6    (ff scaling)
```

`0.98` is the predicted buggy value `0.9844530049`, and `5.9` is 6x it. The `precip = NULL` case
errors rather than returning a wrong number, because the current signature validates
`is.numeric(precip)`.

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

## `stac-dem.Rmd` published figures do not reproduce at all

Its 10 m baseline config (explicit `slope.tif`, **no** waterbodies, ff=6) measured today:

| | cells |
|---|---|
| published in the baked vignette | 54,637 |
| as-coded reproduction, today | 53,635 |
| corrected | **28,727** |

So ~1,002 cells of the gap predate the units fix and come from changes since the vignette was last
baked. Worth knowing before quoting the vignette's numbers as a units-fix delta — the caveat added
to it says so explicitly rather than attributing the whole difference to #49.

Also note the config matters: the same tile gives 53,635 with explicit `slope.tif` and no
waterbodies, but 55,345 with waterbodies. A cell count quoted without its configuration is not a
reproducible figure.

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
| `csv.writer` rewrote all 6 rows of `flood_params.csv` when 2 were edited — it re-quotes every field by its own rules, stripping quotes the original carried | Plain-text replacement inside the already-quoted field, so the diff shows only the edited lines |
| Then the plain-text approach broke `flood_scenarios.csv`: the inserted prose contained a **comma** and `ecological_process` was **unquoted**, so each row gained a field and `read.csv` consumed column 1 as row names. 8 tests failed with `scenario_id` returning `2,4,6` | Use `csv.writer` where every data row is being edited anyway (no churn possible), plain text only when the target field is already quoted **or** the insert has no delimiter |
| `git checkout <path>` restored the **broken staged** copy, because it reads the index — the "fix" reproduced the same failure and looked like the edit was wrong | `git checkout HEAD -- <path>` |
| `git stash` + `lint_package()` + `git stash pop` chained on one line to compare lint counts: `lint_package()` took >2 min, the 120 s Bash timeout fired, and **`stash pop` never ran** — the entire branch's work sat in the stash with a clean tree, while a review subagent was concurrently reading those files | Recovered with `git stash pop`. Do not stash to compare against a baseline: `git show HEAD:path` into a temp dir is non-destructive. And never put a destructive setup and its undo in one timeout-able command |
