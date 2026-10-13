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
