# Code-check round 2: fl_valley_join() (flooded#83) + floodplains adapter

## Findings

- **[severity: bug (doc)]** CLAUDE.md:51 says `(19 test files, 182 test_that blocks)`. The tree has
  **183**. `grep -c '^test_that(' tests/testthat/test-*.R` sums to 183, the base 1ca0d12 had 166 (which
  matches its own line), and test-fl_valley_join.R has 17. The count looks like it was taken before
  b2c7dc3 added "a polygon covering no cell centre claims no cell". Change it to 183.

- **[severity: fragile]** R/fl_valley_join.R:901 (`cb <- cb[!is.na(cb[, "cell"]), , drop = FALSE]`,
  the NaN drop from round-1 fix 1). No test fails without it. Mutation run in a temp copy, with that
  line replaced by `cb <- cb`: all 17 tests pass and one test only WARNs. The new test "a polygon
  covering no cell centre claims no cell" checks `any` and `nearest` but not `out$check`. Without the
  filter, the NaN row from `small = FALSE` goes into `claimed`. `check` then reads
  `attributed_cells` +1 and `extra = 1`, and the "claimed cells lie outside the valley" warning is
  false. The join tables come out right only because `%in% valley_cells` drops the NaN later. The
  test names the defect class, but the half of the fix that keeps `check` honest is unguarded. An
  `expect_equal(out$check[["extra"]], 0L)` (or `expect_no_warning`) in that test would pin it.
  Other round-1 fixes, mutation-checked in the same copy:
  - `small = FALSE` removed: the sliver test goes red.
  - The empty-segment drop removed: the empty-only-group test goes red.
  - The `any` NA rule reverted: the no-segments test goes red.
  - NA key sorted first: the NA-key tie test goes red.

- **[severity: fragile, low]** floodplains scripts/floodplain_lcc/fp_habitat_join.R `fp_hj_join_position()`
  against `fp_hj_grid_cells()`. Since round-1 fix 1, the integrity check the callers `stop()` on and
  the claims the join uses are two derivations of one fact. `fp_hj_grid_cells()` calls
  `terra::cells(r, vect(v))` with the default `small = TRUE`. `fl_valley_join()` uses
  `small = FALSE`.
  - **Where they diverge:** a polygon that covers no cell centre. The caller's check passes, while
    `fl_valley_join()` only warns (missing > 0). Those cells then drop out of the by-position
    hectares but stay in the by-blue-line ones, and the log does not record the warning.
  - **Not reachable today:** `fl_valley_attribute()` polygons come from `as.polygons()` on the grid,
    so they are cell-aligned. The claims were identical on the bundled tile, and your 4-WSG A/B
    matched.
  - **The fix if wanted:** have the adapter also stop on `fr$check[c("missing","extra")] != 0`, so
    the guard checks the claims that were actually joined. This uses the existing check; no new
    error handling.

## Checked and clean (no action)

- **`terra::cells(..., touches = FALSE, small = FALSE)`**, on terra 1.9.50:
  - A polygon covering no cell centre returns `ID, NaN`. `small = TRUE` returns the overlapped cell.
  - `small` predates the `terra (>= 1.9-25)` floor.
  - `vect()` of an sf with an empty polygon row keeps the row, so `cb[, "ID"]` stays aligned with
    `keys`.
- **`lvls` construction** handles no-NA, NA, and zero-row `attributed`. The zero-row-and-empty edge
  cases run through `rbind` with the typed template, `tabulate(nbins = 0)`, and the `second` /
  `prev_dist` vectors at nrow 0 and 1.
- **Tie count on the tile is 48** with `check` 0/0. The claims with `small = TRUE` and `small = FALSE`
  are identical on the tile.
- **Doc figures verified against their sources:**
  - "49 of 50 segments carry the same habitat flags": rearing/spawning `1 1` on 49 of 50 rows.
  - BULK sk 16,705.26 / 571.86 ha: from floodplains logs/20261015_habitat_join-query_bulk.md.
- **Doc claims verified against the code:**
  - "A nearest TRUE is always an any TRUE".
  - "no-segment group never owns a cell another claimer has segments for" (`Inf` sorts last).
  - "ties exclude Inf".
  - "Rows in cell order".
- **floodplains adapter:**
  - `%in% TRUE` restores the old NA-as-FALSE semantics.
  - `blk_without_segments` = `length(no_segments)` matches the old per-claiming-key count when
    integrity holds.
  - The extra `blue_line_key` and `dist` columns in `nearest` are harmless to `merge()` (suffixed),
    `cls()` and `fp_hj_summ()`.
  - The demo's `a$v` keys (integer or double from the gpkg) `match()` numeric `h$blue_line_key`.
  - The query passes `cfg$attribute_by` as `group`. A non-`blue_line_key` config now errors
    ("not found in `segments`") rather than silently mis-joining as before. This is not a
    regression, because the old code already hard-coded `blue_line_key` on the segment side.
- **Ordering note, not a defect:** `scripts/packages.R` installs flooded from GitHub main. Until
  flooded#83 merges, the "update it with scripts/packages.R" remedy in the adapter's stop() would
  install a flooded without the function. Merge flooded first.
