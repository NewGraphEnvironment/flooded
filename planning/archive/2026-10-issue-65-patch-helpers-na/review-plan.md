# Plan review for #65 (Plan agent, spawned 2026-10-13 04:05 UTC, delivered after Phases 1-3 landed)

Findings (verbatim structure, condensed):

- **B1 Blocker**: DEM-valid cells with NA slope (DEM speck inside a gap; user `slope` NA where DEM
  valid) read NA on the default path on the branch, where main's fl_patch_rm() zeroing gave 0.
  Fix: after `mask(valleys, dem)`, `ifel(is.na(valleys) & !is.na(dem), 0L, valleys)`; reword @return.
- **G1**: CLAUDE.md Test-data-traps bullet still says the bundled DEM hides #65.
- **G2**: Phase 4 should compare cached rasters cell for cell plus printed stac_meta fields; the
  script hard-codes out_dir (run in a copy).
- **G3**: Parsnip checked offline by reviewer: 441,054 valley cells main vs branch, 0 cells differ.
- **G4**: NEWS needs a behaviour-change entry for direct helper callers (diggs checked, unaffected).
- **O1**: B1 before Phase 4.
- **A1-A5**: helper fix correct for NaN/factor; Inf in removed patch -> NaN (outside binary contract);
  bundled pins confirmed untouched; costDist returns NaN for cut-off cells.
- **S1**: stream raster with no cells -> all 0 where main gave all NA.
- **AC1**: island st=5000 arm passes on main (guards Phase 3); rm-early and conn-no-anchor tests are
  guards, not reproductions.
- **AC2**: assert the fixture reaches the case (cost NaN on island; default arm removes a patch).
- **AC3**: tests for cases B and C on both arms.
- **AC4**: build vignettes / devtools::check().
