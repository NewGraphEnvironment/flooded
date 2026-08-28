# Findings — fl_cost_distance() seeds every zero-friction cell (#41)

## Issue context

`fl_cost_distance()` treats every zero-friction cell as a stream seed, not just stream cells.

```r
# R/fl_cost_distance.R:51-52
cost <- terra::ifel(!is.na(streams), 0, friction)
out  <- terra::costDist(cost, target = 0)
```

`costDist(target = 0)` finds *all* cells equal to 0. Stream cells are set to 0 deliberately — but so
is any cell whose friction (percent slope) is already exactly 0. The roxygen says otherwise.

Filed separately from #40 because it changes VCA output on any DEM containing exact zeros — a
result-changing decision that deserves its own diff and regression check, not a side effect of an
attribution feature. Found during the plan review for #40.

## Reproduction (measured 2026-08-27)

Synthetic 50x50 grid, friction 10% everywhere, one stream cell at [45,45], a 6x6 exact-zero patch at
rows/cols 10-15:

```
                          current    fixed
zero-cost cells              37         1     (stream cells: 1; 36 patch cells were seeds)
cost at flat-patch centre     0      4101
cost one cell beyond it      50      4151
```

## Why the bundled tile cannot catch it

| raster | min | cells == 0 |
|---|---|---|
| `inst/testdata/slope.tif` | 1.422896e-14 | 0 |
| slope derived from `dem.tif` by the `slope = NULL` path in `fl_valley_confine()` | 1.422896e-14 | 0 |

Both verified this session. `terrain()`-derived slope on a continuous float DEM essentially never
produces an exact zero. Production DEMs do: integer-metre DEMs, hydro-flattened lake surfaces,
void-filled plateaus.

Corroboration already in the repo: the 1 m lidar run at `vignettes/stac-dem.Rmd:311` emits
`[costDist] distance algorithm did not converge`, which is the shape of large zero-cost plateaus.

## Design: why flooring, not a sentinel target

`terra::costDist(x, target)` takes a target *value* in `x`; there is no separate seed-raster
argument. So seeds must be encoded as a value in the friction raster. Two ways:

**A — sentinel `target = -1`.** Leaves genuinely flat ground free to cross.
**B — floor non-positive friction to `EPS`, keep `target = 0`.**

Probed both on the grid above; numerically identical (patch centre 4101 either way, exactly 1 zero
cell). **B chosen.** A *assumes* no friction cell equals −1; B *constructs* the invariant that
nothing but a stream cell equals 0. A is the same bug relocated to a rarer value.

## Properties verified by probe, not assumed

| property | probe result |
|---|---|
| `NA` friction survives the floor (barriers preserved) | `ifel(NA <= 0, ...)` -> `NA`. Confirmed |
| integer-typed friction does not round the floor back to 0 | `INT2S` raster promotes to float under `ifel`; min after floor 1e-06, zeros 0 |
| flat ground stays cheap to *cross*, not made a barrier | 4101 through the flat patch vs 4596 over equal-length 10 %-friction ground |
| a stream cell whose friction is `NA` still seeds at 0 | confirmed — seeding runs after flooring |
| all-flat friction raster | exactly 1 zero cell (the stream); corner cost 1.2e-04 |

## Scale of `EPS = 1e-6`

`costDist` accumulates friction × distance in map units — confirmed empirically: a 10x10 grid at
10 m res, friction 1e-6, corner-to-corner ≈ 127 m gave 1.202e-04 ≈ 127 × 1e-6.

So at 10 m cells a **100 km** path over floored ground accrues **0.1** against a default
`cost_threshold` of 2500. Percent slope runs 0–100+; `EPS` is eight orders below. Negligible by
construction, and the probe above shows it does not read as a barrier.

## No new argument

`EPS` stays an internal constant. `fl_cost_distance()` is exported, so a user in unusual friction
units already has a one-line escape hatch — pre-floor their own raster before calling. A parameter
buys nothing they cannot already do. This keeps the change a pure bug fix (0.4.0 -> 0.4.1).

## Relationship to #40

`fl_cost_distance()` is the package's only `costDist` call site — `R/fl_valley_confine.R:147` and
`R/fl_valley_attribute.R:315`. One fix covers both.

Under `fl_valley_confine()` alone a spurious flat seed lowers cost slightly in ground that was
probably valley anyway. Under per-group attribution it is worse: a flat patch is a free source for
whichever group's corridor contains it, so that group's cost mask spreads across ground its own
streams never reach. Cost then stops discriminating between groups exactly where floodplains are —
on flat ground — and membership degenerates toward the distance buffer.

#40's coverage argument ("a valley cell's global cost is reproduced by its own group's seeds") is
*strengthened* by this fix, not perturbed.

## Revised during implementation: floor `== 0`, not `<= 0`

The issue proposed `terra::ifel(friction <= 0, 1e-6, friction)`. Probing found that
`terra::costDist()` **rejects a negative cost surface outright**:

