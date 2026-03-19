# VCA Parameter Rationale

Literature verification of Valley Confinement Algorithm parameters used in `fl_valley_confine()`.
Sources verified via ragnar semantic search against purchased PDFs (2026-03-17).
See flooded#28 for upstream documentation plan.

## Source Verification Method

Quotes and parameter values were verified by building a ragnar DuckDB store from Zotero PDFs
and querying with semantic + BM25 search. The build script is at:
`/Users/airvine/Projects/repo/restoration_wedzin_kwa_2024/scripts/rag_build.R`

PDFs sourced from Zotero group library 4733734 (NewGraphEnvironment),
primarily from the `hydrology` and `riparian` collections.
15 PDFs ingested (2,464 chunks). Key papers: Nagel et al. 2014 (RMRS-GTR-321),
Hall et al. 2007 (JAWRA, purchased).

---

## Bankfull Regression

The VCA predicts bankfull depth from upstream drainage area and mean annual precipitation.

**Equation** (from @hall_etal2007Predictingriver, verified from purchased PDF):
- Bankfull width: `W_b = 0.196 × A^0.280 × P^0.355` (R² = 0.47, p < 0.001, n = 1,951 field measurements, Columbia River basin)
- Bankfull depth: `H_b = 0.145 × W_b^0.607` (from upper Salmon River basin, Knighton 1998)
- Combined (as cited by @nagel_etal2014LandscapeScale): `h_bf = 0.054 × A^0.170 × P^0.215`
- A = drainage area (km²), P = mean annual precipitation (cm/yr)

**Limitations:**
- R² = 0.47 — moderate fit with considerable scatter
- Depth equation from a single basin in Idaho (upper Salmon River), not regional
- PNW equation applied to BC interior — standard practice but no BC-specific alternative exists
- The moderate R² means floodplain extents have inherent uncertainty from bankfull prediction alone, before flood_factor amplifies it

## flood_factor

The flood_factor is a **dimensionless multiplier on predicted bankfull depth**. It has no direct ecological meaning — it is a DEM compensation parameter.

From @nagel_etal2014LandscapeScale:
> "Rosgen (1994, 1996) defined the flood prone extent of a valley as the width measured at an elevation twice the maximum bankfull depth. This value roughly corresponded with the 50-year flood stage or less."

> "Using 10-m DEM data, Hall and others (2007) found that an elevation of **three times the bankfull depth** provided the best results for estimating the historical floodplain width."

> "Clarke and others (2008) used a factor of **five times** the bankfull depth to estimate the elevation for measuring valley-floor width when using 10-m DEM data."

> "The VCA flood factor parameter **defaults to a value of 5**; however, a value of **5-7 is recommended** based on the user's familiarity with the terrain and field observations."

> "Comparison of predicted and observed valley extent for field sites in central Idaho indicates that **a flood factor of seven is most appropriate for 30-m DEMs**. The coarser vertical resolution of 30-m DEMs relative to 10-m data requires a larger flood factor (7 vs. 5) to obtain similar results."

### Valley Bottom vs Floodplain

This distinction is critical for interpretation:

- **Historical floodplain** (@hall_etal2007Predictingriver): The area that was actively flood-prone before human modification. Hall validated ff=3 on 10m DEM against 213 field-measured floodplain widths. This is what ecologists mean by "functional floodplain" — where the river exchanges nutrients, recruits LWD, and supports off-channel habitat.

- **Valley bottom** (@nagel_etal2014LandscapeScale): The full depositional zone including terraces and depositional surfaces that are not actively flooded. Nagel's recommended ff=5-7 maps this broader extent. Useful for geomorphic context but overstates the area of active floodplain processes.

Labelling ff=6 output as "functional floodplain" overstates the claim. At ff=6, the mapped extent includes valley margin that is geomorphically part of the valley floor but is not regularly influenced by high flows.

### DEM Resolution Effects

Higher flood_factor values compensate for DEM smoothing of valley bottoms:
- **10m DEM:** ff=3 matches historical floodplain, ff=5 matches valley bottom
- **25m DEM:** ff=4 is a reasonable functional floodplain estimate, ff=6 for valley bottom
- **30m DEM:** ff=7 needed for valley bottom (@nagel_etal2014LandscapeScale)
- **1m LiDAR:** ff=2-3 may be sufficient — minimal DEM smoothing, channel is well-resolved

## slope_threshold

