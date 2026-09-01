# Review round 3 — staged prose diff, `inst/notes/floodplain_interpretation.md` + `CLAUDE.md` (#52)

Scope: the staged diff reviewed as *fixes* to rounds 1 and 2. Every number recomputed from the
committed artifacts, `methodology.md`, `NEWS.md` and the consuming report code; nothing taken from
`findings.md`, `review-round1.md` or `review-round2.md`.

Constants: AOI = 5,596.6047 km² = 559,660.47 ha; cell area 932.8312 m²; `sf_use_s2(FALSE)`.

## Verified clean — the round-2 fixes landed and did not relocate

| round-2 finding | fix landed? | note |
|---|---|---|
| 1. "48,540.8 … quoted elsewhere in this memo" false | **yes** | claim removed; replaced by "unclipped the same two layers give 8.67% and 7.35%", both correct (below) |
| 2. bullet paired the two lineages while the parenthetical forbade it | **yes** | "this package's corrected delineation of the same group" + "brackets the restatement rather than being one delineation corrected" — but see finding 2 below |
| 3. wrong chunk named | **yes** | clip is `sf::st_intersection(floodplain, aoi)` at peace `0730-appendix-floodplain.Rmd:41`, inside `flood-load` (14–48); `flood-rollup` starts `:50`. Correct |
| 4. "higher, drier … farther from the channel" | **yes, and not relocated** | `grep -rn "drier\|farther from the channel" inst/ NEWS.md CLAUDE.md vignettes/ R/` → **no hits** |
| 5. "Scenario-to-scenario comparisons are unaffected on every dataset" | **yes, and not relocated** | `grep -rn "comparisons are unaffected\|proportional claims stand"` → **no hits** anywhere in the package |
| 6. "AOI" meaning two things three lines apart | **yes** | bullet 1 now "disturbed-as-a-share-of-floodplain", and the `drift` AOI is named explicitly |
| 7. "7.4%" 7.85 ha from printing 7.3 | **yes** | text now quotes the two-decimal quantities only |

Arithmetic recomputed (all ✓):

```
100 * 48,116.2027 / 559,660.47 = 8.5974 %  -> sprintf("%.1f") "8.6"   published, confirmed in
                                                                     docs/results-and-discussion.html
                                                                     ("48,116 ha — 8.6 % of the 5,597 km²")
100 * 40,807.8791 / 559,660.47 = 7.2915 %  -> "7.3"
100 * 48,540.8040 / 559,660.47 = 8.6733 %  -> "8.7"   unclipped peace layer      -> digit moves ✓
100 * 41,142.8929 / 559,660.47 = 7.3514 %  -> "7.4"   unclipped corrected layer  -> digit moves ✓
area fall  (48,116.2027 - 40,807.8791)/48,116.2027 = 15.1889 %
share fall (8.597392    - 7.291542   )/8.597392    = 15.1889 %   identical, fixed denominator ✓
521,028 - 520,360 = 668 cells;  668 x 932.8312 = 62.313 ha;  48,603.1174 - 48,540.8040 = 62.313 ✓
  direction correct — the peace raster is the smaller one
wedzin kwa: (17,100.7 - 14,345.3)/17,100.7 = 16.11 % fall; 83.89 % retained (memo's "84%") ✓
section 9: ff06/ff04 as-coded 536.4/476.8 = +12.50 % (cells 53,635/47,681 = +12.49 %)
           ff06/ff04 corrected 287.3/231.9 = +23.89 % (cells 28,727/23,192 = +23.87 %)   -> "23.9%" ✓
```

Also checked and correct:

- **"the floodplain polygon is itself the AOI handed to `drift`"** — true for
  `restoration_wedzin_kwa_2024`: `scripts/floodplain_lcc/03_lulc_classify.R:75`
  `dft_stac_fetch(floodplain, source = "io-lulc", years = years)`, and `2043-Appendix-lulc.Rmd:79`
  `aoi = floodplain`, where `floodplain` is `st_read(fp_file, layer = "co_ff04")`.
