# Review — round 1 (#47, `area_field` rename)

Staged diff reviewed against `CLAUDE.md` "Code Check Conventions" and "R Package Development
Conventions". Everything below was probed, not reasoned about; commands are given where the
claim is load-bearing.

## Findings

- **[fragile] `R/fl_valley_confine.R:165-166` — the defect this issue fixes is still fully
  reachable through the `SpatRaster` branch, with no error and no warning.** The requirement is
  scoped to `inherits(streams, "sf")`, which is correct as far as it goes, but
  `fl_stream_rasterize()` still *defaults* to `"channel_width"` — so the shortest composition
  reproduces #47 exactly, using nothing but package defaults:

  ```r
  sr <- fl_stream_rasterize(streams, dem)        # default "channel_width"
  fl_valley_confine(dem, sr)                     # accepted silently
  ```

  Measured on the bundled tile just now: **14,149 cells** through that path against **19,383**
  with `upstream_area_ha` — 73%, the same class and roughly the same size as the `sf`-branch
  defect the diff closes. The roxygen states the assumption ("must already be upstream
  contributing area in hectares") but nothing enforces it, and the composition is not exotic:
  `test-fl_valley_confine.R:34` and `:91` were doing precisely this before the diff moved them
  off it.

  A cheap tell exists and is already in the data — `fl_stream_rasterize()` does
  `names(out) <- field`, so the layer is literally named `channel_width`:

  ```r
  names(fl_stream_rasterize(streams, dem))   # "channel_width"
  ```

  A one-line `warning()` when `inherits(streams, "SpatRaster") && names(streams)[1] ==
  "channel_width"` would close the obvious case at no cost. This is the "a fix to code that
  writes data is not done until the readers are reconciled" shape: the `sf` reader is guarded,
  the `SpatRaster` reader is not, and the guard's scope reads as complete.

- **[fragile] `tests/testthat/test-fl_valley_confine.R:180-183` — `expect_error(..., "sf")` is
  matched by two different errors in this function.** The diff correctly defused the immediate
  hazard by supplying `area_field`, and the test now fails for the right reason. But the regex
  itself still cannot tell `inherits(waterbodies, "sf") is not TRUE` from ``` `area_field` is
  required when `streams` is an sf object ```, so the next edit that drops `area_field` from
  this call re-opens it silently. The `stopifnot` message contains the word `waterbodies` —
  tightening the regex to `"waterbodies"` makes the assertion discriminating rather than
  coincidental.

- **[fragile] `CLAUDE.md:273` is generated content and the fix will be reverted.** The
  `Land Cover Change` section is propagated from `soul/conventions/cartography.md`, which still
  carries `flooded::fl_valley_confine(dem, streams)` — the two-argument form this change makes
  an error. The next `claude-md-propagate` overwrites the staged edit. `task_plan.md:98` already
  tracks the soul-side change as unchecked; flagging so it is not lost at merge, since the
  symptom (a documented example that errors) shows up in every repo soul syncs, not just this
  one.

## Checked and clean

The specific hazards named in the brief were probed and none of them fire:

- **Positional resolution is unchanged.** `field` moved 3 -> 14 and `area_field` took position 3;
  positions 1-13 (`dem, streams, *, slope, slope_threshold, max_width, cost_threshold,
  flood_factor, precip, waterbodies, channel_buffer, size_threshold, hole_threshold`) are
  identical before and after, so no caller's positional arguments shift. Verified with
  `match.call()` against the real signature.
- **Partial matching does not regress.** `fi` / `fie` / `fiel` still resolve to `field`, so a
  prefix-passing caller warns and forwards rather than breaking. `f` was ambiguous before the
  change (`field` / `flood_factor`) and still is — `argument 3 matches multiple formal
  arguments` — so nothing that worked stopped working. `a` / `ar` / `area` newly resolve to
  `area_field`; previously they were `unused argument`, so this is a gain, not a break.
- **`missing()` is used correctly.** `has_area_field <- !missing(area_field)` is computed before
  anything touches the formal, and `missing()` is never consulted again after the shim assigns
  into it. `field = NULL` supplied explicitly does *not* warn and does *not* satisfy the
  requirement, which is the right behaviour. `area_field` supplied wins over `field`, and the
  test at `:253` can actually fail — an unconditional `area_field <- field` produces a different
  raster and trips the `expect_equal`.
- **The warning cannot fire twice.** One `warning()` call, one path to it. In both tests that
  assert on it the streams fixture has a `channel_width` column, so the second warning site
  (`channel_buffer = TRUE` with no `channel_width`) cannot co-fire and bubble up under
  testthat 3e.
- **No `expect_warning()` regex is cross-matched.** `:112` asserts `"channel_width"`, which does
  not appear in the deprecation message; `:246` and `:256` assert `"area_field"`, which does not
  appear in the `channel_width` message.
- **The two fixture column changes preserve their invariants.** `:34` only asserts
  `sum(values == 1) > 0`, which holds for either column. `:91` moves in lockstep with `:96`, so
  the raster-path-equals-sf-path equality at `:102` still compares the same column on both sides
  — this was the one that would have compared two different columns had only one side moved.
- **`:273` is a real assertion, not decoration.** It cannot fail for the *current* defect (it
  does not exercise a default), but it is a premise assertion in the sense CLAUDE.md prescribes:
  it pins the fact the whole change rests on — that the two columns give materially different
  answers on this fixture — and it fires if that ever stops being true. The margin is wide
  (14,789 vs 19,838), so it discriminates.
- **Nothing trips `R CMD check`, roxygen, or NAMESPACE.** `devtools::document()` regenerates the
  three staged `.Rd` byte-identically and writes nothing else; `NAMESPACE` unchanged at 17
  exports; the roxygen block sits immediately above `fl_valley_confine` with no helper inserted
  between (the `@export` rebinding trap); `@seealso [fl_flood_surface()]` targets an exported
  function, so no dangling Rd link; `devtools::test(filter="fl_valley_confine")` is
  `FAIL 0 | WARN 0 | SKIP 0 | PASS 35`; no line in the changed files exceeds the `.lintr`
  120-char limit.

## Notes, not findings

- `area_field = NULL` or `character(0)` supplied explicitly sets `has_area_field = TRUE` and
  falls through to `fl_stream_rasterize()`'s `stopifnot(is.character(field), length(field) ==
  1L)`, which errors with the bare deparsed condition rather than the informative message. It
  errors, so nothing silently proceeds; only the diagnostic is worse than it could be.
- When both spellings are supplied the warning says `field` is deprecated but does not say the
  supplied `field` value was *ignored*. A caller passing two different columns gets no signal
  about which one ran.
- `NEWS.md` and `inst/notes/floodplain_interpretation.md` are modified but **unstaged**, so they
  are outside this review. Both assert the wrong-column result is a *strict subset* ("0 cells
  gained anywhere"); the test at `:273` pins only `n_cw < n_area`, so the stronger claim in the
  release notes has no guard behind it. Worth either weakening the claim or asserting
  `sum(v_cw == 1 & ref == 0) == 0`.
- `DESCRIPTION` is still at 0.5.0 against a `NEWS.md` 0.6.0 heading. That matches the convention
  of bumping last and Phase 4 is unchecked — noted only so it is not forgotten before the tag.
