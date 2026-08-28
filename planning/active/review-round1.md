# Review round 1 — #41 zero-friction seeding fix

Reviewed: staged diff (`R/fl_cost_distance.R`, `R/fl_valley_poly.R`,
`tests/testthat/test-fl_cost_distance.R`, plus `man/`, `inst/notes/methodology.md`,
`planning/` in the full staged set). Every claim below was probed, not reasoned.
terra 1.9.34.

The fix itself is correct. All findings are about artifacts and claims the fix
orphans, plus one guard weaker than its comment says.

## Findings

- **[bug]** `inst/vignette-data/pars_valleys.tif` and the `floodplain` layer in
  `inst/vignette-data/pars.gpkg` are cached outputs of the **buggy** code, and the
  Parsnip DEM they came from does contain exact zeros — so the published
  `vignettes/pars-floodplain.Rmd` now shows a floodplain the package no longer
  produces. Measured on `inst/vignette-data/pars_dem.tif`
  (`tan(terrain(dem,"slope",unit="degrees")*pi/180)*100`, the exact `slope = NULL`
  path `fl_valley_confine()` takes):

  ```
  non-NA cells   10,688,931
  exact zeros            80      <- 80 free cost sources under the old code
  min nonzero     2.58e-15
  ```

  Re-running cost distance over that DEM + `pars.gpkg` streams, old vs new:

  ```
  cost-mask (cost < 2500) cells differing:  2,289 of 10,688,931
  old-only (spurious under the bug):        2,289   (~214 ha at 30 m)
  ```

  The `vca` chunk at `vignettes/pars-floodplain.Rmd:218` is `eval = FALSE`, so the
  vignette renders the committed raster/gpkg rather than recomputing — the stale
  numbers publish to pkgdown and, per the appendix-port convention in `CLAUDE.md`,
  flow into the fp_peace reporting appendix. Nothing in the diff flags this.
  Either regenerate the cached bundle or state in the vignette which version
  produced it. (Secondary, already acknowledged in `inst/notes/methodology.md:142`:
  `vignettes/stac-dem.Rmd:311` is pre-baked and carries a
  `[costDist] distance algorithm did not converge` warning plus a
  "3,883,179 valley cells / 27.7 %" figure from a 1 m lidar run under the bug.)

- **[bug]** `NEWS.md` (0.4.1 bullet 2) and `inst/notes/methodology.md:136-139`
  generalize a one-AOI measurement into a claim about the package's default DEM
  source: *"the bundled tile and a 30 m MRDEM-30 clip over the same AOI both
  contain zero exact-zero slope cells"* / *"neither the bundled tile nor the
  package's default DEM source is affected here"*. The package **ships** a second
  MRDEM-30 clip — Parsnip — with 80 exact-zero cells and a 2,289-cell mask delta
  (above). A reader on MRDEM-30 will read this as "I am not affected" and be
  wrong. Scope the claim to the Bulkley AOI it was measured on, and add the
  Parsnip row to the methodology table.

- **[fragile]** `tests/testthat/test-fl_cost_distance.R:107-119` — the guard is
  weaker than its comment. It claims to catch *"flooring to 1, or to the median
  friction"*. Measured by patching the floor and re-running the file (namespace
  **and** globalenv, see note below):

  | floor  | `through_flat` | `over_slope` | line 118 |
  |--------|----------------|--------------|----------|
  | 1e-6   | 4101.22        | 4596.19      | pass (correct) |
  | 1      | 4150.72        | 4596.19      | **pass** — over-correction undetected |
  | 10     | 4596.19        | 4596.19      | fail ✓ |
  | 100    | 7621.93        | 4596.19      | fail ✓ |

  The 6×6 flat patch is 60 m across against a ~4.1 km path, so a floor of 1 barely
  moves the total. Floor 1 is exactly the over-correction the comment describes:
  1 % slope × 100 km = 100,000, forty times `cost_threshold`, i.e. flat ground more
  than ~2.5 km from a stream would fail the cost mask. If the guard is meant to
  hold, make the flat patch large enough to dominate the path, or assert an
  absolute bound on the flat-crossing increment rather than a relative one.

- **[fragile]** `tests/testthat/test-fl_cost_distance.R:133` — `expect_error(...,
  "negative friction")` matches terra's own wording, not this package's;
  `fl_cost_distance()` raises nothing here. Verified message is
  `[costDist] negative friction values not allowed` (terra 1.9.34). A terra
  rewording turns this green guard red and reads as a regression in `flooded`.
  Low priority — worth a comment naming terra as the source of the string.

## Verified — not findings

Recorded so they are not re-litigated.

- **Restore-the-bug.** Reverting `R/fl_cost_distance.R:77` and re-running the file:
  `FAIL 3 | PASS 18`. Genuine detectors are lines **95** (zero cells ≠ seed cells:
  37 vs 1), **104** (`0.0 <= 50.0`), **156** (17 zeros vs 1). The other four new
  tests pass in both states and are labelled in-file as guards, which is accurate.
  *Method note:* `testthat::test_file()` here resolves `fl_cost_distance` through
  globalenv, not `asNamespace("flooded")` — patching only the namespace gives a
  false green. Both bindings must be assigned.
- **Checklist 5, `== 0` vs tolerance.** `terra::costDist(target=)` is exact
  equality against the same doubles R compares, so nothing can seed without
  satisfying `friction == 0`. The one theoretical gap — a nonzero double below
  float32 normal min (~1.18e-38) flushing to 0 when the `ifel` intermediate spills
  to FLT4S — is unreachable for percent slope: bundled min 1.42e-14, Parsnip min
  2.58e-15. `-0.0 == 0` is TRUE, so signed zero is floored. NaN condition is NA →
  cell stays NA.
- **Checklist 6 + 9, type promotion.** `terra::ifel(friction == 0, 1e-6, friction)`
  on an INT2S **file-backed** source returns FLT4S both in memory and under
  `terraOptions(todisk=TRUE)` (default write datatype is FLT4S regardless of source
  type) — verified; the floor is not rounded away. 1e-6 in float32 is
  9.99999997e-07, not 0. `NA == 0` is NA and `ifel` keeps NA, confirmed by the
  barrier test at line 159.
- **Checklist 7, aliasing.** `friction <- terra::ifel(friction == 0, ...)`
  evaluates the argument before rebinding; no recursion or aliasing. Ordering is
  right — the floor runs *before* seed encoding; reversed it would erase the seeds.
- **Convergence under the floor.** A 1500×1500 grid that is 87 % floored produces
  no `did not converge` warning, exactly one zero cell, and a sane range. The
  Parsnip run (10.7 M cells) also emitted none. Flooring does not make push-broom
  convergence worse.
- **Checklist 8, callers + inventory.** `terra::costDist` has exactly one call site
  in `R/`. `fl_valley_confine():147` and `fl_group_cells()` in
  `fl_valley_attribute.R:315` both pass single-layer percent slope (cropped in the
  attribute path) and a rasterized stream seed layer — nothing they pass breaks
  under the new behaviour. The bundled-data equality test at line 175 covers both
  routes, and its premise assertions (lines 182, 188) are real.
- **Full suite:** `FAIL 0 | WARN 0 | SKIP 0 | PASS 246`.
- **`R/fl_valley_poly.R:32`** is a one-space indent fix, no behaviour change.
- **Bookkeeping, not a defect:** `DESCRIPTION` (0.4.0 → 0.4.1) and `NEWS.md` are
  modified but **unstaged**. Committing the staged set as-is lands the fix without
  the version bump and NEWS entry. That matches this repo's "version bump as the
  final commit" convention — noting only so it is deliberate rather than an
  oversight.
