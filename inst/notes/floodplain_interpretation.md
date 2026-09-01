# What the floodplain model actually maps

Plain-language memo for reporting and onboarding. Companion to
[`methodology.md`](methodology.md) (the regressions and scenarios) and
[`../research/vca_parameter_rationale.md`](../research/vca_parameter_rationale.md) (verified
citations). This one answers the questions a reviewer asks: *what is this a map of, what does the
flood factor mean, and can we defend it?*

**Status (2026-08-31):** lit-search pass run against `vca_refs.duckdb`. The units question is
**resolved and it is a code defect** (flooded#49) — read section 4 before quoting any area figure
from this package. Section 6's ecological claims are now sourced. Remaining gaps are listed at the
end; BibTeX keys for the newly cited papers still need generating.

---

## 1. It is a terrain classifier, not a flood model

There is no discharge, no hydrograph and no flood routing anywhere in `flooded`. The model asks four
questions of the *terrain* and keeps ground where all four are true:

| # | Test | Default |
|---|---|---|
| 1 | Is the ground gentle? | slope ≤ 9% |
| 2 | Is it near a stream? | within `max_width/2` = 1,000 m |
| 3 | Is it reachable without climbing? | cost-distance < 2,500 |
| 4 | Is it *low relative to the river*? | the "flood" mask |

Then it tidies up (bridge gaps, fill pinholes, drop specks) and adds the channel itself plus any
waterbodies supplied.

Criterion 4 is the one everybody misreads. It is a **relative-elevation filter**, not a simulation.
Calling it "flood depth" in the code is the source of most of the confusion below.

## 2. How criterion 4 works, in five steps

1. **Burn streams onto the DEM.** Each stream cell carries upstream area and mean annual precip.
2. **Estimate channel size** from those two numbers (the Hall regression, §4).
3. **Raise a waterline:** `flood_depth = bankfull_depth × flood_factor`, added to the DEM elevation
   *at stream cells only*.
4. **Drape it** across the valley by interpolating outward from those cells.
5. **Subtract the ground.** Anywhere the draped surface sits above the terrain is "flooded".

## 3. The flood factor

A dimensionless multiplier on predicted bankfull depth. **It is a fitted index, not a water depth.**

Verified from the literature (@nagel_etal2014LandscapeScale, quotes confirmed against purchased PDFs
2026-03-17):

| ff | Anchored to | Maps to a return period? |
|---|---|---|
| **2** | Rosgen's flood-prone width — "the width measured at an elevation twice the maximum bankfull depth… roughly corresponded with the 50-year flood stage or less" | **Yes** — the only one that does |
| **3** | Hall's best fit for *historical floodplain* width on a 10 m DEM, validated against **213 field-measured floodplain widths** | No — calibrated to mapped floodplain |
| **5** | Clarke et al. (2008), valley-floor width on 10 m DEM | No |
| **5–7** | Nagel's recommended range for *valley bottom* | No — geomorphic envelope |
| **7** | Nagel: most appropriate for **30 m** DEMs | No — resolution compensation |

Two separate jobs are riding on one number:

- **Ecological target** — how much of the valley you mean to include.
- **DEM compensation** — coarse rasters smooth away the small relief that confines water, so you
  raise the waterline to recover the footprint a finer DEM would have found.

| DEM | ff for the *same* real floodplain |
|---|---|
| 1 m lidar | 2–3 |
| 10 m | 3 |
| 25 m TRIM | 4 |
| 30 m MRDEM | up to 7 |

So `ff04` on 25 m TRIM and `ff03` on 10 m are aiming at **the same ecological thing**. Comparing
`ff04` on 30 m against `ff04` on 10 m compares two different things.

## 4. Is "4× bankfull" an impossible flood? Partly, and that is a bug

The obvious objection: at-a-station hydraulic geometry means depth responds only weakly to
discharge, so a waterline at 4× bankfull depth would need a discharge far beyond any real flood.

Three reasons that objection does **not** land against the model as designed:

1. **The DEM's "streambed" is not the streambed.** Neither lidar nor MRDEM penetrates water, so the
   stream cell holds roughly the water surface at acquisition, blended with banks at 10–30 m. The
   multiplier stacks onto a surface already above the channel bottom.
2. **`flood_factor` is a fitted index, not a stage.** Hall's 3 was chosen because it reproduced 213
   field-measured floodplain widths, not because it corresponds to a discharge.
3. **It absorbs DEM smoothing**, explicitly, per the resolution table above.

**And one reason it does land against the model as currently coded.** The bankfull depth being
multiplied is **3.59× too large**, because `fl_flood_surface.R` feeds hectares and millimetres into a
regression that Hall and Nagel both specify as taking km² and cm/yr (flooded#49, confirmed against
both papers). So the shipped `ff04` is really about **14.4×** true bankfull depth — well past Hall's
3 and Nagel's 5–7, and past any defensible reading of "flood".

Until #49 is fixed, treat the absolute extents as over-mapped: corrected, the bundled tile gives
231.9 ha at `ff04` rather than 476.8 ha. The *relative* comparisons between scenarios are unaffected,
since every scenario carries the same error.

## 5. What we can and cannot claim

| Scenario | Defensible | Not defensible |
|---|---|---|
| `ff02` | inundation zone; ~50-yr stage or less | — |
| `ff04` | functional floodplain — calibrated against field-mapped floodplain widths | a specific flood recurrence |
| `ff06` | valley bottom, migration corridor, alluvial extent | recurrent inundation or nutrient exchange throughout |

**The single most important line in the verified rationale:** *"No paper maps specific ff values to
ecological processes."* The ecological labels on our scenarios are **our interpretive framework**,
not a literature finding. Say so in reports.

And from the same document: *"Labelling ff=6 output as 'functional floodplain' overstates the
claim."* Lead with `ff04` for functional-floodplain arguments; reserve `ff06` for connectivity and
migration-corridor framing.

## 6. Why intact valley bottom matters even where it rarely floods

The challenge — *if it never floods, it cannot contribute LWD or nutrients, so why protect it?* —
assumes both are delivered by overbank flow. Largely they are not. Sources retrieved from `vca_refs.duckdb`
on 2026-08-31; citation keys confirmed against the Zotero library and added to
`vignettes/references.bib`.

- **Large wood is recruited by bank erosion and lateral channel migration**, not by flooding
  [@rapp_abbe2003FrameworkDelineating]. Their process tables pair *Bank Erosion*
  directly with *Wood Recruitment*, and they describe lateral migration as arising from meander-bend
  development, flow obstruction, or increased bank erodibility — all channel-adjacent processes. The
  recruitment zone is therefore the **migration corridor**, which is what a valley-bottom map
  delineates. They also note wood that has already fallen becomes bank structure: *"large trees fall
  into the river and deflect flow; with time these structures become integrated into a new river
  bank."*

- **The subsurface is a habitat, not just a substrate.** @hauer_etal2016Gravelbedriver describe the
  *"hyporheic alluvial aquifer, characterized by river-origin water flowing through the gravel
  subsurface"* as a defining structure of gravel-bed river floodplains, with spawning
  *"heavily concentrated in habitats directly associated with groundwater upwelling."* That aquifer
  occupies valley-bottom alluvium well beyond the annually inundated zone.

- **Side channels are formed by migration and persist without overbank flow.** @rosenfeld_etal2008EffectsSide:
  *"Seasonal or permanently wetted side channels consist of old river channels formed by channel
  avulsion or migration, ponds created by American beavers on floodplain side channels or tributary
  streams, and slough habitat… natural features of most undisturbed river floodplains."*

- **Where floodplain *is* inundated, the productivity gain is large and measured.** @sommer_etal2001Floodplainrearing on the Yolo Bypass found *"evidence of enhanced growth and survival"* for juvenile chinook
  rearing on floodplain versus the adjacent river channel; @katz_etal2017Floodplainfarm reproduced the effect on
  deliberately flooded farm fields. This supports the `ff02`–`ff04` extent specifically, not the
  valley-bottom margin.

- **Confinement is the real signal.** The map's practical value is separating "the river can move
  here" from "the river is locked in place" — which is what predicts habitat complexity.

Do not attach the ecological language of `ff04` to the extent of `ff06`. That is the actual
overclaiming risk, and it is a writing decision more than a modelling one.

## 7. How good is the bankfull estimate?

`W_b = 0.196 × A^0.280 × P^0.355` — **R² = 0.47**, n = 1,951 field measurements, Columbia River
basin (@hall_etal2007Predictingriver). Depth from width uses Knighton 1998 coefficients derived from
a **single Idaho basin**.

Moderate fit, considerable scatter, and `flood_factor` multiplies whatever error it carries.

The model is also strikingly **insensitive** to its inputs — depth ∝ A^0.170 × P^0.215:

```
double the watershed area  ->  depth x1.13
10x the watershed area     ->  depth x1.48
double the precipitation   ->  depth x1.16
```

The Bulkley drains **57×** Cesford Creek and gets **1.95×** the bankfull depth. Robust to input
error; blind to local character. Two streams with identical area and precip get identical depth
whether one is a boulder cascade and the other a meadow meander. The regression cannot see channel
slope, bed material, or confinement.

Three specific cautions:

1. **It predicts a peak-driven geometry from a mean-flow proxy.** Hall's own reasoning chain is
   width ← discharge ← (area, precipitation): *"Stream width is predominantly a function of stream
   discharge… and discharge is typically estimated as a function of drainage area (A) and
   precipitation (P)."* That holds where the peak-to-mean ratio is regionally consistent. Whether it
   holds across BC's snowmelt / rain-on-snow / glacial regimes is **not addressed by any source in
   our reference set** — flagged as an open question rather than a claim.
2. **The equation contains no storage term.** Verifiable by inspection: `A` and `P` are the only
   inputs, so a basin whose peaks are attenuated by lakes or wetlands is indistinguishable from one
   of the same area and precipitation that is not. The *direction* of that limitation follows from
   the equation's form; its *magnitude* in BC is uncited and should not be asserted.
3. It is a **Columbia-basin regression applied to the BC interior** — standard practice, no BC
   alternative exists, but the bias is undetectable without local data
   (`vca_parameter_rationale.md`).

Corroborating signal: the package ships two independent channel-width models (bcfishpass/Thorley and
Hall) that disagree for the same stream and are documented as not interchangeable. Two credible
models giving different answers is the field telling you the uncertainty is real.

## 8. Which regression does what

| | **Hall / VCA** | **bcfishpass `channel_width`** |
|---|---|---|
| Where | `fl_flood_surface.R:79-81` | `fl_valley_confine.R:202` |
| Computed in-package? | **yes** | no — a precomputed column |
| Drives | the flood surface — criterion 4 | a `channel_width/2` buffer OR'd in after cleanup |
| If removed | model collapses | loses a sub-pixel sliver along the channel |

Hall does the science. bcfishpass `channel_width` is a DEM gap-fill: at 10–30 m a 20 m river can miss
cell centres entirely, and the buffer stamps the channel back in. It never touches the flood
calculation.

## 9. Measured on the bundled Bulkley tile (10 m)

| | | |
|---|---|---|
| `ff02` | 32,081 cells | **320.8 ha** |
| `ff04` | 47,681 cells | **476.8 ha** (+49%) |
| `ff06` | 53,635 cells | **536.4 ha** (+12%) |

Diminishing returns are the model working: by `ff06` the water is meeting valley walls and the slope
and cost criteria clamp it. Flood factor cannot invent floodplain where the terrain says no.

Worked bankfull depths:

| Stream | Upstream area | Bankfull | `ff04` | `ff06` |
|---|---|---|---|---|
| Cesford Creek | 1,929 ha | 0.77 m | 3.07 m | 4.60 m |
| Bulkley River | 110,337 ha | 1.50 m | 6.00 m | 9.00 m |

---

## Open verification items

Lit-search pass run 2026-08-31 against `vca_refs.duckdb` (15 papers), BM25 + semantic via Ollama
`nomic-embed-text`.

| # | Item | Status |
|---|---|---|
| 1 | Units in the bankfull regression | **Resolved — code defect.** flooded#49 |
| 2 | Ecological mechanisms (section 6) | **Sourced** — Rapp & Abbe 2003, Hauer et al. 2016, Rosenfeld et al. 2008, Sommer et al. 2001, Katz et al. 2017 |
| 3 | Bankfull recurrence interval | **Partly.** @wheaton_etal2019LowTechProcessBased give *"bankfull discharge… often approximates the mean annual flood for perennial streams."* The commonly quoted 1.5–2 yr figure is **not** in our set — use the mean-annual-flood phrasing, or add Leopold/Wolman to the store |
| 4 | At-a-station hydraulic geometry (depth ∝ Q^0.4) | **Cut.** Leopold & Maddock 1953 is not in the store, and section 4 no longer needs the exponent |
| 5 | BC-specific hydrology (regime variability, lake attenuation) | **Not in this store.** Rewritten in section 7 as a structural observation plus an explicit open question rather than a claim |

Remaining before this memo is cited in a report:

- ~~Generate BibTeX keys and `references.bib` entries.~~ **Done 2026-08-31** — `references.bib` now
  holds 8 entries. Keys were read from BBT's `citationKey` field in `zotero.sqlite` (BBT's HTTP
  endpoint was not serving); the mapping was validated by the two pre-existing keys resolving
  exactly.
- **flooded#49 must be resolved before any absolute area figure is published.** Extents are currently
  over-mapped by roughly 2x. Scenario *comparisons* are unaffected.
- **Item 3** — decide between the mean-annual-flood phrasing we can source and adding the classic
  reference.
- **Item 5** — if BC regime variability matters to a report's argument, it needs its own literature,
  not this store.

Rebuild or re-query the store with
`restoration_wedzin_kwa_2024/scripts/rag_build.R`; it is also cached at `s3://fresh-bc/rag/`
(see NewGraphEnvironment/rtj#194). Ollama must be running for semantic search — `ollama serve` —
though BM25 works without it and was enough to settle item 1.
