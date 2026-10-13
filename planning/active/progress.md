# Progress — fl_patch_rm() and fl_patch_conn() turn NA input cells into 0 (#65)

## Session 2026-10-12

- Plan-mode exploration — phases approved by user (cut-off cells read 0)
- Created branch `65-fl-patch-rm-and-fl-patch-conn-turn-na-in` off main
- Scaffolded PWF baseline from issue #65 with approved phases
- Next: start Phase 1
- Phase 1: tests added. On unfixed code 4 fail (rm removal path, conn connected path, slope.tif
  ring, valley_confine island). The rm early-return and conn no-anchor tests pass by design: those
  paths already kept NA, and the tests pin them. Island probe on main: 625/625 NA at
  size_threshold = 1, 625/625 zero at 5000.
- Phase 2: both helpers use `ifel(is.na(kept), x * 0L, x)`; helper tests 14/14 pass.
- Phase 3: `mask_cost` NA -> 0 where slope has a value. Island test passes on both paths;
  test-vignette_data pins hold; bundled-tile output identical cell for cell to main's
  fl_valley_confine() with and without slope.tif. @return softened to "fails the cost criterion
  rather than reading as NA": hole fill can still set a small enclosed island to 1 before
  fl_patch_rm(), so "is 0" would overclaim.
- Plan review delivered after Phases 1-3 (findings in review-plan.md). B1 reproduced: a 2x2 DEM speck
  inside a gap (4/4 NA) and a supplied slope with a 31x31 NA block (625/961 NA) came out NA on both
  paths. Fixed with a guard after `mask(dem)`; the Phase 3 `mask_cost` line was dropped (subsumed;
  mutation showed no test depended on it). Mutation without the guard: speck and slope tests fail.
  Bundled-tile output still identical to main's, with and without slope.tif.
- Phase 4: stac-dem rebuilt in scratch on final logic; rasters identical to the cache, kept. Parsnip recomputed; identical. Code-check rounds 1-2 done (round 1: two prose fixes; round 2 clean); round 3 running.
