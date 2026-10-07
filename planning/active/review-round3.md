# Review round 3 — #51 stac-dem live vignette (review of round-2 fixes + the enumeration)

Reviewer: code-check subagent, 2026-10-07. Repo untouched except this file. All probes ran in
`scratchpad/r3/`. The 1 m mask decomposition rebuilt the site DEM from the two local 2019 tiles
(`terra::project(bilinear)` onto the 1 m site grid; NA share 0.07892221, which matches
`na_frac_1m`). The full 1 m `fl_valley_confine()` on that DEM gives 3,096,019 valley cells against
the cached 3,096,003. It differs from `scratchpad/stac_valleys_1m_native.tif` in **28 of 14 M
cells**, and that native file resampled (near) equals `stac_valleys_1m_site.tif` exactly. So the
per-criterion masks below describe the same run the page shows. The run took 39.7 min and raised no
warnings.

## Mechanism

All three earlier defects, and the one below, come from one assumption: **that a 0 cell in
`fl_valley_confine()`'s output means one physical thing, "ground above the flood surface", so
reading the picture explains it.** It does not. The output is the AND of four criteria, followed by
a cleanup whose size depends on resolution:

- the four criteria are slope ≤ 9%, distance, cost and flood;
- the cleanup is a 3x3-**cell** closing (30 m at 10 m, 3 m at 1 m), hole fill, patch removal and a
  modal filter.

No artifact records *why* a cell is 0, so every causal sentence on the page was written from the
image.

The enumeration in `findings.md` answers the earlier rounds by measuring **how much and where**:
counts, shares, tributary vs main stem, inside vs outside the envelope. Every C1–C11 row is that
kind. None measures **why** a cell is excluded, so the enumeration is complete for extent claims and
cannot see a "because" claim. The two lists that happen to agree are the page's "white = above the
flood level" and the reader's eye. Nothing ties either to the masks.

Measured, for the 1,984 pop-up cells (10 m valley, 1 m not), using the 1 m masks sampled at the
10 m cell centres, which is the same nearest-neighbour sampling the cache uses:

| 1 m exclusion | share of pop-ups |
|---|---|
| fails slope (> 9%) | **77.4%** |
| fails flood (above the flood surface) | **11.6%** |
| slope only, flood passed | 73.8% |
| flood only | 8.0% |
| passes all four masks (removed by cleanup) | 14.6% |

At the pop-up cells, the ground is a median **2.0 m below** the 1 m flood surface (`flood_depth`:
10th–90th percentile 0.72–3.47 m). All 1 m non-valley cells inside the 10 m floodplain at native
resolution (207,464 cells) give the same picture: 76.3% fail slope and 12.2% fail flood.

The round-1/2 profile feature, which is the page's "narrow diagonal white line", shows it directly.
Round 2 profiled x = 979405 / 979605 / 979805, from y 1056405 down to 1055825:

```
x 979405  1m : 11111111111111111111111111100111111111111111111111111111111
          slp: 11111111111110011111111111100010111011110111111111111111111
          fld: 11111111111111111111111111111111111111111111111111111111111
x 979805  1m : 11111111111111111111111111111111111111001111111111100000000
          slp: 11111111111111111111111011111011111100001101111111110000000
          fld: 11111111111111111111111111111111111111111111111111100000000
```

Every line cell passes the flood criterion. It is excluded by slope, which picks up the embankment
shoulders. At 10 m the same feature is the reverse: the 60–90 m band fails **flood** and passes
slope (10 m `fld` 0-runs coincide with the gap, `slp` is mostly 1). The 25 m DEM puts a broad band
above its flood surface. The 1 m DEM puts the grade below its flood surface and excludes only its
steep sides.

## Findings

