# Code review — round 1: bankfull units fix (flooded#49)

Reviewed staged diff (`/tmp/cc_diff.txt`, 6 files: `R/fl_flood_surface.R`,
`R/fl_flood_model.R`, `R/fl_valley_confine.R` + regenerated `man/`) against
`soul/conventions/code-check.md`.

**The R code change itself is correct.** Verified arithmetic against the published
Hall et al. (2007) form, checked both precip branches, checked the clamp ordering,
checked every call path for the new `NULL` default, and ran the suite. The findings
below are all in *other* files that the diff has now made wrong — the class
`code-check.md` calls "Documentation Staleness", and the first one is live executing
code, not prose.

---

## Findings

### 1. [bug] `vignettes/valley-confinement.Rmd:328-336` — `precip = 1` no longer omits the term; the chunk executes and publishes a wrong number

```r
valleys_no_precip <- fl_valley_confine(
  dem, streams, field = "upstream_area_ha",
  precip = 1
)
n_no <- sum(values(valleys_no_precip) == 1, na.rm = TRUE)
cat("Without precip:", n_no, "cells (", ...)
```

This is exactly the case the diff's own roxygen warns about. `precip = 1` is now
read as 1 mm = 0.1 cm/yr, giving a width multiplier of `0.1^0.355 = 0.4416` and a
**depth multiplier of 0.609** — so the chunk labelled "Without precip" produces a
*shallower* flood surface than actually dropping the term, and the printed cell
count is smaller than a true no-precip run. Measured on the bundled data at
`flood_factor = 1`:

| call | mean flood depth at stream cells | ratio vs `NULL` |
|---|---|---|
| `precip = NULL` | 0.1336 m | 1.000 |
| `precip = precip_r` | 0.3160 m | 2.366 |
| `precip = 1` | 0.0813 m | **0.609** |

`valley-confinement.Rmd` has **no `.Rmd.orig`** (unlike `stac-dem.Rmd`), so it is
the live source and this chunk runs during `R CMD check` and the pkgdown build. The
wrong figure goes onto the public site.

The surrounding prose is stale in the same motion:

- **:88-90** — "With `precip = 1` (the default), the precipitation term drops out
  and flood depths are dramatically underestimated. For the Bulkley mainstem
  (`upstream_area_ha ~ 110,000`), the difference is ~2 m vs ~8 m flood depth."
  Both halves are now wrong: `1` is no longer the default, no longer drops the
  term, and at `flood_factor = 6` the corrected Bulkley figures are **~1.1 m vs
  ~2.5 m**, not 2 vs 8.
- **:323-325** — "Omitting precipitation (`precip = 1`, the default) underestimates
  flood depth by roughly 4x … about half the width of the correct result."
  The corrected ratio is **2.37x**, and `precip = 1` is not "omitting".
- **:517** — parameter table row `| `precip` | 1 | MAP in mm …|` — stale default.

Fix: `precip = NULL` in the chunk, and re-derive the three numbers from the run.

### 2. [fragile] `README.md:38-45` — front page publishes the un-converted equation, i.e. the defect that was just fixed

```
bankfull_width = (upstream_area ^ 0.280) * 0.196 * (precip ^ 0.355)
```
> Both `upstream_area` (hectares) and `precip` (mean annual precipitation, mm) are
> important — omitting precipitation underestimates flood depth by ~4x.

The README states the coefficients applied directly to **hectares and millimetres**
— which is precisely the bug. `inst/notes/methodology.md:14` already records the
correct units (`area **km2**, precip **cm/yr**`), so the README now contradicts the
package's own reference note *and* the newly-corrected roxygen. Anyone
re-implementing from the README reproduces #49. The "~4x" figure is also stale
(measured 2.37x).

### 3. [fragile] `tests/testthat/test-fl_flood_surface.R:55` — a fixture carrying the old "term drops out" intent

```r
surface <- fl_flood_surface(dem, streams, flood_factor = 6, precip = 1)
```

Written when `1` meant "no precipitation"; it now means 0.1 cm/yr. The assertions
are loose (`sum(!is.na(...)) == 1L`, `values[13] > 100`) so it passes either way —
which is the problem: the fixture no longer exercises what the test is named for,
and it is the one remaining `precip = 1` in the package's own code. Should be
`precip = NULL`.

