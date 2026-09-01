# Findings — 'proportional claims stand' needs the counter-case (#52)

## Issue context

**If we do it:** the memo stops implying that all proportional claims survived the 0.5.0 units fix.
**If we never do:** the next person quoting it repeats the mistake made in three downstream notices
before catching it.

`inst/notes/floodplain_interpretation.md` section 4 says, correctly, that proportional claims stand —
citing `restoration_wedzin_kwa_2024`, where disturbed-as-a-share-of-AOI moved 27.51% -> 27.50% under
the fix. That is true for land-cover composition **within** the floodplain. It is not true for a
ratio whose denominator sits outside the floodplain, and the memo does not distinguish the two.

Suggested: one short paragraph in section 4 distinguishing the two shapes, since this memo is
explicitly the document we draw on for reporting and "can we still quote this number" is exactly the
question it exists to answer.

Downstream instances: NewGraphEnvironment/fish_passage_peace_2025_reporting#47,
NewGraphEnvironment/fish_passage_skeena_2025_reporting#18,
NewGraphEnvironment/fish_passage_fraser_2025_reporting#37.

## Measured, not taken from the issue

**First pass was wrong, and the reviewer caught it.** I measured `sf::st_area()` on the
`floodplain` layer directly. Both consuming chunks clip to the AOI first —
`sf::st_intersection(floodplain, aoi)` at `0730-appendix-floodplain.Rmd:42` and
`0400-results.Rmd:209` — so the raw layer is not what any report publishes. Same class as CLAUDE.md's
*"Measure the output, not the input you handed in"*: measured upstream of the transformation the
consumer applies.

Corrected, over the same AOI (5,596.6047 km2 = 559,660.47 ha), `sf_use_s2(FALSE)`:

| source | raw layer | **clipped to AOI** | pct raw | **pct clipped** | prints |
|---|---|---|---|---|---|
| peace `data/gis/pars.gpkg[floodplain]` — pre-fix, as committed | 48,540.8 | **48,116.2** | 8.6733% | **8.5974%** | **8.6** |
| `flooded/inst/vignette-data/pars.gpkg[floodplain]` — 0.5.0 corrected | 41,142.9 | **40,807.9** | 7.3514% | **7.2915%** | **7.3** |

Clipped drop = 15.19%; raw drop = 15.24%. Either way the share tracks the hectares, because the
denominator is the watershed group and does not shrink — the issue's argument holds, only its
figures needed restating.

Confirmed against the committed rendered output, so this is not a prediction:
`docs/app-floodplain.html` carries `48,116` and `8.6 %`.

`fp_pct_aoi` is real and published in all three report repos as
`100 * fp_area_ha / (aoi_area_km2 * 100)`, rendered `sprintf("%.1f", ...)`: peace
`0730-appendix-floodplain.Rmd:53` / `0400-results.Rmd:213`, skeena `0720-appendix-floodplain.Rmd:55`,
fraser `0720-appendix-floodplain.Rmd:53`. Published values: peace 8.6%, skeena 6.2%, fraser 13.1%.

## The 62.3 ha gap is a different run, not a different polygonization

Section 4's Parsnip bullet cites **48,603.1 ha** / 521,028 cells for the 0.4.1 run
(`methodology.md:93`, `NEWS.md:75`, `planning/archive/2026-08-issue-49-bankfull-units/review-round2.md:165`).
The peace report's committed raster measures **520,360 cells**:

```
521,028 - 520,360 = 668 cells
668 x 932.8312 m2 = 62.31 ha  ==  48,603.1 - 48,540.8 = 62.3 ha
```

A whole number of cells, to the hectare — so it is raster, not vector. Polygonization is exact in
both artifacts (raster and polygon agree to 0.01 ha). The first draft called it "a separate
polygonization of the same pre-fix run", which asserted an identity the artifacts contradict, and
paired a pre-fix figure from one lineage with a corrected figure from another. The memo now says
they are different runs and should not be paired.

## Scope decisions

