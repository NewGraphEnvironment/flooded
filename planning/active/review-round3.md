# Review round 3 — do the round-2 fixes converge?

Target: worktree == index on `40-fl-valley-attribute-attribute-valley-cel`, so line numbers are
live file line numbers. Baseline re-measured: `devtools::test()` → `FAIL 0 | WARN 0 | SKIP 0 |
PASS 226`; `devtools::document()` produces no diff.

Short answer: **the four round-2 fixes converge inside `fl_valley_attribute.R`.** Every case the
brief asked about was reproduced and all of them behave. But the *mechanism* behind rounds 1-3 is
still live one call down, and it still produces a corrupt `sf`.

## Findings

- **[bug]** `R/fl_valley_poly.R:38` — the round-1 defect was fixed at the instance, not at the
  idiom, and the idiom survives in the function that builds **every row** `fl_valley_attribute()`
  returns. `names(out)[1] <- "valley"` renames an `sf` column by position. When
  `terra::as.polygons()` yields zero features, `sf::st_as_sf()` returns an `sf` whose *only*
  column is the geometry column, so line 38 renames **the geometry column** to `"valley"` while
  `attr(out, "sf_column")` still says `"geometry"`. Reproduced:

  ```r
  o <- fl_valley_poly(valleys * 0L)
  nrow(o)                 # 0
  names(o)                # "valley"
  attr(o, "sf_column")    # "geometry"
  sf::st_geometry(o); print(o); plot(o); sf::st_write(o, f)
  # all: attr(obj, "sf_column") does not point to a geometry column.
  ```

  That is byte-for-byte the round-1 failure mode. It is **not** reachable from
  `fl_valley_attribute()` — `fl_cells_poly()` only calls it with `length(cells) > 0`, so at least
  one cell is `1L` and `as.polygons()` always returns a feature (verified: the one-cell case gives
  `names = valley, geometry`). It **is** reachable on the path the roxygen advertises:
  `fl_valley_poly()` is exported and documented as "the natural final step after
  `fl_valley_confine()`", and `fl_valley_confine()` returns an all-zero raster on a tile with no
  floodplain — the same object `test-fl_valley_attribute.R:276` builds deliberately. Fix is the
  round-1 fix applied here: name the column at construction (`names(polys) <- "valley"` on the
  `SpatVector`, before `st_as_sf()`), never by position afterwards. `grep -rn "names(.*)\[[0-9]"
  R/` returns exactly this one line, so one edit closes the family.

- **[fragile]** `R/fl_valley_attribute.R:188-196` — round 2's finding was "a diagnostic emitted
  before the state it describes". The fix moved the `warning()` after the fallback and left the
  `cli::cli_alert_info()` in front of it, so the same defect shape remains at the line above.
  `fate` is chosen from `complete` alone (`:189-193`), then printed (`:194-196`), and only then do
  `usable` (`:197`) and the all-NA `idx_r` guard (`:203`) decide whether any assignment happens.
  When either guard fires the message asserts an assignment that did not occur. Reproduced, all
  three shapes:

  ```
  streams[0, ], complete = TRUE
    ℹ 53635 valley cells outside every group's thresholds - assigned to the nearest group.
    → 0 rows returned, 0 cells assigned, and NO warning (levels_grp is empty), so this
      false line is the only diagnostic the caller gets.

  all geometries empty (usable = FALSE)
    ℹ 53635 valley cells ... - assigned to the nearest group.   → 0 assigned, 0 rows

  every segment sub-pixel (idx_r all NA)
    ℹ 53635 valley cells ... - assigned to the nearest group.   → 0 assigned, 0 rows
  ```

  Informational only — the returned object and `fl_fallback_cells` are both correct in all three —
  which is why this is `fragile` and not `bug`. But it is the identical mistake round 2 filed, so
  it belongs in the same fix: compute the fallback, then report what it did. Note the two
  guard-fires can only coincide with a zero-row result (see below), so no run that returns rows
  can mis-report.

## The four round-2 fixes, item by item

