# Review — fl_valley_attribute() plan (#40)

Plan-agent review, reviewed against the code at `6a9d9d9`. Every claim was reproduced by running
the real functions on `inst/testdata/`. 19 findings: 3 Blocker / 6 Gap / 2 Ordering / 3 Assumption /
2 Scope / 3 Acceptance.

Verdict: the mechanism is sound as an algorithm on the raw criteria, and the seed-decomposition
argument was confirmed empirically. But the plan's central guarantee is stated against
`fl_valley_confine()`'s mask intersection (lines 140-160) while the function returns mask
intersection PLUS cleanup PLUS channel buffer PLUS waterbodies (lines 162-220).

## BLOCKER 1 — Coverage guarantee false for real fl_valley_confine() output

`fl_valley_confine.R:213-220` ORs waterbodies in after the mask intersection; those cells never
passed the distance or cost criterion, so no group's predicate can hold.

```
valley cells   orphans (valley==1 but outside dist<=1000 AND cost<2500)
53,635         0        # no waterbodies
55,345         1,643    # + inst/testdata/waterbodies.gpkg  -> 3.0% orphaned
53,261         0        # channel_buffer = FALSE
```

Fix: residual pass — assign leftover valley cells to the nearest / argmin-cost group so coverage
holds by construction, and report the residual count as a diagnostic.

STATUS: FIXED before this review landed. `complete = TRUE` fallback assigns by nearest group;
`attr(x, "fl_fallback_cells")` reports the count; the waterbody case is now a non-vacuous test.

## BLOCKER 2 — Cleanup breaks coverage too, but not at the defaults

```
max_width  cost_threshold  valley   orphans
2000       2500            16,268   0
 200       2500             6,396   5      (0.08%)
2000        300            10,574   56     (0.53%)
2000        150             7,255   57     (0.79%)
```

At package defaults the coverage test passes for the wrong reason — the criteria are not binding.
Fix: parameterise the coverage test; run at a binding `cost_threshold`, not only at defaults.

STATUS: FIXED — added a binding-threshold coverage test.

## BLOCKER 3 — fl_cost_distance() seeds every zero-friction cell

`fl_cost_distance.R:51-52` sets stream cells to 0 then calls `costDist(target = 0)`, so ANY cell
with friction exactly 0 becomes a seed. Roxygen at `:9-12` says only stream cells are seeds — the
documentation is wrong about the function's own behaviour.

Synthetic 50x50 grid, friction 10%, one stream cell, a flat (0%) patch 380 m away:

```
cost at flat-patch centre        : 0      (should be ~1400)
cost one cell beyond the patch   : 50     (should be ~1450)  -> 29x understated
cells with cost 0                : 122    (stream cells: 1)
```

Bundled DEM masks this (0 cells exactly zero). Production DEMs — integer-metre, hydro-flattened
lakes, void-filled plateaus — do produce exact zeros. Matters MORE under attribution: a flat patch
is a free zero-cost source for whichever group's crop contains it, so cost stops discriminating
between groups exactly where floodplains are.

Fix: floor the friction before seeding (`ifel(friction <= 0, 1e-6, friction)`). Verified to restore
correct values with no change on bundled data.

STATUS: NOT fixed here — pre-existing behaviour in a different function, filed as its own issue.

## GAP 4 — Required crop margin unproven

```
margin = 1000 m (= max_width/2) : 200 corridor cells differ, max delta 216.9 cost units
margin = 2000 m (= max_width)   : 0 cells differ, max delta 0.000
```

Least-cost paths ARE truncated at max_width/2. No finite bound exists in general — across near-flat
ground a detour of arbitrary length costs arbitrarily little.

Fix: expose `crop_margin` (default `max_width`), document as an approximation.

STATUS: FIXED — `crop_margin` argument added and documented as an approximation.

## GAP 5 — Crop-safety test near-vacuous; perf framing overstated

Group bbox + 2000 m margin crops are 39-74% of the bundled grid, so the crop can barely fail, and
at k=5 the crops sum to 276% of a full-grid pass.

Fix: soften the "scales with network length" claim; make the crop test meaningful.

STATUS: PARTIALLY FIXED — claim softened in docs/issue; a small-margin test now pins the
approximation. A genuine large-grid synthetic remains unbuilt.

## GAP 6 — Grouping-invariance test vacuous twice over

On bundled data `gnis_name` and `blue_line_key` are a bijection (5 groups each), so any
implementation passes. The union over groups is also a tautology in exact arithmetic.

Fix: test a genuine coarsening — coarse group == union of its fine members, cell for cell.

