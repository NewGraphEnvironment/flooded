# Review — round 3 (#47, `area_field` rename — the mechanism)

Scope: the staged diff, the full current contents of every file it touches, and
`review-round1.md` / `review-round2.md`. Round 1's and round 2's findings are all closed (re-verified
at the bottom). This round's job was to find the *mechanism* producing a defect inside each round's
fix rather than to enumerate more instances. It found one, and it is the same class as round 1's
finding, sitting inside round 1's own fix.

## The mechanism

Both prior findings are **a guard whose correctness rests on two things happening to agree**, not on
construction:

| round | the guard | what it computes | what it needed to mean | why they agreed |
|---|---|---|---|---|
| 1 | requirement scoped to `inherits(streams, "sf")` | "the caller handed us an sf object" | "the values reaching the regression are area" | every non-sf caller in the repo happened to be correct |
| 3 (below) | `identical(names(stream_r)[1L], formals(fl_stream_rasterize)$field)` | "this layer is named like the rasterizer's default" | "this layer is not upstream area" | the rasterizer's default happens to be the wrong column |

Round 2's three findings were of a different and benign kind (a version floor, a stale line pointer,
a check placed where the docs said the argument was unused) — none of them is this shape. So the
class is specifically: **the new guards in this change are keyed to a *cause that was measured*
rather than to the *property that is wanted*.** That is the `code-check.md` rule "A guard that
encodes the cause you measured is a proxy for the property you want".

## Findings