**1. Warning moved after the fallback — converged.** The warning predicate
(`lengths(cells_by_group) == 0L`, `:221`) and the polygonize skip (`length(cells) == 0L`, `:236`)
are now the *same expression over the same object at the same point in time*, with only the
fallback assignment between them and nothing that can empty a group. So it cannot stay silent
about an absent group and cannot name a present one — the two sets are equal by construction, not
by coincidence. `test-fl_valley_attribute.R:314-357` pins the direction that regressed.

Reason-text accuracy after the fallback: only the `"no valley cells within the thresholds"` reason
can be attached to a group that later wins fallback cells, and such a group is no longer in
`empty_grp`, so its stale reason is never printed. The other three reasons
(`"streams outside the valley raster"`, `"segments do not cross a cell centre"`,
`"all geometries empty"`) all describe groups that burn nothing into `idx_r` either — the fallback
rasterizes with the same `fl_stream_rasterize()` / `touches = FALSE` — so those groups can never
gain fallback cells and their reason cannot go stale. `reasons` is not read anywhere else.

The `if (is.na(reasons[i])) "no valley cells"` fallback text at `:224` is unreachable (a group with
`reason = NA` returned cells, so it is never in `empty_grp`). Harmless.

**2. `group == "geometry"` rejected up front — complete for what it guards.** The output geometry
column is unconditionally named `geometry` on both paths (`fl_valley_poly()` via `st_as_sf()`;
`st_sf(..., sf_column_name = "geometry")` at `:246`), verified on the one-cell, full-grid and
zero-row cases. So `"geometry"` is the only value of `group` that can collide with the *output*,
and the guard is exhaustive.

Probed the three adjacent collisions the brief names, none of them a defect:

- *`streams` whose active sf column is named something else* — the bundled GeoPackage's is `geom`,
  which is why round 2's data column named `geometry` was constructible. `group = "geom"` gets past
  both guards (`group %in% names(streams)` does not exclude `attr(streams, "sf_column")`) and dies
  at `sort()` on an `sfc` with `both operands of the expression should be "units" objects`. Loud,
  no corrupt object, no data loss, and pre-existing — the round-2 guard was never aimed at it.
