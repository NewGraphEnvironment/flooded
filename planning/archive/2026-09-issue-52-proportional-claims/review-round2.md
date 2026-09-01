# Review round 2 — staged prose diff, `inst/notes/floodplain_interpretation.md` + `CLAUDE.md` (#52)

Scope: the staged diff, reviewed as *fixes* to round 1. Every number below was recomputed from the
committed artifacts and the consuming code; nothing is taken from `findings.md`, `task_plan.md` or
`review-round1.md`.

Constants used throughout, as settled in round 1: AOI = 5,596.6047 km² = 559,660.47 ha; cell area
932.8312 m²; `sf_use_s2(FALSE)`.

**Verified clean (no action):**

- `48,116 ha` / `8.6%` is what the peace report publishes — confirmed in the rendered
  `fish_passage_peace_2025_reporting/docs/app-floodplain.html`: table rows
  `Floodplain area (ha) => 48,116`, `Floodplain as % of watershed group => 8.6`, and the prose
  "covers about 48,116 ha, or 8.6 % of the watershed group". Not a prediction.
- `40,807.9 ha — 7.3%`: 100 × 40,807.8791 / 559,660.47 = **7.291542%**, `sprintf("%.1f", …)` = `7.3`. ✓
- "The share falls the same ~15% as the area": area (48,116.2027 − 40,807.8791) / 48,116.2027 =
  **15.1889%**; share (8.597392 − 7.291542) / 8.597392 = **15.1889%**. Identical, as it must be with a
  fixed denominator. ✓
- "smaller by 668 cells / 62.3 ha": 521,028 − 520,360 = 668; 668 × 932.8312 = 623,131 m² = **62.31 ha**;
  and 48,603.1174 − 48,540.8043 = **62.313**. Direction correct — peace's raster is the smaller one. ✓
- "`fp_pct_aoi` … in every fish-passage report appendix beside the hectares": true in all three.
  `fp_pct_aoi <- 100 * fp_area_ha / (aoi_area_km2 * 100)` at peace `0730-appendix-floodplain.Rmd:53`,
  skeena `0720-appendix-floodplain.Rmd:55`, fraser `0720-appendix-floodplain.Rmd:53`, and rendered in
  each appendix's metric table on the row immediately below "Floodplain area (ha)". ✓
- "disturbed area fell 16%": (17,100.7 − 14,345.3) / 17,100.7 = **16.11%**. ✓
- `CLAUDE.md` hunk: `8.6% -> 7.3% as published` ✓, `raw layer's 8.67%` (= 8.6733%) ✓, 27.51 -> 27.50 ✓.
  Numerically consistent with the memo. It also does *not* carry the "higher, drier ground" assertion
  in finding 4, so only the memo needs that change.

---

## Findings

### 1. **[bug]** `inst/notes/floodplain_interpretation.md:131` — "48,540.8 … quoted elsewhere in this memo" is false, and the pair crosses the two lineages the next sentence warns about

The sentence reads: *"where the unclipped rasters quoted elsewhere in this memo, 48,540.8 and
41,142.9 ha, round to 8.7% and 7.4% instead."*

`41,142.9` is quoted elsewhere (line 109). `48,540.8` is **not**. Searched every tracked file:

```
$ git grep -n "48,540\|48540" -- .
inst/notes/floodplain_interpretation.md:131     <- the sentence itself
planning/active/findings.md:35,58,80            <- planning, not the memo
planning/active/task_plan.md:27
```

The memo's own unclipped pre-fix figure is **48,603.1** (line 109), which is also what
`methodology.md:93` and `NEWS.md:75` carry. Nothing outside the planning files has ever quoted
48,540.8.

Worse than a dangling pointer, the two numbers are from **different runs** — the same fact the
parenthetical two lines later exists to state:

