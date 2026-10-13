# Code-check round 2 — #65 (diff 6b5cd1d...HEAD, d54553d)

## Clean

No issues found.

## What was checked (evidence)

All probes ran on rsync copies under the session scratchpad; nothing under the repo was edited
except this file.

- **Suite on the branch tree** (`NOT_CRAN=true`, `test_file()`, counting `failed > 0 | error`):
  test-fl_patch_rm 7/0 bad, test-fl_patch_conn 7/0, test-fl_valley_confine 28/0.
- **Restore-the-bug, each guard alone, exact prior lines:**
  - `fl_patch_rm()` old `ifel(is.na(masked) | is.na(patches), 0L, x)`: 1 bad, "keeps NA cells NA
    when it removes a patch" (the early-return test stays green, as it should: it is the control).
  - `fl_patch_conn()` old `ifel(!is.na(kept), x, 0L)`: 2 bad, the connected-path test and the
    slope.tif ring test.
  - `fl_valley_confine()` with the new `ifel(is.na(valleys) & !is.na(dem), 0L, valleys)` line
    deleted (patch helpers fixed): 3 bad, the island, speck and NA-slope tests. So the three new
    valley tests are what pins that line; the patch-helper fix alone does not satisfy them.
- **Equivalence of the helper rewrites off NA:** old and new `ifel` forms agree on every non-NA
  cell (0 -> `x*0L` = 0, small/dropped patch -> 0, kept -> x); they differ only on NA input,
  which now stays NA on both paths of both helpers. Roxygen `@return` lines for both are true.
- **Roxygen absolute "Every cell with a DEM value is 0 or 1":** branch points between input and
  claim walked. After `mask(valleys, dem)` the new line sets every DEM-valid NA to 0; the two
  overlays only write 1 (`buf_r`/`wb_r` use `background = 0L`, so no NA enters). Holds.
- **"size_threshold is read only by fl_patch_rm()"** (test helper comment): grep confirms the
  only use is `R/fl_valley_confine.R:267`. Default is 5000 (line 145), matching `p5000`.
- **Island fixture comment "more than 200 m from any stream":** measured 202.5 m to the nearest
  stream cell centre, 206.8 m to the nearest stream line. True. 3-cell ring / 25 x 25 island
  arithmetic checks.
- **NA-slope test:** no valley cell within 5 cells of the 31 x 31 block on the unmodified tile, so
  `== 0L` cannot be broken by the closing filter reaching in; the `anyNA` assertion is the
  discriminating one and fires on the mutant.
- **Roxygen "(one or two cells)" envelope for cleanup marking a cut-off cell 1** — measured on 4
  all-valley 21 x 21 windows with an NA ring of width g around a stream-free island:

  | g | derived slope (default) | supplied slope, masked to DEM |
  |---|---|---|
  | 1 | 56/225 (island edge ring) | 104/225 (two rings deep) |
  | 2 | 0/169 | 48/169 (edge ring) |
  | 3 | 0/121 | 0/121 |
  | 4 | 0/81 | 0/81 |

  So "one or two cells" is the correct envelope (two only with a supplied slope); 3+ never
  reaches. Accurate as written.

## Non-blocking observations (not defects; for the caller to weigh)

1. **Test comment precision** (`test-fl_valley_confine.R`, island_fixture header): "behind a 1-2
   cell gap they can mark its edge 1". With the fixture's derived slope only a 1-cell gap
   reaches (edge ring only); with a supplied slope a 1-cell gap marks two rings, not just the
   edge. True as an envelope, slightly loose in both directions. Leave or tighten.
2. **"Cut off" is a slope/cost property, not a DEM one.** If a caller supplies a `slope` that has
   values inside a DEM gap, `costDist` crosses the gap and the island is not cut off at all:
   measured 225/225 and 169/169 island cells = 1 at g = 1, 2 with an unmasked supplied slope.
   That is reasonable behaviour and the roxygen ("a cell that a gap cuts off") does not claim
   otherwise; the code comment's "costDist cannot cross NA" is about NA in the friction (slope)
   surface. Worth knowing if anyone later writes "a DEM gap always cuts off".
3. `test-vignette_data.R` parenthetical "(before #65, fl_patch_rm() kept NA on its early
   return)": true, but after #65 the helpers keep NA on *both* paths, so a regression of #63's
   mask would leave even more NA — the conclusion ("any NA" would not catch it) is stronger now,
   not weaker. Not false.

Pre-existing, out of scope: `terra::freq()` errors on an all-NA `patches` raster (no 1-cells at
all) in `fl_patch_rm()` / the hole-fill step; untouched by this diff.
