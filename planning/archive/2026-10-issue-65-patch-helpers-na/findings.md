# Findings — fl_patch_rm() and fl_patch_conn() turn NA input cells into 0 (#65)

## Issue context

## Problem

Two exported helpers turn `NA` cells into `0`, which is the mechanism behind #63:

- **`fl_patch_rm()`** (`R/fl_patch_rm.R`): `out <- terra::ifel(is.na(masked) | is.na(patches), 0L, x)`.
  `patches` is NA on every cell that is not a `1`, including NA input cells, so they come back as 0.
  This only happens when at least one patch falls under `min_area`. Otherwise the early
  `if (length(small_ids) == 0L) return(x)` hands `x` back with its NA intact. So whether NA
  survives depends on an unrelated property of the data. The `@return` says all other values are
  unchanged.
- **`fl_patch_conn()`** (`R/fl_patch_conn.R`): `out <- terra::ifel(!is.na(kept), x, 0L)` sets NA
  input cells to 0 the same way. It has its own early return too: when no patch touches the
  anchor it returns `x * 0L`, which keeps NA. So it is also path-dependent.

The early return has a second consequence. Cells that do have DEM values but are cut off from every
stream by a gap get no cost distance (`costDist` gives NaN past an NA barrier), so they are NA going
into `fl_patch_rm()`. If no patch is small enough to remove, they come out of `fl_valley_confine()`
as NA even though the DEM has values there. When some patch is small enough, they come out as 0.
The output therefore depends on an unrelated property of the data in both directions.

#63 fixed the symptom in `fl_valley_confine()` by masking its result with the DEM after cleanup.
A caller that runs `fl_patch_conn()` on that output, as the valley-confinement vignette does, gets
the 0s back on any DEM with gaps. The bundled tile has no NA cells, so nothing in the suite shows it.

## Proposed

Preserve NA in both: `ifel(is.na(x), NA, ...)`, or restrict the zeroing to `!is.na(patches)`.
Cover the no-anchor path of `fl_patch_conn()` as well. The bundled `slope.tif` has a 2,892-cell NA
border ring that can serve as a ready-made fixture: `test-fl_patch_conn.R` already passes it through
without asserting anything about NA. Pin it with a synthetic NA block, plus a case with no small patches so both paths of `fl_patch_rm()`
are covered.

Found by plan review on #63.




## Plan-mode probe (2026-10-12)

6x6 synthetic grid, 2 NA cells (`pkgload::load_all()` on main @ 6b5cd1d):

| call | NA cells out |
|---|---|
| `fl_patch_rm(r, 150)` (removes a patch) | 0 |
| `fl_patch_rm(r, 50)` (early return) | 2 |
| `fl_patch_conn(r, anchor)` | 0 |
| `ifel(is.na(kept), x * 0L, x)` | 2 (fix shape) |

## Decision at the plan gate

Cells with a DEM value that a gap cuts off from every stream (costDist NaN) read **0** in
`fl_valley_confine()`: unreachable fails the cost criterion. NA stays reserved for "no DEM".

## Errors Encountered

| Error | Resolution |
|-------|------------|

## Parsnip cache (Phase 4, 2026-10-13)

Recomputed with the branch code (guard at 0e81083) from the cached `pars_dem.tif` and `pars.gpkg`
streams/waterbodies, using the `data-raw/wsg_vignette_data.R` call (ff04, waterbodies, precip):
441,054 valley cells live and cached; 0 cells differ in `== 1`; 0 DEM-valid cells NA. The valid-slope
area is one 8-connected region (no cut-off ground). No rebuild needed.
Side note, outside #65: `pars_valleys.tif` holds no NA although `pars_dem.tif` has 10,180,862 NA
cells — the cache predates #63 or was written without a nodata flag.

## Narrow gaps (code-check round 1)

Cut-off ground behind a 1-2 cell DEM gap can still come out 1: the closing and modal filters reach
across. Bundled tile, 1-cell NA ring around rows 307:315, cols 237:245: 24 of 49 island cells 1, 25 0,
all 49 with no cost distance. Pre-existing cleanup behaviour; the roxygen now says so.

## stac-dem cache rebuild (Phase 4, 2026-10-13)

`data-raw/stac_dem_vignette_data.R` run in a scratch copy of the tree (it hard-codes
`inst/vignette-data/` as output), code at 0e81083 (logic final; later commits are prose), tiles in a
scratch `STAC_DEM_TILE_DIR`. 04:36:21 to 05:02:18 UTC. Both rasters identical cell for cell to the
committed cache: 5 m-on-10 m NA 115,385 / ones 46,656; 1 m site NA 11,020 / ones 31,030. stac_meta
differs only in flooded_version, git_sha (empty: copy has no .git) and date_built. Cache left
unchanged. (A first run on pre-B1 code was stopped at the 1 m stage once B1 landed.)

## Where the zeroing sits (code-check round 3)

The zeroing must come before the 3 x 3 modal filter, because `na.rm = TRUE` skips NA voters. Main's
removal path (inside fl_patch_rm()) zeroed every NA there. Zeroing after the filter (round 2
placement) changed DEM-valid cells next to NA regions: valley-floor 13 x 13 supplied-slope NA block
gave 120/169 ones vs 92; an island behind a 1-cell ring gave 34/121 vs 2. Final placement (right
after fl_patch_rm(), then mask(dem)) is identical to main's removal path on every fixture measured
(`scratchpad equiv.R`: ring1/ring2 on valley floor, ring3 island, slope-NA valley/hill, bundled).
