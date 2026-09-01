# Task: Bankfull regression is fed hectares and mm where Hall 2007 specifies km2 and cm/yr — depth overestimated 3.59x (#49)

`R/fl_flood_surface.R:79` feeds **hectares** (`upstream_area_ha`) and **millimetres**
(`map_upstream`) into Hall 2007's verbatim coefficients, which two primary sources state take
**km²** and **cm/yr**. Verified independently 2026-08-31:

| | factor |
|---|---|
| bankfull width over-estimated | **8.2224x** |
| bankfull depth over-estimated | **3.5926x** |
| as-coded `ff04` behaves as | corrected **ff14.37** |

Every floodplain this package has produced is over-mapped — ~2x on the bundled 10 m tile, ~16% on
the 30 m production watershed (the slope and cost-distance criteria bind first there).

Corrected, the literature ff values produce physically sensible flood stages: a 1,000 km² river gets
2.5 m at ff06, against ~9 m as-coded.

## Decisions taken at planning (user-approved 2026-08-31)

- Scenario values **stay 2 / 4 / 6** — they already sit on the literature ladder (Rosgen 2, Hall 3,
  Nagel 5–7); the fix makes their labels true for the first time. Re-derivation is a measured
  verification pass plus new DEM-resolution guidance.
- `precip` default becomes **`NULL`** meaning "omit the term". A literal `1` would otherwise be read
  as 1 mm = 0.1 cm and silently multiply depth by 0.44.
- **#47 stays a separate issue** — one breaking change per release.

## Two traps found while planning

Both would have produced a green suite over a broken fix:

1. Nagel's published combined form `h_bf = 0.054 A^0.170 P^0.215` is an **algebraic identity** of the
   two-step form (`0.145 × 0.196^0.607 = 0.0539`, `0.280 × 0.607 = 0.170`, `0.355 × 0.607 = 0.215`).
   It holds in *any* units and therefore **cannot** be the oracle for a units test.
2. No existing test pins an absolute value — every assertion in `test-fl_flood_surface.R` and
   `test-fl_flood_model.R` is relational, and `_snaps/` is empty. The units fix would otherwise be
   silently accepted by `R CMD check`.

## Phase 1: Pin the units with a test that fails on current code

- [x] Synthetic one-cell raster, area `10000` ha (= 100 km²), precip `500` mm (= 50 cm),
      `flood_factor = 1`. Assert flood depth equals the hard literal `0.2740248754`, tolerance
      `1e-8`. Current code returns `0.9844530049` — 259% apart, so no tolerance choice can mask it.
- [x] Second assertion: `precip = NULL` gives the multiplier exactly `1`, i.e. depth equals the
      literal `0.145 * (0.196 * 100^0.280)^0.607`.
- [x] Comment in the test naming why the Nagel combined form is *not* used as the expected value.
- [x] Run the new tests against unmodified code and confirm both fail before touching `R/`. Record
      the observed failure values in `findings.md`.

## Phase 2: Correct the units in `R/fl_flood_surface.R`

- [ ] Convert inside the function: `area_km2 <- contrib / 100`, `precip_cm <- precip / 10`.
- [ ] `precip = NULL` default → multiplier exactly `1`; scalar or `SpatRaster` interpreted as mm.
      Keep the existing negative-value clamp on both inputs.
- [ ] Roxygen: state **hectares** on `streams` and **mm** on `precip`; delete the current
      "(or another proxy for channel size)" escape — that phrasing is the #47 hazard in miniature.
      Update the `@details` formula block to show the conversions.
- [ ] Propagate the `precip = NULL` default and units wording to `R/fl_flood_model.R` and
      `R/fl_valley_confine.R` (both currently default `precip = 1`).
- [ ] `devtools::document()`; read its output — no unexpected `.Rd` written, `git diff NAMESPACE`
      empty.
- [ ] Phase 1 tests pass; full `devtools::test()` green.

## Phase 3: Measure, then re-anchor the scenarios

- [ ] Re-run `ff02/ff04/ff06` on the bundled 10 m tile; record corrected cell counts and hectares
      against the as-coded 320.8 / 476.8 / 536.4 ha.
- [ ] Re-run on `inst/vignette-data/pars_dem.tif` + `pars.gpkg` (30 m MRDEM) for the resolution
      comparison. Confirm the corrected result is a strict subset (0 cells gained).
- [ ] Values stay 2 / 4 / 6. Update `inst/extdata/flood_scenarios.csv` `ecological_process` text and
      the `flood_factor` row of `inst/extdata/flood_params.csv` to state input units and the
      resolution equivalence.
- [ ] Add the guidance that at 30 m MRDEM the functional-floodplain equivalent is nearer
      **ff06–ff07**, so the Parsnip and `restoration_wedzin_kwa_2024` runs at `ff04` are
      conservative — state it, do not silently change those runs.
- [ ] Update `fl_scenarios()` roxygen ladder to match.

## Phase 4: Documentation

- [ ] `inst/notes/methodology.md` — the two-model formula table states **no units at all** for
      either row; add them. Update the scenario table, add resolution guidance, refresh the stale
      live cell counts (53,635 / 521,028).
- [ ] `inst/notes/floodplain_interpretation.md` — rewrite section 4 (defect fixed, not pending),
      update section 9's area figures, the status header, and open-verification item 1. Fix the
      stale "BibTeX keys still need generating" clause, contradicted by its own strikethrough.
- [ ] `inst/research/vca_parameter_rationale.md` — already correct; note that the code now agrees.
- [ ] `README.md:45` — "underestimates flood depth by ~4x" is the as-coded ratio (3.87x); corrected
      is **2.35x**.
- [ ] `vignettes/valley-confinement.Rmd` — Step 2 prose ("~2 m vs ~8 m flood depth") and the formula
      block. Vignette area figures compute live and need no edit.
- [ ] `vignettes/pars-floodplain.Rmd` — check the `ff04` framing against the new guidance.
- [ ] Fix the `@nagel_etal2014LandscaleScale` typo in `flood_params.csv` line 5 while there.

## Phase 5: Regenerate the shipped vignette artifacts

- [ ] Regenerate `inst/vignette-data/pars_valleys.tif` and the `floodplain` layer of `pars.gpkg`
      from the **cached** `pars_dem.tif` + `pars.gpkg` streams/waterbodies — steps 6–7 of
      `data-raw/wsg_vignette_data.R` only. No DB tunnel needed; steps 1–5 are skipped.
- [ ] Record before/after cell counts and hectares; confirm strict-subset.
- [ ] `pars_meta.rds` carries no ff value — verify before assuming it needs no change.

## Phase 6: Release and downstream notice

- [ ] `NEWS.md` — prominent **result-changing** entry with measured before/after on both shipped
      datasets. Leave the historical 0.4.1 figures alone; they were true when written.
- [ ] `DESCRIPTION` 0.4.1 → **0.5.0** as the final commit of the branch.
- [ ] Notify downstream: `restoration_wedzin_kwa_2024#138` (recalibration was done on top of this
      bug), `stac_floodplains_bc` (published `<wsg>_<sp>_ff0N` products), the `floodplains` driver.
- [ ] Update #48 item 1; close #49.

## Validation

- [ ] Phase 1 tests fail on unmodified code, pass after Phase 2 — recorded, not asserted from memory
- [ ] `devtools::test()` green; `lintr::lint_package()` no new lints vs `HEAD` baseline
- [ ] `devtools::document()` output read; `NAMESPACE` diff empty
- [ ] `devtools::check()` clean before the version bump
- [ ] Corrected delineation is a strict subset of the as-coded one on **both** shipped datasets
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
