# Review — round 4 (#47, `area_field` rename — round 3's two fixes)

Narrow scope, as briefed: only (a) the `SpatRaster` layer-name guard now naming `"channel_width"`
literally plus its new tripwire, and (b) the reconciled `@param area_field` sentence. Nothing closed
in rounds 1–3 is re-opened, and the tradeoffs listed in round 3's "Notes, not findings" are not
re-flagged.

## Clean

Both fixes hold. The class rounds 1–3 kept reproducing — a guard that fails toward *green and
wrong* — is now provably absent on this branch: I perturbed the three things the guard and its
premises rest on, and **every** perturbation reddens exactly one assertion, each naming the thing
that actually moved. No perturbation produced a green suite with an inverted or neutered guard.

---

## 1. Literal-vs-derived, both directions

Round 3's prescription was "literal where it is derived, derived where it is literal". Shipped:

| | keyed to | file:line |
|---|---|---|
| guard | the literal `"channel_width"` | `R/fl_valley_confine.R:197` |
| tripwire | `formals(fl_stream_rasterize)$field` | `tests/testthat/test-fl_valley_confine.R:260` |

They are keyed to **different** things, which is the point, and I confirmed it by measurement rather
than by reading.

### The perturbation, with proof it took

Patched `formals(fl_stream_rasterize)$field` into **both** `asNamespace("flooded")` and
`as.environment("package:flooded")`, touching nothing in `fl_valley_confine()`:

```
=== BASELINE ===
formals default: channel_width
  cw raster    -> WARNS: `streams` is a raster of 'channel_width', which is not upstream contri...
  area raster  -> silent

=== AFTER PERTURBATION ===
proof patch took (namespace): upstream_area_ha
proof patch took (attached) : upstream_area_ha
proof patch took (as tests see it): upstream_area_ha
names(fl_stream_rasterize(streams, dem)) = upstream_area_ha     <- the default really moved
  cw raster    -> WARNS: `streams` is a raster of 'channel_width', which is not upstream contri...
  area raster  -> silent
```

**The guard's behaviour is byte-for-byte unchanged.** Round 3 measured a complete inversion here
(false alarm on the correct raster, silence on the defect); that inversion is gone.

### Exactly which assertions go red, and what a reader concludes

Full orthogonality matrix. Rows are perturbations, columns the three assertions in play. Guard
perturbations were applied by rewriting the one `if` line and re-binding `fl_valley_confine` into
both environments, with the patched line printed as proof:

| perturbation | `:260` tripwire | `:265` warn | `:244` no-warn |
|---|---|---|---|
| `fl_stream_rasterize` default -> `"upstream_area_ha"` | **RED** | green | green |
| `fl_stream_rasterize`'s `field` formal renamed away entirely | **RED** | green | green |
| guard literal -> `"__never__"` (neutered) | green | **RED** | green |
| guard condition -> `if (TRUE)` (unconditional) | green | green | **RED** |
| baseline (as staged) | green | green | green |

One red per perturbation, on disjoint axes. So the tripwire **can** fail independently of the guard,
and the guard can fail independently of the tripwire — they are not both keyed to the same thing.

What a reader gets from each message:

