# Findings — stac-dem.Rmd ships pre-0.5.0 figures and could not be re-baked; its numbers do not reproduce even under the old units (#51)

## Issue context

## Problem

`vignettes/stac-dem.Rmd` publishes numeric output produced by the units defect fixed in #49, and it
could not be regenerated as part of that work. It ships a caveat block instead (added in 0.5.0), but
the caveat is a stopgap — the figures on the pkgdown site are still wrong.

It is the **baked** half of the `.Rmd.orig` pattern: its chunks are plain ` ```r ` blocks with `#>`
output already embedded, so `R CMD check` and the pkgdown build render them as-is. Re-baking needs
the STAC endpoint reachable **and** a 1 m lidar re-run, which is why it was deferred rather than done.

## What is stale

| line | published figure |
|---|---|
| :85 | `10 m DEM valley cells: 54637 / 518400 ( 10.5 %)` |
| :189 | `5 m DEM valley cells: 250564 / 2073600 ( 12.1 %)` |
| :205 | `Valley area (bundled 10 m DEM): 5.46 km²` |
| :207 | `Valley area (STAC 5 m DEM): 6.26 km²` |
| :317 | `1 m DEM valley cells: 3,883,179 / 1.4e+07 ( 27.7 %)` |

## The published figures do not reproduce even under the old units

Worth recording, because it means a re-bake is not simply "apply the 0.5.0 delta". Running the
vignette's own 10 m baseline configuration — `field = "upstream_area_ha"`, `slope = slope_10m`,
`slope_threshold = 9`, `max_width = 2000`, `cost_threshold = 2500`, `flood_factor = 6`,
`precip = precip_r`, no waterbodies:

| | cells |
|---|---|
| published in the baked vignette | 54,637 |
| as-coded reproduction, today | **53,635** |
| corrected (0.5.0) | **28,727** |

So roughly **1,000 cells** of that gap predate this release and come from changes since the vignette
was last baked. Nobody noticed, because a baked vignette has nothing checking it.

Configuration matters too, and is easy to get wrong when quoting a figure: the same tile gives 53,635
with explicit `slope.tif` and no waterbodies, but 55,345 with waterbodies. A cell count quoted
without its configuration is not reproducible.

## What to do

- [ ] Re-bake `stac-dem.Rmd` from `stac-dem.Rmd.orig` with the STAC endpoint reachable
- [ ] Remove the 0.5.0 caveat block once the figures are current — it lives only in the baked `.Rmd`,
      deliberately not in `.orig`, so a clean re-bake drops it automatically
- [ ] Confirm the resolution comparison still makes its argument at corrected depths — it is the
      point of the vignette, and every run in it shrank

## Worth considering while open

A baked vignette drifting silently for several releases is the underlying problem, not the units fix.
Two options, neither free:

1. **A staleness guard** — record the package version the vignette was baked at, and fail or warn when
   it is behind. Cheap, and it converts a silent drift into a visible one.
2. **Drop the pre-bake for the 10 m baseline section**, which needs no network and could run live like
   `valley-confinement.Rmd` does. Only the STAC and 1 m lidar sections genuinely need pre-baking.

Option 2 would have caught this one, since the stale figure is in the baseline section.

Related: `vignettes/valley-confinement.Rmd` runs live and was correct automatically;
`vignettes/pars-floodplain.Rmd` had its cached artifacts regenerated in #49. This is the only one of
the three left stale.



## Published site state at start (gh-pages @ 7a416c1)

- Both `<img>` sources (`figure/plot-compare-1.png`, `figure/site-compare-1.png`) return 404 — never committed.
- The "Figures \\@ref(fig:plot-compare)" cross-ref renders as the literal `@ref(fig:plot-compare)`.
- STAC endpoint `https://images.a11s.one/` returned 200 on 2026-10-07; gdalcubes 0.7.5, rstac 1.0.1, terra 1.9.50 installed.

## The STAC collection was renamed (2026-10-07)

