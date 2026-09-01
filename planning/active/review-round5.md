# Review round 5 — staged prose diff (`CLAUDE.md`, `inst/notes/floodplain_interpretation.md`)

Scope: the 53 added lines in `git diff --cached`. Enumeration is exhaustive over the quantifier
tokens in those lines (`every|either|all|any|none|never|always|both|each|only|by construction|
exactly|across the figures|does not transfer|has to|must`), extracted mechanically, not sampled.

Every number in the changed text was recomputed. All arithmetic checks out — see
"Arithmetic verification" at the end. The findings below are all scope, not arithmetic.

---

## Findings

### 1. **[bug]** `inst/notes/floodplain_interpretation.md:124`, `:128-131`, `:320-321` — "Denominator outside the floodplain — moves with the hectares" / "a *share* of a fixed denominator may be rescaled by its own group's retention" is a universal over a population whose published members mostly falsify it

Population: shares with a floodplain-derived numerator and a denominator outside the floodplain.
Not enumerable from the memo — but the memo cites the peace appendix nine lines earlier, and that
appendix *does* enumerate them. `fish_passage_peace_2025_reporting/0730-appendix-floodplain.Rmd`,
`flood-table`, as rendered in `docs/app-floodplain.html` (Table 5.9):

| Metric | Value | Scales by the group's area retention (0.8481)? |
|---|---|---|
| Floodplain area (ha) | 48,116 | **yes** — the one case the memo demonstrates |
| Floodplain as % of watershed group | 8.6 | **yes** |
| Streams within floodplain (km) | 1,580 of 2,310 | **no** — a length, scales with floodplain *width*, not area |
| Lakes within floodplain (count) | 198 | **no** — an integer count; rescaling is meaningless |
| Lakes within floodplain (ha) | 1,603 | **no** — near-invariant, see below |
| Wetlands within floodplain (count) | 464 | **no** |
| Wetlands within floodplain (ha) | 6,582 | **no** — near-invariant, see below |

