# Review round 2 — the four round-1 fixes

Target: `git diff --cached` on branch `40-fl-valley-attribute-attribute-valley-cel`.
Worktree == index at review time, so line numbers below are live file line numbers in
`R/fl_valley_attribute.R`.

Baseline: `devtools::test()` → `FAIL 0 | WARN 0 | SKIP 0 | PASS 221`. `devtools::document()`
produces no diff (man/ and NAMESPACE are in sync). `vignettes/valley-confinement.Rmd`
renders end to end (67/67 chunks) under `bookdown::html_document2`.

## Findings

- **[bug]** `R/fl_valley_attribute.R:180-187` — the dropped-group `warning()` is emitted
  **before** the coverage fallback runs, so with the default `complete = TRUE` it can name a
  group as *"omitted from the output"* that is in fact present in the output with
  substantial area. The warning is built from `reasons[]`, which only records the outcome of
  the threshold pass (lines 168-175). Lines 202-214 then hand uncovered valley cells to the
  nearest group — including a group that scored zero on thresholds — and line 219-225
  polygonizes it into a row.

  Reproduced on the bundled tile: a 30 m synthetic segment placed on non-valley ground
  22 m from the valley edge and 1022 m from any real stream, run with
  `max_width = 10` (so nothing is within `max_width / 2`):

  ```
  WARNING: No valley cells attributed to 1 group, omitted from the output:
           Ghost Creek (no valley cells within the thresholds)
  output groups: Bulkley River | Cesford Creek | Ghost Creek | Richfield Creek |
                 Robert Hatch Creek | NA
  area of the "omitted" group: 394,700 m2 (39.5 ha)
  ```

  `max_width = 10` is only the cheapest trigger; the general condition is *a group whose
  streams are further than `max_width / 2` from every valley cell yet still the nearest
  stream to some valley cell*. That is exactly the shape of the case the Coverage section
  documents — waterbody polygons get no spatial filter, so a lake 1.5 km from the mapped
  network with a tributary group 1.2 km away hits it at package defaults.

  Consequence: the warning asserts something demonstrably false about the returned object.
  The round-1 finding was "silently dropped groups"; the fix now mis-reports which groups
  were dropped, which is worse than the count being silent — a caller that filters or
  re-queues on the warning text will drop or reprocess a group that is already attributed.
  The `reason` plumbing in `fl_group_cells()` is fine; only the point at which the warning
  is raised is wrong. Warn after the fallback, driven by
  `length(cells_by_group[[i]]) == 0L` at polygonize time (keeping `reasons[i]` as the
  explanatory text), not by `reasons` alone.

- **[fragile]** `R/fl_valley_attribute.R:257` — **not every no-cell path returns a reason**;
  one of them aborts the whole call. A group whose geometries are all empty
  (`st_linestring()` — routine after `st_intersection()` clipping or a sloppy export)
  reaches `terra::ext(terra::vect(sf::st_geometry(streams_g)))` with an empty vector and
  the call dies:

  ```
  ERR: [ext] invalid extent
  ```

  No reason, no warning, no partial result — one bad row kills the attribution of every
  other group. `nrow(streams_g) == 0L` (line 255) does not catch it because the rows exist.
  Same class: `fl_valley_attribute(valleys, streams[0, ], …)` with `complete = TRUE` gets
  past the (correct) `"no stream segments"` reason and then dies at line 206 with
  `[distance] no locations to compute distance from`, after having already printed
  `ℹ 53635 valley cells … assigned to the nearest group`. This is pre-existing rather than
  introduced by the fix, but it is the gap in the "every no-cell path is covered" claim the
  fix is making.

- **[fragile]** `R/fl_valley_attribute.R:223` (and `:229-231`) — the round-1 geometry-column
  clobbering is fixed in the empty branch but survives in the populated one. `fl_cells_poly()`
  returns an `sf` whose geometry column is named `geometry`, so
  `poly[[group]] <- levels_grp[i]` overwrites it when `group == "geometry"`. Reproduced on
  a GeoPackage-read `streams` (its sf column is `geom`, so a plain data column *can* be
  named `geometry` and passes the `group %in% names(streams)` check):

  ```r
  s$geometry <- ifelse(is.na(s$gnis_name), "unnamed", s$gnis_name)
  fl_valley_attribute(valleys, s, group = "geometry", dem = dem)
  # ERR: attr(obj, "sf_column") does not point to a geometry column.
  ```

  It fails loudly rather than returning a corrupt object, so it is milder than the round-1
  bug, but it is the same trap. In the empty branch the collision is silent instead:
  line 229 writes the group column, line 230 overwrites it with the `sfc`, and the caller
  gets a structurally valid `sf` with **no group column at all**. Rejecting
  `group == "geometry"` alongside the existing name check closes both.

## Verified — the four fixes hold on everything else probed

Each was reproduced by running code, not by reading it.

**1. Empty sf (`:227-233`).** Genuinely usable, and the group column carries the right type.
For `gnis_name` (character), `blue_line_key` (integer) and a `factor` group column, all of
`names()`, `attr(out, "sf_column") == "geometry"`, `st_geometry()`, `print()` and
`st_write()` to a real `.gpkg` succeed, and the group column comes back `character` /
`integer` / `factor` respectively — `keys[0]` carries the type correctly in all three.
`rbind()` works in both directions with a non-empty result (`rbind(empty, ne)` and
`rbind(ne, empty)` → 5 rows), because the non-empty path also names its geometry column
`geometry` and both carry an `integer` `valley` column. `plot()` errors with
`NA value(s) in bounding box` — but so does a canonical `st_sf(a = integer(0), geometry =
st_sfc(crs = 3005))`, so that is sf's behaviour for any zero-row `sf`, not a defect of this
construction.

