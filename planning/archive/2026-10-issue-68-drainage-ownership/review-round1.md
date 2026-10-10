# Review round 1 — branch 68 (drainage method), diff 484c2de...HEAD

Scope read in full: R/fl_flood_depth.R, R/fl_flood_model.R, R/fl_valley_confine.R,
tests/testthat/setup.R, tests/testthat/test-fl_flood_depth.R, tests/testthat/test-fl_valley_confine.R;
measure_morr.R, measure_audit.R, measure_level_rule.R, measure_drainage_reach.R and their logs.

No WhiteboxTools run was made: a `devtools::test()` (pid 78774) was in flight during the review.
Pure-R probes only.

Verified correct (no finding):
- `fl_path_max()`: brute-force comparison on 300 random permuted forests (n up to 60, 40% NA),
  both `max` and `from`: 0 mismatches. Loop cap `ceiling(log2(n)) + 2` is sufficient.
- `fl_pointer_next()`: ESRI codes map to the right offsets; off-grid / 0 / NA / invalid self-point.
- `R_WHITEBOX_MAX_PROCS` really outranks `whitebox.max_procs` in whitebox 2.4.3
  (`wbt_max_procs()` returns the env var first), and `wbt_system_call()` passes it as `--max_procs`.
  The on.exit restore is correct for unset and set-but-empty.
- `terra::focal(fun = "max", na.rm = TRUE)` on an all-NA window returns NA (terra 1.9.50), so
  cells with no stream in their window carry NA -> -Inf, never a spurious level.
- WhiteboxTools D8Pointer skips nodata neighbours, so no path enters an NA cell.
- `fl_valley_confine()` pass-through, `match.arg` validation, and the pooled pins are fine.
- Measurement scripts: the numbers quoted in roxygen/CLAUDE.md/research (−28.6% / 29%, 5.9 m,
  −25.6% MORR, 0 ha vs 451.9 ha, 13,569 cells ≈ 1,256.5 ha, ~2.5x ff gaps) match the logs.

## Findings

- **[fragile] DESCRIPTION (Suggests: `testthat (>= 3.1.5)`) vs tests/testthat/test-fl_flood_depth.R:78** —
  the branch introduces the package's first `local_mocked_bindings()` call (no other test file uses
  it), but `local_mocked_bindings()` only exists from testthat **3.1.7** (testthat NEWS: "3.1.7 —
  Experimental new `with_mocked_bindings()` and `local_mocked_bindings()`"). On a 3.1.5/3.1.6 install
  the "names whitebox when it is unavailable" test errors with "could not find function". Bump the
  pin to `>= 3.1.7` (3.1.8 if relying on its binding fixes).

- **[bug, doc claim] R/fl_flood_depth.R:58-60** — "adding a watercourse never lowers a waterline, so the
  flood mask is monotone in the streams" is false at the added watercourse's own cells. Line 150
  replaces the path-max waterline with the stream's own `flood_surface` at stream cells (which can be
  lower than the inherited level), and line 156 sets depth there to 0, so `fl_flood_model()`'s
  `flooded` layer (`depth > 0`) goes 1 -> 0 on any previously flooded cell that becomes a stream cell.
  The package's own test knows this: test-fl_flood_depth.R:131 excludes the creek cells
  (`off_creek`) before asserting monotonicity. Only `fl_valley_confine()` is monotone, because it ORs
  stream cells back in (fl_valley_confine.R:246). Scope the sentence to non-stream cells / the
  valley output, or it is a claim the exported `fl_flood_model()` output violates.

- **[bug, doc claim] R/fl_flood_depth.R:53-54** (mirrored in the `fl_drainage_level` comment) —
  "The level can sit up to one cell's down-path drop below the stream's own" is not a bound the code
  enforces. `bed` is the 3x3 minimum of the original DEM over *any* neighbour, stream or not, so the
  level can sit below the stream's level by however far the lowest neighbour is below the stream
  cell (a bank-drawn stream line, a ditch, a channel cell beside the line). That is the stated
  purpose of the rule two sentences earlier ("one high stream-cell elevation ... is not carried
  upstream"), so the two sentences contradict each other; the "one cell's drop" only holds on the
  synthetic planar fixture. Per CLAUDE.md ("compute it or do not make it"), drop or measure it.

- **[bug, wrong number label] research/flood_surface_interpolation.md ("On Parsnip, 94.7% of the lost
  cells *do* drain to a stream")** — per measure_audit.log, 94.7% is the "owned but dry" share; the
  share of lost cells whose path meets a stream is 94.7% + 3.7% (wet, removed by cleanup) = 98.4%
  (unowned 1.6%). The number is attached to the wrong category. Either "98.4% drain to a stream" or
  "94.7% drain to a stream and come out dry".
