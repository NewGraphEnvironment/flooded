# Progress — fl_dem_aoi() lets GDAL choose the output grid (#67)

## Session 2026-10-13

- Plan-mode exploration — phases approved by user
- Gate decisions: Parsnip cache rebuilt in this PR; geographic target with no `res` stops with a computed suggestion
- Created branch `67-fl-dem-aoi-lets-gdal-choose-the-output-g` off main
- Scaffolded PWF baseline from issue #67 with approved phases
- Next: start Phase 1
- Plan review (Plan agent) returned 2 blockers and 6 gaps; dispositions in `review-1.md`. The crop design changed (G2); Phase 3 got three arms (G1) and like-for-like warp paths (B2); Phase 4 rebuilds from cache, not the DB (B1)
- Phases 1–2: grid tests written and shown red on the old code; `fl_dem_aoi(res = )` projects onto a template aligned to multiples of `res`. Full suite 372 PASS, 0 FAIL
- Phase 3 measurement started: harness `planning/active/measure_grid.R`
- Phase 3: MORR measurements. Root cause is the PROJ datum operation, not GDAL's warper. Gate decision 2 (user): pin plus override plus recording. The pin landed in 30df085
- Phase 4: Parsnip cache rebuilt from cached inputs (40,888.2 ha ff04 on the fixed grid); vignette and notes updated
- Filed flooded#76 (UInt32 nodata reprojected as 2^32, pre-existing)
- Phase 5: CLAUDE.md note; #67 and floodplains#117 bodies corrected (cause = PROJ datum operation)
- /code-check branch:
  - r1: 7 findings, fixed (geographic NAD83 gave all-NA; terra floor; datum regex; a test passing for the wrong reason)
  - r2: a defect inside r1's fix (northing-first projected CRSs), fixed with an axis guard
  - r3: the mechanism (stand-ins for library behaviour) traced to every place it reaches; harness made able to fail
  - enumeration over 1,935 CRSs: 0 unexplained. Loop ended by enumeration
