# Findings — fl_flood_depth() pools every stream's flood level; max-per-watercourse fix over-floods, needs drainage-based ownership (#68)

## Issue context

**Status (2026-10-09):** the mechanism is confirmed, but the candidate fix (one surface per watercourse, keep the highest) was built, measured and **rejected**. It roughly doubles the floodplain and makes `flood_factor` nearly irrelevant. No code has changed. The next candidate is drainage-based ownership (below). Measurements and the rejected implementation: PR for #68, `planning/archive/2026-10-issue-68-flood-surface-blend/` (implementation at commit d71bbb5).

## Problem

`fl_flood_depth()` builds the water surface away from the streams as an inverse-distance-squared average (`terra::interpIDW(power = 2, radius = max_width / 2)`). The average runs over **every** stream cell within 1 km, whatever stream it belongs to. Each stream cell's level comes from `fl_flood_surface()`: bed elevation + `flood_factor` × bankfull depth.

So a spot between a big river and a small creek gets a weighted blend of a deep flood and a shallow one. A creek crossing a big river's valley floor pulls the river's waterline down around itself, and adding streams to a run can **remove** floodplain.

**Measured symptom (floodplains#110, MORR `co_ff04`, one common DEM):**
- Delineating from all FWA streams instead of the coho network loses **451.9 ha (1.27%)** of the coho network's floodplain. That reproduces exactly on flooded main.
- Order ≥ 2 loses 444 ha.

## What was measured

**1. The blend is what loses the ground.** Slope doesn't depend on the streams, and the distance and cost masks only loosen as streams are added. So a lost cell is dropped either by the flood mask or by cleanup. Recomputing the flood mask for both networks:
- **78.6%** of the lost cells are wet with the coho streams and dry with all streams.
- Only 4.8% survive the all-streams run's pre-cleanup masks.
- Over the whole grid, 1,256 ha of flood-mask cells go from wet to dry when streams are added.
- The coho flood depth on the lost cells has a median of 2.2 m, so these cells are not marginal.

The diagnostic first proposed here, "do the lost cells sit next to added streams", **cannot separate the cases**. The added network is dense enough that the median floodplain cell is already 185 m from an added stream, and the lost cells' median is 213 m.

**2. Lineage.**
- Nagel et al. (2014) set the flood height "for each stream segment" and do not say how neighbouring segments' heights combine laterally.
- The Python VCA (BlueGeo, carried in bcfishpass `valley_confinement.py`) pools every stream cell into one `scipy griddata` interpolation.
- So the blend is inherited from the Python port, not from the published method.

**3. The candidate fix over-floods.** It was implemented as per-`blue_line_key` IDW surfaces merged by cell-wise max, with confluence cells shared by every watercourse that crosses them. It passed every property test, including "adding a blue line never removes floodplain". But the extent (bundled tile, valley cells):

| flood_factor | pooled (today) | max per blue line | max per stream order |
|---|---|---|---|
| ff2 | 18,543 | 45,101 (+143%) | 37,209 (+101%) |
| ff4 | 23,192 | 46,758 (+102%) | 40,610 (+75%) |
| ff6 | 28,727 | 48,027 (+67%) | 43,764 (+52%) |

- **Per-blue-line ff2 exceeds today's ff6.** The extent is set by where the tributaries sit, not by flood height.
- **The steep tributaries win all the gained ground, not the Bulkley.** Each tributary's own waterline, carried from its steeper upper reach (17–43 m/km), sits metres above the Bulkley's valley floor beside it. Median depth on the gained cells is 4.9 m.
- **IDW's reach is not the main cause.** With each tributary's nearest-cell level instead of IDW, 72% of the gain stays wet.
- **Per-order grouping does not avoid it.**

**So the pooled blend has two errors that partly cancel:**
- it lowers a river's waterline near small streams (the 1.3% loss above);
- it hides steep tributaries carrying their waterline sideways onto the mainstem floor, which is a much larger effect.

Removing the first error exposes the second. Any fix has to handle both.

## Next candidate: drainage-based ownership

A cell takes the waterline of the stream it *drains to*, not of every stream within 1 km. A Bulkley valley-floor cell then gets the Bulkley's level, even beside a tributary mouth. Ground on a tributary's own fan gets the tributary's level. This is HAND-style (height above nearest drainage) assignment, a different interpolation domain rather than a tweak to the IDW.

**Acceptance for any fix:**
- Monotone in added watercourses on the bundled tile. The test from the rejected implementation (d71bbb5) can be reused.
- `flood_factor` ordering and sensitivity preserved: ff2 < ff4 < ff6, with gaps of the same order as today's.
- Bounded change against today on fixed streams: report the bundled tile, MORR arm 5 and the Parsnip A/B, not just arm 1 vs arm 5.
- An audit of gained cells covering which stream owns each cell, the depth, and the height above the owner's bed.

A rejected mitigation, for the record: "no flooding below the group's own bed at its nearest cell" brings the ff6 gain down to +21%. But it loses 7,067 cells the blend had, so it is not a drop-in fix.

**Results change:** only once a fix passes the acceptance above. Then add a NEWS entry, and have floodplains re-run, timed with flooded#67.

Relates: floodplains#104, floodplains#110, flooded#67, flooded#40.

## Errors Encountered

| Error | Resolution |
|-------|------------|
| `Error unwrapping 'output'` / `Error running WhiteboxTools (BreachDepressionsLeastCost)`, twice, in test runs while the plan reviewer ran its own R probes | Not reproduced in 25 sequential calls. Likely two WhiteboxTools processes at once; measurement scripts now run one at a time |
| Monotone test failing on fixed streams | WhiteboxTools multi-threaded breach/fill non-deterministic; pinned to 1 thread |

## Phase 1 — Can a conditioned D8 path reach the streams? (2026-10-09)

Scripts and logs: `measure_drainage_reach.R/.log`, `measure_drainage_window.R/.log` (this
directory). Bundled tile; reference set = today's 28,727 valley cells (`upstream_area_ha` +
precip, ff6). "Reached" = some cell on the D8 path lies in the 3x3 window of a stream cell.

