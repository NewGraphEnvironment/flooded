# Review round 1 — `fl_valley_attribute()` staged diff

Target: `git diff --cached` at review time (`R/fl_valley_attribute.R`,
`tests/testthat/test-fl_valley_attribute.R`, `man/`, `NAMESPACE`).
Line numbers below are from the **staged** blob (`git show :R/fl_valley_attribute.R`).

Note: the working tree has already moved past the index (adds `crop_margin`, reorders
`dem`/`slope`, adds a `no_seeds` warning, returns a list from `fl_group_cells()`). All
probes below were run against the **staged** code in a sandbox copy so the review matches
what is about to be committed. Where a worktree change already addresses a finding it is
called out.

Staged tests pass: `FAIL 0 | WARN 0 | SKIP 0 | PASS 33`.

## Findings

- **[bug]** `R/fl_valley_attribute.R:188-193` — the zero-parts branch returns a
  structurally **corrupt `sf`** that cannot be printed, plotted, or written.
  `sf::st_sf(valley = integer(0), sf::st_sfc(crs = ...))` makes the unnamed `sfc` the
  *geometry* column with an auto-generated name (`sf..st_sfc.crs...sf..st_crs.valleys..`).
  `names(out)[2] <- group` then renames **the geometry column** to e.g. `"gnis_name"`
  while `attr(out, "sf_column")` still points at the old name. The result has no group
  column at all, and every sf accessor errors:
  `attr(obj, "sf_column") does not point to a geometry column.`
  Reproduced end-to-end against the staged code on the bundled tile:
  ```r
  out <- fl_valley_attribute(valleys * 0, streams, group = "gnis_name", dem = dem)
  names(out)              # "valley" "gnis_name"
  attr(out, "sf_column")  # "sf..st_sfc.crs...sf..st_crs.valleys.."
  st_geometry(out); print(out); plot(out); st_write(out, f)   # all error
  ```
  Reachable whenever no group yields a cell — an empty/over-thresholded delineation, or a
  tile with no floodplain. No test exercises the branch, so it ships untested. Build the
  group column explicitly and let `st_sf()` name the geometry, e.g.
  `sf::st_sf(valley = integer(0), setNames(list(keys[0]), group), geometry = sf::st_sfc(crs = sf::st_crs(valleys)))`
  — never rename an sf column by position. Still present in the working tree.

- **[bug]** `R/fl_valley_attribute.R:180-186` (with `:210-215`) — a group whose streams lie
  **entirely outside the valley raster** is silently dropped from the output: no row, no
  warning, no error. `fl_group_cells()` returns `integer(0)` via the `is.null(e)` guard and
  the polygonize loop `next`s. Reproduced: appending one stream segment translated 500 km
  and grouping on it returns rows for `main` only, with `far` absent. `@return` promises
  "one row per group", so a caller doing
  `merge(attribution, per_group_stats, by = "gnis_name")` loses that group with no signal —
  the missing row reads as "this river has no floodplain" rather than "this river was not
  processed". The staged test at `test-fl_valley_attribute.R:213-225` explicitly permits
  the drop (`|| nrow(out) == 1L`) rather than pinning the behaviour, so tests pass while the
  contract is broken. The working tree added a `no_seeds` warning for the sibling
  "rasterized to nothing" case but left this path silent.

- **[fragile]** `R/fl_valley_attribute.R:191,196` — `fl_fallback_cells` is set to
  `length(uncovered)` unconditionally, including under `complete = FALSE` where **nothing
  was assigned**. `@return` and the Coverage section both describe it as "the number of
  cells assigned by the coverage fallback". Measured on the waterbody fixture:
  `complete = FALSE` returns `fl_fallback_cells = 1643` for a run that attributed zero
  fallback cells. Anyone using the attribute as a QA metric ("how much ground was guessed?")
  gets a false positive. Either zero it when `complete` is `FALSE` or redocument it as
  "cells outside every group's thresholds".