| | cells | ha |
|---|---|---|
| peace `data/gis/pars_valleys.tif`, pre-fix | 520,360 | 520,360 × 932.8312 / 1e4 = **48,540.80** |
| flooded's 0.4.1 artifact (`methodology.md:93`) | 521,028 | **48,603.12** |
| flooded corrected | 441,054 | **41,142.89** |

So "48,540.8 and 41,142.9" is peace-lineage paired with flooded-lineage, in the clause immediately
preceding *"the two should not be paired as though they were one delineation."*

**The rounding conclusion survives either way**, so this is a provenance fix, not a numbers fix:

```
100 * 48,540.8040 / 559,660.47 = 8.673259 %  -> "8.7"
100 * 48,603.1174 / 559,660.47 = 8.684393 %  -> "8.7"
```

Fix: either drop "quoted elsewhere in this memo" and attribute 48,540.8 to the peace layer
explicitly (it is the correct unclipped counterpart of 48,116.2, so the paragraph needs *that*
number, not 48,603.1), or say "the unclipped peace layer, 48,540.8 ha, and this package's corrected
41,142.9 ha".

---

### 2. **[bug]** `inst/notes/floodplain_interpretation.md:125-127` vs `:132-134` — the bullet performs the pairing the parenthetical forbids

Bullet: *"The peace report publishes **48,116 ha — 8.6%** …; **re-measured the same way on the
corrected delineation**, **40,807.9 ha — 7.3%**. The share falls the same ~15% as the area."*

Parenthetical, nine lines later: *"The peace report's committed pre-fix raster is also a *different
run* from this package's … so the two should not be paired as though they were one delineation."*

That is a straight internal contradiction, and the bullet is the load-bearing half — it is the
before/after the reader will quote. "Re-measured the same way on the corrected delineation" is true
of the *method* (clip, then `st_area`) and false of the *subject*: 48,116.2 is the clip of peace's
520,360-cell layer, 40,807.9 is the clip of this package's 441,054-cell layer, and no run corrected
the former into the latter.

Round 1's finding 2 removed "the same delineation" from one sentence; the fix reintroduced the same
identity claim in a different sentence ("the corrected delineation", "re-measured the same way") and
then wrote the disclaimer beside it instead of into it. `planning/active/findings.md:63` records the
intent as *"the memo now says they are different runs and should not be paired"* — which the bullet
does not honour.

**The ~15% is robust to the lineage, so only the sentence needs repair:**

```
same lineage   (48,603.1 -> 41,142.9, raw)      = 15.349 %
cross lineage  (48,540.8 -> 41,142.9, raw)      = 15.241 %
cross lineage  (48,116.2 -> 40,807.9, clipped)  = 15.189 %
```

Fix: say what it is — "this package's corrected delineation of the same watershed group, measured the
same way, gives 40,807.9 ha — 7.3%; the two are different runs (see below), and the ~15% fall is the
same on either lineage." Then the parenthetical is supporting detail rather than a retraction.

---

### 3. **[bug]** `inst/notes/floodplain_interpretation.md:129-130` — the clip is not in the rollup chunk

*"— `sf::st_intersection()`, in the appendix's own rollup chunk —"*

The floodplain→AOI clip is in the **`flood-load`** chunk, not `flood-rollup`, in all three repos:

| repo | file | clip line | `flood-load` | `flood-rollup` |
|---|---|---|---|---|
| peace | `0730-appendix-floodplain.Rmd` | **41** | 14–48 | 50–64 |
| skeena | `0720-appendix-floodplain.Rmd` | **43** | 14–50 | 52–… |
| fraser | `0720-appendix-floodplain.Rmd` | **41** | 14–48 | 50–… |

peace `0730:41`:
```r
floodplain  <- suppressWarnings(sf::st_intersection(floodplain,  aoi))
```
peace `0730:50-53` (`flood-rollup`) contains no such call for the floodplain — it computes
`st_area()` on the already-clipped object, and its own `st_intersection()` calls are
`streams_in_fp` and `wb_in_fp`, which are streams/waterbodies against the floodplain, a different
operation.

