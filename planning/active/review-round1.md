# Review round 1 — staged diff to `inst/notes/floodplain_interpretation.md` (#52)

Scope: the staged prose diff only. Everything below was measured, not read off the issue or the
session's own `findings.md`.

## Findings

### 1. **[bug]** `inst/notes/floodplain_interpretation.md:123-124, 126-127` — the peace report does not publish 48,540.8 ha or 8.67%. It publishes **48,116 ha** and **8.6%**.

The new bullet asserts "the peace report as committed carries 48,540.8 ha, or **8.67%**", and the
parenthetical closes with "either divided by 559,660 ha rounds to **8.7%**". Both are wrong about
the published figure, and the parenthetical is wrong in the one digit the report actually prints.

**Why.** 48,540.8 ha is the raw `floodplain` layer in `data/gis/pars.gpkg`. Neither consuming chunk
uses the raw layer — both clip it to the AOI first:

- `fish_passage_peace_2025_reporting/0730-appendix-floodplain.Rmd:42`
  `floodplain <- suppressWarnings(sf::st_intersection(floodplain, aoi))`
  then `:53` `fp_pct_aoi <- 100 * fp_area_ha / (aoi_area_km2 * 100)`
- `fish_passage_peace_2025_reporting/0400-results.Rmd:209` — the same `st_intersection`, same
  formula at `:213`.

Measured with `sf::st_area()` (`sf_use_s2(FALSE)`), both layers out of the committed
`data/gis/pars.gpkg`:

| | raw layer | clipped to `aoi` (what the report computes) |
|---|---|---|
| peace, pre-fix | 48,540.8040 ha | **48,116.2027 ha** |
| flooded, 0.5.0 corrected | 41,142.8929 ha | **40,807.8791 ha** |

AOI = 5,596.6047 km² = 559,660.4741 ha.

```
published pct = 100 * 48,116.2027 / (5,596.6047 * 100) = 8.5974 %
sprintf("%.1f", 8.5974)                                 = "8.6"
```

Confirmed against the committed rendered output, so this is not a prediction:

- `docs/app-floodplain.html` — table rows `Floodplain area (ha) => 48,116`,
  `Floodplain as % of watershed group => 8.6`
- `docs/results-and-discussion.html` — prose "8.6 % of the 5,597 km² watershed group"

**Why it matters.** This memo exists to answer "can we still quote this number". A reader taking
the memo at its word goes to the peace report looking for 48,540.8 ha / 8.67% / "rounds to 8.7%"
and finds 48,116 ha / 8.6%. The parenthetical's entire job is to reassure that the 62 ha
polygonization gap does not reach the published digit; on the numbers as written it wouldn't, but
the published digit is 8.6 either way, so the reassurance is offered about the wrong quantity.

The corrected side has the same defect: "the same delineation corrected is 41,142.9 ha, or 7.35%"
is also the unclipped value. Re-run through the report's own chunk it is 40,807.9 ha → 7.2915% →
prints **7.3**.

**The lesson survives the correction — only the figures need restating.** On the clipped values:

```
(48,116.2027 - 40,807.8791) / 48,116.2027 = 7,308.3236 / 48,116.2027 = 15.19 %
```

still "~15%", still tracking the hectares. So the bullet's argument is sound; its four numbers are
not the published ones.

**Origin.** `planning/active/findings.md:26-31` measured `st_area()` on the layer directly and
concluded "8.67% ... is what the peace report *publishes*". The `st_intersection` step was missed.
Same class as CLAUDE.md's "Measure the output, not the input you handed in" — the measurement was
taken upstream of the transformation the consumer applies.

**Precision, secondarily.** Quoting 8.67% / 7.35% to two decimals for a quantity the report renders
with `sprintf("%.1f", ...)` overstates what is published, independently of the clip.

---

### 2. **[bug]** `inst/notes/floodplain_interpretation.md:125-126` — "a separate polygonization of the same pre-fix run" is false. It is a different run: 668 fewer floodplain cells.

Polygonization is exact in both artifacts, so it cannot account for the 62.3 ha. Measured with
`terra::freq()` on the two `pars_valleys.tif`, both at 30.5423 m (932.8321 m²/cell):

| raster | cells == 1 | cells × area | polygon in the matching `.gpkg` |
|---|---|---|---|
| `fish_passage_peace_2025_reporting/data/gis/pars_valleys.tif` | **520,360** | 48,540.80 ha | 48,540.80 ha |
| `flooded/inst/vignette-data/pars_valleys.tif` | 441,054 | 41,142.89 ha | 41,142.89 ha |

Raster and polygon agree to 0.01 ha in **both** cases — vectorizing loses nothing here. Meanwhile
flooded's recorded 0.4.1 artifact is 521,028 cells (`inst/notes/methodology.md:93`, `NEWS.md:75`,
`planning/archive/2026-08-issue-49-bankfull-units/review-round2.md:165`). The gap is therefore in
the raster:

```
521,028 - 520,360 = 668 cells
668 x 932.8321 m2 = 623,131 m2 = 62.31 ha   ==   48,603.1 - 48,540.8 = 62.3 ha
```