The *new* units tests (:107-160) are sound — I checked they can reach the failure
mode. The literals (0.2740248754 / 0.1179471463) differ from the pre-fix answer by
3.59x, far outside the 1e-8 tolerance; and the raster-vs-scalar test would catch a
`/10` missing from only the SpatRaster branch. The comment at :82-88 explaining why
Nagel's combined form is unusable as an oracle is correct — it *is* an algebraic
identity and would agree in any units.

### 4. [fragile] `R/fl_flood_surface.R:50` points readers at a note that says the code is still broken

The new roxygen ends:

> see the units defect recorded in `inst/notes/floodplain_interpretation.md`.

That note is written entirely in the unfixed tense and still instructs against using
the package's output:

- `:94` — "**Until #49 is fixed**, treat the absolute extents as over-mapped"
- `:245` — "**flooded#49 must be resolved before any absolute area figure is
  published.** Extents are currently…"

`inst/` travels with the installed package via `system.file()` and renders on the
pkgdown site, so the shipped documentation will tell users the shipped code is wrong
after this merge. Either update the note's status to "fixed in vX.Y.Z" or reword the
roxygen to point at the historical record rather than a live warning.

---

## Checked and clean

Recording these so a later round does not redo them.

- **`precip = NULL` reaches every call path.** `fl_valley_confine(precip = NULL)`
  -> `fl_flood_model(..., precip = precip)` (`fl_valley_confine.R:157`) ->
  `fl_flood_surface(..., precip = precip)` (`fl_flood_model.R:35`). All three
  defaults changed together; both intermediate hops pass `precip` explicitly, so no
  path re-injects the old `1`. `@inheritParams fl_flood_surface` keeps
  `fl_flood_model`'s docs in sync automatically.
- **Conversion applied to both branches, and the clamp still fires first.**
  Scalar: `stopifnot(precip >= 0)` then `(precip / 10) ^ 0.355`. Raster:
  `(terra::ifel(precip < 0, 0, precip) / 10) ^ 0.355` — clamp inside, divide
  outside, correct order. Area: `terra::ifel(streams < 0, 0, streams)` then
  `/ 100`. Clamping and scaling by a positive constant commute here anyway, but the
  written order is the safe one.
- **No terra operator-dispatch trap.** The new `contrib / 100` is `Arith`, a
  *primitive* group generic — S4 methods dispatch off the object's class whether
  terra is attached or imported. This is not the `%in%` case (`%in%` is an ordinary
  base function, which is why that one falls through). Proven in situ: `+`
  (`:105`) and `^` (`:100`) on SpatRaster were already in this function and work.
- **`is.null(precip)` guard cannot fail toward pass.** The `else if` /`else` chain
  is exhaustive: `NA`, `character`, `numeric(0)` and length > 1 all reach the
  `stopifnot` and error rather than silently taking a default.
- **`pcp <- 1` is a length-1 numeric,** so `bankfull_width` stays a SpatRaster
  (`raster * 1`); no shape change versus the old `1 ^ 0.355`.
- **Suite green.** `devtools::test(filter = "fl_flood|fl_valley")` ->
  `FAIL 0 | WARN 0 | SKIP 0 | PASS 128`.
- **Factual claims in the new roxygen verified against the bundled data:**
  "raises predicted depth by ~2.35x" -> measured **2.366**; "5.7 m against 31.3 m
  for the Bulkley" -> computed **5.78 m** from A = 110,337 ha, P ≈ 550 mm, and
  `max(streams$channel_width) = 31.32`. Both hold.
- **`man/*.Rd` are consistent with the roxygen** — regenerated, not hand-edited.
- **No other caller in the package passes `precip = 1`.** Swept `R/`, `tests/`,
  `vignettes/`, `data-raw/`, `inst/`, `README.md`. Hits are findings 1-3 above;
  `data-raw/wsg_vignette_data.R:259`, `vignettes/pars-floodplain.Rmd:222`,
  `vignettes/stac-dem.Rmd` and all `@examples` pass a real precip raster and are
  unaffected.
- **`fl_valley_confine(field = "channel_width")`** left as-is per instructions
  (flooded#47); the added roxygen warning is accurate.

## Note, not a finding

`NEWS.md` and `DESCRIPTION` (0.4.1) are untouched. Per the repo's own convention the
version bump is the final commit of a branch, so this is expected mid-branch — but
this change alters **every numeric result the package has produced**, so the release
note is load-bearing rather than routine. Worth carrying the 3.59x figure and the
"absolute extents previously over-mapped" consequence into it, and reconciling
`inst/notes/floodplain_interpretation.md` (finding 4) in the same commit.