- **[bug] Every "above the flood surface" sentence about the pop-ups is false against the
  rasters.** At this site, 74% of pop-up cells sit *below* the modelled flood surface and are
  excluded only because their 1 m slope exceeds 9%. Places this reaches:
  - `vignettes/stac-dem.Rmd:479-481`: "the 1 m lidar reveals are sitting above the flood surface".
    This holds for 11.6% of cells.
  - `vignettes/stac-dem.Rmd:496-497`: "narrow white lines ... where the ground surface sits
    **above** the modelled flood level". This is false for the measured line cells (profiles above).
  - `vignettes/stac-dem.Rmd:503-505`: "At 1 m, the actual elevation of a raised road bed ... is
    resolved, so it stands out". At the one measured feature it stands out through slope, not
    elevation, and the 25 m DEM is the one that puts it above flood level. This reverses the
    paragraph's averaging argument at :500-503. Line :500 ("too high or too steep") is the only
    sentence on the page that is true as written.
  - `vignettes/stac-dem.Rmd:521-526`: "the pop-ups — floodplain at 25 m that 1 m lidar puts above
    the flood surface", and "these raised features are blocking it".
  - `vignettes/stac-dem.Rmd:465`: the table label "Elevated features (pop-ups)" names the same
    mechanism. It is pre-existing, and it sits beside the number now presented as current.
  - `NEWS.md:17`: "The 'pop-ups' (25 m floodplain that lidar puts above the flood surface) are
    19.8 ha". This is new text, and it defines the quantity by the wrong criterion in the one
    document readers will not re-derive.
  - `README.md:55`: "...agricultural fill that sit above the flood surface and block lateral
    connectivity". The sentence was rewritten in this diff and the clause survived the rewrite.

  This matters beyond wording. A 9% threshold on a 1 m grid is a 9 cm rise per metre, so it fires on
  embankment sides, ditch banks and microrelief. A share of the "pop-ups" is therefore an effect of
  the slope criterion's resolution. 14.6% is not excluded by any criterion: those cells are removed
  by the cleanup filters. The restoration framing ("where to look for the anthropogenic footprint",
  "raised features are blocking it") reads the whole 19.8 ha as raised ground. A rewrite that
  survives the data: *pop-ups are 25 m floodplain the 1 m run excludes; at this site about three
  quarters are excluded because the 1 m surface is steeper than the 9% slope criterion (embankment
  sides, banks, microrelief), about one in nine because the ground is above the 1 m flood surface,
  and the rest by the cleanup filters.* Better still, have `data-raw/stac_dem_vignette_data.R` cache
  the per-criterion share, so the sentence is computed rather than described. `fl_valley_confine()`
  does not return the masks, so the script would recompute them as above.

- **[fragile] `vignettes/stac-dem.Rmd:299`** says "Those features are invisible at 25 m." This is
  the same claim as C9. Round 2 showed it false where a grade crosses the 10 m floodplain (the lower
  right, where it appears as a broad band). The enumeration reworded only the instance at the old
  :501 and missed this one 200 lines earlier. The grep for the sentence was not run, only the fix to
  the quoted line.

- **[fragile] `vignettes/stac-dem.Rmd:187`**: "use 1 for full resolution (100x more cells, ~25 min
  fetch)". Going from 5 m to 1 m is **25x** more cells: `ncell_5m` is 2,073,600, and the same extent
  at 1 m is 51.84 M. This is pre-existing and quantitative, so it falls outside a qualitative-only
  enumeration. It sits in the displayed code this branch rewrote. The "~25 min fetch" also predates
  the download step, and no artifact backs it.

## Verified (no issue)

- **C1, C2, C6 and the table.** Live `n_10m` is 28,727 and `n_site_10m` is 20,586, both equal to
  the cache. Pop-ups are 1,984 cells (19.8 ha, 9.64%) and 1 m-only is 12,428 cells (124.3 ha).
  Native and resampled areas agree: 5 m is 186,675 × 25 m² = 4.667 km² against 4.666 on the 10 m
  grid, and 1 m is 309.6 ha native against 310.3 ha resampled.
- **C3.** The 18,617 5 m-only cells split by nearest stream line as 43.7% Bulkley and 56.3%
  tributaries (Richfield 3,212, Cesford 2,471, Robert Hatch 2,160, unnamed 2,639). "Both" holds.
- **C4.** 32 of 28,727 10 m valley cells fall where lidar is missing, which reproduces. "The rest is
  upland" also holds: the uncovered area is 770–929 m (5th–95th percentile) against 656–679 m for
  the 10 m floodplain, and 0% of it lies below the floodplain's 95th-percentile elevation. The
  parenthetical "(checked when the lidar results were built)" is true of when the check was run,
  but no script or cached artifact performs it.
- **C6 mechanism ("low ground a 25 m pixel likely averages upward").** Of the 12,428 1 m-only cells,
  91.2% fail the **10 m flood** criterion (76.5% flood-only) and 22.0% fail 10 m slope. So the 25 m
  DEM does place them above its flood surface, and the hedged sentence holds. Most of these cells
  (9,794) lie outside the 10 m floodplain's 150 m closing envelope, and 2,634 lie inside it: the
  1 m run mostly extends margins rather than filling holes. That is consistent with the page, which
  does not claim otherwise.
- **`methodology.md`.** The 1 m re-run on an independently built DEM raised no warnings, so
  "emits no warnings at all" reproduces.
- **Site description.** The streams cropped to the site include Robert Hatch, Richfield and Cesford
  Creeks and the Bulkley. The extent is 3.5 × 4.0 km.