- **[fragile] `R/fl_valley_confine.R:189-190` — the raster-branch guard is keyed to
  `fl_stream_rasterize()`'s *current default*, not to "this is not upstream area". Change that
  default and the guard inverts: it warns on the correct input and goes silent on the defect.**

  ```r
  rasterize_default <- formals(fl_stream_rasterize)$field
  if (identical(names(stream_r)[1L], rasterize_default)) { warning(...) }
  ```

  The comment above it — *"Derived from the formal rather than hardcoded, so the two cannot drift"* —
  is true of the **value** and is the wrong invariant to want. The two things that must not drift are
  the guard and *the wrong column*, not the guard and *whatever the rasterizer defaults to*. They
  coincide today only because `fl_stream_rasterize()`'s default happens to be the wrong column, which
  is exactly the coincidence this issue exists to remove.

  Measured, by patching only `formals(fl_stream_rasterize)$field` (into **both**
  `asNamespace("flooded")` and `as.environment("package:flooded")`, with the patch printed as proof
  it took) and touching nothing in `fl_valley_confine()`:

  ```
  proof patch took: formals(fl_stream_rasterize)$field = upstream_area_ha

  --- baseline (default = channel_width) ---
  area raster : silent
  cw raster   : WARNS: `streams` is a raster of 'channel_width', which is `fl_strea…

  --- after (default = upstream_area_ha) ---
  area raster : WARNS: `streams` is a raster of 'upstream_area_ha', which is `fl_st…
  cw raster   : silent
  ```

  A complete inversion: false alarm on the correct raster, and the actual #47 composition passes
  unguarded. The warning text also becomes self-contradicting ("a raster of 'upstream_area_ha' …
  is not upstream contributing area").

  **The test does not protect against this, and its natural repair makes it worse.** `:256`
  (`expect_equal(names(default_r), "channel_width")`) goes red under that perturbation — but it goes
  red on the *premise* line, whose obvious repair is "the default changed, update the expected
  name". Do that and the suite is green with the guard pointing the wrong way. This is the
  fail-toward-the-wrong-fix direction: the assertion fires, and what it says sends you to fix the
  test rather than the guard.

  Note this is not hypothetical scope creep — flipping `fl_stream_rasterize()`'s default is a live
  candidate in the same neighbourhood as #53, and the accepted tradeoff ("`fl_stream_rasterize()`
  keeps its `"channel_width"` default; it is deliberately generic") is a decision about *today*, not
  a guarantee.

  Fix, and it is the inverse of what is there now — literal where it is derived, derived where it is
  literal:

  ```r
  # The wrong column, named. Not fl_stream_rasterize()'s default — those coincide
  # today and the guard must survive that stopping being true.
  if (identical(names(stream_r)[1L], "channel_width")) { warning(...) }
  ```

  and keep `:256` as the tripwire on the coincidence, saying so:

  ```r
  # If this fails, fl_stream_rasterize()'s default moved. The guard above is
  # deliberately NOT keyed to it — fix the fixture, not the guard.
  expect_equal(formals(fl_stream_rasterize)$field, "channel_width")
  expect_warning(fl_valley_confine(f$dem,
    fl_stream_rasterize(f$streams, f$dem, field = "channel_width")),
    "not upstream contributing")
  ```

  Same file already gets this right one branch over: the `channel_buffer` auto-detect at `:159` uses
  the literal `"channel_width"`, because there the string means *the bcfishpass width column*. Two
  different meanings, one current value — which is the whole hazard in one file.

- **[fragile] `R/fl_valley_confine.R:19` and `man/fl_valley_confine.Rd:39` — `@param area_field`
  states "nothing checks that branch", which the shipped code contradicts and `NEWS.md` contradicts
  in the opposite direction.**

  ```
  #'   ... Not used when `streams` is already a `SpatRaster` — but nothing checks
  #'   that branch, so a raster rasterized on the wrong column carries the same
  #'   defect one call earlier.
  ```

  Round 1's fix added a check to that branch (the layer-name warning at `:190`), and `NEWS.md`
  describes it at length — *"`fl_valley_confine()` now warns when handed a raster named after that
  function's own `"channel_width"` default"*. The roxygen was written before that fix and was never
  reconciled, so the reference documentation and the release notes now make opposite claims about
  the same branch. Measured: `fl_valley_confine(dem, fl_stream_rasterize(streams, dem))` warns.

  This is the round-2 finding's exact shape recurring — there the *code* was moved to match the
  roxygen; here the roxygen was left behind when the *code* gained a check. Worth naming both halves
  in one sentence, since the accurate statement is narrow: the branch checks the layer's **name** and
  cannot check its **values**, so a raster burned from any other wrong column is still undetected.
  Suggested replacement, which keeps the honest caveat the sentence was written for:

  ```
  #'   ... Not used when `streams` is already a `SpatRaster`. That branch cannot
  #'   inspect the values it is handed; it warns only when the layer's *name*
  #'   gives it away (see Details), so a raster burned from any other wrong column
  #'   carries the same defect one call earlier, undetected.
  ```

## The four items the brief named

**1. Moving the type check inside the `sf` branch — nothing escapes, no message regressed.**

`area_field` is read in exactly four places (`:140` `missing()`, `:147` the both-supplied warning
text, `:151` the forward, `:175`/`:181` the check and the call). Nothing outside the `sf` branch
consumes it. Swept every bad value against both branches:

```
raster + area_field=NULL / 3 / c("a","b") / NA      -> OK      (accepted, never read — the intent)
raster + area_field=<bad> + field="x"               -> OK, warning names the discarded value
sf     + area_field=NULL / 3 / length-2             -> ERROR, message names `area_field`
streams="x" + area_field=3                          -> ERROR: `streams` must be an sf object…
```

The `streams`-type error still wins over a bad `area_field`, which is the right precedence. No sf-branch
message changed.

One diagnostic wart, not a finding: `fl_valley_confine(dem, streams_sf, field = 3)` warns about the
rename and then errors with ``` `area_field` must be a single column name ``` — naming an argument
the caller did not use, which is the precise complaint that motivated adding this check in round 2's
triage. It is the mirror of that case rather than a recurrence: the caller has already been told in
the preceding warning that `field` is now `area_field`, so the two messages read together. Left alone.

**2. `testthat (>= 3.1.5)` is the correct floor — verified against testthat's NEWS, not memory.**

Every expectation used anywhere in `tests/` (`expect_equal`, `expect_error`, `expect_false`,
`expect_gt`, `expect_gte`, `expect_lt`, `expect_lte`, `expect_match`, `expect_no_warning`,
`expect_output`, `expect_s3_class`, `expect_s4_class`, `expect_setequal`, `expect_silent`,
`expect_true`, `expect_type`, `expect_warning`, `skip_if_offline`, `skip_on_cran`), checked against
`system.file("NEWS.md", package = "testthat")` with the enclosing version heading resolved rather
than eyeballed:

| function | first appears | note |
|---|---|---|
| `expect_no_warning` | **3.1.5** | the binding constraint |
| `expect_s4_class` | 0.x (`#373`) | 3.3.0 only added unquoting |
| `expect_match`, `expect_gt`, `expect_lt` | pre-3.0 | — |
| everything else in the suite | pre-3.0 | — |

3.1.5 is the floor and nothing in the file needs more. `expect_no_error(1)` was broken until 3.2.3 —
irrelevant, `expect_no_error` is not used.

One thing the same NEWS entry raises, recorded as a note because it is about #53 rather than this
diff: *"Deprecation warnings are no longer captured by … `expect_no_warning(code)`"* from 3.1.5
onward. The two negative controls (`:244`, `:333`) work today because the shim uses base
`warning()`. If the `field` shim is ever moved to `lifecycle::deprecate_warn()` — deliberately
rejected in `progress.md`, but the obvious thing to reach for while working #53 — `:333` silently
stops guarding the deprecation path and stays green. Worth one line in #53.

**3. The `inst/notes` pointer is correct, and the row is half-converted.**

```
| Where | `fl_flood_surface.R:101-103` | the `channel_buffer` branch of `fl_valley_confine()` |
```

- `fl_flood_surface.R:101-103` — verified: `:101` `bankfull_width`, `:102` `bankfull_depth`,
  `:103` `flood_depth`. Correct.
- "the `channel_buffer` branch of `fl_valley_confine()`" — verified: the `channel_width / 2` buffer
  is at `fl_valley_confine.R:268`, inside `if (isTRUE(channel_buffer) && inherits(streams, "sf"))`.
  The prose is accurate and is now the only thing in that cell.

Not a finding: the left half is still a line range, into a file this diff does not touch, so it is
correct today. Recorded only so the asymmetry is deliberate — the row was fixed on the side that
broke, not on the class.

**4. Every `area_field` block discriminates. One edit to `R/` that reddens each:**

| block | edit that fails it |
|---|---|
| `:223` required when sf | drop the `!has_area_field` `stop()` (also the `expect_match("hectare")` on message content) |
| `:233` not required when rasterized | hoist the `stop()` out of the `sf` branch |
| `:233` `expect_no_warning` (`:244`) | make the layer-name warning unconditional |
| `:247` default-column raster warns | delete the layer-name warning, or neuter `rasterize_default` |
| `:260` deprecated forwards | drop `area_field <- field` (raster differs), or delete the `warning()` |
| `:271` `area_field` wins | drop the `if (has_area_field)` branch — `area_field` becomes `"channel_width"` and `expect_equal` against `ref` fails |
| `:283` third positional | move `area_field` in the signature |
| `:291` not interchangeable | make the `sf` branch ignore `area_field` — `n_cw == n_area`, `expect_lt` fails |
| `:327` path is silent | warn unconditionally anywhere on the `sf` path |
| `:336` single column name | delete the type check — `fl_stream_rasterize()`'s messages (`is.character(field) is not TRUE`, `length(field) == 1L is not TRUE`) contain no "area_field", so all three fail |

`:271` and `:283` are the two whose *first* assertion (`expect_warning(..., "area_field")`) is
non-discriminating on its own — both shim messages contain "area_field" — and both are carried by
the `expect_equal` against `f$ref` that follows. Correct as written; noted because the regex alone
would not be.

## Everything else probed

- **Suite green on the tree as staged:** `devtools::test()` -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 273`.
- **`devtools::document()` writes nothing and deletes nothing**; `git status --porcelain` is
  byte-identical before and after, so the three staged `.Rd` files are current. `NAMESPACE`
  unchanged.
- **Lint:** longest line in any changed `R/` or `tests/` file is 107
  (`test-fl_valley_confine.R`), under the `.lintr` 120 limit.
- **Round 1's three findings** are closed: the raster branch now warns (`:190`), the `waterbodies`
  regex is anchored on "waterbodies" (`:185`), and `CLAUDE.md` is tracked in soul#135.
- **Round 2's three findings** are closed: `DESCRIPTION:45` is `testthat (>= 3.1.5)`, the notes
  pointer is prose and accurate, and the type check sits inside `if (inherits(streams, "sf"))` at
  `:175`.

## Notes, not findings

- **`DESCRIPTION` is still `Version: 0.5.0` against a `NEWS.md` `0.6.0` heading.** Third round
  carrying this; it matches the bump-last convention and Phase 4 is open. Flagged once more only
  because this is the last review before merge.
- `fl_valley_confine(dem, streams_sf, area_field = "channel_width")` on the **sf** branch is still
  silent, by design (a required argument means the caller chose) and `:306` depends on it. If
  finding 1's fix lands, the asymmetry becomes sharper — the raster branch will refuse a
  `channel_width` layer by name while the sf branch accepts the same string as an argument. That is
  defensible and was already deliberate; recorded so a future "warn everywhere" edit is read as
  breaking `:306`.
