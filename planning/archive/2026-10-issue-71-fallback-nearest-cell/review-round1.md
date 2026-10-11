# Code review, round 1: branch diff b701391...HEAD (#71)

## Clean

No issues found.

What was checked, and how:

- `fl_nearest_group()` against `terra::distance(target = NA, values = TRUE)` on synthetic
  grids (projected and EPSG:4326): identical assignments, including a query cell that is
  itself burned (distance 0, takes its own value). Passing `cells` as double works.
- CRS-less grid: the helper errors in `sf::st_crs("")` where terra only warned. This is
  **not reachable** through `fl_valley_attribute()`: with a missing CRS, the existing
  `sf::st_crs(streams) != terra::crs(valleys)` check is TRUE and `st_transform()` already
  errors at line 171 on main as well (probed end to end). Not a regression.
- Empty burned set and empty `cells` both return all-NA of the right length; the caller's
  `!all(is.na(assigned))` guard reproduces the old "no burned cells" skip, and the message,
  `n_assigned` and `fl_fallback_cells` paths are unchanged.
- Test file `test-fl_valley_attribute.R` run under `NOT_CRAN=true`: 20 blocks, 0 failed,
  0 errors, 0 skipped. The new test is not vacuous (`expect_gt(length(uncovered), 0)`,
  `expect_gt(length(msgs), 0)` before the `all = FALSE` matches), `gap` on an empty `differ`
  is `numeric(0)` and passes `all()` correctly, and `hits == 1L` catches an unassigned cell
  (`got == 0`). Its unconditional NA level only appends an index, so named-group indices
  match the function's.
- Docs figures (37.8 s, 35.2 s, 0.4 s, 805.6 s, 855.8 s, 14,170 cells, "assigned
  identically") all match `bench_fallback.log` (cells_differing 0, 339 groups with 0
  differing counts).
- `planning/` is in `.Rbuildignore`, so `bench_fallback.R` does not ship.