STATUS: FIXED — replaced with a coarsening test.

## GAP 7 — A group whose streams rasterize to zero cells is unhandled

`touches = FALSE` means a segment that misses every cell centre burns nothing; the group then
vanishes silently. Near-certain at k=340 on MORR.

Fix: `warning()` naming the group (not `cli_alert_warning()`, per CLAUDE.md — not catchable).

STATUS: FIXED — warning names the dropped group values.

## GAP 8 — NA propagation, and slope must never be derived on a crop

`terra::terrain()` puts NA in the outer one-cell ring (2,892 cells on the bundled DEM = exactly the
border), and `fl_cost_distance()` treats NA friction as impassable — so deriving slope per crop
would wall every crop.

STATUS: ALREADY CORRECT — slope is derived once on the full DEM, then cropped per group.

## GAP 9 — Signature omits `field`; template should be `valleys`

STATUS: NOT APPLICABLE to the implementation — it adds its own constant seed column and rasterizes
onto the cropped slope grid, which is derived from `valleys`.

## ORDERING 10 — Argument order fights the existing convention

`fl_valley_confine(dem, streams, field, slope, ...)` puts `dem` first. Fix: `dem` before `slope`.

STATUS: FIXED.

## ORDERING 11 — Review concurrent with Phase 2 invalidates the test contract

STATUS: MOOT — the two contract-changing findings (BLOCKER 1, GAP 6) were resolved by edit.

## ASSUMPTION 12 — Parameter drift enforced only by a roxygen note

Nothing detects a `valleys` raster produced at `max_width = 1000` being attributed at 2000.

STATUS: ACCEPTED AS-IS — the fallback count is reported at runtime and exposed as an attribute,
which surfaces drift as an unusually large residual. A hard warning would fire on the legitimate
waterbody case, which is common.

## ASSUMPTION 13 — Performance story unmeasured at production scale

A bbox is a poor proxy for a long sinuous mainstem: the Morice's bbox is close to the whole AOI, so
the largest group gets no saving.

STATUS: CLAIM SOFTENED — measured k=5 at 0.74 s (vs 1.36 s for the delineation itself); k=340 on a
27M-cell raster is explicitly not claimed.

## ASSUMPTION 14 — findings.md numbers not reproducible without the exact call

`fl_valley_confine(dem, streams)` gives 16,268 cells; the reported 53,635 needs
`field = "upstream_area_ha"` and `precip = fl_stream_rasterize(streams, dem, "map_upstream")`.

STATUS: FIXED — the exact parameterisation is now recorded in findings.md.

## SCOPE 15 — waterbodies / channel_buffer / size_threshold invisible to the API

STATUS: DOCUMENTED — `@details` names waterbodies specifically as a source of fallback cells.

## SCOPE 16 — New parameters want a row in the parameter legend

STATUS: DECLINED — `fl_params()` documents VCA model parameters; `crop_margin` is an implementation
knob, not part of the model.

## ACCEPTANCE 17 — "Delineation untouched" not testable as written

STATUS: FIXED — replaced with an input-mutation test (terra objects are C++ pointers, so this is a
real risk), plus `git diff -- R/fl_valley_confine.R` being empty on the branch.

## ACCEPTANCE 18 — Vacuous assertions in the Phase 2 list

Containment is true by construction and passes on a 0-row result; overlap "count > 0" passes on a
single cell. Measured anchors at `channel_buffer = FALSE` defaults, by `gnis_name`:

```
valley cells 16,268 | Bulkley 14,842 | Richfield 6,528 | Cesford 5,944 | unnamed 4,184
Robert Hatch 3,003  | sum 34,501 = 2.12x the valley | uncovered 0
```

STATUS: FIXED — assertions anchored to group count and an overlap-ratio band.

## ACCEPTANCE 19 — Both issue bodies need editing, not just the driver one

flooded#40's Acceptance list contains the two bullets disproved above.

STATUS: FIXED — flooded#40 body edited with the disproof and the fallback policy.

## What the reviewer checked and could not fault

- The subset/argmin decomposition is correct on the raw criteria: union of all five group
  memberships covers all 16,268 valley cells, 0 uncovered.
- Overlap is genuinely large (2.12x by cell count), so overlapping rows are the right output shape.
- Keeping the flood mask global is right: `fl_flood_depth.R:68-71` builds the IDW point set from ALL
  non-NA flood_surface cells, so a per-group flood surface really would move the answer.
- Operator consistency: `fl_mask_distance()` uses `<=`, the cost mask uses `<`. The predicate
  matches both.
- Test-suite runtime: `skip_on_ci()` genuinely unnecessary.