| conditioning | valley cells reached | time |
|---|---|---|
| raw `terra::terrain(v = "flowdir")` (3,932 code-0, 8.5% cyclic) | 29.2% | <1 s |
| raw WBT D8, no conditioning | 17.8% | <1 s |
| WBT breach least-cost, dist 10 cells (+fill) | 67.9% | 1.3 s |
| **WBT breach least-cost, dist 50 cells (+fill)** | **79.1%** | 4.2 s |
| WBT breach least-cost, dist 200 cells (+fill) | 68.0% (11,627 code-0 cells) | 8.3 s |
| WBT fill depressions (fix_flats) | 67.1% | 0.9 s |

Rejected without a number: `terra::flowDir()` (experimental) did not finish in 10 min on 518k
cells; `terra::pitfiller()` (experimental PEM4PIT) was killed by a 15 min timeout. Stream burning
(5-50 m) moved raw D8 from 29% to <=30% and would make flow directions depend on the streams,
which breaks monotonicity.

**The gate as written (>= 90%) fails at 79.1%, and the misses are not what the gate was for.** It
was meant to catch D8 paths missing streams through misalignment or diagonal leaks. That is not
what happens:
- Widening the window barely moves it: 79.1% at 10 m, 79.3% at 50 m, 79.5% at 100 m.
- **Every one** of the 5,991 missed valley cells drains off the tile edge, never within 15 m of a
  seeded stream.
- The missed cells are themselves a median **582 m** from a stream. Pooled IDW wets them because
  its 1 km radius reaches across the valley.

These are cells whose drainage leaves the bundled tile before meeting a seeded stream (down-valley
swales and side drainage running parallel to the river), so the bundled tile is a worst case. On a
watershed-clipped DEM (MORR, a WSG) every path reaches the outlet through the network. Re-measure
there in Phase 4 rather than assume it. Decision: proceed; window 3x3; breach dist 50 cells.

WBT ESRI pointer convention confirmed on synthetic planes: east-falling 1, south-falling 4,
northeast-falling 128; NA DEM gives an NA pointer, and neighbours do not point into it.

## Phase 3 — WhiteboxTools is not deterministic multi-threaded (2026-10-09)