From @nagel_etal2014LandscapeScale:
> "A default **slope threshold of 9%** is used by the VCA."

> "The **9% ground slope threshold was chosen based on empirical evidence** indicating that slopes less than 9% in the DEM likely correspond to unconfined valleys."

**Units:** Percent slope (NOT degrees). 9% = ~5.1°. Confirmed from flooded source code: roxygen documents "percent slope", and the computation converts degrees to percent via `tan(degrees) * 100`.

> "The slope value of 9% seems high; however, valley bottoms in USGS DEMs are generally modeled at a higher gradient than their true value on the ground."

**DEM resolution effect:** At higher resolution (1m LiDAR), DEM-derived slopes are more accurate. The 9% threshold was calibrated on 30m DEMs where slopes are systematically overestimated. At 1m, a lower threshold may be appropriate.

## cost_threshold

From @nagel_etal2014LandscapeScale:
> "A slope cost distance threshold of **2,500** adequately captures an initial valley bottom domain that can be refined by further processing. **This variable has no physical meaning** and is simply an empirical rule that is used to set the initial processing domain for subsequent operations in the algorithm."

> "The variable is intended to capture a relatively low-sloped domain near the stream network and eliminate low slope features outside of valleys."

This is a processing parameter, not an ecological one. The cost is accumulated as cell_size × cell_slope, so the threshold scales with DEM resolution. At 1m resolution, the same physical distance accumulates ~25x less cost than at 25m. May need adjustment for high-resolution DEMs.

## max_width

From @nagel_etal2014LandscapeScale:
> "This parameter allows the user to select a width (m) for clipping the extent of the valley floor orthogonal to the channel."

> "The 1000 m maximum width is an arbitrary measure."

Nagel's examples use 500-1000m. The flooded default is 2000m. This is a safety cap — in most valleys, flood_factor and slope_threshold constrain the extent well before max_width kicks in. Relevant mainly for very wide, flat valley floors where slope constraints are weak.

## size_threshold

From @nagel_etal2014LandscapeScale:
> "The minimum polygon **size threshold was set at an arbitrary size of 10,000 m², equal to 1 HA.**"

**Units:** m² (confirmed from flooded source: `fl_patch_rm(min_area = size_threshold)` with `count * cell_area` computation).

The flooded default is 5,000 m² (0.5 ha) — half of Nagel's 1 ha default.

**DEM resolution effect:**
- At 25m: 5,000 m² = 8 pixels. Reasonable minimum for detecting real floodplain patches.
- At 1m: 5,000 m² = 5,000 pixels. This would preserve very small features. May want to reduce to ~100-500 m² to remove 1m-scale noise while keeping meaningful features like side channels.

## hole_threshold

**flooded-specific** — not from @nagel_etal2014LandscapeScale.

**Units:** m² (confirmed from flooded source: `count * cell_area < hole_threshold`).

The default is 2,500 m² (0.25 ha). Fills holes in the floodplain polygon caused by roads, buildings, or DEM artifacts that create gaps in the valley floor.

**DEM resolution effect:**
- At 25m: 2,500 m² = 4 pixels. Fills small DEM artifact gaps.
- At 1m: 2,500 m² = 2,500 pixels. This would fill a ~50m × 50m gap — large enough to erase roads, berms, and small infrastructure from the floodplain polygon. For site-level restoration design where infrastructure visibility matters, reduce substantially (e.g., 25-100 m²).

## What's Literature vs What's Ours

| Parameter | Source | Confidence |
|-----------|--------|-----------|
| Bankfull equation (h_bf) | @hall_etal2007Predictingriver via @nagel_etal2014LandscapeScale | **High** — verified from purchased PDF |
| slope_threshold = 9% | @nagel_etal2014LandscapeScale empirical | **High** — direct quote, confirmed units |
| cost_threshold = 2500 | @nagel_etal2014LandscapeScale empirical | **High** — direct quote, no physical meaning |
| flood_factor defaults (5-7) | @nagel_etal2014LandscapeScale, referencing Rosgen, Hall, Clarke | **High** — multiple sources |
| flood_factor as ecological zones | **Interpretive framework** | No paper maps specific ff values to ecological processes |
| max_width = 2000m | **Project choice** | Nagel uses 500-1000m |
| size_threshold = 5000 m² | flooded default (modified from Nagel) | Nagel uses 10,000 m² |
| hole_threshold = 2500 m² | **flooded-specific** | Not from literature |
