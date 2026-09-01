# Review — round 2 (#47, `area_field` rename — reviewing round 1's fixes)

Scope: the staged diff, read against the full current contents of every file it touches, plus
`planning/active/review-round1.md`. Everything below was probed; the commands are given where the
claim is load-bearing. Round 1's three findings were re-checked and all three are genuinely closed
(evidence at the bottom).

## Findings

- **[bug] `DESCRIPTION:45` — `expect_no_warning()` is new in testthat 3.1.5, and the pin is
  `testthat (>= 3.0.0)`.** This diff introduces the package's *first two* uses of it
  (`test-fl_valley_confine.R:244`, `:333`; `git grep expect_no_warning HEAD -- tests/` returns
  nothing). On any install of testthat 3.0.0–3.1.4 the whole file errors with
  `could not find function "expect_no_warning"` — it does not skip, and the failure names a missing
  function rather than a version floor. Confirmed against testthat's own NEWS:

  ```
  # testthat 3.1.5
  * New experimental `expect_no_error()`, `expect_no_warning()`, ...
  ```

  This is the exact rule in CLAUDE.md ("R Package Development Conventions → Common pitfalls"):
  *bump the pin when you first use a newer assertion*. It matters more than usual here because both
  uses are **negative controls** — the assertions that stop an unconditional-warning implementation
  passing — so the version where they vanish is the version with no guard behind the warning logic.
  Fix: `testthat (>= 3.1.5)`.