First full run of the monotone test failed for 4 of 5 blue lines. The flood mask itself gained
55-315 cells when a line was dropped, which the path maximum cannot do on fixed flow directions.
They were not fixed: two identical `fl_flow_next()` calls on the bundled tile differed in
**60,541** and **69,960** of 518,400 cells. Isolated in a scratch probe:

| tool (default threads) | cells differing between two identical runs |
|---|---|
| breach least cost (+fill) | 59,638 |
| breach least cost (no fill) | 49,570 |
| fill depressions (fix_flats) | 36,047 |
| breach depressions (fast) | 0 |
| D8 pointer on a fixed input | 0 |

With `max_procs = 1` every tool is identical between runs. `fl_flow_route()` sets
`R_WHITEBOX_MAX_PROCS=1` for its own call and restores the caller's value (the env var outranks
the `whitebox.max_procs` option in `whitebox::wbt_max_procs()`). Bundled tile at 1 thread: 4.2 s.
With it, the monotone test passes for every blue line.

## Plan review (review-1.md) — what was taken (2026-10-09)

- **B1, taken.** The path maximum takes the top of the bed-noise distribution, so the level now
  comes from the conditioned DEM along the path plus the 3x3 max of ff x bankfull depth
  (`fl_drainage_level()`, the HAND convention). Raw, conditioned, and conditioned-3x3-min were
  measured side by side before pinning (`measure_level_rule.R`).
- **B2, the gate.** The Phase 1 gate (>= 90% reach) failed at 79.1% and I proceeded on my own
  call, not the user's. It is flagged for the user in the PR. The opt-in method changes no
  default output, so nothing ships on the strength of the waiver. Reach is re-measured on the
  watershed-clipped Parsnip and MORR DEMs (`measure_audit.R`, `measure_morr.R`).
- **G1, taken.** Scope the claim: the flood mask is monotone; the delineation is monotone on
  DEMs without NA gaps (#65 switch, `costDist` NA regions). Squeezed (`cost_threshold = 300`)
  variant of the monotone test added.
- **G2, partly.** The #63 contract test runs under drainage. A NA gap over the channel (lidar
  water returns) leaves the floor beside it unowned. That is a limitation to document and
  measure, not a test to pin.
- **G3, taken:** explicit `NAflag`, and the grid length is asserted after read-back.
- **G4, taken:** `fl_pointer_next()` is split out and all 8 codes, 0, NA and the 4 edges are
  tested without whitebox. The downhill invariant on the route is tested with whitebox.
- **G5, taken:** `fl_path_max(which = TRUE)` returns the supplying cell for the audit.
- **Scope note, taken:** `flood_method` moved to the end of the signature, before the deprecated
  `field`, so positional calls are unchanged.
- **Not taken:** caching the route across calls (an optional precomputed-route argument). This
  is a speed concern for a method still being judged; measurement scripts cache it themselves.

## Phase 4a — Which level rule, and the first verdict signal (2026-10-09)

`measure_level_rule.R` / `.log`. Valley cells from `fl_valley_confine()` with precip
(Parsnip also with its waterbodies, as in the vignette build), pooled against three drainage
level rules:
- raw: 3x3 max of the stream flood surface;
- cond: conditioned path-cell elevation + 3x3 max ff x d;
- condmin: 3x3 min of conditioned elevation + 3x3 max ff x d.

| site | rule | ff2 | ff4 | ff6 | ff4 vs pooled | gap ff2->4 | gap ff4->6 |
|---|---|---|---|---|---|---|---|
| bundled (10 m tile) | pooled | 18,543 | 23,192 | 28,727 | — | +25.1% | +23.9% |
| | raw | 9,462 | 13,185 | 17,650 | −43.1% | +39.3% | +33.9% |
| | cond | 7,672 | 11,565 | 16,071 | −50.1% | +50.7% | +39.0% |
| | condmin | 6,900 | 10,902 | 15,545 | −53.0% | +58.0% | +42.6% |
| Parsnip (MRDEM-30, WSG) | pooled | 417,543 | 441,054 | 461,129 | — | +5.6% | +4.6% |
| | raw | 384,894 | 406,090 | 430,299 | −7.9% | +5.5% | +6.0% |
| | cond | 293,715 | 321,003 | 349,767 | −27.2% | +9.3% | +9.0% |
| | condmin | 238,935 | 276,208 | (run cut off by session end) | −37.4% | +15.6% | — |

