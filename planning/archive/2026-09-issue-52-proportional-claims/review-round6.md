# Review round 6 — staged prose diff (`inst/notes/floodplain_interpretation.md`, `CLAUDE.md`)

Verdict on the round-4 mechanism: **not terminated at round 5.** One round-5 fix
(fix #1) narrowed the rescale license correctly *and, in the same sentence, added a new
absolute invariance claim over an unmeasured population*. That claim is now measured and
is **false**. Everything else round 5 wrote survives verification, including the two
claims most likely to have failed (`the rule reaches two`, `all order-preserving`) —
both hold under direct measurement.

Method note: 0.4.1 is exactly reproducible from current code, because the units defect
multiplied bankfull depth by a constant 3.5926 and `flood_depth = bankfull_depth *
flood_factor`. So `flood_factor = 4 * 3.5926 = 14.3704` on current code **is** 0.4.1's
`ff04`. Confirmation: that run on the cached Parsnip inputs returns **521,028 cells**,
the settled 0.4.1 constant, and `flood_factor = 4` returns **441,054**, the cached
corrected raster. This gives a same-lineage, fix-isolated pair — no lineage confound.

## Findings

- **[bug]** `inst/notes/floodplain_interpretation.md:131-133` — "neither do the
  waterbodies or the channel buffer, which `fl_valley_confine()` unions in independently
  of `flood_factor` and **which therefore do not move with the fix at all**." The
  waterbody rows *do* move with the fix. Measured on the Parsnip WSG, same lineage, same
  inputs, only `flood_factor` differing (14.3704 → 4), rolled up exactly as the peace
  appendix does:

  | appendix row | as-coded `ff04` | corrected `ff04` | ratio |
  |---|---|---|---|
  | Floodplain area (ha) | 48,177.580 | 40,807.879 | 0.847030 |
  | Floodplain as % of WSG | 8.6084 | 7.2915 | 0.847030 |
  | Streams, order 3+ (km) | 2,309.858 | 2,309.858 | 1.000000 |
  | Streams within floodplain (km) | 1,579.235 | 1,538.343 | 0.974106 |
  | Lakes within floodplain (count) | 198 | 198 | 1.000000 |
  | **Lakes within floodplain (ha)** | **1,603.012** | **1,598.819** | **0.997384** |
  | Wetlands within floodplain (count) | 464 | 464 | 1.000000 |
  | **Wetlands within floodplain (ha)** | **6,582.852** | **6,538.329** | **0.993236** |

  −4.193 ha (−0.262%) and −44.523 ha (−0.677%). Not a rounding artifact: the digits the
  report prints move, **1,603 → 1,599 ha** and **6,583 → 6,538 ha**.

  The mechanism, and it is structural rather than incidental: `terra::rasterize()` burns
  a cell only when its centre is covered, so a waterbody's fringe is in the floodplain
  only where the *VCA mask* covers it — and that mask shrinks with the fix. Measured on
  the corrected Parsnip delineation, **22.97 ha of lake and 105.66 ha of wetland area
  supplied to the model sit outside the resulting floodplain** (1,621.79 → 1,598.82 ha
  and 6,643.99 → 6,538.33 ha). The unioned set is invariant; the *published* row is
  `waterbodies ∩ floodplain`, which is not the unioned set.

  This is the round-4 mechanism recurring inside round-5's own fix: the sentence repairs
  an over-broad license by asserting a *new* absolute ("at all") over a population
  (everything waterbody- or channel-buffer-derived) that was not enumerated or measured.
  The first half of the clause — that they do not **rescale by the retention** — is true
  and is what the measurement supports; only the "do not move at all" extension is false.
  Note the Open-items sentence already carries the correct, milder form ("it does not
  extend to lengths, counts, or the waterbodies and channel buffer") and needs no change.

- **[fragile]** `floodplain_interpretation.md:133-134` vs `:324-325` — "the rule reaches
  **two**" against "The **single** exception is the floodplain's own area as a share of a
  fixed denominator." The count **two is arithmetically correct**: exactly two of the
  seven rows carry the retention ratio, 0.847030 to six places (Floodplain area ha,
  Floodplain as % of WSG); no other row is within 0.12 of it. But a reader cannot derive
  "two" from the rule as worded — the preceding sentence defines the rule as "the
  floodplain's *own area* over a fixed denominator", which names **one** thing, and the
  Open-items line then says "single". The two statements are reconcilable (the raw-hectare
  row rescales by the retention only circularly, since you must have re-run it to know the
  retention, so it is not an *exception to the re-run prohibition*) but nothing in the
  text does the reconciling. Name the two rows.

  For the record, "floodplain-derived" **is** a well-defined division of that table and 7
  is correct: of the 9 rows in the `flood-table` chunk
  (`fish_passage_peace_2025_reporting/0730-appendix-floodplain.Rmd:78-108`), only
  "Watershed group area (km²)" and "Bull trout accessible streams, order 3+ (km)" are
  computed without the floodplain layer — confirmed by measurement, the second is the one
  row with ratio exactly 1.000000 for a non-count. The skeena and fraser appendices carry
  the identical 9-row structure.

- **[fragile]** `floodplain_interpretation.md:151` — "`ff04`–`ff02` narrows, 48.63% ->
  **25.08%** (section 9)". The exact value is **25.07%**. From section 9's cell counts,
  (23,192 − 18,543)/18,543 = 25.0715%; from exact hectares, (231.92 − 185.43)/185.43 =
  25.0715%. 25.08% is reproducible only from section 9's *rounded* hectares
  (231.9/185.4 = 25.0809%), i.e. the second decimal is an artifact of 0.1-ha rounding in
  the inputs. The companion 48.63% is right either way (48.6269% from cells, 48.6284%
  from rounded ha). This matters precisely because round-5 fix #5 added the second decimal
  so a reader could verify against section 9 — and the more authoritative column there
  gives 25.07. `CLAUDE.md`'s 1-decimal form (25.1%) is unaffected and correct.

- **[fragile]** `floodplain_interpretation.md:154-155` — "the two 30 m watersheds here
  agree to within 1%, while the 10 m tile sits **36 points** of retention away." The
  first half is right in both readings: 84.6507% vs 83.8872% is 0.7635 points, 0.902%
  relative to Parsnip and 0.910% relative to wedzin_kwa. The second half gives one number
  for a distance that has two values: Parsnip − bundled = **36.011** points, wedzin_kwa −
  bundled = **35.247** points, which rounds to 35, not 36. The sentence's own subject is
  the pair, so "35–36 points" is the exact form. The argument is unaffected; the precision
  is one-sided.

- **[fragile]** `CLAUDE.md:90-91` — "Scenario *ranking* survives such a fix by
  construction, since `flood_factor` only raises the waterline". This is the pre-round-4
  wording: the memo's copy of the same claim was repaired at round 4/5 to carry two more
  premises ("every other criterion is independent of it, and the cleanup steps and the
  channel/waterbody unions are all order-preserving"), and both files are in this one
  staged diff. The claim is true (see next item), but the conventions file states it with
  the premise set that round 4 flagged as not reaching the conclusion. Mirror the memo's
  clause, or drop "by construction" here and point at the memo.

- **[fragile]** `floodplain_interpretation.md:149` — "the cleanup steps and the
  channel/waterbody unions are **all** order-preserving." The claim is **true** — I could
  not break it — but the memo's own enumeration of "the cleanup steps" is 3 of the 4 in
  the code. Section 1 line 29 says "(bridge gaps, fill pinholes, drop specks)"; the code
  and the `fl_valley_confine()` roxygen have a fourth, the 3x3 majority filter
  (`R/fl_valley_confine.R:257`) — the one step whose monotonicity is not obvious, since a
  modal filter with an even window can tie. So a reader auditing "all" against the memo
  audits three quarters of the population. Either name the majority filter in section 1 or
  cite the roxygen list here.

  What I verified, since the claim is load-bearing: closing (dilate then erode) is
  monotone; hole-fill is monotone because `zeros(B) ⊆ zeros(A)` makes each cell's 0-patch
  in B a subset of its 0-patch in A, so anything filled in A is filled in B; patch removal
  is monotone because a cell's component only grows; and the majority filter is monotone
  because terra breaks ties toward 0 (verified: a 2×2 raster `c(1,0,0,1)` and its inverse
  both return all-0 under `focal(w=3, fun="modal", na.rm=TRUE)`, terra 1.9.34), making it
  the threshold function `count(1) > count(0)`. Empirically: 300 randomised nested 12×12
  pairs through the exact cleanup chain, **0 violations**; the bundled tile gives
  ff02 ⊂ ff04 ⊂ ff06 with **0 cells lost** at each step (18,543 / 23,192 / 28,727,
  reproducing section 9 exactly); and at watershed scale on the 20.9 Mcell Parsnip grid
  (`floodplains/data/pars/floodplain_bt_ff0{2,4,6}.tif`, 415,698 / 439,664 / 459,409)
  nesting also holds with 0 cells lost. The premise "every other criterion is independent
  of it" is true by inspection — `mask_slope`, `mask_dist` and `mask_cost` never see
  `flood_factor` (`R/fl_valley_confine.R:212-220`).

- **[fragile]** `floodplain_interpretation.md:124` — the bullet header "**Denominator
  outside the floodplain — moves with the hectares.**" over-claims relative to its own
  body four lines later. The peace appendix's prose publishes exactly such a ratio —
  "attached to 1,580 km of the 2,310 km network" — whose denominator is outside the
  floodplain and which does **not** move with the hectares: streams-within-floodplain
  falls **2.589%** where the hectares fall **15.297%**, a factor of 5.9. The body says so
  ("a numerator that is a length or a count does not"); the header, which is the part that
  gets quoted, does not. Weakest of the findings, listed for completeness of the sweep.

## Quantifier sweep — the closed set

Every scope quantifier in the changed passage, its population, and whether the population
is enumerable. All values below are computed, not recalled.

| # | quantifier | population | enumerable? | holds? |
|---|---|---|---|---|
| 1 | "absolute hectare claims from 0.4.1 need restating" | 0.4.1 outputs | yes (3 datasets in §4) | yes |
| 2 | "for a floodplain-derived numerator … where the denominator sits" | inside / outside dichotomy | yes | yes |
| 3 | "**Denominator inside** — can hold, but check" | 1 measured case | yes | yes, hedged |
| 4 | "one measured case, not a rule" | wedzin_kwa only | yes | yes |
| 5 | "the margin … is the ground criterion 4 removes" | removed cells | yes | yes |
| 6 | "**Denominator outside** — moves with the hectares" | ratios w/ outside denominator | yes | **no** — finding 7 |
| 7 | "in **each** 2025 fish-passage appendix … (peace, skeena, fraser)" | 2025 report repos | yes | yes — all three carry `fp_pct_aoi`; 2024/2023 repos have no floodplain appendix |
| 8 | "48,116 ha — 8.6%" | — | — | yes: 48,116.2027 ha, 8.5974% → `%.1f` = 8.6 |
| 9 | "40,807.9 ha — 7.3%" | — | — | yes: 40,807.8791 ha, 7.2915% → 7.3 |
| 10 | "falls ~15%, **exactly** as the area does" | — | — | yes: 15.1889% both, to 4 dp |
| 11 | "**Only** the floodplain's own area … rescales" | 7 fp-derived rows | yes | yes — measured, only 2 carry 0.847030 |
| 12 | "a length or a count does **not**" | same 7 | yes | yes — 0.974106 / 1.000000 |
| 13 | "neither … waterbodies or channel buffer … **at all**" | same 7 | yes | **no** — finding 1 |
| 14 | "the rule reaches **two**" | same 7 | yes | count right, derivation ambiguous — finding 2 |
| 15 | "**Both** figures are … clipped" | 2 figures | yes | yes — `flood-load` chunk, `0730-appendix-floodplain.Rmd:41` |
| 16 | "unclipped … 8.67% and 7.35%" | — | — | yes: 8.6733% / 7.3514% |
| 17 | "enough to move the digit the report prints" | `%.1f` | yes | yes: 8.6→8.7, 7.3→7.4 |
| 18 | "668 cells (62.3 ha) smaller" | — | — | yes: 521,028−520,360 = 668; ×932.8312 m² = 62.31 ha |
| 19 | "**no** corrected run of *its* lineage exists" | runs | partly | not refuted — the corrected raster is not a subset of the peace one (1,318 cells gained, 80,624 lost), so it is a different lineage; `floodplains/data/pars` holds a **third** |
| 20 | "**either** pre-fix layer … **both** unclipped" | 2 layers | yes | yes: 15.3493% and 15.2406% |
| 21 | "**by construction** … **every** other criterion … **all** order-preserving" | 4 criteria, 4 cleanup steps, 2 unions | yes (roxygen) | yes — but memo enumerates 3 of 4, finding 6 |
| 22 | "not **even** predictably in direction" | 2 gaps | yes | yes: widens 12.49→23.87, narrows 48.63→25.07 |
| 23 | "12.5% -> 23.9%" | — | — | yes: 12.4872% / 23.8660% |
| 24 | "48.63% -> 25.08%" | — | — | **no** — 25.0715%, finding 3 |
| 25 | "gap is 4.6% — 41,142.9 -> 43,015.6 ha" | — | — | yes: 4.5517%; both figures in `methodology.md:94-95` |
| 26 | "**cannot be assumed** to transfer" | — | — | yes, correctly hedged |
| 27 | "agree to **within 1%**" | 2 watersheds | yes | yes: 0.7635 pts / 0.902% |
| 28 | "**36 points** of retention away" | 2 watersheds | yes | one-sided — finding 4 |
| 29 | "The **single** exception" (Open items) | absolute-area claims | yes | yes, but see finding 2 |
| 30 | "falls **exactly** as the area does" (Open items) | — | — | yes: 15.1889% both |
| 31 | "does **not** extend to lengths, counts, or the waterbodies and channel buffer" | 7 rows | yes | yes — this is the correct, milder form of finding 1 |
| 32 | CLAUDE.md "a ratio survives **only** if numerator and denominator moved together" | ratios | yes | yes |
| 33 | CLAUDE.md "8.6% → 7.3% on the same basis" / "raw layer's 8.67%" | — | — | yes |
| 34 | CLAUDE.md "**by construction**, since `flood_factor` only raises the waterline" | premises | yes | true claim, premises short — finding 5 |
| 35 | CLAUDE.md "12.5% -> 23.9%", "48.6% -> 25.1%", "only 4.6%" | — | — | yes, all three correct at 1 dp |

## Round-5 fixes: did any widen?

| fix | verdict |
|---|---|
| 1 — rescale license restricted, "seven rows … reaches two", Open-items narrowed | **half widened.** The enumeration is a genuine narrowing and is correct. The appended "do not move with the fix at all" is a new absolute over an unmeasured population, and is false (finding 1). |
| 2 — "cannot be *assumed* to transfer", 1% / 36 points | narrowed; populations enumerable; one figure one-sided (finding 4) |
| 3 — "(peace, skeena, fraser)" | narrowed; enumeration complete and correct |
| 4 — "all order-preserving" | narrowed; **true** under measurement; the enumeration it points at is 3 of 4 (finding 6) |
| 5 — gap written 48.63% -> 25.08% | narrowed; second decimal wrong (finding 3) |

## Residual, stated exactly

After finding 1 is repaired, one clause in the passage is left that **no available data
can test**, and it is testable-in-principle-nowhere rather than merely unmeasured: the
**channel-buffer** half of "neither do the waterbodies or the channel buffer". The peace
appendix publishes no channel-buffer-derived row — the buffer contributes cells to
`fp_area_ha` and is never reported separately — so against the seven-row enumeration the
clause is attached to, that half is **vacuous**: its population there is empty. That is
definitional, not unlikely.

Everything else in the passage now ranges over a population I enumerated and measured:
the 9 appendix rows (table above), the 3 2025 report repos (checked on disk), the 3
datasets (retentions computed), and the 4 cleanup steps plus 2 unions (each shown
monotone, plus 300 randomised nested pairs and two watershed-scale nesting checks, 0
violations). The one thing I would still call a live risk rather than a residual is that
the waterbody-area movement in finding 1 was measured on Parsnip only; the mechanism
(cell-centre rasterization leaving a waterbody fringe to the VCA mask) is generic at 30 m,
so skeena and fraser will show the same sign, but the magnitude is theirs, not Parsnip's.