A whole number of cells, to the hectare. Two different delineations, not two renderings of one.

**Consequence, and it is the load-bearing part.** "the same delineation corrected is 41,142.9 ha"
is not established. 41,142.9 ha is the corrected form of the **521,028**-cell run
(521,028 → 441,054, `methodology.md:93-94`). The peace report's committed layer is the
**520,360**-cell run, and no corrected run of it exists anywhere I can find. The bullet pairs a
pre-fix number from one lineage with a corrected number from another and calls them one delineation.

The ~15% conclusion is not threatened by this — both lineages drop ~15% — but the sentence claims
an identity that the artifacts contradict, in the paragraph that tells a reader which specific
published figure to restate and to what.

---

### 3. **[fragile]** `inst/notes/floodplain_interpretation.md:117` — "**Denominator inside — stable**" states as a rule what the memo's own next clause says was contingent.

The bullet's own explanation is "because the over-mapped margin carried almost exactly the
land-cover mix of the core". That is a property of `restoration_wedzin_kwa_2024`, measured once
(27.51% → 27.50%; disturbed area itself fell 16% — check: (17,100.7 − 14,345.3)/17,100.7 = 16.11%,
and 14,345.3/17,100.7 = 83.9% retained, consistent with line 111's "84% retained").

A denominator inside the moved region does not make a ratio stable. It makes numerator and
denominator move *together only if the margin's composition matches the core's* — and the margin is
systematically the higher, drier, farther-from-channel ground, so there is no reason to expect it in
general. `CLAUDE.md:1823` records exactly this hedge: "the over-mapped margin **happened to** carry
the same land-cover mix as the core".

The pre-diff text was worse ("proportional claims stand"), so this is a real narrowing. But a
bolded header reading "Denominator inside — stable" is what a reader will quote, and on n=1 it
licenses "our land-cover composition figures are unaffected" for watersheds nobody has measured.

Consistency note: the memo is now aligned with `CLAUDE.md:84-88`, which states the same rule the
same way. If finding 1 is acted on, `CLAUDE.md:86` ("floodplain-as-a-share-of-watershed fell
8.67% -> 7.35%") does **not** need changing — as a statement about the raw delineation that pair is
arithmetically correct. It is only the memo's new *attribution* of those numbers to a published
report that is wrong.

---

### 4. **[fragile]** `inst/notes/floodplain_interpretation.md:114-115` — the general rule is stated as necessary-and-sufficient and is neither.

"**a ratio is stable only if its denominator is also inside the region the fix moved**", with the
two bullet headers forming a dichotomy (inside → stable, outside → moves with the hectares).

Counterexample to the "only if": any ratio with **both** terms outside the floodplain — parks or
reserves as a share of the watershed group, road density, `streams_km_total` per km². Denominator
outside, entirely unmoved by the fix. The stated dichotomy classifies it as "moves with the
hectares".

The operative property is whether numerator and denominator move *together*, not whether the
denominator is inside. Finding 3 is the other half of the same gap: inside is not sufficient either.

Limited practical reach — the memo's context is floodplain-derived ratios, where a numerator is by
construction inside, and for those the second bullet is correct. Flagging because the sentence is
written as the one thing it all turns on, and is the sentence most likely to be lifted verbatim.

---

## Checked and clean

- **`fp_pct_aoi` exists and is defined as claimed.** `100 * fp_area_ha / (aoi_area_km2 * 100)` in
  all three repos: peace `0730-appendix-floodplain.Rmd:53` / `0400-results.Rmd:213`, skeena
  `0720-appendix-floodplain.Rmd:55`, fraser `0720-appendix-floodplain.Rmd:53`.
- **"in every fish-passage report appendix beside the hectares" — not an over-claim.** All three
  extant report repos publish it in the metric table directly under "Floodplain area (ha)":
  peace 48,116 ha / 8.6%, skeena 48,344 ha / 6.2%, fraser 54,306 ha / 13.1%. All three clip to the
  AOI the same way, so finding 1 applies to all three, not only peace.
- **AOI arithmetic.** `st_area(aoi)` = 5,596.6047 km² = 559,660.4741 ha; the memo's "5,596.6 km²,
  so 559,660 ha" is exact.
- **Section 4 bullet at line 109-110 (unchanged by the diff).** 41,142.9/48,603.1 = 84.65% →
  "84.7% retained" ✓; consistent with `methodology.md:93-94` and `NEWS.md:75`.
- **"The share falls the same ~15% as the area".** Identical denominators, so the two drops are
  equal by construction: both 15.24% on the memo's numbers, both 15.19% on the clipped ones.
- **"either divided by 559,660 ha"** — 48,540.8/559,660 = 8.6733%, 48,603.1/559,660 = 8.6844%.
  Both do round to 8.7%. The arithmetic in the parenthetical is right; the premise that either is
  the published number is what fails (finding 1).
- **Final sentence, "Scenario-to-scenario comparisons are unaffected on every dataset".** Carried
  over unchanged from the pre-diff text; consistent with `methodology.md:96-104`.
- No broken cross-references introduced: `restoration_wedzin_kwa_2024`, `fp_pct_aoi`,
  `fl_flood_surface()` all resolve.