- **`:260`** — `Expected `formals(fl_stream_rasterize)$field` to equal "channel_width".
  actual: "upstream_area_ha"`. Names the rasterizer's formal, i.e. the thing that moved, and the
  five-line comment directly above says the guard is deliberately not keyed to it and to fix the
  fixture rather than the guard. This is the round-3 failure mode repaired: previously the red line
  was `expect_equal(names(default_r), "channel_width")`, whose obvious repair ("the default changed,
  update the expected name") left a green suite with an inverted guard. Now the red line is *about*
  the coincidence and says so.
- **`:265`** — `Expected `fl_valley_confine(f$dem, default_r)` to throw a warning.` Points at the
  guard, which is what was neutered. Correct attribution.
- **`:244`** — `Expected ... not to throw any warnings. Actually got ... 'channel_width', which is
  not upstream contributing area`. Points at over-firing, and three other tests emit the same
  warning as noise, which reinforces it.

Non-vacuity of the tripwire was checked separately: renaming the formal makes
`formals(...)$field` return `NULL`, and `expect_equal(NULL, "channel_width")` is **RED**, not a
silent pass. So it cannot go green by the thing it inspects disappearing.

## 2. Guard coverage — fires where it should, silent where it should

Re-measured against the literal form (round 2's table was against the derived form; same value, but
the brief asks and it costs nothing):

| input | layer name | guard |
|---|---|---|
| `fl_stream_rasterize(streams, dem)` (package default) | `channel_width` | **warns** |
| `fl_stream_rasterize(..., field = "channel_width")` | `channel_width` | **warns** |
| written to **GeoTIFF** and read back | `channel_width` | **warns** |
| hand-rolled `terra::rasterize(vect(streams), dem, field = "channel_width")` | `channel_width` | **warns** |
| hand-rolled -> GeoTIFF -> back | `channel_width` | **warns** |
| `.grd` round trip | `channel_width` | **warns** |
| `fl_stream_rasterize(..., field = "upstream_area_ha")` | `upstream_area_ha` | silent |
| name forced to `CHANNEL_WIDTH` | `CHANNEL_WIDTH` | silent |
| name forced to `channel_width_m` | `channel_width_m` | silent |

The two silent name-variants are correct as a matter of judgement rather than accident: the guard's
claim is narrow (it recognises the one name `fl_stream_rasterize()` writes), the roxygen and NEWS
both say so explicitly, and widening it to a fuzzy match would start refusing legitimate columns.
Recorded so a later "make it case-insensitive" edit is read as a scope change, not a bug fix.

Multi-layer input is unaffected by this change: `c(channel_width, area)` warns on layer 1 as
designed, and `c(area, channel_width)` fails later in `fl_valley_confine()` with
`[names<-] incorrect number of names` — pre-existing behaviour on a path the function has never
supported, not introduced or altered here.

## 3. Roxygen vs NEWS — they agree

`R/fl_valley_confine.R:18-21` (identical in `man/fl_valley_confine.Rd:38-41`):

> Not used when `streams` is already a `SpatRaster`. That branch cannot inspect the values it is
> handed; it warns only when the layer's *name* gives it away, so a raster burned from any other
> wrong column carries the same defect one call earlier, undetected.

`NEWS.md:27-35`:

> **The requirement is scoped to the `sf` branch.** … that branch cannot inspect the values it is
> handed … It can inspect the layer's *name*, since `fl_stream_rasterize()` names its output after
> the column it burned, so `fl_valley_confine()` now warns when handed a layer named
> `channel_width` … The guard names the column literally rather than reading the rasterizer's
> default: those coincide today, and keying to the default would invert the guard if it ever moved.
> **A raster burned from any other wrong column is still undetectable**, so the roxygen states the
> requirement rather than claiming to enforce it.

**They agree, on all three claims** — values are not inspected, the name is, and any other wrong
column is undetected. Round 3's finding (roxygen said "nothing checks that branch" while NEWS
described the check at length) is closed, and the two now make the same claim in the same direction.

Both are accurate against shipped code, verified rather than read:

- "cannot inspect the values … warns only when the layer's *name*" — the branch at `:194-202` reads
  only `names(stream_r)[1L]`; it never touches `terra::values()`. Measured above: every
  `channel_width`-named raster warns regardless of provenance, and an `upstream_area_ha`-named
  raster is silent regardless of what its values are.
- "Not used when `streams` is already a `SpatRaster`" — still true after round 2's fix: the type
  check sits inside `if (inherits(streams, "sf"))` at `:175`, and `area_field` is never read on the
  raster branch except to *quote back* a value the caller supplied alongside `field`, which round 3
  swept and accepted.
- NEWS's "keying to the default would invert the guard if it ever moved" is now a *measured* claim,
  not a prediction — round 3 measured the inversion, and section 1 above measures its absence.

## 4. Other invariants held up by two things agreeing

Complete candidate set. I enumerated it by grepping every occurrence of the literal, every
`names()` call in `R/`, and every assertion added or changed by the diff, rather than by recalling
what I had already looked at:

| # | pair that must agree | enforced by | status |
|---|---|---|---|
| A | guard literal `:197` ↔ `formals(fl_stream_rasterize)$field` | test `:260` | **pinned**; nothing above the source — the formal is a hand-chosen default with no artifact deriving it, so `:260` is the top of that chain |
| B | guard reads `names(stream_r)[1L]` ↔ `fl_stream_rasterize.R:76` `names(out) <- field` | tests `:264` **and** `:265` | **pinned twice**; removing the naming reddens both |
| C | guard condition literal `:197` ↔ guard message literal `:198` | nothing | same `if` block, two adjacent lines; a divergence yields a wrong *message*, never a wrong *decision* — definitional adjacency, not the class |
| D | guard literal `:197` ↔ `channel_buffer` literals `:160`, `:267`, `:271`, `:274` | nothing, **deliberately** | see below |
| E | `fl_stream_rasterize` roxygen "Default `\"channel_width\"`" ↔ the formal at `:51` | transitively by `:260` | the default cannot move silently; `:260` reddens first and sends the reader to that function |
| F | `expect_warning(..., "not upstream contributing")` ↔ the warning text | nothing | definitional — this is what `expect_warning` is |
| G | `expect_match(err, "hectare")` `:231` ↔ the `stop()` text | nothing | same, definitional |
| H | `DESCRIPTION` `testthat (>= 3.1.5)` ↔ first use of `expect_no_warning` | nothing | hand-maintained pin, closed in round 2, standard R practice with no artifact above it |
| I | `NEWS.md` cell/ha figures ↔ the bundled fixture | nothing | reproduced exactly in round 2; a measurement record, not a guard |
| J | `af_fixture()`'s cached `ref` ↔ `"upstream_area_ha"` repeated across tests | construction | every alias path is compared to the one `ref`, so they cannot drift apart |

**D is the residual, and it is definitional.** Stated precisely: the string `"channel_width"` carries
**two distinct meanings** in `R/fl_valley_confine.R` — at `:160`/`:267`/`:271`/`:274` it means *the
bcfishpass channel-width attribute*, and at `:197` it means *the column that is not drainage area* —
and there is no artifact anywhere in the package from which either meaning can be derived. The name
originates in bcfishpass's schema, outside this repo; the second is a judgement about what the flood
model requires. So there is nothing above the source to key either to, and coupling them would be
the round-3 defect in a new dress: an edit that broadened the buffer's column detection would
silently move the guard. They are correctly independent literals, the code comment at `:184-193`
says why in as many words, and round 3 named the same asymmetry. Nothing further to do, and a future
"deduplicate this constant" refactor should be read as re-introducing the defect.

I am not claiming convergence by assertion: the terminating argument is A and D above — every pair
either has a pin (A, B, E), is a test asserting a message it was written for (C, F, G), is a
hand-maintained record with no generator (H, I), or is construction (J) — and for the one pair with
no pin and no generator, the *absence* of a pin is the correct design and I have said why.

## Everything else probed

- **Suite green on the tree as staged:** `devtools::test()` -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 274`
  (273 in round 3; the +1 is the new tripwire at `:260`).
- **Index matches worktree** for every file in scope — `R/fl_valley_confine.R`,
  `tests/testthat/test-fl_valley_confine.R`, `R/fl_stream_rasterize.R`, `man/fl_valley_confine.Rd`,
  `NEWS.md` — so what I reviewed is what would be committed. (Only `planning/active/progress.md` is
  `MM`.)
- **`devtools::document()` writes nothing and deletes nothing**; `git status --porcelain` shows the
  three `.Rd` files still staged-clean afterwards, so the reconciled roxygen sentence is current in
  `man/`.
- **Lint:** no line over 120 in any changed `R/` or `tests/` file (longest is
  `test-fl_valley_attribute.R:180` at 100, from the round-2 prose-pointer fix).

## Notes, not findings

- **The test's *title* is keyed to the coincidence while its body is keyed to the property** —
  `"a raster of fl_stream_rasterize()'s default column warns"`. If the default ever moves, `:260`
  goes red (correctly), the reader re-points it per the comment, and the block is then green with a
  title that no longer describes what it asserts. This is cosmetic rather than the round-3 class:
  **no** repair of that red line can leave the guard wrong, which the matrix in section 1
  demonstrates. Recorded only because the honest repair at that point is to *delete* `:260` and
  rename the test, not to re-point the expectation — the coincidence, once gone, needs no tripwire.
- The guard's only *positive* assertion (`:265`) lives inside that same block. Nothing today makes
  that fragile — `:260` reddens before anyone reaches for the delete key — but a one-line comment
  saying the block also carries the guard's sole positive coverage would make the wrong repair
  harder to reach.
- **`DESCRIPTION` is `Version: 0.5.0` against a `NEWS.md` `0.6.0` heading.** Fourth round carrying
  this; matches the bump-last convention and Phase 4 is open. Not re-flagged as a finding, per the
  brief, but this is the last review before merge.