The waterbody rows are not merely unproven, they are invariant **by construction** — the same kind
of construction argument the memo makes for scenario ranking, pointed the other way.
`fl_valley_confine()` rasterizes the supplied waterbodies and ORs them into the output *after*
cleanup, with no spatial filter and no dependence on `flood_factor`
(`R/fl_valley_confine.R:282-291`; CLAUDE.md's own next bullet names it — "waterbodies, the last
with no spatial filter"). The peace run supplied them deliberately ("Waterbodies were included so
the valley confinement model fills cells that gradient and cost-distance masks would otherwise
exclude"). So every waterbody polygon is in the footprint at any flood factor, and its area inside
the floodplain does not move with the units fix at all.

Applying the license as written:

```
wetlands within floodplain: 6,582 x 0.8481 = 5,582 ha   (true value ~6,582 — understated ~1,000 ha)
lakes    within floodplain: 1,603 x 0.8481 = 1,360 ha   (true value ~1,603)
```

Two consequences, and the second also lands on the *other* bullet:

- The Open-items sentence at `:320-321` is an explicit **license**, not a caution, and it licenses
  the wrong operation for 5 of the 7 floodplain-derived rows the peace appendix publishes. It reads
  "a *share* of a fixed denominator", with no restriction on what the numerator measures. The
  demonstration beside it only ever exercises **area over a fixed denominator**.
- The first bullet's "Denominator inside the floodplain — can hold, but check" is anchored on a
  27.51% -> 27.50% case (0.01 pp). But waterbody-share-of-floodplain is a denominator-inside ratio
  that is *predictably* broken by the same construction: 8,185 ha of lakes + wetlands over a
  floodplain that falls 48,116 -> 40,808 ha moves **17.0% -> 20.1%**, ~3 pp, and it can be derived
  from the code without measuring anything. The memo's chosen example is the mild case; a
  3 pp counterexample sits in the appendix it cites.

Narrowing that would hold: say **the floodplain's own area** over a fixed denominator, and say that
a numerator which is a length, a count, or a layer OR'd in independently of `flood_factor` does not
carry the area retention.

Secondary, same lines: the license is close to vacuous even where it is right. "Its own group's
retention" is `corrected_area / pre-fix_area` for that group — knowing it is equivalent to already
having the corrected area, which is the re-run the prohibition demands. And `:137-139` states that
for the one group under discussion "no corrected run of *its* lineage exists", so the exception
cannot be exercised on the example it sits beside.

### 2. **[bug]** `inst/notes/floodplain_interpretation.md:150-151` — "A restatement factor measured on one dataset does not transfer to another" is a universal negative falsified by the memo's own table 40 lines above

Population **is** enumerable from the memo — the three datasets at `:108-111`:

| dataset | ff04 retention |
|---|---|
| bundled 10 m tile | 48.64% |
| Parsnip WSG, MRDEM-30 | 84.65% |
| `restoration_wedzin_kwa_2024`, MRDEM-30 | 83.89% |

The claim holds for either 30 m watershed against the 10 m tile. It **fails** for the pair the memo
itself supplies:

```
Parsnip factor applied to wedzin_kwa: 17,100.7 x 0.846508 = 14,475.9 ha
measured                                                    14,345.3 ha
error 0.91%   (reverse direction: 40,771.8 vs 41,142.9, error -0.90%)
```

Under 1% — inside the memo's own printing precision everywhere it quotes hectares to one decimal.
So a factor measured on one dataset transfers to another perfectly well when the binding criterion
and DEM resolution match; what does not transfer is across those axes, which is exactly what the
preceding sentence ("because there the slope and cost criteria bind before the flood mask does")
already establishes.

It also sits against `:129-131`, which licenses transferring a factor ("Rescaling works only with
*this* group's own retention"): one sentence permits a rescale, the other denies transfer
categorically.

Narrowing that holds: "cannot be assumed to transfer — the two 30 m watersheds agree to within 1%,
while the 10 m tile is 36 points away."

### 3. **[fragile]** `inst/notes/floodplain_interpretation.md:125` — "published as `fp_pct_aoi` in every fish-passage report appendix" quantifies over other repos' contents, the category a round-4 clause was cut for

Population: fish-passage report appendices. Not enumerable from the memo. Measured across
`~/Projects/repo/fish_passage_*` (8 repos):

| repo | defines `fp_pct_aoi` | has `*appendix-floodplain*` |
|---|---|---|
| `fish_passage_peace_2025_reporting` | yes | yes |
| `fish_passage_skeena_2025_reporting` | yes | yes |
| `fish_passage_fraser_2025_reporting` | yes | yes |
| `fish_passage_template_reporting` | **no** | **no** |
| `fish_passage_peace_2024_reporting` | no | no |
| `fish_passage_skeena_2024_reporting` | no | no |
| `fish_passage_fraser_2023_reporting` | no | no |
| `fish_passage_hctf_skeena_fraser_2026_proposal` | no | no |

True if "appendix" means "floodplain appendix" (3/3). False if it means "fish-passage report"
(3/8) — and the miss includes `fish_passage_template_reporting`, the canonical structure the port
workflow routes through, whose backfill CLAUDE.md records as still outstanding.

This is the same shape as the clause round 4 **cut** for asserting other repos' data provenance
without verification. It survived because it reads as background rather than as evidence. Narrow to
"in the peace, skeena and fraser 2025 report appendices" or "in each fish-passage report appendix
that carries a floodplain delineation".

### 4. **[fragile]** `inst/notes/floodplain_interpretation.md:145-147` — "by construction, since `flood_factor` only raises the waterline and every other criterion is independent of it": the quantifier holds, but the premise is necessary and not sufficient, and the gap is the same steps finding 1 turns on

The population **is** enumerable — section 1's table defines exactly four criteria, so "every other
criterion" is {slope, distance, cost-distance}, three members. The claim holds, verified in code
(`R/fl_valley_confine.R:212-219`): `fl_mask(slope, ...)`, `fl_mask_distance(stream_r, ...)`,
`fl_cost_distance(slope, stream_r)` — none reads `flood_factor`. Criterion 4 is monotone in
`flood_factor`: `fl_flood_surface()` adds `bankfull_depth * flood_factor` at stream cells
(`R/fl_flood_surface.R:100-107`) and `fl_flood_depth()` interpolates with IDW weights that depend
only on distance (`R/fl_flood_depth.R:80-84`), so the interpolated surface is affine and increasing
in `flood_factor` everywhere.

The gap: section 1 puts the cleanup and the two ORs **outside** "criterion" ("Then it tidies up …
and adds the channel itself plus any waterbodies supplied"), so the stated premise does not cover
them — and the conclusion "by construction" needs them to be **order-preserving**. They are, which
is why this is fragile and not a bug:

| step | line | order-preserving under set inclusion |
|---|---|---|
| closing (focal max then focal min) | 236-237 | yes — dilation and erosion are both monotone |
| fill holes below `hole_threshold` | 240-251 | yes — a hole of the larger mask is a subset of a hole of the smaller, so still under threshold |
| `fl_patch_rm(min_area)` | 254 | yes — a surviving patch is contained in a patch at least as large |
| 3x3 modal filter | 257 | yes — window 1-count is monotone, and majority is a threshold on it |
| channel buffer OR, waterbodies OR | 277, 290 | yes — constant in `flood_factor` |

So the conclusion stands. Worth stating the missing premise explicitly, because it is exactly the
set of steps that makes finding 1 true — the ORs being independent of `flood_factor` is what
preserves the ranking *and* what breaks the waterbody rescale.

Note also that this round-4 fix is the one **widening** in the set: "on every run recorded here"
(finite, enumerable, and vacuous for the run in question) became a deductive claim over all
possible runs. It happens to be sound. But it is a widening, and it was justified by a premise that
does not by itself reach the conclusion.

### 5. **[fragile]** `inst/notes/floodplain_interpretation.md:148-149` — the "(section 9)" pointer lands on the surviving half of the 48.6% collision

Round-4 fix 5 removed the collision on the retention side by writing the bound as "roughly 49% to
85% *retained*". The gap side still prints **48.6%** at `:149` and points the reader at section 9,
whose table prints **48.6%** in a column headed *retained* (`:275`). The two are different
quantities:

```
gap:       (476.8 - 320.8) / 320.8 = 48.628%
retention:  23,192 / 47,681         = 48.640%
```

The pointer is not broken — section 9 does carry the two areas the gap is computed from — but it
sends a reader verifying a gap to a cell where the same string means a retention. Cheapest fix:
cite the areas rather than the section ("320.8 -> 476.8 ha"), or write the gap to one more digit.

---

## Complete quantifier enumeration

Every quantifier in the 53 added lines. Numbering is the added-line numbering from
`git diff --cached -U0`.

| # | added line | quantifier | population | enumerable from the memo? | holds? |
|---|---|---|---|---|---|
| 1 | 1 | "a ratio survives **only if** num and denom moved together" | all ratios | n/a — tautology | yes |
| 2 | 4 | "**only** because the over-mapped margin happened to carry the core's mix" | the one wedzin_kwa case | yes | yes — narrowing |
| 3 | 5, 23 | "**one measured case**, not a rule" | 1 | yes | yes — narrowing |
| 4 | 6 | "on **the same** basis" | the 2 peace/flooded clipped figures | yes | yes (both clipped) |
| 5 | 9 | "**by construction**" (CLAUDE.md ranking) | all runs | no | yes — see finding 4 |
| 6 | 9 | "`flood_factor` **only** raises the waterline" | the flood surface | yes (§2) | yes — `R/fl_flood_surface.R:100-107` |
| 7 | 12 | "the gap is **only** 4.6%" | Parsnip ff06-ff04 | yes | yes — 4.5517% |
| 8 | 13 | "**absolute hectare claims from 0.4.1** need restating" | all 0.4.1 claims | no | precautionary instruction, not a factual universal |
| 9 | 21 | "almost **exactly** the land-cover mix" | 1 case | yes | yes — 27.51 -> 27.50 |
| 10 | 25 | "**every** fish-passage report appendix" | other repos | **no** | **finding 3** |
| 11 | 27 | "measured **the same** way" | the 2 clipped figures | yes | yes |
| 12 | 28, 30 | "falls **exactly** as the area does" | area-over-fixed-denominator | partly | yes for area; **finding 1** for the generalisation |
| 13 | 29 | "**has to** be re-run, not held" | shares of this shape | no | tension with `:320-321`, **finding 1** |
| 14 | 29 | "Rescaling works **only** with *this* group's own retention" | rescaling operations | no | **finding 1** (vacuity) |
| 15 | 31 | "**never** with a retention borrowed from another dataset" | other datasets | no | over-strict; cf. **finding 2** (0.9% transfer error between the two 30 m runs) |
| 16 | 31-32 | "those run from roughly **49% to 85%** retained **across the figures in this memo**" | retentions stated or derivable in the memo | **yes** | **yes** — see table below |
| 17 | 34 | "**Both** figures are the floodplain clipped" | 2 | yes | yes — 48,116.2027 and 40,807.8791 |
| 18 | 36 | "**the same** two layers" unclipped give 8.67% / 7.35% | 2 | yes | yes |
| 19 | 38 | "**no** corrected run of *its* lineage exists" | peace-lineage runs | no | committed artifact confirmed pre-fix (520,360 cells / 48,540.80 ha); self-limiting hedge |
| 20 | 40 | "the fall is ~15% from **either** pre-fix layer" | 2 | yes | yes — 15.35% / 15.24%, correctly attributed |
| 21 | 41 | "**both** unclipped so the comparison isolates the lineage" | 2 | yes | yes — clipping held constant, only the pre-fix lineage varies |
| 22 | 44 | "**each** scenario carried the same error" | ff02/ff04/ff06 | yes | yes — the 3.5926x is a factor on depth, common to all |
| 23 | 46 | "**every other criterion** is independent of it" | {slope, distance, cost} | **yes** (§1) | **yes** — but see **finding 4** |
| 24 | 47 | "not **even predictably** in direction" | the 2 measured gaps | yes | yes — one widened, one narrowed |
| 25 | 51 | "**does not transfer** to another" | the memo's 3 datasets | **yes** | **no — finding 2** |
| 26 | 52 | "a *share* of a fixed denominator **may** be rescaled" | shares with a fixed denominator | no | **no — finding 1** |

### Item 16 worked exhaustively — the retention bound holds

Every retention figure stated or directly derivable in the memo:

| source | retention |
|---|---|
| §9 table, `ff04` | 48.64% ← **lower bound** |
| §9 table, `ff06` | 53.56% |
| §9 table, `ff02` | 57.80% |
| §8, wrong-column subset (not a units-fix retention) | 59.90% |
| §4 bullet, `restoration_wedzin_kwa_2024` "84%" | 83.89% |
| §4 bullet, Parsnip "84.7%" / prose "15.35% on this package's own" | 84.65% |
| §4 prose, "15.24% from the peace raster" | 84.76% |
| §4 prose, clipped pair "falls ~15%" | 84.81% ← **upper bound** |

48.64% -> "roughly 49%"; 84.81% -> "roughly 85%". Both bounds hold, and the scoping to *this memo*
correctly excludes `methodology.md`'s 88.5% and 90.1%, which are cross-scenario ratios against the
as-coded `ff04` rather than retentions — the round-2 defect, now properly fenced. The only ratios in
the memo below 49% are the §9 bankfull **depths** (0.21/0.77 = 27.3%, 0.42/1.50 = 28.0%,
1.28/4.60 = 27.8%, 2.50/9.00 = 27.8%, all ≈ 1/3.5926), which are never called "retained" and are
not areas. Round-4 fixes 2 and 5 both hold.

---

## Round-4 fixes: widened or narrowed?

| # | fix | verdict |
|---|---|---|
| 1 | "15.35% on this package's own, 15.24% from the peace raster, both unclipped" | **narrowed, holds.** One axis varies (pre-fix lineage); clipping held constant; both attributions correct. |
| 2 | "roughly 49% to 85% *retained* across the figures in this memo" | **narrowed, holds.** Bounds verified over the complete set. Cutting the skeena/fraser clause was right. |
| 3 | CLAUDE.md "the corrected `ff06`–`ff04` gap" | **narrowed, holds.** 4.5517% -> 4.6%. |
| 4 | "by construction, since … every other criterion is independent of it" | **widened.** Finite empirical claim replaced by a universal deductive one. Sound, but the stated premise does not reach the conclusion — **finding 4**. |
| 5 | retention bound written as "roughly 49% … *retained*" | **narrowed, holds** — but the 48.6% collision survives on the gap side at the pointer — **finding 5**. |
| 6 | Open-items "a *share* of a fixed denominator may be rescaled by its own group's retention" | **widened, and it breaks.** Subject is "a *share*", unrestricted in what the numerator measures — **finding 1**. |
| 7 | CLAUDE.md "by construction, since `flood_factor` only raises the waterline" | **narrowed, holds.** Shorter than the memo's version but not in conflict with it. |

So the mechanism round 4 named is **not terminated**: 2 of 7 fixes widened, and both widenings are
findings here (one sound-but-under-justified, one broken). The five that narrowed all hold.

---

## Arithmetic verification

All values recomputed from the settled constants (AOI 559,660.47 ha, cell area 932.8312 m²) and
cross-checked against `fish_passage_peace_2025_reporting/data/gis/pars_valleys.tif`
(520,360 cells / 48,540.8043 ha at 30.54229 m, read directly) and the rendered
`docs/app-floodplain.html` Table 5.9 (48,116 ha, 8.6).

| claim | computed | printed | ok |
|---|---|---|---|
| peace clipped ha / % | 48,116.2027 / 8.5974% | 48,116 / 8.6% | yes |
| corrected clipped ha / % | 40,807.8791 / 7.2915% | 40,807.9 / 7.3% | yes |
| unclipped pair | 8.6733% / 7.3514% | 8.67% / 7.35% | yes |
| AOI | 5,596.6047 km² | 5,596.6 km² | yes |
| cell difference | 521,028 − 520,360 = 668; 62.3131 ha | 668 cells (62.3 ha) | yes |
| fall, own lineage | 15.3493% | 15.35% | yes |
| fall, peace raster | 15.2406% | 15.24% | yes |
| fall, clipped pair | 15.1889% | "~15%" | yes |
| `ff06`–`ff04` 10 m, pre / post | 12.5000% / 23.8896% | 12.5% / 23.9% | yes |
| `ff04`–`ff02` 10 m, pre / post | 48.6284% / 25.0809% | 48.6% / 25.1% | yes |
| Parsnip `ff06`–`ff04` | 4.5517% | 4.6% | yes |
| wedzin_kwa area fall | 16.11% | "fell 16%" | yes |
| §9 retentions | 57.80 / 48.64 / 53.56% | 57.8 / 48.6 / 53.6% | yes |

Pointers checked and correct: `flood-load` chunk (`0730-appendix-floodplain.Rmd:14`, the
`st_intersection(floodplain, aoi)` at line 41, before the `flood-rollup` measuring chunk at line
50); `methodology.md` lines 94-96 carry 41,142.9 / 43,015.6 / 43,780.8; section 9's table carries
the 10 m areas.

One pointer hazard worth naming, below finding level: `:149-150` cites `methodology.md` for a
**4.6%** gap, and the figure `methodology.md` actually prints in that paragraph is **6.4%**
(`ff04` -> `ff07`, verified 6.4117%). Both are right, for different pairs, and they are digit
transpositions of each other.

---

## Residual

The enumeration is complete over the 53 added lines — the token sweep is mechanical and every hit
is accounted for in the table above. Three quantifiers do not hold (findings 1, 2, 3), one holds on
an incomplete premise (finding 4), and one collision survives at a pointer (finding 5).

After those, the residual is stateable precisely rather than merely unlikely:

> Two negative existentials about artifacts **outside this repository at a point in time** —
> `:137-139` "no corrected run of *its* lineage exists" and the implicit claim behind finding 3 that
> the three 2025 report appendices are the whole population. Neither is checkable from the memo, and
> both hedge the memo's own claim *downward*, so a wrong one weakens the memo rather than
> over-claiming through it. I verified as far as artifacts allow: `pars_valleys.tif` is pre-fix
> (520,360 cells), and the 8 `fish_passage_*` repos enumerate as tabled above. Both facts have a
> date on them and no mechanism in this repo to keep them true.

That is definitional — a memo in one repo cannot close a quantifier over another repo's working
tree. It is not a sixth instance of the round-4 mechanism, because the direction of failure is
against the memo's own interest rather than in favour of it.
