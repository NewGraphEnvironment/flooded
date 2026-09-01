# Progress — fl_valley_confine(): default field= is wrong for the flood model (#47)

## Session 2026-09-01

- Plan-mode exploration — one Explore agent swept every `field` / `fl_valley_confine()` /
  `fl_stream_rasterize()` reference in the repo
- Two design forks put to the user: deprecation shim vs hard rename (shim chosen), and how far the
  downstream doc fix reaches (soul + this repo chosen)
- Phases approved by user
- Created branch `47-fl-valley-confine-default-field-is-wrong` off main
- Scaffolded PWF baseline from issue #47 with approved phases
- Next: Phase 1 — write the failing tests

### Phase 1 — tests first

- Added the `area_field` contract block to `tests/testthat/test-fl_valley_confine.R`: required on
  the `sf` branch (message must name hectares), not required on the `SpatRaster` branch,
  `field =` warns and forwards *exactly* (`terra::values()` identical, not just equal counts),
  `area_field` wins when both are supplied, third-positional still lands on `area_field`, and a
  guard that the two columns are not interchangeable.
- Runs red as intended: `FAIL 6 | PASS 24`, every failure `unused argument (area_field = ...)`.
- Next: Phase 2 — the signature, the shim, and the roxygen.

### Phase 2 — implementation

- `R/fl_valley_confine.R`: `area_field` is now the third argument with no default; `field` moved to
  the end of the signature, defaults to `NULL`, warns and forwards. A `has_area_field <-
  !missing(area_field)` flag is computed before anything touches the formal, so the forwarding does
  not rely on `missing()`'s post-assignment behaviour. The required check sits inside the
  `inherits(streams, "sf")` branch only.
- Roxygen on both `fl_valley_confine()` and `fl_stream_rasterize()` now states hectares and names
  the regression that consumes the values, with `@seealso` in both directions. Dropped the interim
  "tracked in flooded#47" sentence.

### Phase 3 — in-repo callers

- 18 default-relying calls in `test-fl_valley_confine.R` given `area_field`; the two
  `fl_stream_rasterize()` fixtures at `:34` and `:91` moved from `"channel_width"` to
  `"upstream_area_ha"` — `:91` in lockstep with `:96`, which asserts the raster and `sf` paths are
  equal and would otherwise compare two different columns.
- `:181` mattered more than it looked: `expect_error(..., "sf")` for a bad `waterbodies` would have
  matched the new `area_field` message ("when `streams` is an sf object") and passed for the wrong
  reason.
- Also updated: `test-fl_valley_attribute.R` (2), roxygen examples in `fl_valley_confine.R` and
  `fl_valley_attribute.R`, `README.md`, all four vignettes (`stac-dem.Rmd.orig` **and** the baked
  `.Rmd`), `data-raw/wsg_vignette_data.R`, `CLAUDE.md:273`.
- `devtools::document()` rewrote exactly the three expected `.Rd` files; `NAMESPACE` unchanged at
  17 exports.
- Full suite: `FAIL 0 | WARN 0 | SKIP 0 | PASS 265`.

### Measurement — bundled 10 m tile, package defaults (`flood_factor = 6`)

| `area_field` | precip | cells | ha |
|---|---|---|---|
| `upstream_area_ha` | none | 19,838 | 198.4 |
| `channel_width` | none | 14,789 | 147.9 |
| `upstream_area_ha` | `map_upstream` | 28,727 | 287.3 |
| `channel_width` | `map_upstream` | 17,206 | 172.1 |

The old default returned **59.9%** of the floodplain with precipitation supplied, 74.6% without.
Every wrong-column run is a **strict subset** — 0 cells gained, 11,521 lost with precip. The issue's
headline 47% was measured before the 0.5.0 units fix and no longer describes current code; the
defect is the same, its size is not. `field = "upstream_area_ha"` through the shim reproduces
`area_field = "upstream_area_ha"` exactly (`identical(terra::values(...))` TRUE).

### Restore-the-bug

Sourced the pre-fix `fl_valley_confine()` from commit 184eb22 (exact bytes, not a reconstruction),
assigned it into **both** `asNamespace("flooded")` and `as.environment("package:flooded")`, and
printed the formals as proof the patched version ran (`area_field present = FALSE`, `field default =
"channel_width"`). Both assertions of the required-argument test then failed. The guard can fire.

### Plan review (Plan agent) — triage

Returned 25 findings. Verified before acting, in both directions.

**Acted on:**
- `area_field = NULL` or a non-character fell through to `fl_stream_rasterize()`, whose message names
  `field` — the argument the caller did not use. Probed and confirmed
  (`is.character(field) is not TRUE`); now validated in `fl_valley_confine()` with its own message,
  plus three tests.
- The "not interchangeable" test was partly decoration: `channel_buffer` auto-detects TRUE, so the
  channel is ORed back in after cleanup and `expect_gt(n_cw, 0)` held even for an all-zero flood
  mask, while the shared buffered cells compressed the gap. Both sides now run
  `channel_buffer = FALSE` (14,149 vs 19,383).
- Its comment claimed the wrong column "strictly under-maps" because the regression is monotonic in
  area. The flood *surface* is monotonic; the cell count is not — closing, hole fill, patch removal
  and the modal filter sit in between. Reworded as measured, and the strict-subset claim NEWS makes
  is now pinned as an assertion rather than left in prose.
- No negative control that the clean path is silent; an implementation warning unconditionally would
  have passed everything. Added `expect_no_warning`.
- The both-supplied warning did not say which value was discarded — the same silent-wrong-column
  problem one level up. It now names both.