- **"the margin … is the ground criterion 4 removes, the highest relative to the modelled
  waterline"** — correct. Only `flood_factor` × bankfull changed, and it enters solely through
  `fl_flood_surface()` → `fl_flood_depth()`; `depth <- surface_full - dem`, `NA` where negative
  (`R/fl_flood_depth.R:86,91`). The three other masks (`R/fl_valley_confine.R:213,216,220`), the
  channel buffer and the waterbodies OR are all untouched by the fix, so the margin is by
  construction the ground the relative-elevation filter drops. The "slope and cost bind first on
  MRDEM-30" premise does not undercut this — it changes *how much* is removed, not *which criterion*
  removes it. (Two immaterial refinements: the margin is that ground **within** the region the other
  three criteria already pass, and the cleanup/patch-removal steps can drop a few extra cells that
  criterion 4 did not itself remove. Neither changes the bullet's conclusion.)
- **"the same two layers"** now has a clean antecedent — "Both figures are the floodplain clipped
  …" immediately precedes it, and the two figures are the only pair in scope.
- **"no corrected run of *its* lineage exists"** — supportable. `data/gis/pars_valleys.tif` and
  `pars.gpkg` in the peace repo are untouched since `0c9ffe3` / `7c15411` (#15, #20), and no
  520,360-cell corrected artifact appears in `flooded`, `floodplains` or the peace repo.
- **`fp_pct_aoi`** resolves: `100 * fp_area_ha / (aoi_area_km2 * 100)` at peace
  `0730-appendix-floodplain.Rmd:53`, skeena `0720:55`, fraser `0720:53` — every floodplain appendix
  that exists, rendered directly under "Floodplain area (ha)".
- **`CLAUDE.md` numbers** are all consistent with the memo: 27.51→27.50, 8.6→7.3, raw 8.67%,
  12.5%/23.9%.

---

## Findings

### 1. **[bug]** `CLAUDE.md:92-93` (and, more weakly, `inst/notes/floodplain_interpretation.md:142-143`) — a bundled-10 m-tile ratio is stated with no dataset, in a bullet whose every other number is a 30 m watershed figure. On 30 m the answer is 4.6%, not 23.9%.

```
- ... Scenario *ordering* survives such a fix; scenario *ratios* do not — `ff06` mapped 12.5%
  more than `ff04` as-coded and 23.9% more corrected, because the slope and cost masks clamp
  each scenario differently (#52).
```

12.5% and 23.9% are derived from section 9, whose heading is **"Measured on the bundled Bulkley
tile (10 m)"**. `CLAUDE.md` carries them with no tile, no resolution and no pointer, three clauses
after `8.6% -> 7.3%`, `27.51% -> 27.50%` and "the report appendix" — all of which are MRDEM-30
watershed figures. The natural read is that 12.5%→23.9% is a general restatement factor for
scenario gaps.

It is not. `methodology.md:91-96` measures the corrected scenarios on the Parsnip WSG at 30 m:

```
ff04 corrected  441,054 cells  41,142.9 ha
ff06 corrected  461,129 cells  43,015.6 ha
ff06/ff04 corrected = 43,015.6/41,142.9 = 1.045517  ->  +4.55 %   (cells: +4.55 %)
ff07/ff04 corrected =                                    +6.41 %
```

**4.55%, against the 23.89% quoted** — a factor of 5.2 apart. `methodology.md:98-100` says why:
"at 30 m the slope and cost-distance criteria bind first and the flood mask is nearly non-binding",
so the whole `ff04`→`ff07` span is only 6.4%. A report author restating a 30 m watershed's
scenario comparison from this bullet applies a factor five times too large.

This is the exact class `CLAUDE.md` names in its own conventions — *"A defect's magnitude is
dataset-specific — measure it where it lands"*, whose worked example is this very issue (the 2×
bundled-tile figure vs the 16% production figure). The bullet reproduces the error one level down,
on scenario ratios instead of on area.

The memo is the milder case: it appends "(section 9)", which does name the dataset for a reader who
follows the pointer. But the sentence sits in section 4's paragraph about restating the
**Parsnip/peace watershed** figures, so the nearest referent is a 30 m dataset with a 4.6% answer.

Fix: name the dataset inline in both — "on the bundled 10 m tile, `ff06` mapped 12.5% more ground
than `ff04` as-coded and maps 23.9% more corrected (section 9); on the Parsnip WSG at 30 m the
corrected `ff06`–`ff04` gap is only 4.6% (`methodology.md`)". The two-dataset form is also the
stronger argument for the claim being made, since it shows the ratio is not transferable either.

---

### 2. **[fragile]** `inst/notes/floodplain_interpretation.md:134-137` — "no corrected run of *its* lineage exists" and "the fall is ~15% on either lineage" contradict each other two clauses apart

```
... the peace report's committed pre-fix raster is 668 cells (62.3 ha) smaller than the 48,603.1
ha above, and no corrected run of *its* lineage exists. So the pair brackets the restatement
rather than being one delineation corrected — which is good enough here, because the fall is
~15% on either lineage.
```

If no corrected run of the peace lineage exists, there is no fall measurable *on* that lineage. The
sentence asserts a measurement the previous clause has just said cannot be taken — and this is the
sentence that licenses the whole "good enough" conclusion, so it is load-bearing.

What is actually true is that ~15% holds from **either pre-fix starting point** to the single
corrected run:

```
same lineage,   raw      48,603.1174 -> 41,142.8929 = 15.349 %
cross lineage,  raw      48,540.8040 -> 41,142.8929 = 15.241 %
cross lineage,  clipped  48,116.2027 -> 40,807.8791 = 15.189 %
```

The conclusion survives; only the attribution is wrong. Fix: "because the fall is ~15% from either
pre-fix layer" (or "whichever pre-fix figure you start from"). This is round-2 finding 2's residue —
the identity claim was removed from the bullet and a weaker version of it reappeared in the caution
that replaced it, which is the relocation pattern this round was asked to watch for.

---

### 3. **[fragile]** `inst/notes/floodplain_interpretation.md:142-143` — the one example given is the one inter-scenario gap that *widened*; the memo's own table shows the other two narrowed

The claim ("ratios between scenarios do not survive") is correct and the example is arithmetically
right. But it is the only direction shown, and it is not the general one. From section 9's own
table:

```
ff06/ff04   as-coded 1.1250  ->  corrected 1.2389    gap  +12.5 %  ->  +23.9 %   WIDENS
ff04/ff02   as-coded 1.4863  ->  corrected 1.2508    gap  +48.6 %  ->  +25.1 %   NARROWS
ff06/ff02   as-coded 1.6721  ->  corrected 1.5496    gap  +67.2 %  ->  +55.0 %   NARROWS
```

A reader restating "our `ff04` maps 49% more than our `ff02`" from this paragraph will infer the
gap grows, and it halves. Since the paragraph's job is to tell someone what to do with a published
comparison, the direction matters. One clause fixes it: "…and maps 23.9% more corrected — while the
`ff04`–`ff02` gap moves the other way, 48.6% to 25.1% (section 9). The direction is not
predictable."

Relatedly, the stated mechanism — "because the slope and cost masks clamp each one differently" —
is only part of the story: retention across scenarios is **non-monotonic** (57.8% / 48.6% / 53.6%),
which clamping alone would not produce; the terrain's hypsometry between the two waterlines is
doing the rest. "Differently" is loose enough to be compatible, so this is an observation rather
than a defect, but "because" claims a single cause the memo's own numbers do not isolate.

---

### 4. **[fragile]** `inst/notes/floodplain_interpretation.md:141` — "each scenario is still a superset of the one below" is asserted, and sits close enough to section 9's *measured* "strict subset" to be mistaken for it

Section 9's "The corrected delineation is a **strict subset** at every scenario — 0 cells gained" is
a measured statement about **corrected vs as-coded at the same scenario**. The new clause is about
**`ff02` ⊆ `ff04` ⊆ `ff06` within one run** — a different pair, nowhere measured in this package
(`grep -rn "superset" inst/ NEWS.md planning/` returns only this line and round 2's suggestion of
it).

It is almost certainly true, and derivably so: `flood_factor` enters only through
`fl_flood_surface()`, raising the surface at every stream cell; `terra::interpIDW` weights are
independent of `z`, so the draped surface rises everywhere; `depth > 0`, the AND with three
`ff`-independent masks, dilate/erode, the hole-fill, `fl_patch_rm()` and the modal filter all
preserve containment; the channel buffer and waterbodies are OR'd in identically. The cell counts
are consistent (18,543 < 23,192 < 28,727) but consistency is not containment.

Fix: say "by construction" and give the one-line reason, or measure it once and cite the number —
the memo holds itself to exactly that standard at section 7 item 2 ("its *magnitude* … is uncited
and should not be asserted").

---

### 5. **[fragile]** `CLAUDE.md:88-89` — "fell **8.6% -> 7.3%** as published" reads as though both figures are published; only 8.6% is

The memo it summarises is careful to split the attribution: *"The peace report publishes 48,116 ha
— 8.6% …; **this package's corrected delineation** of the same group, measured the same way, is
40,807.9 ha — 7.3%"*, and then states outright that no corrected run of the peace lineage exists.
`CLAUDE.md` compresses both halves under "as published".

The intended sense is "on the published (clipped) basis", which the following clause supports. But
this file is read as a standalone convention, and the sentence directly beneath the one that
matters most here — *can this published figure be quoted* — should not imply a corrected figure has
been published when none has. Fix: "fell from a published **8.6%** to a corrected **7.3%** on the
same basis".

---

### 6. **[fragile, low]** `inst/notes/floodplain_interpretation.md:129` — "not scaled" is right in general and wrong in the specific case the paragraph has just worked

```
A share of this shape has to be **re-run, not scaled and not held**.
```

Scaling by the *same group's* retention ratio is exact, because the denominator is fixed — which is
what the preceding sentence ("The share falls ~15%, **exactly** as the area does") establishes:

```
8.597392 % x (40,807.8791 / 48,116.2027) = 8.597392 x 0.848111 = 7.291542 %
```

— the corrected share to four decimals. What is genuinely invalid is scaling by a retention ratio
borrowed from another dataset, since retention runs 48.6% to 90% across the runs this memo records.
The memo says exactly that at `:311` ("must be re-run rather than scaled, **since the error only
reaches the boundary where the flood mask binds**"); the new bullet drops the reason, leaving a
prohibition that the sentence above it appears to contradict. Add four words: "not scaled from
another dataset's retention".