- **No version bump, no NEWS entry.** Docs-only correction to a shipped memo; nothing a caller does
  changes. v0.6.0 is tagged and released.
- The general rule already lives in `CLAUDE.md` under "Which claims survive a change in mapped
  extent" (added under this issue number). This work lands it in the shipped memo.
- No test reads the memo — `grep -rln "floodplain_interpretation\|inst/notes" tests/ R/ _pkgdown.yml
  vignettes/` returns only `R/fl_flood_surface.R`, in roxygen prose.

## Six review rounds, and the mechanism they found

| round | findings | the one that mattered |
|---|---|---|
| 1 | 4 (2 bug) | the raw layer is not what the report publishes — the consumer clips first |
| 2 | 7 (5 bug) | a bullet performed the exact pairing the sentence nine lines below forbade |
| 3 | 6 (1 bug) | a bundled-10 m-tile ratio quoted in a paragraph about the 30 m watershed |
| 4 | 7 (3 bug) | **named the mechanism** (below) |
| 5 | 5 (2 bug) | the rescale license was unrestricted in what the numerator measures |
| 6 | 7 (1 bug) | "waterbodies do not move with the fix at all" — they move 0.3% / 0.7% |

**The mechanism (round 4, confirmed by 5 and 6).** Every round's finding was about a *number*; every
round's fix was correct about the number and then introduced a new **scope quantifier over a
population the memo never enumerates**. Flagged as under-evidenced, the passage kept repairing
itself by *widening the stated evidential base* ("on every run", "from either layer", "across the
figures in this memo") rather than by narrowing the claim. Widening requires a population; the
population was asserted. Across rounds 4-6, **every widening broke or was under-justified; every
narrowing held.**

Root cause: the memo's figures sit on a ragged dataset x resolution x lineage x clipped/raw grid
that no dataset fills, so "across the figures here" quantifies over holes as much as cells.

Round 6 terminated it by enumeration rather than by another instance — it reproduced 0.4.1 exactly
on current code (`flood_factor = 4 * 3.5926 = 14.3704` returns the settled 521,028 cells) and
measured every row of the appendix rollup on one lineage, so the population became finite and
checked. Residual, stated exactly: the channel-buffer half of one clause is *vacuous* against the
seven-row enumeration, because the appendix publishes no channel-buffer-derived row.

## Errors Encountered

| Error | Resolution |
|-------|------------|
| Reported the raw `floodplain` layer's area as the report's published figure (48,540.8 ha / 8.67%) | The consumer clips to the AOI first; measure through `sf::st_intersection(floodplain, aoi)`. Published is 48,116 ha / 8.6% |
| Called a 62.3 ha gap between two pre-fix artifacts "a separate polygonization" | `terra::freq()` on both rasters: 668 cells exactly. Different runs; polygonization loses nothing |
| Quoted `fp_pct_aoi` to two decimals | The appendices render it `sprintf("%.1f", ...)`. Two decimals overstate what is published |
| Carried the pre-existing "Scenario-to-scenario comparisons are unaffected" through the diff | Contradicted by section 9's own retention table: `ff06`-`ff04` widens 12.5% -> 23.9% while `ff04`-`ff02` narrows 48.63% -> 25.07%. Only the *ranking* survives |
| Quoted a bundled-10 m-tile scenario ratio in a paragraph about the 30 m Parsnip watershed | The 30 m corrected gap is 4.6%, a factor of 5 apart. Name the dataset inline — the repo's own "measure it where it lands" rule, one level down |
| Licensed rescaling "a *share* of a fixed denominator" with no restriction on the numerator | Breaks for 5 of the 7 floodplain-derived rows the peace appendix publishes — lengths, counts, waterbody areas |
| Asserted waterbodies "do not move with the fix at all" | They do: lakes -0.3%, wetlands -0.7%. `terra::rasterize()` burns by cell centre, so a waterbody's fringe is in the floodplain only where the VCA mask covers it |
| Fixing an under-evidenced claim by widening its stated evidential base | Narrow the claim instead, or enumerate the population and measure it. Every widening across rounds 4-6 broke; every narrowing held |
