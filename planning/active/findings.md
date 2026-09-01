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

Both sides read with `sf::st_area()` over the same AOI layer (5,596.60 km2 = 559,660 ha):

| source | floodplain ha | % of watershed group |
|---|---|---|
| `fish_passage_peace_2025_reporting/data/gis/pars.gpkg[floodplain]` — pre-fix, as committed | 48,540.8 | **8.6733%** |
| `flooded/inst/vignette-data/pars.gpkg[floodplain]` — 0.5.0 corrected | 41,142.9 | **7.3514%** |

Confirms the issue's 8.67% -> 7.35% exactly. The share falls 15.2%, tracking the hectares, because
the denominator is the watershed group and does not shrink.

`fp_pct_aoi` is real and published: defined at `0730-appendix-floodplain.Rmd:53` and
`0400-results.Rmd:213` in the peace report, both as
`100 * fp_area_ha / (aoi_area_km2 * 100)`, rendered with `sprintf("%.1f", ...)`.

## A 62 ha discrepancy between two pre-fix runs

Section 4's Parsnip bullet cites **48,603.1 ha** for the 0.4.1 run (measured from flooded's own
artifacts during #49 — see `planning/archive/2026-08-issue-49-bankfull-units/review-round2.md:165`,
521,028 cells). The peace report's committed layer measures **48,540.8 ha** — 62.3 ha (0.13%) less,
a separate polygonization run.

Over the same AOI those give 8.68% and 8.67% respectively. Resolved by naming each numerator's
source in the memo text, so a reader dividing either figure by 559,660 ha reconciles. 8.67% is the
number to lead with: it is what the peace report *publishes*, which is the whole point of the
paragraph, and it matches `CLAUDE.md` and the three downstream notices already filed.

## Scope decisions

- **No version bump, no NEWS entry.** Docs-only correction to a shipped memo; nothing a caller does
  changes. v0.6.0 is tagged and released.
- The general rule already lives in `CLAUDE.md` under "Which claims survive a change in mapped
  extent" (added under this issue number). This work lands it in the shipped memo.
- No test reads the memo — `grep -rln "floodplain_interpretation\|inst/notes" tests/ R/ _pkgdown.yml
  vignettes/` returns only `R/fl_flood_surface.R`, in roxygen prose.

## Errors Encountered

| Error | Resolution |
|-------|------------|
