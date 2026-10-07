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

## Errors Encountered

| Error | Resolution |
|-------|------------|
