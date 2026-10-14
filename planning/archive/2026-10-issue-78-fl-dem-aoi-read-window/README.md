# Issue #78 — fl_dem_aoi(): pin the AOI's own transforms

## Outcome

`fl_dem_aoi()` pinned the warp's datum step in 0.7.0 (#67) but still carried the AOI into the
source CRS (the read window) and, for an AOI in a third CRS, into `target_crs` (the grid) with
sf's default PROJ operation. Both now go through `dem_pipeline_nad83()` between projected NAD83
pairs; a supplied `pipeline` is used inverted (`reverse = TRUE`) for the window when the AOI is in
`target_crs`; `pipeline = ""` hands everything back to PROJ; a supplied pipeline that cannot be
applied in reverse stops with a clear error. The plan review caught a real blocker in the first fix:
the grid transform read `pipeline` after it had been replaced by the source -> target pin, so a
WGS 84 source left a pinnable CSRS AOI's grid to sf. Four code-check rounds then tightened the
tests along one mechanism: a guard that compares two runs of the same code (mocked against
unmocked sf) cannot see a deterministic wrong answer, and a fixture or mock that follows sf's own
PROJ loses its power on a newer PROJ. The tests now measure everything from the shift-free
position (`pin_transform()`), assert against independently built results, and every
cell-deciding transform, mutated, is red on sf PROJ 9.5.1 and on sf routed through terra's PROJ
9.8.1. Durable verdict: `research/dem_reprojection.md` §2, "The AOI's own transforms are pinned too".

## Measurement

- **Hazard, 0.7.0:** bundled streams, buffer 100 m, a 30 m x-field source in EPSG:3979, 60
  sub-cell AOI positions; window shift-free vs PROJ 9.8.1's WGS 84 route: **3/60** positions
  changed the DEM, by 49, 91, 47 cells (32, 60, 31 NA/value flips), **0 inside the buffered AOI**.
  Moves a digest, not a delineation inside the buffer.
- **Fix, real PROJ split:** unpinned sf transforms routed through terra's PROJ 9.8.1
  (+0.706, −1.054 m for 3005 -> 3979): 0.7.0 **3/60** (dx = 3.5, 21.5, 28.5), branch **0/60**.
- **Neutral on sf PROJ 9.5.1:** six call shapes byte-identical to 0.7.0.
- **Wrong turns kept:** the first offset search used a source with a different origin from the
  test fixture, so its offsets crossed no boundary and the identity tests passed on 0.7.0; the
  first B1 offsets (2, 9) moved the unpinnable CSRS -> WGS 84 window, not the grid; round 3's
  "window mutant red" was measured on sf 9.5.1 only, and round 4 showed it did not hold on a
  routed 9.8.1 sf. See `findings.md` and `review-round*.md`.

## Evidence

`logs/20261014_*` (this directory), produced by `measure_window.R` and
`measure_window_real_proj.R`; mutant x toolchain table in `review-round4.md`.

Closed by: PR for #78 (branch `78-fl-dem-aoi-the-source-read-window-is-sti`)
