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