**2. Reason coverage and warning mechanics.** Every `return()` in `fl_group_cells()` except
the crash in the finding above carries a reason, and the success return sets
`NA_character_`, so `any(!is.na(reasons))` cannot misfire on a successful group. Confirmed
each reason actually fires for the case it names: `"streams outside the valley raster"` for
the 500 km translation, `"segments do not cross a cell centre"` for the sub-pixel segment,
`"no valley cells within the thresholds"` for a hillslope segment, `"no stream segments"`
for an empty subset. `warning()` (not `cli::cli_alert_warning()`) is the right call —
`cli_alert_warning()` does not signal a `warning` condition, so `expect_warning()` would not
catch it, `suppressWarnings()` would not suppress it, and `options(warn = 2)` would not
promote it. CLAUDE.md imposes no cli-only convention. Boundary cases around the new crop
are clean: a segment 300 m outside the raster edge (inside `crop_margin`, so
`terra::intersect()` returns a sliver rather than `NULL`) and a segment exactly touching
`xmax` both return `"segments do not cross a cell centre"` without error.

**3. `fl_fallback_cells` semantics.** `length(uncovered)` is computed at line 190 from the
threshold pass only, before any fallback assignment, in every exit path — the normal return
(`:237`) and the empty-result early return (`:232`). Measured on the waterbody fixture:
`complete = TRUE` → 1643, `complete = FALSE` → 1643. That matches the reworded
`@return` ("cells outside every group's thresholds … the count reports the same quantity in
both modes") exactly. The Coverage section's "covers the delineation exactly" claim also
holds: `sum(valley_cells & !covered) == 0` under `complete = TRUE`. `attr()` is `integer`.

**4. `crop_margin`.** Threading verified by instrumenting `fl_group_cells()` via
`assignInNamespace()`: `max_width = 600` with no `crop_margin` → every call receives `600`
(the lazy default picks up the caller's `max_width`, as intended); `crop_margin = 137`
explicit → every call receives `137`. There is no second crop site to thread it to —
`fl_cells_poly()` crops to the cells' own bounding box, which needs no margin.
`terra::extend(SpatExtent, n)` confirmed to add `n` in **map units** on all four sides
(`ext(0,10,0,10)` → `-5 15 -5 15`), so the "metres" wording is right. Validation
(`is.numeric`, `length == 1`, `> 0`) is evaluated after `max_width`'s own checks, so the
default expression can never be forced against an invalid `max_width`. Against a full-grid
oracle for all five `gnis_name` groups: `crop_margin = 2000` → 0 missing / 0 extra;
`crop_margin = 500` → 33,860 missing (silently, as documented).

**Test-suite interaction.** Full suite is `FAIL 0 | WARN 0 | SKIP 0 | PASS 221`, and that
zero is real, not masked: the only two tests that trigger the new `warning()` wrap it in
`expect_warning()`, and the empty-valleys test uses `suppressWarnings()`. The
`cost_threshold = 300` test does not warn (every group keeps its own stream cells, which are
valley cells at cost 0, so no group empties).

**The `far` test.** `sf::st_geometry(far) <- sf::st_geometry(far) + c(5e5, 5e5)` does drop
the CRS (`st_crs(far)$input` is `NA` afterwards), and without the `st_crs(far) <- …` line
the subsequent `rbind()` fails with `arguments have different crs` — so the reassignment is
load-bearing and the test is not passing by accident. The warning it matches really is
`Elsewhere River (streams outside the valley raster)`, i.e. the `is.null(e)` branch it
claims to exercise. The sub-pixel test likewise fires the reason it advertises
(`Subpixel Creek (segments do not cross a cell centre)`) and the group is genuinely absent
from the output.

**Vignette.** The new "Whose floodplain is it?" section renders under
`bookdown::html_document2` with no errors or warnings. `valleys_wb` (line 284), `dem`,
`streams`, `sf` and `terra` are all in scope at line 421. Nothing is environment-dependent:
no `system.file()` beyond the bundled testdata already loaded, no network, no `whitebox`,
no absolute paths. The numeric claims check out — sum of attributed parts / delineated area
is 2.40 on `valleys_wb` (text says "roughly 2.4 times"), and `fl_fallback_cells` renders as
`1643`. The one chunk with a figure carries a `fig.cap`, so bookdown numbering works.

## Notes, not findings

- The dropped-group warning renders an `NA` group as the literal string `NA`
  (`paste0(NA, " (...)")`), indistinguishable from a group whose value is the string
  `"NA"`. Diagnostic text only; no behavioural consequence.
- The `crop_margin` docs say the default "reproduced the uncropped answer exactly on the
  bundled test data, where `max_width / 2` did not (200 corridor cells differed, by up to
  217 cost units)". Against a full-grid oracle, `crop_margin = max_width / 2` (1000 m) gives
  **0 missing / 0 extra** membership on this tile — the 200-cell difference is in the cost
  surface, not in the attributed answer. The parenthetical discloses this ("cost units"),
  but the lead clause overstates it. The important half of the round-1 fix — that the crop
  is an approximation and not a bound — is now stated correctly.
- `vignettes/valley-confinement.Rmd` `plot-attribute` caption says "the hatched overlap near
  the confluence belongs to both", but the plot draws two alpha-blended fills and no
  hatching. Cosmetic.