- Stale line anchors in `inst/notes/floodplain_interpretation.md` and
  `test-fl_valley_attribute.R`, and the sweep arithmetic in `findings.md` (13 + 2 != 18; actual 21
  calls = 18 + 2 + 1). Corrected. The issue body's citation of the driver at `:134` is stale — it is
  at `:148`, verified by grep.

**Recorded, not changed:**
- Phase 1's red baseline was one fixture line failing six times, not six behaviours pinned. True.
  The guard is earned by the restore-the-bug run instead, which reddens the assertions it targets.
- Migrating the 18 defaulting tests to `upstream_area_ha` re-baselines their magnitudes rather than
  preserving them. Deliberate: those tests should exercise the correct usage, and they pass. The
  alternative (`area_field = "channel_width"`, bit-for-bit preservation) would have kept the defect
  live in the file that documents the fix.
- `lifecycle::deprecate_warn()` deliberately not used: it would add an Import, change NAMESPACE, and
  warn once per caller — the second `expect_warning()` would then fail because the first consumed it.
- Restore-the-bug used commit 184eb22 (the test-only commit), whose `R/fl_valley_confine.R` is the
  original pre-fix source. Not a reconstruction.

### Code check round 1 — triage

Three findings, all `fragile`; the shim itself came back clean, with the partial-matching,
`missing()`-ordering and lockstep questions probed rather than reasoned.

- **Acted on:** the `SpatRaster` branch reproduced #47 unguarded at package defaults —
  `fl_valley_confine(dem, fl_stream_rasterize(streams, dem))`, 14,149 cells against 19,383. The
  branch cannot inspect values, but it can inspect the layer *name*, because
  `fl_stream_rasterize()` names its output after the column it burned. It now warns when handed a
  raster named after that function's own default, compared against
  `formals(fl_stream_rasterize)$field` rather than a hardcoded string so the two cannot drift.
- **Acted on:** `expect_error(..., "sf")` for a bad `waterbodies` is matched by three distinct error
  paths now. Re-anchored on "waterbodies".
- **Already tracked:** `CLAUDE.md:273` is generated from `soul/conventions/cartography.md`.

### Phase 5 — downstream docs

- soul PR NewGraphEnvironment/soul#135, cut in a temp worktree off `origin/main` so no parallel
  session's checkout was touched. The `flooded/CLAUDE.md` edit is provisional until it merges.
- Filed #53 to remove the `field` shim, naming the one external caller
  (`floodplains/scripts/floodplain_lcc/02_floodplain_model.R:148`) and recording what removal cannot
  close.

### Code check rounds 2-4

**Round 2** (three findings, all acted on):
- `expect_no_warning()` needs testthat **3.1.5**; `DESCRIPTION` pinned `>= 3.0.0`. On 3.0.0-3.1.4
  the whole file *errors* rather than skips — and the version that loses those two negative controls
  is the version with nothing guarding the new warning logic. Pin bumped, verified against
  testthat's own NEWS rather than from memory.
- The refreshed `inst/notes` pointer `fl_valley_confine.R:239` landed on the hole-fill block; the
  buffer it names had moved to `:267`. Replaced with prose, the same fix already applied to its
  sibling — a line number into a file this branch is actively growing cannot stay right.
- The `area_field` type check ran on the `SpatRaster` branch too, refusing a value the function
  never reads while the roxygen said it was unused. Moved inside the `sf` branch.

**Round 3** found the *mechanism* rather than more instances, and it indicted my own round-1 fix.
Both new guards were keyed to **a cause that was measured** rather than **the property wanted**:

| round | guard | computes | needed to mean | why they agreed |
|---|---|---|---|---|
| 1 | requirement scoped to `inherits(streams, "sf")` | "the caller handed us sf" | "the values are area" | every non-sf caller happened to be correct |
| 3 | `identical(names(r), formals(fl_stream_rasterize)$field)` | "named like the rasterizer's default" | "not upstream area" | that default happens to be the wrong column |

The comment I wrote — "derived from the formal rather than hardcoded, so the two cannot drift" — was
true of the *value* and named the wrong invariant. Measured by patching only
`formals(fl_stream_rasterize)$field` to `"upstream_area_ha"`: the guard **inverts**, warning on a
correct area raster and going silent on the actual #47 composition. Worse, the test failed on its
*premise* line, whose obvious repair ("the default moved, update the expected name") leaves the
suite green with the guard pointing the wrong way — failure toward the wrong fix.

Fixed as the inverse of what was there: the guard names `"channel_width"` literally, because whether
a column means drainage area is a judgement no formal can answer, and the test pins the coincidence
separately with a comment saying to fix the fixture and not the guard. The same file already got
this right one branch over — `channel_buffer` auto-detect uses the literal, because there the string
means the bcfishpass width column. Two meanings, one current value.

Round 3's second finding: `@param area_field` still said "nothing checks that branch" after round 1
added the check there, so the reference docs and NEWS made opposite claims about the same branch.
Round 2's finding in reverse — there the code was moved to match the docs, here the docs were left
behind by the code.

**Round 4** was scoped to those two fixes alone, since three rounds running had each found a defect
inside the previous fix.

Also noted on #53 as a comment: testthat 3.1.5 stopped `expect_no_warning()` capturing *deprecation*
warnings, so moving the shim to `lifecycle::deprecate_warn()` while removing it would silently
un-guard both negative controls.

### Close

- Round 4 clean, and terminated by enumeration rather than assertion: ten candidate pairs where an
  invariant could rest on two things agreeing, nine pinned/definitional/constructed, and the one
  residual stated precisely — `"channel_width"` carries two meanings in the file (the bcfishpass
  attribute, and "the column that is not drainage area") with no artifact above either from which to
  derive them, so their independence is the correct design and deduplicating the constant would
  re-introduce round 3's defect.
- `DESCRIPTION` and `CLAUDE.md` bumped to 0.6.0 as the final commit.
