# #47 — `fl_valley_confine()`: required `area_field`, deprecated `field`

`fl_valley_confine()`'s `field` argument defaulted to `"channel_width"`, and the flood model reads
the rasterized values as the drainage-area term in hectares of the Hall bankfull regression. Both
columns are plain positive numerics, so the wrong one was raised to the 0.280 power without
complaint and returned a smaller floodplain with no error and no warning — the same class as #41
and #49. The argument is now `area_field`, required on the `sf` branch, with its units and its
consumer stated in the roxygen; `field` survives one release as an alias that warns and forwards, so
the `floodplains` driver keeps running while it migrates. No published result was affected: every
caller passed the right column under the wrong name.

Shipped as **0.6.0**, commits `184eb22` (tests) → `4e9c88e` (implementation) → `1b089de` (release).
Follow-ups: **#53** (remove the shim), **NewGraphEnvironment/soul#135** (the two-argument call
published in `conventions/cartography.md`, which generates every repo's CLAUDE.md).

## Measurement

Bundled 10 m Bulkley tile, `flood_factor = 6`, current code:

| `area_field` | precip | cells | ha |
|---|---|---|---|
| `upstream_area_ha` | `map_upstream` | 28,727 | 287.3 |
| `channel_width` | `map_upstream` | 17,206 | **172.1** |
| `upstream_area_ha` | none | 19,838 | 198.4 |
| `channel_width` | none | 14,789 | **147.9** |

The old default returned **59.9%** of the floodplain with precipitation supplied, and every
wrong-column run is a **strict subset** — 0 cells gained anywhere, 11,521 lost. That changed what
the issue could claim: it was filed with 222.1 vs 476.8 ha (47%), measured on 0.4.1 before the #49
units fix, so its own headline number no longer described the package. The issue body was rewritten
to current numbers rather than left as a stale spec. `field = "upstream_area_ha"` through the shim
reproduces `area_field =` exactly (`identical(terra::values(...))`).

With `channel_buffer = FALSE`, isolating the flood model from the channel stamp: 14,149 against
19,383.

## Evidence

`review-round1.md` … `review-round4.md` — one Plan review (25 findings) and four `/code-check`
rounds. The wrong turns are the point and are kept:

- Round 1's fix for the `SpatRaster` residual keyed its guard to
  `formals(fl_stream_rasterize)$field`, with a comment claiming "the two cannot drift". Round 3
  measured that the guard **inverts** if that default ever moves — warning on a correct area raster,
  silent on the actual defect — and that the test would have failed on its *premise* line, whose
  obvious repair leaves a green suite with the guard pointing the wrong way.
- Rounds 1, 2 and 3 each found a defect inside the previous round's fix. Round 3 named the mechanism:
  both new guards were keyed to a **cause that was measured** rather than the **property wanted**.
- Round 4 was scoped to those fixes alone and came back clean, terminating by enumerating all ten
  candidate pairs and showing nothing sits above their source — not by asserting convergence.

`progress.md` carries the full triage, including what was recorded rather than changed.