- **[fragile]** `R/fl_valley_attribute.R:143-145` — the comment claims the crop margin makes
  the answer exact: *"Margin is max_width (twice the corridor half-width) so a least-cost
  path to a candidate cell cannot be clipped by the crop edge."* That is not a bound.
  `terra::costDist` treats everything outside the crop as impassable, and a least-cost
  detour across flat ground can leave and re-enter the corridor over an arbitrary distance,
  so cropping can only ever *over*-estimate cost and silently drop edge cells. Verified
  exact on the bundled tile — cropped vs full-grid oracle for **all five** `gnis_name`
  groups gave `missing = 0, extra = 0` — so there is no observable defect here, but the
  guarantee in the comment is false and the single-group test
  (`test-fl_valley_attribute.R:109-133`) cannot catch it on other terrain. The working tree
  has already reworded this and exposed `crop_margin`; it should not land in the index in
  its current form.

## Probed and clean

Each of these was reproduced against the staged code on `inst/testdata/`, not reasoned about:

- **Cropped-cell → global-cell mapping is exact.** `cellFromXY(valleys, xyFromCell(member, …))`
  matched a full-grid oracle for every group (`ref == got`, 0 missing / 0 extra; 49,989 /
  20,087 / 25,187 / 12,651 / 23,367 cells). The half-cell tolerance in `cellFromXY` swamps
  any float drift from the `snap = "out"` crop.
- **`terra::extend(SpatExtent, n)` and `terra::intersect(SpatExtent, SpatExtent)` are the
  right calls.** terra 1.9.34: `extend` grows all four sides by `n`; `intersect` returns
  **`NULL`** (not an empty extent, no warning) when the extents miss, so the `is.null(e)`
  guard on line 215 fires correctly. Partly-outside groups clamp to the raster via `crop`.
- **`levels_grp` NA handling is correct** for: no NAs (trailing `NA` correctly filtered),
  all NAs (single `NA` group kept), the literal string `"NA"` (treated as an ordinary
  group, and correctly distinct from a real `NA` when both are present), numeric keys, and
  factor keys. `match(keys, levels_grp)` also matches `NA` to the `NA` level, so the
  fallback index raster is right. (Only a factor built with `exclude = NULL` — an explicit
  `NA` *level* — produces a duplicated group; `sf::st_read()` never yields that.)
- **The `cli` glue string renders correctly**, including `{ifelse(...)}` with single-quoted
  branches and `{?s}` pluralization: verified singular, plural, `complete = TRUE`, and
  `complete = FALSE`. `cli` is declared in `Imports`.
- **No input mutation.** `identical(snapshot, streams)` is `TRUE` after a call (the
  `streams_g$fl_seed` / `idx_streams$fl_group_idx` assignments hit R copies), and
  `terra::values(valleys)` is unchanged. No terra pointer aliasing — `terra::rast(tmpl)`
  builds a fresh raster and `crop()` returns new objects.
- **`attr(out, "fl_fallback_cells")` survives `do.call(rbind, parts)`** (it is set after the
  rbind) and is `integer`, as the test asserts.
- **`fl_cells_poly()` is fine at both ends of the range**: a single cell yields a polygon of
  exactly one cell area (100 m² at 10 m), and the full grid (518,400 cells, exercised by the
  "single constant group" test) completes without issue. `terra::values(r) <- NA_integer_`
  recycles correctly and keeps integer type.
- **The roxygen `@examples` block runs** end to end and produces 5 rows.

## Notes, not findings

- `fl_stream_rasterize(..., fun = "max")` on the fallback index raster shadows the
  lower-indexed group where two groups burn the same cell — 4 cells out of 1,607 on the
  bundled tile. Only nudges nearest-group ties at confluences; not worth changing.
- Passing `group = "valley"` silently overwrites the `valley` marker column that
  `fl_valley_poly()` adds. Output stays a valid `sf` with the group labels in `valley`, so
  nothing breaks — just be aware the schema collapses to one column.
- The cli message on line 161 is ~190 characters, over the 120-char `line_length_linter`
  in the project `.lintr` config. Style only, listed so it isn't a surprise in CI.
