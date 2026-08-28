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

## Does the default DEM source hit this? Measured, and no

| source (Bulkley test AOI) | exact-zero slope cells |
|---|---|
| bundled `slope.tif` | 0 of 45,726 (min 1.42e-14) |
| slope derived from `dem.tif` by the `slope = NULL` path | 0 (min 1.42e-14) |
| MRDEM-30 at 30 m via `fl_dem_aoi()` | 0 of 45,726 (min 0.0041) |

An honest negative result, and it bounds the claim: the package default source is unaffected over
this AOI, so the NEWS entry should not imply a general result change. The exposure is integer-metre
DEMs, hydro-flattened lake surfaces and void-filled plateaus. One clip is not proof MRDEM-30 never
contains zeros — a clip over a large lake might.

Confirmed unmoved on bundled data end to end: `fl_valley_confine()` returns 53,635 valley cells and
`fl_valley_attribute(group = "gnis_name")` the same 5 rows and 0 fallback cells as before the fix.

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

## Errors Encountered

| Error | Resolution |
|-------|------------|
