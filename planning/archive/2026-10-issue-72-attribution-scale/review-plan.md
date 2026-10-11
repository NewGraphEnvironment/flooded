# Plan review — #72 (Plan agent, 2026-10-11)

Read-only review of `task_plan.md` against the code; no R was run by the reviewer. Copied from its
reply (the Plan agent type cannot write files). Dispositions follow each item in **[brackets]**.

## Blocker
**B1. PSOCK workers would run the installed flooded 0.6.0, not the tree under test.** The installed
copy (`~/Library/R/arm64/4.5/library/flooded`, 0.6.0, RemoteSha 1eaaaa0) is what a worker loads when
it unserializes a function whose environment is the flooded namespace. A closure defined inside
`fl_valley_attribute()` drags its whole frame (streams, valley_cells, dem, dead SpatRaster pointers).
The Phase 3 bench would then time 0.6.0's `fl_group_cells()`, and "parallel equals serial" would
compare new serial with old parallel. Under `R CMD check` it works, because the package is installed.
Fix: bench installs the tree to a private library and workers get `R_LIBS`, or an internal
worker-init hook does `pkgload::load_all(path)` when `pkgload::is_dev_package("flooded")`. Acceptance:
record the flooded version as seen inside a worker (`clusterEvalQ`), and a restore-the-bug run (a
deliberate change in `fl_group_cells()`) must make the parallel-vs-serial test fail under
`devtools::test()`. **[Accepted — Phase 3.]**

## Assumptions
**A1.** "Most of the 0.6.0 BULK time was the fallback" may not hold for arm 2: 10,202.9 − ~2,519 ≈
7,684 s ≈ 3.0 s/group at 0.6.4 if the old pass cost the same on arm 2, which is ~7.5x over budget.
Caveat: the old full-grid pass may have grown with burned cells; only a main baseline settles it.
**[Being measured: main baseline on bulk_a2. Note the 0.6.0 BULK arm 2 run was itself contended —
10,574 s real vs 8,528 s user, 4.8 M involuntary context switches against MORR arm 2's 0.25 M.]**

**A2.** Per-group cost at 0.6.0 depends on the network as much as the watershed (MORR arms 1–4
0.63–0.78 s/group against coho 0.07–0.10; BULK arm 2 ~3.0, coho 0.65–0.76). Polygon overlap and
vertex counts are similar between watersheds (BULK a2 1.87 M member cells / 466 k vertices, MORR a2
1.70 M / 305 k), so `fl_cells_poly()` and rbind cannot drive the ratio. Profiling coho tells little
about arm 2. **[Accepted: arm 2 is profiled, not only coho. The residuals assume a constant fallback,
which A1's caveat questions.]**

**A3.** Bench `valleys` is file-backed (LZW, one-row strips `Block=<ncol>x1`), so each crop
decompresses full-width rows, twice per group (`fl_group_cells`, `fl_cells_poly`). The 0.6.0 probe
attributed an in-memory `v` straight from `delineate()`. Pick one state and record `inMemory()`.
**[Accepted: bench loads valleys into memory as production has it, and records inMemory for both.]**

**A4.** FLT8S/FLT4S claim unmeasured; test bit-identity directly. Derived slope spilled to disk under
memfrac may use terra's default datatype. **[Accepted for Phase 3 (assert identical values after the
round trip). Record inMemory(slope).]**

**A5.** "Identical to serial" needs guards: CRS round-trip through GeoTIFF may not compare equal under
sf, so workers would `st_transform` and shift burned cells; set the master's CRS string and assert
`compareGeom()`. Worker warnings are dropped and errors re-wrapped — capture and re-raise in group
order. **[Accepted — Phase 3.]**

**A6.** Threads cannot explain the BULK/MORR ratio (both at 12); `terraOptions` is global, so changing
it inside the function is a side effect. **[Accepted; the 80-group probe already showed threads 1 vs
12 within noise.]**

## Gaps in the profile design
- **G1.** Get one run whose parts sum to the total (checkpoints in `fl_valley_attribute()`: slope,
  valley read, group loop, unique/setdiff, fallback, polygonize loop, rbind), plus gc deltas.
  **[Accepted. The 108/37/130 split came from three different runs under heavy, varying load —
  the 130 s gap was an artefact: a clean main e2e on bulk_co is 52.7 s.]**
- **G2.** Slope derivation (terrain + four full-grid passes on 38.3 M cells from a one-row-strip DEM)
  is inside the timed call and outside both helpers; `steps` never sees it. Keep `tan(x*pi/180)*100`
  order exactly. **[Accepted: checkpoint it.]**
