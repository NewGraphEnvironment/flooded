# What the floodplain model actually maps

Plain-language memo for reporting and onboarding. Companion to
[`methodology.md`](methodology.md) (the regressions and scenarios) and
[`../research/vca_parameter_rationale.md`](../research/vca_parameter_rationale.md) (verified
citations). This one answers the questions a reviewer asks: *what is this a map of, what does the
flood factor mean, and can we defend it?*

**Status:** the interpretation and the measured numbers are solid. Several supporting claims are
flagged **[UNVERIFIED]** and need a lit-search pass before this text goes into a report. One open
question about units could matter a great deal — see the end.

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

## 4. Why "4× bankfull" is not an impossible flood

The obvious objection: at-a-station hydraulic geometry gives depth ∝ Q^0.4 **[UNVERIFIED — Leopold &
Maddock 1953]**, so 4× bankfull depth would need ~32× bankfull discharge, which never happens. If
that were what the model claimed, the map would be indefensible.

It is not, for three reasons:

1. **The DEM's "streambed" is not the streambed.** Neither lidar nor MRDEM penetrates water, so the
   stream cell holds roughly the water surface at acquisition, blended with banks at 10–30 m. The
   multiplier stacks onto a surface already above the channel bottom.
2. **Bankfull depth is itself modelled, with R² = 0.47.** If the true value is larger than predicted,
   the effective multiplier is smaller than it looks.
3. **The factor absorbs DEM smoothing** — explicitly, per the table above.

The multiplier is a coefficient tuned to reproduce mapped floodplain boundaries. That it *sounds*
like an absurd flood is an artifact of the variable it scales, not evidence the map is wrong.

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

The obvious challenge — *if it never floods, it cannot contribute LWD or nutrients, so why protect
it?* — assumes both are delivered by overbank flow. Largely they are not. **Every claim in this
section needs a lit-search pass before use.**

- **LWD is recruited by bank erosion, not flooding [UNVERIFIED].** Trees enter the channel when the
  bank beneath them is undercut as the river migrates. The recruitment zone is the *migration
  corridor* — which is what the valley-bottom map delineates.
- **Side channels, groundwater-fed and wall-base channels [UNVERIFIED]** sit in valley-bottom
  alluvium, fed by hyporheic flow and small tributaries rather than mainstem overbank flow. Often
  the limiting overwintering habitat in BC coho and steelhead systems.
- **The hyporheic zone and shallow water table [UNVERIFIED]** occupy that alluvium; nutrient exchange
  runs through the subsurface as well as over the bank.
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

Three specific cautions for BC:

1. `area × precip` is a **mean-flow proxy predicting peak-driven geometry** — it works where the
   peak-to-mean ratio is regionally consistent, and strains across snowmelt / rain-on-snow / glacial
   regimes **[UNVERIFIED]**.
2. **Lakes and wetlands attenuate peaks and drainage area cannot see them** — a lake-headed basin has
   a smaller channel than its area implies **[UNVERIFIED]**.
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

Ordered by consequence. **Item 1 should be settled before this memo is cited anywhere.**

1. **UNITS IN THE BANKFULL REGRESSION — potentially serious.**
   `vca_parameter_rationale.md` annotates the equation as *"A = drainage area (km²), P = mean annual
   precipitation (cm/yr)"*. The code feeds it **hectares** and **millimetres**
   (`fl_flood_surface.R:79`, via `upstream_area_ha` and `map_upstream`).

   | Bulkley, 110,337 ha / 531 mm | bankfull width | bankfull depth |
   |---|---|---|
   | as coded (ha, mm) | 46.95 m | **1.50 m** |
   | as documented (km², cm) | 5.71 m | **0.42 m** |

   An 8.2× difference in width, 3.6× in depth. Circumstantially the code looks right — the
   independent bcfishpass estimate for the same segment is 31.3 m, near the as-coded value and
   nowhere near 5.71 m; and 0.42 m is implausibly shallow for a 1,100 km² river. The code also
   reproduces Nagel's published combined form `h_bf = 0.054 × A^0.170 × P^0.215` exactly in *form*,
   so only the units are in question, not the algebra.

   **But "the answer looks plausible" is not verification.** Check the units in the Hall 2007 PDF
   directly. Then fix whichever is wrong — the doc annotation, or every floodplain we have produced.

2. **Bankfull recurrence interval** — commonly cited as 1.5–2 years. Not in our verified set. Needed
   only if a report states it.
3. **At-a-station hydraulic geometry** (depth ∝ Q^0.4, Leopold & Maddock 1953) — used in §4 as an
   order-of-magnitude argument. Verify before printing the exponent.
4. **The §6 ecological mechanisms** — LWD via bank erosion, hyporheic exchange, wall-base channels.
   These carry the protection argument and currently have no citation. Highest priority after item 1
   for reporting use.
5. **BC-specific caveats** in §7 — peak-to-mean variability by hydrologic regime, lake attenuation.

Suggested next step: build the ragnar store (`rag_build.R`, referenced in
`vca_parameter_rationale.md`) and run `/lit-search` over items 2–5, then attach citation keys inline
and delete the `[UNVERIFIED]` markers as each is confirmed. Anything that cannot be supported should
be cut rather than softened.