```
Error: [costDist] negative friction values not allowed
```

So flooring `<= 0` would have silently disabled a real guard, converting meaningless input into
plausible-looking output — the same failure direction the rest of this fix exists to close. Landed
as `friction == 0` instead, which eliminates exactly the set that `costDist(target = 0)` would
mistake for seeds and nothing more. Verified the guard still fires after the change.

`NA == 0` is `NA`, so barriers are still untouched.

## Does the default DEM source hit this? Yes — corrected after review

My first measurement was one 30 m MRDEM-30 clip over the Bulkley test AOI: **0** exact-zero slope
cells. I wrote that into NEWS and `methodology.md` as "the default source is unaffected". A
code-review agent caught that the package's own *other* MRDEM-30 dataset contradicts it. Verified:

| DEM shipped by this package | exact-zero slope cells | cost mask (`< 2500`) | valley cells |
|---|---|---|---|
| bundled `dem.tif` / `slope.tif`, 10 m | 0 of 45,726 (min 1.42e-14) | unchanged | 53,635 -> 53,635 |
| MRDEM-30 clip over the same AOI, 30 m | 0 of 45,726 (min 0.0041) | unchanged | n/a |
| `pars_dem.tif` (MRDEM-30, 30 m, 20.9 Mcell) | **80** of 10.7 M | **-2,289 cells (214 ha)**, 0 added | 521,028 -> 521,028 |

Textbook "an inventory is only complete relative to a boundary — name the boundary". The
measurement was correct and the generalisation from it was not. A small clip returning zero is not
evidence about the source; scale is what surfaces the zeros.

### But the reviewer's conclusion from it was wrong in the other direction

It reported the shipped `pars_valleys.tif` as **stale** — produced under the bug, published by
pkgdown, feeding the fp_peace report. That inference came from the cost mask, an *intermediate*.
Measuring the actual output instead — the shipped raster **is** the old code's output, so it is its
own oracle — gives:

```
shipped(old): 521028 cells (48603.1 ha)
current(new): 521028 cells (48603.1 ha)
only in old : 0        only in new : 0
```

Bit-identical. `fl_valley_confine()` intersects cost with slope, distance and flood and then runs
morphological cleanup, which absorbs all 2,289 cells. No shipped artifact needs regenerating —
which matters, because `data-raw/wsg_vignette_data.R` needs an fwapg database connection that is not
available here.

Worth keeping as the general lesson: **a moved intermediate is not a moved output.** Both directions
of this finding cost a measurement to settle, and both were worth making.

One property that does generalise: the fix can only *raise* a cost that was spuriously zero, so it
strictly removes cells from the cost mask and never adds (0 added, confirmed). Where cost is the
binding criterion the delineation will shrink; it can never grow.

## Bug-restoration check

Tests were run against the unfixed function before Phase 3. Three went red — and only the three
that target the bug:

```
test-fl_cost_distance.R:95   zero_cells != seed_cells  (37 zeros vs 1 expected)
test-fl_cost_distance.R:104  patch centre 0.0 <= near-stream 50.0
test-fl_cost_distance.R:156  INT2S output had 17 zeros, expected 1
[ FAIL 3 | WARN 0 | SKIP 0 | PASS 18 ]
```

The other new tests pass in both states by design — they guard the *opposite* over-correction
(flooring high enough to make flat ground a barrier) and terra's negative-friction guard, neither of
which the bug touches.

## Review round 1 — what landed

| finding | verdict | action |
|---|---|---|
| shipped `pars_valleys.tif` is stale | **wrong** — cost mask moved, output did not (0 cells) | none; recorded above |
| NEWS/methodology overclaim the default source is unaffected | **right** | rewritten with the two-DEM table |
| over-correction guard cannot catch a floor of 1 | **right** | replaced with a negligibility ratio guard |
| negative-friction test pins terra's error string | **right**, minor | loosened to `"negative"` with a comment |

The third is the one worth remembering. The test asserted "crossing flat ground costs less than
crossing sloped ground", which *any* floor below the sloped friction satisfies — so a floor of 1
passed, while costing 1e5 over a 100 km path, 40x a default `cost_threshold`. The assertion was
correct and the property it encoded was too weak. Replaced with a ratio bound (flat traverse under
3e-5 of the sloped equivalent), then verified by restoration: floors of 1e-6 and 1e-4 pass, 1e-3 and
1 fail, with the patch confirmed to have taken effect on each run.

Also noted by the reviewer and worth carrying: under `pkgload::load_all()` / `test_file()`,
`fl_cost_distance` resolves through `globalenv()` as well as the namespace, so a restoration probe
that patches only `asNamespace("flooded")` gives a **false green**. Patch both, and print a value
that proves the patch took before trusting the run.

## Errors Encountered

| Error | Resolution |
|-------|------------|