- **G3.** Rprof samples CPU by default; `Rprof(event = "elapsed")` exists since R 4.4.0. Compare
  `sampled_s` with `t_attr_s` before reading by.total. **[Accepted: 101 s sampled of 338 s wall in the
  contended rprof run; that run is discarded.]**
- **G4.** Rprof over 200 small groups cannot see whole-call terms; whole-call rprof is right.
  **[Accepted.]**
- **G5.** Order bias in `steps`: the real `fl_group_cells()` warms caches before the replica. Time
  the replica first. **[Accepted.]**
- **G6.** Profile MORR and BULK on the same arm; k-scaling probe (k = 250/500/1000/2550,
  `complete = FALSE`); padding probe (empty-geometry rows under one dummy key: per-row ∝ N vs
  per-group ∝ k); regress per-group time on crop, seed, member cells and vertices. **[Partly: k-scaling
  and per-row vs per-group if the main baselines leave a superlinear term to explain.]**
- **G7.** `steps` hard-codes 1000 / 2000; assert against scenario values. **[Accepted.]**

## Phase 3 design
- **P1.** Load balance: `clusterApplyLB`, largest crop first, reassemble by group index.
- **P2.** Amdahl: group work alone is a fraction of the total; say whether `fl_cells_poly()` runs in
  workers (a second parallel pass, after the fallback).
- **P3.** Tempfiles: `TILED=YES`, `COMPRESS=NONE`; valleys INT1U.
- **P4.** Worker setup: `terraOptions(threads = 1, progress = 0)`; `setGDALconfig` not inherited;
  GDAL reserves ~3.3 GB per process — measure summed RSS.
- **P5.** Only plain data crosses the socket: pre-split per-group sf + paths in, `list(cells, reason)`
  out.
- **P6.** `on.exit(stopCluster)` right after `makeCluster`, unlink tempfiles after; `workers = 1`
  takes today's exact path.
- **P7.** Validate `workers`: length 1, finite, whole, >= 1; clamp to number of groups.
**[All accepted if Phase 3 runs.]**

## Membership testing
- **M1.** The bundled tile is 800 x 648 at 10 m; a 2 km margin is 200 cells per side, so most crops
  clamp to tile edges and an off-by-one in a local->global offset is invisible. Add a non-vacuity
  check (some group with row0 > 0, col0 > 0, crop smaller than the grid); if none, force interior
  crops (e.g. `max_width = 400`, `crop_margin = 600`) pinned to a main snapshot, not the oracle.
  Confirm the oracle test passes at main first. **[Accepted.]**
- **M2.** Restore-the-bug runs: (a) one-row local->global shift, (b) `snap = "near"`/`"in"`,
  (c) FLT4S tempfile, (d) parallel results in completion order. Report which the tests catch; (b) is
  probably not caught at a 2 km margin. **[Accepted.]**
- **M3.** Parallel test with many groups (one per segment), `identical()` on the whole sf incl.
  `fl_fallback_cells`, the Elsewhere/Subpixel/Empty fixtures at `workers = 2` with matching warnings,
  `skip_on_cran`, <= 2 workers. **[Accepted.]**
- **M4.** e2e cell extraction via `terra::cells(valleys, vect(x))` is sound. **[Noted.]**

## Ordering
- **O1.** BULK arm 2 e2e at main first, before choosing Phase 2 candidates. **[In progress.]**
- **O2.** Measure each Phase 2 commit on BULK coho or a fixed subset; arm 2 for acceptance.
- **O3.** Arm 2 extraction already done. **[Done.]**
- **O4.** New oracle test must pass at main before any change.

## Scope
- **S1.** Decide polygonize / cell-table from arm 2's profile, not coho's. **[Accepted.]**
- **S2.** Replacing rbind or partial `st_make_valid` changes geometry/row names/agr — needs
  `identical()` on output; likely small gain. **[Accepted: not pursued unless profile demands.]**
- **S3.** Cheap and safe: pre-split streams with `split()`, skip per-group PROJ CRS parse in
  `fl_stream_rasterize`. Measure both. **[Accepted as Phase 2 candidates.]**

## Acceptance
- **AC1.** If A1 holds, say what is accepted when 17 min is not reached: report the figure and the
  gap, file a follow-up. **[Accepted.]**
- **AC2.** Phase 3 equality acceptance includes proof of which code the workers ran. **[Accepted.]**
