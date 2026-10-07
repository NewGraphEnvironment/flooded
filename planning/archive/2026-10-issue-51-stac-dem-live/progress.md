# Progress — stac-dem stale figures (#51)

## Session 2026-10-07

- Plan-mode exploration — phases approved by user (approach: live + cached)
- Created branch `51-stac-dem-rmd-ships-pre-0-5-0-figures-and` off main
- Scaffolded PWF baseline from issue #51 with approved phases
- Next: start Phase 1
- Plan review (Plan agent) returned 20 findings; disposition table in findings.md
- Commits: 12c4dd2 (fl_dem_aoi collection rename), acb2453 + d7b5a0f (cache build script)
- Cache build: 18.9 min from d7b5a0f, local tiles; n_10m 28,727, n_site_10m 20,586, n_5m 186,675,
  n_1m 3,096,003; no warnings at 1 m; lidar NA 22.3% (extent) / 7.9% (site), barely touching floodplain
- Vignette converted to live; guard proven to fire in a scratch copy (callout + test FAIL 1)
- `devtools::test()` 280 pass / 0 fail; lintr clean on touched files; `devtools::check()` 0/0/2 NOTEs
  (both pre-existing: CITATION.cff, pkgdown/); `pkgdown::build_article()` writes both figures, 0 `@ref`
- Next: /code-check, commit, archive, PR

## Session 2026-10-07 (cont.)

- /code-check: round 1 (2 fixed), round 2 (1, inside round-1 fix), round 3 (mechanism: every 0
  cell read as "above the flood surface"; 77.4% of pop-ups fail 1 m slope — reproduced), round 4
  (3, one inside round-3 fix). Ended by enumerating all 36 result-describing sentences.
- c0c0e46: build script records popup_steep_share, site_steep_share, n_10m_no_lidar; cache
  rebuilt (21.3 min), valley rasters byte-identical
- Filed #63 (fl_valley_confine NA -> 0)
- Final: devtools::test 280/0; lint clean on touched files; pkgdown article 2 figures, 0 @ref
- Next: archive, PR