This matters because the sentence's only job is to tell a reader **where to go and check**. Sent to
`flood-rollup`, they find `st_intersection` calls that are not the clip, and the natural reading —
"the clip is the streams-into-floodplain step" — is wrong. Round 1's own write-up cited `:42`
without naming a chunk, which was correct; naming the chunk introduced the error.

---

### 4. **[bug]** `inst/notes/floodplain_interpretation.md:120-122` — "the margin is systematically the higher, drier ground farther from the channel" is one supportable claim carrying two unsupported ones, and "drier" contradicts section 6

Taken apart against what the package computes:

- **"higher" — supported.** Criterion 4 is `depth = surface_full - dem`, `NA` where negative
  (`R/fl_flood_depth.R:86,91`). Lowering `flood_depth` by 3.5926× lowers the draped surface, so the
  cells that leave are exactly those whose DEM sits between the corrected and as-coded waterlines —
  the highest ground relative to the modelled waterline, by construction. Section 9's "strict subset
  — 0 cells gained" is the same fact.

- **"farther from the channel" — not supported.** The drape is `terra::interpIDW` from stream cells
  (`R/fl_flood_depth.R:78`), and inclusion is decided cell-by-cell by `dem - surface_interp`, i.e.
  local height above the interpolated waterline. Distance is a *separate* criterion (criterion 2,
  `fl_mask_distance(stream_r, threshold = max_width/2)`, `R/fl_valley_confine.R:215`) and does not
  order the criterion-4 removals. A steep bank 30 m from the channel is dropped while flat ground
  800 m out is kept. Section 4's own premise cuts the other way too: on MRDEM-30 "slope and cost bind
  first", so over much of the perimeter criterion 4 is *not* the binding one and nothing is removed
  at the outer edge at all.

- **"drier" — not computed, and contradicted 60 lines later.** Section 1:32 states the model is *"a
  **relative-elevation filter**, not a simulation"*, and section 5 lists "recurrent inundation" as
  **not defensible**. Section 6 then argues the opposite of "drier" at length: the hyporheic alluvial
  aquifer *"occupies valley-bottom alluvium well beyond the annually inundated zone"* (:172-176) and
  side channels *"persist without overbank flow"* (:178-181). A memo that spends a section
  establishing that outer valley bottom is not dry should not describe the outer margin as "drier"
  in an earlier section.

- **"systematically" — an unmeasured generality**, held to a lower standard than the memo applies to
  itself at section 7 item 2: *"The direction of that limitation follows from the equation's form;
  its magnitude in BC is uncited and should not be asserted."*

The bullet's actual point does not need any of the three. It needs only: *the margin is not a random
sample of the floodplain — it is the ground the relative-elevation filter removes, i.e. the highest
ground relative to the modelled waterline, so there is no reason its land-cover mix should match the
core's.* That is derivable from criterion 4 alone and says everything the sentence is doing.

---

### 5. **[bug]** `inst/notes/floodplain_interpretation.md:137-138` — "Scenario-to-scenario comparisons are unaffected on every dataset" is contradicted by the memo's own section 9 table

Carried through verbatim from the removed hunk into the added one, so it is in the diff.

If every scenario scaled together, retention would be constant across scenarios. Section 9:261-263
shows it is not — 57.8% / 48.6% / 53.6% — because the slope and cost masks clamp the inflated
waterline non-uniformly. Working the ratios from the memo's own figures:

```
ff04/ff02   as-coded 476.8/320.8 = 1.4863   corrected 231.9/185.4 = 1.2508   ratio -15.8%
ff06/ff04   as-coded 536.4/476.8 = 1.1250   corrected 287.3/231.9 = 1.2389   ratio +10.1%
ff06/ff02   as-coded 536.4/320.8 = 1.6721   corrected 287.3/185.4 = 1.5496   ratio  -7.3%
```