- **Drainage ownership under-floods under every rule**, where round 1's max of per-watercourse
  IDW over-flooded. Parsnip has no tile edge (watershed-clipped DEM), so this is not the
  bundled tile's off-tile drainage.
- **`flood_factor` sensitivity is kept and strengthened**: the gaps are wider than pooled's on
  both sites, the opposite of round 1's compression. Review B1 predicted compression from bed
  noise under the raw rule; on Parsnip raw's gaps are about pooled's, so not observed here.
- **Rule choice: cond** (HAND convention, review B1).
  - raw is closest to pooled on Parsnip (−7.9%), but it is the rule the review showed takes the
    top of the bed-noise tail. The Parsnip DEM is stored as integers (INT2S), and FWA lines sit
    on banks. Being close to pooled is not evidence that it is right.
  - cond has a known high bias: the cell beside a stream carries a level one cell's relief above
    the stream's own, 0.2 m on the creek fixture. This is pinned in the tests.
  - condmin removes that bias and biases low by one cell's down-path drop.
  - The three rules bracket the answer, and none comes near pooled under the HAND convention.
- Runtime: drainage ~110-225 s per Parsnip run against pooled 126-181 s (single-threaded
  WhiteboxTools route recomputed every call; an unrelated R job shared the machine).

## Phase 3 — WhiteboxTools panics in its fill branch; conditioning changed (2026-10-09)

The full suite hit `thread 'main' panicked at ... breach_depressions_least_cost.rs:657:27: Error
unwrapping 'output'` (exit 101) with no second WhiteboxTools process running, so the earlier
"two processes at once" explanation was wrong. Upstream source (v2.4.0):
- in the fill branch, workers hold `Arc` clones of `output`;
- the main thread calls `Arc::try_unwrap` after receiving their messages, but before they are
  guaranteed to have dropped those clones. That is a race at any thread count.
- `fill_depressions.rs:366` has the same pattern; `breach_depressions.rs` has none.

Conditioning is now least cost with `fill = FALSE`, then `BreachDepressions` (Lindsay's hybrid
breach-fill) for the pits it leaves. `measure_route_robust.R/.log`, bundled tile:
- 30 sequential calls: 0 errors, all identical, median 4.5 s;
- 0 cells whose next cell is higher; 265 fixed points;
- 78.9% of pooled valley cells reach a stream, against 79.1% before.

Upstream report drafted, not posted: `upstream_whitebox_draft.md`.