`stac-dem-bc` no longer exists on `https://images.a11s.one/` — `GET /collections/stac-dem-bc/items/<id>`
returns `NotFoundError: Collection stac-dem-bc does not exist`, and an `rstac` search against it
returns **zero features, not an error**, so the build script failed one step later at
`stac_image_collection()` ("Input does not include any STAC items"). The collection is now
`stac-elevation-bc` with the DEM under asset `dem` (was `image`), a deliberate restructure
(rtj#229; rtj#322 tracks the registration script still naming the old one). The same two 2019 1 m
items exist under their old ids; the collection now also holds 2018 1 m and 2000-era 2 m Albers
tiles over this area, so the 2019 `datetime` filter is what keeps the selection identical.

Also stale for the same reason: `R/fl_dem_aoi.R`'s `\dontrun` lidar example — fixed in this branch
(collection + `$assets$dem$href`).

## Guard placement — deviation from the plan

The plan put a `warning()` in the vignette guard chunk. knitr captures chunk warnings into the
page, so a `warning()` there neither reaches the build log nor fails anything — it would only
duplicate the visible callout. The loud half of the guard is instead a test,
`tests/testthat/test-vignette_data.R`, which recomputes the two 10 m counts and fails when they
differ from `stac_meta.rds`. The vignette keeps the visible callout.

## Lidar coverage is partial, and the tiles are strip-organised (2026-10-07)

- `gdalinfo` on the 2019 COGs: `Block=13460x1`, Float32, no overviews, ~630 MB each. Over
  `/vsicurl/` that is a range request per strip; the convention is to download first.
- First run with a "mosaic NA > 0.1% means partial read" guard stopped at **22.29% NA**. Measured
  from locally downloaded tiles (both, projected bilinear onto a 5 m grid of the bundled extent):
  **22.29% NA** for the bundled extent, **7.89%** for the site. Identical to the gdalcubes figure,
  so the NA is the 2019 flight footprint, not a failed read — the tile *bboxes* cover 100% of the
  AOI, the data does not. The guard's premise ("wholly inside lidar coverage") was wrong; it now
  records `na_frac_*` in meta instead, and the script reads local tiles via `url_fun`, which
  removes the partial-read risk it was guarding.
- The published 0.4-era vignette ran on the same partial coverage; NA is outside the analysis
  extent for the VCA, so the 5 m vs 10 m area comparison has always compared a smaller lidar
  footprint against the full 10 m tile. Phase 3 has to account for this.

## Plan review (Plan agent, 2026-10-07) — disposition

| # | finding | disposition |
|---|---|---|
| 4 | mixed live/cached chunks need splitting | done in the draft vignette |
| 5 | guard callout placement | callouts sit beside each comparison they invalidate |
| 6 | guard blind to 1–5 m-only drift and to shown-code drift | stated on the page; test comment |
| 7 | `warning()` goes nowhere | replaced by `test-vignette_data.R` (see above) |
| 9 | no geometry check on cached rasters | `stopifnot(compareGeom())` in load chunks + test |
| 10 | collection renamed | confirmed independently, fixed |
| 11 | partial-fetch / costDist capture | warnings captured into meta; NA recorded; tiles downloaded |
| 12 | stale docs: methodology.md costDist note, README claim, NEWS gdalcubes line | Phase 3/4 |
| 13 | drop gdalcubes from Suggests | not taken — plan approved keeping it; offered as follow-up |
| 14 | native 1 m inset | native 1 m written to scratch for Phase 3 to decide |
| 15 | version stamp | git SHA + R/ dirty flag recorded |
| 17 | "no network" check untestable | replace with purl grep of evaluated code |
| 18 | st_crop warning on page | `suppressWarnings()` |

## Enumeration of the vignette's raster claims (code-check round 2 -> 3)

Round 2 found a defect inside round 1's prose fix — the mechanism is describing figures by eye.
Every qualitative claim about the rasters, measured (site envelope = 15-cell closing of the 10 m
site result; tributary/main-stem split by nearest stream line):

| # | claim | measurement | outcome |
|---|---|---|---|
| C1 | lidar maps more valley bottom | 4.67 vs 2.87 km2, inline | holds |
| C2 | the two mostly agree where 10 m finds floodplain | 28,039 of 28,727 10 m cells also 5 m | holds |
| C3 | lidar adds "chiefly along tributaries and wider flats" | 5 m-only 18,617: 56% nearer a tributary, 44% main stem | reworded "both" |
| C4 | 78% coverage, uncovered part barely overlaps | 32 of 28,727 cells | holds |
| C5 | pop-ups "are the barriers" | 19.8 ha; page itself lists natural terraces | "candidate barriers" |
| C6 | 1 m-only larger than pop-ups; low ground averaged up | inline comparison; mechanism unmeasured | inline + "likely" |
| C7 | 25 m breaks broad and "the lidar finds them too" | 3,643 gap cells, 1,009 (28%) still gap at 1 m | rewritten |
| C8 | 1 m breaks narrow, diagonal | round 2 profiles | holds |
| C9 | barriers "invisible" at 25 m | grade shows as a broad 10 m gap lower right | "smeared or lost" |
| C10 | caption "side channels and terrace edges emerge" | not measured | "narrow linear breaks" |
| C11 | README "one continuous surface" at 25 m | same as C7 | rewritten |

## Code-check round 3 — the mechanism, and the causal-claim enumeration

Round 3's mechanism: the prose read every 0 cell as one physical cause ("above the flood
surface"), when `fl_valley_confine()` can exclude a cell on slope, distance, cost, flood depth or
cleanup, and nothing cached said which. The C1–C11 enumeration measured *extent* and could not
see a *because* claim. Independently reproduced: **1,535 of 1,984 pop-up cells (77.4%)** sit on
1 m ground steeper than 9% (nearest 1 m cell to each 10 m centre), against **23.6%** across the
whole 25 m site floodplain. The build script now computes both (`popup_steep_share`,
`site_steep_share`) and the lidar-gap overlap (`n_10m_no_lidar` = 32); cache rebuilt from c0c0e46
in 21.3 min, valley rasters byte-identical to the previous build.

Every causal sentence in the changed prose:

| # | sentence (stac-dem.Rmd unless noted) | basis | outcome |
|---|---|---|---|
| E1 | pop-ups mostly on 1 m ground steeper than threshold | inline `popup_steep_share` vs `site_steep_share` | computed |
| E2 | 1 m-only floodplain is low ground a 25 m pixel "likely" averages upward | round 3: 91% of 1 m-only cells fail the 10 m flood criterion | hedged, supported |
| E3 | lidar fills most of the 25 m gaps | 72% of 3,643 gap cells | holds |
| E4 | diagonal lines are steep ground (sides of a raised grade) | round 3: line cells pass flood, fail slope | holds |
| E5 | excluded cells are "too high or too steep" | covers both criteria | holds |
| E6 | at 25 m a raised grade shows as a broad gap | round 3: the 10 m band fails the flood criterion | holds |
| E7 | at 1 m the steep sides are resolved, so a line | as E4 | holds |
| E8 | pop-ups "mostly on steep ground" | as E1 | computed |
| E9 | NEWS / README restate E1 | same numbers | consistent |
| E10 | caption "narrow linear breaks emerge at 1 m" | as E4 | holds |
| — | "invisible at 25 m" (old :299), "100x more cells" (5 m -> 1 m is 25x) | round 3 | fixed |

## Code-check round 4 and the terminal enumeration

Round 4 found three claims the E-table missed, one inside round 3's fix ("raised features are in
the way" — 100% of pop-ups pass cost and distance, so nothing is in the way), "smooths nearly
flat" (pop-ups have a 25 m median slope of **5.0%**, p90 8.8%, 7.1% above 9% — reproduced), and
README:57's "the gap ... shows what is preventing floodplain". Keyword-grepping for causal words
was the incomplete instrument. Terminal enumeration instead: every prose sentence of the
vignette's Intro, Compare, Quantifying and Barriers sections, split mechanically (36 sentences),
plus README:55-57 and the top NEWS entry, each classified:

| class | sentences |
|---|---|
| computed inline from the cache or the live run | 3, 4, 9, 10, 13, 14 |
| measured, number recorded here or in a review file | 1, 2 (C1-C3), 5, 16, 17 (72% filled), 19, 20 (round 3 slope/flood split), 26 (73.8% slope-only), 34 (18.9/21.3 min) |
| definition / method statement | 6, 7, 8, 30-33, 35, 36 |
| hedged interpretation ("likely", "may", "candidate", "where to look") | 11, 12, 15, 21-24, 27-29 |
| rewritten in this pass | 18 (conflated slope and flood criteria), 26 (removed "in the way"), 10 ("smooths nearly flat" -> computed 25 m median) |
| README:55, :57 and NEWS | restate 9/10/13 with the same numbers; :57 rewritten to the two-way gap (124.3 vs 19.8 ha) |

Nothing in the set asserts a cause above what its source supports. This is what ends the
code-check loop (karpathy.md: terminate by enumeration, not by a reviewer).

Pre-existing defect found by round 4, not this branch's: `fl_valley_confine()` returns **0**, not
NA, where the DEM is NA (reproduced: 10x10 NA block -> 0), contradicting its roxygen
("NA = outside analysis extent"). Filed separately.

## Errors Encountered

| Error | Resolution |
|-------|------------|
| `stac_image_collection(): Input does not include any STAC items` | Collection renamed to `stac-elevation-bc`, asset `dem` |
| `Lidar mosaic is 22.29% NA - partial read?` | Not a partial read: measured 22.29% from local tiles. Guard premise wrong; record NA, download tiles first |