So a 0.4.1 report stating "`ff06` maps **12.5%** more valley bottom than `ff04`" restates to
**23.9%** — nearly double. That is precisely the class of claim this section exists to adjudicate,
and the memo currently green-lights it.

What *is* unaffected is the **ordering**: each scenario is still a superset of the one below, and
"`ff06` > `ff04` > `ff02`" holds. The premise "each scenario carried the same error" is true of the
depth multiplier and does not propagate to mapped extent, because the masks are non-linear.

Fix: narrow to the rank claim — "the *ordering* of scenarios is unaffected; the *ratios between*
them are not, since the criteria clamp each scenario differently (section 9)."

---

### 6. **[fragile]** `inst/notes/floodplain_interpretation.md:119` vs `:124` — "AOI" names the floodplain in one bullet and the watershed group in the next

Bullet 1: "disturbed-as-a-share-of-**AOI** went 27.51% -> 27.50%", filed under *"Denominator inside
the floodplain"*. Bullet 2: "`fp_pct_**aoi**`", where `aoi` is the watershed-group layer
(`0730-appendix-floodplain.Rmd:51-53`, `aoi_area_km2 <- sum(st_area(aoi))/1e6`).

Bullet 1's AOI really is the floodplain, provably — if the denominator were the fixed watershed the
share would have fallen with the area:

```
implied disturbed ha:  0.2751 x 17,100.7 = 4,704.4  ->  0.2750 x 14,345.3 = 3,945.0   (-16.1%)
denominator:                    17,100.7            ->            14,345.3            (-16.1%)
against a fixed watershed the share would have fallen ~16%, not held at 27.5%
```

`CLAUDE.md` renders the same fact unambiguously as *"Land-cover composition **within the
floodplain**"*. The memo does not, and this is the one passage in the package where the word carries
both denominators three lines apart — in a section whose entire thesis is "ask where the denominator
sits". The pre-fix text had only bullet 1; the restructure created the collision.

Fix: in bullet 1 say "disturbed-as-a-share-of-floodplain (the floodplain polygon *is* the AOI handed
to `drift`)", and leave `fp_pct_aoi` to mean the watershed group.

---

### 7. **[fragile]** `inst/notes/floodplain_interpretation.md:131-132` — "7.4%" is 8 ha from printing 7.3

```
100 * 41,142.8929 / 559,660.47 = 7.351402 %
rounding boundary                7.35     %
margin                           0.001402 pp
```

In hectares: 7.35% of the AOI is 41,135.04 ha, so the figure clears the boundary by **7.85 ha out of
41,142.89 — 0.019%**. An AOI restated 0.02% larger, or a floodplain layer 8 ha smaller, prints
`7.3` and the sentence's contrast collapses to one number instead of two (8.7 vs 8.6 is safe; that
one clears its boundary by 0.17 pp, 120× the margin).

The paragraph is really about the two-decimal quantities (8.67% / 7.35%), which are unambiguous. As
written it invites someone to quote "the raw layer gives 7.4%" and be contradicted by a colleague
re-running against a marginally different group boundary. Either quote the percentages the paragraph
is actually reasoning about, or say "7.35%, which prints 7.4 but only just".

---

## Round-1 fixes: verdict

| round-1 finding | fix landed? | round-2 note |
|---|---|---|
| 1. published figures wrong (48,540.8/8.67% -> 48,116/8.6%) | **yes**, correct | new figures verified against rendered HTML; but the added paragraph introduced findings 1, 3, 7 |
| 2. "same pre-fix run" false | **partly** — stated, then contradicted | finding 2 |
| 3. n=1 stated as a rule | **yes** — "can hold, but check" + "one measured case, not a rule" | the *reason* given is unsound — finding 4 |
| 4. dichotomy neither necessary nor sufficient | **yes** — "moved together" is the right invariant | but "Scenario-to-scenario comparisons are unaffected" (finding 5) is the same over-claim one level down |