Full suite after the change: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 344 ]`, with every drainage test
run. lintr: two "unused argument" warnings on the pass-throughs come from resolving against the
stale installed package (code-check-r, "lintr also resolves against the installed package").

## Phase 4b — The level must come from the original DEM; rule = rawmin (2026-10-09)

Re-run on the bundled tile after the conditioning change (`measure_level_rule_bundled.log`,
`measure_level_rule_bundled_rawz.log`). ff4 against pooled 23,192:

| rule | least cost + fill (Phase 4a) | least cost, then BreachDepressions | gaps ff2->4 / ff4->6 (new) |
|---|---|---|---|
| raw (stream surface) | −43.1% | −36.3% | +44.3% / +31.7% |
| cond (conditioned path cell) | −50.1% | **−75.0%** | +26.4% / +29.7% |
| condmin | −53.0% | **−82.6%** | +34.7% / +32.8% |
| pathraw (original DEM at path cell) | — | −47.3% | +43.5% / +36.6% |
| **rawmin** (3x3 min of original DEM) | — | −52.2% | +60.4% / +36.7% |
| pooled | — | — | +25.1% / +23.9% |

- The cond rules read the conditioned DEM, so the trenches `BreachDepressions` cuts lower the
  waterline directly. The same rule moved from −50% to −75% with the conditioning algorithm
  alone, so cond is rejected.
- Reading the original DEM makes conditioning a routing step only. pathraw and rawmin land where
  cond and condmin sat under the gentler least-cost conditioning.
- **Shipped rule: rawmin.** The lowest original ground in the 3x3 window stands in for the
  channel bed under a misregistered stream line, the review's B1 concern. Its bias is low, up to
  one cell's down-path drop, pinned in the creek-fixture test (`at(29, 20) == 0`).

## Phase 4c — Parsnip, rawmin (2026-10-09)

`measure_level_rule_parsnip.log`: MRDEM-30 WSG clip, bull trout order 3+, precip,
waterbodies. Each run took about 90 s at 4 threads with memfrac 0.3.

| rule | ff2 | ff4 | ff6 | vs pooled (ff2 / ff4 / ff6) | gaps ff2->4 / ff4->6 |
|---|---|---|---|---|---|
| pooled | 417,543 | 441,054 | 461,129 | — | +5.6% / +4.6% |
| raw | 386,939 | 408,335 | 432,073 | −7.3% / −7.4% / −6.3% | +5.5% / +5.8% |
| **rawmin** | 277,681 | 314,772 | 356,391 | **−33.5% / −28.6% / −22.7%** | **+13.4% / +13.2%** |

- On a watershed-clipped DEM, with no tile edge, the shipped rule still maps about a quarter to
  a third less valley than pooled.
- `flood_factor` matters about 2.5x more than under pooled, the opposite of round 1.
- raw sits close to pooled, but it reads the stream cell's own DEM bed, which review B1
  measured carrying noise upstream (p90 excess 7 m on Parsnip). Closeness to pooled is not
  evidence of correctness: pooled is the method under question.

## Phase 4d — Why drainage maps less: the audit (2026-10-09)

`measure_audit.R/.log`, ff4, rawmin. "Lost" = valley under pooled, not under drainage. The
straight-line distance to the cell that supplied the waterline (`fl_path_max(which = TRUE)`) is a
lower bound on its distance along the path.

| | bundled tile | Parsnip WSG |
|---|---|---|
| pooled / drainage valley cells | 23,192 / 11,096 | 441,054 / 314,772 |
| lost / gained | 12,645 / 549 | 137,593 / 11,311 |
| lost: path meets no stream | 43.2% | 1.6% |
| lost: owned, waterline below ground | 55.5% | **94.7%** |
| lost: wet, removed by cleanup | 1.3% | 3.7% |
| owned-but-dry: pooled minus drainage waterline, p10/p50/p90 | 0.9 / 8.9 / 18.6 m | 1.7 / **5.9** / 23.4 m |
| owned-but-dry: pooled depth on them | 0.1 / 1.6 / 5.5 m | 0.2 / 2.3 / 6.9 m |
| owned-but-dry: distance to nearest stream | 50 / 406 / 730 m | 31 / **156** / 519 m |
| owned-but-dry: straight-line distance to waterline source | 128 / 1,205 / 2,210 m | 0 / **590** / 2,765 m |
| gained: drainage minus pooled waterline | 0.2 / 0.9 / 1.8 m | 0.8 / 2.8 / 8.4 m |
| gained: distance to waterline source | 36 / 114 / 197 m | 178 / 1,730 / 6,794 m |
| corridor cells owned / pooled-valley cells owned | 91.7% / 76.4% | 99.5% / 99.4% |

- **On Parsnip, the loss is not unowned ground.** 94.7% of lost cells drain to a stream.
  - Their drainage waterline sits a median 5.9 m below pooled's.
  - It is set by a cell a median 590 m away (straight line, so at least that far along the
    path), against a median 156 m to the nearest stream.
  - Under pooled they stood under a median 2.3 m of water.
  - This is the measured form of the mechanism: under drainage a valley-floor cell takes the
    level of the reach where its path meets the network, which is lower than the reach beside
    it.
- **On the bundled tile**, 43% of the loss is unowned: drainage off the tile edge, Phase 1.
- **The gained cells on Parsnip carry levels from far away**: median 1.7 km, p90 6.8 km, about
  2.8 m above pooled. That is the path maximum carrying a downstream level, such as a lake or a
  large confluence, a long way up. This is the review's backwater concern (As3) at a scale
  larger than its estimate. It is not attributed per waterbody here.