- *`group == "valley"`* — `poly[["valley"]] <- levels_grp[i]` overwrites the marker column, so the
  output has one data column instead of the two `@return` promises. Both branches agree (the empty
  branch's `empty[["valley"]] <- keys[0]` overwrites the same slot with the same type), the result
  is a structurally valid `sf` with `sf_column = "geometry"` and the right 5 group labels, and
  `rbind()` still works. Round 1 already logged this as a note; re-verified, still not a defect.
- *collision after `rbind()`* — `levels_grp` is `unique()`, both branches emit columns
  `valley, <group>, geometry` in that order with matching types, so no duplicate key and no column
  mismatch can reach `do.call(rbind, parts)`.

**3. Empty-geometry filter + `usable` + all-NA guards — all four cases clean.** Run on the bundled
tile:

| case | result |
|---|---|
| `streams[0, ]`, `complete = TRUE` | 0-row `sf`, `fl_fallback_cells = 53635`, no crash |
| all geometries empty, `complete = TRUE` | 0 rows, warning names all 5 groups `(all geometries empty)` |
| all geometries empty, `complete = FALSE` | 0 rows, `fl_fallback_cells = 53635` |
| mix of empty + valid **within one group** (4 of Cesford Creek's 9 rows blanked) | 5 rows, all groups present, `fl_fallback_cells = 94` |
| one group entirely empty, others fine, **with the fallback firing** (`cost_threshold = 300`) | 5 rows, `Empty Creek (all geometries empty)` warned, `fl_fallback_cells = 25051` |
| every segment sub-pixel (`idx_r` all NA), `usable = TRUE` | 0 rows, all 5 warned `(segments do not cross a cell centre)`, no crash |

The last two matter most. The empty-geometry filter lives in `fl_group_cells()` (`:275`) but the
fallback at `:201` rasterizes the **unfiltered** `streams` — the obvious place for a third variant.
It is clean: `terra::vect()` on an `sf` with empty linestrings does not error, unlike
`terra::ext()`. Worth knowing that the committed test
(`test-fl_valley_attribute.R:359-372`) does **not** cover this — `fl_fallback_cells` is `0` at
package defaults on the plain tile, so that test never enters the fallback block at all. The
`cost_threshold = 300` variant in the table above is what actually exercises it.

**4. Nested `if` control flow — correct, despite the mis-indentation.** The braces do what they
look like: `:198` gates on `complete && usable`, `:203` gates on `idx_r` having a burned cell, and
on both false paths `cells_by_group` is untouched, so `uncovered` cells are left unattributed —
never mis-assigned. The third leak path is inside the loop:
`terra::distance(target = NA, values = TRUE)` returns **`NaN` at source cells**, not the cell's own
value (verified on a 5x5 toy raster), so a burned cell appearing in `uncovered` would fall through
`!is.na(assigned)` and be dropped rather than mis-assigned. That intersection is empty in practice
and provably so — a cell burned in `idx_r` is burned in its own group's `seeds` by the same
`touches = FALSE` rasterization on a `snap = "out"`-aligned crop, giving distance 0 and cost 0, so
it is always already covered. Measured: at `cost_threshold = 300`, 25,051 uncovered cells, **0** of
them burned in `idx_r`; `sum(valley_cells & !covered) == 0` under `complete = TRUE` on both the
plain and the waterbody fixtures.

`fl_fallback_cells` is `length(uncovered)` computed once at `:185`, before any assignment, and read
identically at `:247` (empty branch) and `:252` (normal). Measured equal under
`complete = TRUE`/`FALSE` on the waterbody fixture (1643/1643) and on every row of the table above.
Same quantity on every exit path.

## Mechanism

Three rounds, three findings, one property: **`fl_valley_attribute()` builds its return value by
mutating an `sf` in place, and reports on it from a different point in the function than where the
value is decided.** Both halves are the same underlying thing — no single place owns the output
object, so nothing can check it.

- Rounds 1 and 2 (empty branch, `group == "geometry"`) were the column half: `names(out)[2] <- group`
  and `poly[[group]] <- ...` write into an `sf` by position or by a name the caller supplies, with
  no barrier between "a data column" and "the geometry column".
- Round 2 (warning before the fallback) and finding 2 above are the ordering half: a message is
  composed from state that a later block is still free to change.

Each round fixed the instance it was shown. The idiom was not fixed, which is why the family
regenerates: `names(x)[i] <- ` is still in the tree at `fl_valley_poly.R:38`, and it still yields
the exact corrupt object round 1 described. **One change closes the column half of the family** —
delete the positional rename (name the `SpatVector` column before `st_as_sf()`), after which no
line in `R/` renames an `sf` column by position and the sole remaining name-based write is
`poly[[group]]`, already guarded. **One change closes the ordering half** — move the
`cli_alert_info()` below the fallback block so both diagnostics describe settled state, which is
the rule round 2 already established for the `warning()` and simply did not apply to the line above
it.

A cheap structural backstop, if you want one that does not depend on remembering the rule: a
three-line assertion before each `return()` (`identical(attr(out, "sf_column"), "geometry")`,
`"valley" %in% names(out)`, `group %in% names(out)`) would have caught round 1, round 2's
`"geometry"` collision, and the `fl_valley_poly()` bug above, none of which any test caught.

## Notes, not findings

- `lintr::lint("R/fl_valley_attribute.R")` reports the un-reindented fallback body at `:204`
  (6 spaces, should be 8) — the visible residue of fix 4's brace change — and a false-positive
  `object_usage_linter` on `fate` (used inside the `cli` glue string). Style only, but the project
  `.lintr` is configured to be clean, so CI will show them.
- `group = "geom"` (the streams' own sf column on a GeoPackage read) fails with
  `both operands of the expression should be "units" objects` rather than the intended
  "column not found" message, because `group %in% names(streams)` does not exclude
  `attr(streams, "sf_column")`. Pre-existing, loud, no corruption.