- **[fragile] `inst/notes/floodplain_interpretation.md:218` — the refreshed line pointer
  `fl_valley_confine.R:239` lands on the hole-fill block, not on the `channel_width` buffer it
  claims to point at.** The row is the bcfishpass-`channel_width` column of the "Hall vs
  bcfishpass" table, i.e. the `channel_width/2` buffer. In the staged file that is line **267**:

  ```
  $ git show :R/fl_valley_confine.R | sed -n '239p'
    if (length(small_hole_ids) > 0L) {
  $ git show :R/fl_valley_confine.R | grep -n "channel_width / 2"
  267:        buffered <- sf::st_buffer(streams_w, dist = streams_w$channel_width / 2)
  ```

  The old value (202) was already off by five — the buffer sat at `HEAD:207` — and the refresh
  applied a `+37` shift where the real shift is `+60`, so it moved from *nearly* right to pointing
  at unrelated code. `fl_flood_surface.R:101-103` in the same row **is** correct (verified: the
  regression is at `:101-102`). Worth fixing in the same motion the diff already made elsewhere: it
  replaced a line-number comment in `test-fl_valley_attribute.R:180` with prose ("the waterbodies
  branch of `fl_valley_confine()`") for precisely this reason, and then re-introduced the same
  brittleness in the notes.

- **[fragile] `R/fl_valley_confine.R:157-163` — the `area_field` type check runs on the
  `SpatRaster` branch too, where the roxygen says the argument is "Not used".** Measured:

  ```
  raster streams + area_field = NULL   -> ERROR: `area_field` must be a single column name (ch...
  raster streams + no area_field       -> accepted
  ```

  A programmatic caller that always assembles the argument list —
  `do.call(fl_valley_confine, c(list(dem, streams), list(area_field = cfg$area_field)))`, where the
  config carries `NULL` for a pre-rasterized run — now errors on an argument the function will never
  read. It fails **loudly** with a clear message, so nothing proceeds silently, and the strict
  reading is defensible. But `@param area_field` states "Not used when `streams` is already a
  `SpatRaster`", which is now false: it is still type-checked there. Either move the check inside the
  `inherits(streams, "sf")` branch beside the required-argument `stop()`, or amend the sentence to
  say it is validated but unused.

## Checked and clean — the four items the brief named

**1. `formals(fl_stream_rasterize)$field` is safe today, and the failure mode is loud.**

```r
d <- formals(fl_stream_rasterize)$field
class(d)                      # "character"   (a literal default, not a language object)
identical("channel_width", d) # TRUE
```

The comparison works, and the value interpolates cleanly into the warning text. The comment's claim
that "the two cannot drift" is true of the *value* and not of the *form* — if the default ever
became an expression rather than a literal, `formals()` returns a `call`, `identical()` against a
character is `FALSE`, the guard stops firing and the message deparses garbage
(`paste0("x", formals(f2)$field)` -> `"xpaste0" "xchannel" "x_width"`). I chased this as a
fail-toward-pass candidate and it is not one: the test at `:257` breaks loudly in that scenario,
because `names(default_r)` is unchanged (so the `:256` premise still passes) while the
`expect_warning` no longer has a warning to catch. Not a finding; noted only so a future edit to
`fl_stream_rasterize`'s default is read as touching two functions.

**It does not fire spuriously, and it fires in every composition I could build:**

| input | layer name | guard |
|---|---|---|
| `fl_stream_rasterize(streams, dem)` (default) | `channel_width` | warns |
| written to GeoTIFF and read back | `channel_width` (band name survives) | warns |
| hand-rolled `terra::rasterize(v, dem, field = "channel_width")` | `channel_width` | warns |
| `fl_stream_rasterize(..., field = "upstream_area_ha")` | `upstream_area_ha` | silent |

The GeoTIFF round trip was the one I expected to break it — terra preserves the band description,
so it does not.

**Restore-the-bug, both directions** (patched into *both* `asNamespace("flooded")` and
`as.environment("package:flooded")`, with the patch printed as proof it took):

| perturbation | result |
|---|---|
| `rasterize_default <- "__never__"` (guard neutered) | `:247` warn test **FAILS** |
| `if (TRUE)` in place of the name comparison (warns always) | `:244` `expect_no_warning` **FAILS** |
| `if (TRUE)` in place of `if (!is.null(field))` (deprecation warns always) | `:333` `expect_no_warning` **FAILS** |

So all three new assertions can fire. Note `:333` does **not** catch an unconditional *raster-branch*
warning (it is on the `sf` path) — correct, since its stated job is the deprecation warning, and
`:244` is the control for the other one.

**2. The `area_field` validation refuses nothing legitimate except the case flagged above.**

```
sf + area_field = factor("upstream_area_ha")           ERROR  (correct — not character)
sf + area_field = c(a = "upstream_area_ha")            accepted  (named length-1 char)
sf + area_field = structure("upstream_area_ha", ...)   accepted  (attributes carried)
sf + area_field = NULL / 3 / length-2                  ERROR, message names `area_field`
```

`&&` short-circuits before `is.na()`, so no length>1 condition warning. `""` passes and falls
through to `fl_stream_rasterize()`'s "not found in `streams`" error, which is the right diagnostic.
`has_area_field <- !missing(area_field)` is still computed before anything writes to the formal, and
`missing()` is never consulted after the shim assigns.

**3. Every changed/new test still discriminates.**

- **Strict subset (`:317-324`) is non-vacuous and pins the NEWS claim.** `n_cw` is 13,000+ cells, so
  `sum(cw & !ar)` is a real comparison, not `0` by emptiness. `channel_buffer = FALSE` on both sides
  is load-bearing exactly as the comment says — with the buffer on, the shared channel cells
  compress the gap. Round 1's "the stronger NEWS claim has no guard" note is closed.
- **`:244` `expect_no_warning(fl_valley_confine(f$dem, stream_r))`** — `stream_r` is named
  `upstream_area_ha`, so it is a genuine negative control for the new guard, and it fails when the
  guard is made unconditional (above).
- **`:256` `expect_equal(names(default_r), "channel_width")`** is a proper premise assertion in the
  CLAUDE.md sense — it pins the fact the guard rests on, and goes red if `fl_stream_rasterize()`
  stops naming its output after the column.
- **`:180-186` (`waterbodies` regex)** — round 1's finding, fixed correctly and *discriminating*:
  the `area_field`-required message does **not** contain "waterbodies"
  (`grepl("waterbodies", <that message>)` -> `FALSE`), while the `stopifnot` message does
  (`inherits(waterbodies, "sf") is not TRUE`). Dropping `area_field` from that call would now fail
  the test rather than pass it for the wrong reason.
- **The two fixture column moves (`:34`, `:91`)** still hold their invariants; `:91`/`:96`/`:102`
  moved in lockstep so the raster-path-equals-sf-path equality compares the same column on both
  sides.

**4. No warning double-fires, and no `expect_warning()` regex cross-matches.**
There is exactly one path to each of the three `warning()` sites. In every test that asserts on one,
the other two cannot co-fire: the deprecation tests pass `sf` streams that *have* `channel_width`
(so the `channel_buffer` warning is unreachable) and never take the raster branch; the raster-branch
test passes no `field`. Regexes are disjoint — `"channel_width"` (`:115`) does not appear in either
new message, `"area_field"` (`:265`, `:278`) does not appear in the layer-name message, and
`"not upstream contributing"` (`:257`) appears only in the layer-name message.

## Everything else probed

- **Suite green:** `devtools::test(filter = "fl_valley")` -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 114`.
- **Every quantitative claim in `NEWS.md` and `inst/notes/floodplain_interpretation.md` reproduces
  exactly** on the bundled tile: 19,838 / 28,727 / 14,789 / 17,206 cells and 198.4 / 287.3 / 147.9 /
  172.1 ha, and the raster-branch pair 14,149 vs 19,383. The 59.9% figure and the 11,521-cell loss
  both check out.
- **`devtools::document()` writes nothing new** and `NAMESPACE` is unchanged; the roxygen block sits
  immediately above `fl_valley_confine` with no helper inserted between it and the function (the
  `@export`-rebinding trap).
- **Lint:** no line in any changed `R/` or `tests/` file exceeds the `.lintr` 120 limit (max 107, at
  `test-fl_valley_confine.R:96`).

## Notes, not findings

- **The working tree is one revision ahead of the index** for `R/fl_valley_confine.R` and
  `man/fl_valley_confine.Rd`: the unstaged edit swaps "it is removed in a future release" for
  "removal is tracked in flooded#53". Committing the index as-is ships the older wording with the
  newer code. Stage it or drop it deliberately.
- **`DESCRIPTION` is still `0.5.0` against a `NEWS.md` `0.6.0` heading** — carried over from round 1,
  matches the bump-last convention, noted so it is not lost before the tag. The testthat pin above
  is a second edit to the same file, so both land in one commit.
- **The `sf` branch stays silent on an explicit `area_field = "channel_width"`.** Deliberate and
  correct (a required argument means the caller chose), and `:306` depends on it — flagged only
  because the asymmetry with the new raster-branch warning is not obvious from the code, and a
  future "let's warn on channel_width everywhere" edit would break that test.
