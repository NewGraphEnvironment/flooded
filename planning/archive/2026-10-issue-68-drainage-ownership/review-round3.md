# Review round 3: branch 68 (drainage method), diff 484c2de...HEAD (HEAD = 92cc3c3)

Read in full: R/fl_flood_depth.R, the fl_flood_model.R and fl_valley_confine.R hunks,
tests/testthat/setup.R, the added blocks of test-fl_flood_depth.R and test-fl_valley_confine.R,
the CLAUDE.md paragraph, research/flood_surface_interpolation.md and research/README.md. Also read
findings.md, review-1.md, review-round1/2.md, every measure_*.log, and the round 1 archive's findings.md.

Probes ran in a `git archive HEAD` copy in the scratchpad, one R process at a time, read-only:
- creek fixture, pooled: adding the creek loses **46** cells.
- bundled tile, pooled at defaults, dropping each blue line in turn: the valley gains 1,753 / **12,220** (Bulkley) / 732 / 0 / 67 cells.
- the NA block of `na_block_fixture()` holds cells of the Bulkley (360873822) and of Richfield Cr.
- bundled ff4 with precip, drainage method:
  - 286 of 10,432 wet non-stream cells have a path that never enters a stream cell. Round 2's count reproduces.
  - On the 7,013 owned-but-dry lost cells, the waterline exceeds the level at the first path cell within one cell of a stream by 0.000 / 0.062 / 0.062 m (p10/p50/p90). The level is effectively the join point's. It is the supplying cell in 47%.
- `fl_flow_route()` on the bundled tile: conditioning raises 180 cells, by up to 2.0 m, and lowers 167,472. So the second pass does fill some ground, and "breach-fill" holds.

## 1. Mechanism

The prose was written from the method's design concept ("a cell takes the waterline of the stream it
drains to"), not from what the code computes or what a log measured. The code computes the 3x3-minimum
of the original DEM plus the 3x3-maximum depth of any stream within one cell, takes the maximum over the
path, and then overrides stream cells.

So every restatement drifts toward the concept in one of three ways:
- **A stale rule.** It names the stream's own waterline, the conditioned elevation, or "streams on its path".
- **A relabelled measurement.** `owned`, meaning the path passes within one cell of a stream, becomes
  "drains to a stream". A waterline gap becomes "cells sit below".
- **A dropped scope.** A per-tool range becomes "each tool". "Monotone on the valley without NA gaps"
  becomes "exactly monotone".

Fixes were written the same way, so two of this round's defects sit inside round 2's fixes: the CLAUDE.md
5.9 m sentence and the determinism comment.

## 2. Enumeration: added lines making a behavioural or quantitative claim

TRUE = matches the code, a log or a probe. FALSE = contradicted. UNSUPPORTED = no evidence on the branch.
Pre-existing claims that were only re-flowed are counted and marked by their provenance.

### R/fl_flood_depth.R roxygen

| # | claim | verdict | reason |
|---|---|---|---|
| 1 | @param: pooled interpolates every stream cell's surface into one IDW surface | TRUE | `interpIDW` over all stream cells |
| 2 | @param: drainage = highest level met along the downstream path; a path cell's level = lowest ground beside it + deepest stream depth within one cell | TRUE | `fl_drainage_level` + `fl_path_max`. The 3x3 window includes the cell itself, and stream cells are overridden as @return says |
| 3 | @param: needs whitebox package and binary | TRUE | `fl_whitebox_check()` |
| 4 | pooled averages every stream cell within max_width/2 whatever stream, as the Python VCA's griddata does | TRUE | `radius = half_width`. The griddata comparison is about pooling |
| 5 | a creek pulls the river's waterline down; adding streams can remove floodplain | TRUE | probe: 46 cells |
| 6 | step 1: breaches depressions, least cost then a breach-fill pass | TRUE | two calls; probe: 180 cells raised |
| 7 | assigns each cell a D8 direction | TRUE | `wbt_d8_pointer` |
| 8 | directions come from the DEM alone | TRUE | `fl_flow_route(dem)` |
| 9 | single-threaded because multi-threaded breaching is not deterministic | TRUE | least cost (no fill) differs in 49,570 cells (findings.md:118-123) |
| 10 | step 2: candidate = 3x3 min ground + deepest flood_factor x bankfull depth in the window | TRUE | `focal(min)` + `focal(max, flood_surface - dem)`, where `flood_surface = dem + ff*d` |
| 11 | lowest neighbour stands in for the channel bed, as in HAND | TRUE | analogy only: HAND uses a drainage-cell bed, and the 3x3 min is this package's choice |
| 12 | one high stream-cell elevation is not carried upstream | TRUE | elevation enters only through the window min, and the depth term has no elevation |
| 13 | biased low: below the stream's own by the lowest neighbour's drop, at least one cell's drop on a sloping channel | TRUE | min <= z of the supplying stream cell; a channel cell's window holds its downstream neighbour |
| 14 | step 3: waterline = highest candidate on the path, cell included | TRUE | `fl_path_max` |
| 15 | adding a watercourse never lowers a waterline away from its own cells | TRUE | path max; `rasterize(fun = "max")` so shared cells only grow; corridor only grows |
| 16 | flood mask monotone except on the added stream itself | TRUE | `ifel(stream_mask, 0, ...)` |
| 17 | fl_valley_confine() puts every stream cell in its flood mask | TRUE | fl_valley_confine.R `ifel(!is.na(stream_r), 1L, mask_flood)` |
| 18 | its other steps keep the result monotone, so it is monotone on a DEM without NA gaps | TRUE | round 2 step check; per-blue-line tests, also with cost_threshold = 300 |
| 19 | gaps can break that through the cost surface and #65 | TRUE | hedged; plan review B: monotone only while the NA pattern is fixed. Not measured |
| 20 | a large river's level carries up a tributary's lower reach (backwater) | TRUE | path max includes river cells below the junction |
| 21 | a tributary's level reaches only ground whose path passes through it or within one cell | TRUE | level is non-NA only within one cell of a stream |
| 22 | **a cell whose path meets no stream gets no waterline** | **FALSE** | probe: 286 of 10,432 wet cells have paths that never enter a stream and are flooded through the window. Read against #21, "meets" means "enters" |
| 23 | includes ground draining off the DEM edge | TRUE | edges are fixed points; no stream in any window → NA |
| 24 | includes ground whose path runs into an NA gap over the channel | TRUE | by code: `flood_surface - dem` is NA in the gap and D8 never points into NA. Untested directly |
| 25 | experimental; maps much less than pooled | TRUE | logs |
| 26 | Parsnip ff4: 29% fewer valley cells | TRUE | 441,054 → 314,772 (−28.6%) |
| 27 | almost all of the difference is ground that **does drain to a stream**, with a waterline a median 5.9 m lower | UNSUPPORTED (label) | the numbers are right (94.7%, 5.9 m). "Drains to" is the audit's `owned` (path within one cell), which #22's probe shows is a superset |
| 28 | it takes the level of the reach its path joins, not the reach beside it | TRUE | probe (bundled): max − join-point level p90 0.062 m. Not measured on Parsnip |
| 29 | flood_factor matters about 2.5x as much | TRUE | Parsnip 13.4/5.6 = 2.4x, 13.2/4.6 = 2.9x |
| 30 | example: drainage needs WhiteboxTools | TRUE | guard |

### R/fl_flood_depth.R code comments

| # | claim | verdict | reason |
|---|---|---|---|
| 31 | **L133-134: candidate level = "its conditioned elevation" + deepest depth in 3x3** | **FALSE** | `fl_drainage_level` uses the 3x3 **min of the original DEM**. `route$z` is never used. "cond" is the rule Phase 4b rejected (−75%) |
| 32 | L135: then the highest candidate on the downstream path | TRUE | `fl_path_max` |
| 33 | L142: extract stream cell coords + surface as xyz | TRUE | moved code |
| 34 | L148: IDW from stream points onto corridor | TRUE | moved code |
| 35 | fl_has_whitebox: TRUE when package and binary are both available | TRUE | code |
| 36 | route returns `next` cell numbers and `z` conditioned elevations | TRUE | code |
| 37 | whitebox breaches: least cost, then a breach-fill pass | TRUE | as #6 |
| 38 | ESRI codes 1 E … 128 NE | TRUE | ESRI convention; findings.md synthetic planes; test pins all 8 |
| 39 | no outflow / NA / off-grid points to self, so every path ends at a fixed point | TRUE | `fl_pointer_next`; D8 is strictly downhill, so acyclic; round 2: 0 interior self-points |
| 40 | directions from the DEM alone keep the surface monotone | TRUE | a necessary condition, with the max |
| 41 | **"Multi-threaded breaching and filling are not deterministic"** | **FALSE (over-general)** | findings.md:118-123: `BreachDepressions`, now the route's second pass, differs in **0** cells multi-threaded. Only least-cost breaching and FillDepressions differ |
| 42 | two calls of the original route: 60,541 and 69,960 of 518,400 differ | TRUE | findings.md:115-116 |
| 43 | **"(each tool alone: 36,047 to 59,638 elevations)"** | **FALSE** | same table: BreachDepressions 0 and D8Pointer 0. The range covers only least cost ± fill and FillDepressions, and FillDepressions was never in a route |
| 44 | so a run would not be monotone against itself | TRUE | Phase 3: monotone test failed on 4 of 5 lines |
| 45 | one thread is exact | TRUE | route_robust: 30/30 identical; test pins it |
| 46 | env var outranks the option; set and restore | TRUE | round 1 verified `wbt_max_procs()` |
| 47 | least-cost breaching is WhiteboxTools' recommended method | TRUE (unverified offline) | the installed tool help states no preference for least cost; the WBT online manual recommends it as recalled |
| 48 | then a hybrid breach-fill pass for the pits left | TRUE | probe: 180 cells raised |
| 49 | `fill = TRUE` / FillDepressions panic on an `Arc::try_unwrap` race in 2.4.0, whatever the thread count | TRUE | findings.md:193-200: observed, plus a source reading |
| 50 | pointer_next: codes to cell numbers, row 1 on top; invalid/off-grid → self | TRUE | code + test |
| 51 | lookup position = log2(code)+1 for the 8 valid codes | TRUE | `match` |
| 52 | drainage_level: 3x3 min ground + deepest depth in the window | TRUE | code |
| 53 | the lowest neighbour stops a bank-drawn line or integer rounding being carried upstream | TRUE | as #12 |
| 54 | price: low bias of the neighbour's drop below the stream cell | TRUE | as #13 |
| 55 | ground is the original DEM | TRUE | `focal(dem, ...)` |
| 56 | a conditioned level moved bundled ff4 from −50% to −75% with the algorithm alone | TRUE | lcfill cond ff4 −50.1%; breach cond ff4 −74.9% |
| 57 | path_max: max over the downstream path, cell included | TRUE | code; round 1 brute force |
| 58 | pointer jumping: after k steps, the max over 2^k cells; about log2(longest path) iterations | TRUE | code |
| 59 | NA never wins; an all-NA path stays NA | TRUE | −Inf sentinel |
| 60 | `from` = the cell that supplied the max | TRUE | round 1 brute force |
| 61 | a breached, filled DEM has no cycles; the cap prevents a hang | TRUE | strict-descent D8; probe shows some fill |

### R/fl_valley_confine.R

| # | claim | verdict | reason |
|---|---|---|---|
| 62 | @param: pooled = one IDW over every stream cell | TRUE | |
| 63 | @param: drainage = highest level met along the downstream path; needs WhiteboxTools | TRUE | |
| 64 | passed to fl_flood_depth() as `method` | TRUE | code |
| 65 | step 4: flood mask with the waterline carried by `flood_method` | TRUE | code |

### tests/testthat/setup.R

| # | claim | verdict | reason |
|---|---|---|---|
| 66 | drainage needs WhiteboxTools | TRUE | |
| 67 | call inside each test_that(); a skip outside one does not skip the block | TRUE | testthat scoping |

### tests/testthat/test-fl_flood_depth.R

| # | claim | verdict | reason |
|---|---|---|---|
| 68 | pooled pins from main before #68, unchanged in round 2 | TRUE | the pooled branch is the old code, moved |
| 69 | river down the middle (column 40) | TRUE | 80 columns |
| 70 | **creek crosses the floor "to meet it"** | **FALSE (trivial)** | creek is columns 5:38, river column 40: it stops one cell short |
| 71 | floor rises 0.2 m/cell, flat down-valley, every cell drains straight across | TRUE | E/W 0.02 > diagonal 0.014; at(10,30) passes |
| 72 | river's 4 m waterline reaches 20 cells out | TRUE | 4 / 0.2 |
| 73 | creek waterline 0.1 m | TRUE | fixture |
| 74 | round 1 measured pooled loses 46 cells | TRUE | probe: 46 |
| 75 | without it the monotone test could pass vacuously | TRUE | rationale |
| 76 | the river alone floods both sides | TRUE | symmetric fixture; asserts > 500 |
| 77 | path cell level = 3x3 min ground + deepest depth | TRUE | |
| 78 | (10,30) ground 102 drains east; col 39 window: bed 100 + 4 → 104 | TRUE | |
| 79 | **beside the creek the lowest ground is "one cell down-valley, 0.2 m lower"** | **FALSE** | the floor is flat down-valley (line 87). In (29,20)'s window the lowest ground is column 21, one cell **toward the river** (103.8) |
| 80 | 0.2 m > 0.1 m, so (29,20) gets the river's 104 and is not flooded | TRUE | creek candidate 103.9 < 104 |
| 81 | this is the stated low bias | TRUE | |
| 82 | column 15 is 105 m and stays dry | TRUE | |
| 83 | stream cells are 0 | TRUE | |
| 84 | stream on the low side of a west-tilted plane; west ground drains away and is never flooded | TRUE | "low side" is loose: the stream is mid-plane. The rest holds |
| 85 | column 21: bed 102 + 5 = 107 vs ground 103 | TRUE | |
| 86 | 1→2→3; 4 alone; 5→1 | TRUE | |
| 87 | **"A path longer than any power of two"** | **FALSE (trivial)** | n = 1000 < 1024; the intent is "not a power of two" |
| 88 | 3x3 grid, centre 5, ESRI codes, row 1 on top | TRUE | |
| 89 | a swapped direction would still be monotone, so pin each | TRUE | |
| 90 | no outflow / NA / invalid → self | TRUE | |
| 91 | each edge step → self | TRUE | |
| 92 | multi-threaded breaching was not deterministic | TRUE | least cost |

### tests/testthat/test-fl_valley_confine.R

| # | claim | verdict | reason |
|---|---|---|---|
| 93 | pooled: dropping the Bulkley gains 12,220 valley cells | TRUE | probe: 12,220 |
| 94 | **drainage "takes, for each cell, the highest waterline among the streams on its downstream path"** | **FALSE** | the old rule that round 2 removed from both @params. The level is window-min ground + the deepest depth of any stream within one cell of a path cell |
| 95 | flow from the DEM alone, so an added watercourse can only add | TRUE | tests |
| 96 | pinned 28,727 with precip on main | TRUE | = pooled ff6 in measure_level_rule_bundled.log |
| 97 | pooled fails the monotone test on this tile | TRUE | probe: 4 of 5 lines gain |
| 98 | NA block sits on the Bulkley channel | TRUE | probe: Bulkley + Richfield cells in the block |
| 99 | defaults leave criteria slack; cost_threshold = 300 makes them bind | TRUE | as CLAUDE.md states; not re-measured |

### CLAUDE.md

| # | claim | verdict | reason |
|---|---|---|---|
| 100 | opt-in, under-floods, needs WhiteboxTools | TRUE | |
| 101 | **"exactly monotone"** | **UNSUPPORTED (scope dropped)** | the roxygen (#16, #18-19) limits it to the valley output on a DEM without NA gaps, and the flood mask fails on the added stream's own cells. The MORR 0 ha is one gap-free case |
| 102 | −25.6% MORR, −28.6% Parsnip at ff4 | TRUE | logs |
| 103 | a cell takes the level where its path joins the network | TRUE | probe (bundled) |
| 104 | **the lost cells that drain but come out dry "sit a median 5.9 m below pooled's waterline"** | **FALSE** | 5.9 m is pooled waterline − drainage waterline. The cells' ground sits a median **2.3 m** below pooled's waterline ("pooled depth on them 0.2 / 2.3 / 6.9", measure_audit.log). Written in round 2's fix |
| 105 | conditioned-DEM level swung −50% to −75% | TRUE | |
| 106 | single-threaded; multi-threaded breaching not deterministic | TRUE | least cost |
| 107 | never `fill = TRUE` or FillDepressions; `Arc::try_unwrap` panic | TRUE | code uses neither |
| 108 | the next candidate is in research | TRUE | |

### research/README.md and research/flood_surface_interpolation.md

| # | claim | verdict | reason |
|---|---|---|---|
| 109 | README row: maxima rejected (over-floods), drainage opt-in (under-floods) | TRUE | |
| 110 | header cites the round 2 archive slug | TRUE (accepted) | created at archive time |
| 111 | pooled = one IDW over every stream cell, the default | TRUE | |
| 112 | two errors that partly cancel | TRUE | round 1 archive |
| 113 | MORR 451.9 ha (1.27%); 78.6% dropped by the flood mask | TRUE | round 1 archive, re-punctuated only |
| 114 | per-blue-line max is exactly monotone | TRUE | round 1 |
| 115 | +67% to +143%; per order +52% to +101% | TRUE | round 1 |
| 116 | per-blue-line ff2 > pooled ff6 | TRUE | round 1 |
| 117 | gain belongs to tributaries (17–43 m/km) whose waterline sits above the Bulkley floor | TRUE | round 1 archive findings.md:172-179 |
| 118 | conditioning: least cost, then BreachDepressions, single thread | TRUE | code |
| 119 | each cell follows its D8 path | TRUE | |
| 120 | candidate = original 3x3 min + deepest ff x bankfull depth | TRUE | |
| 121 | waterline = highest candidate on the path | TRUE | |
| 122 | MORR row: 32,470 / 24,145 (−25.6%); gaps 6.8/5.2 vs 9.9/8.4 | TRUE | measure_morr.log |
| 123 | Parsnip row: 441,054 / 314,772 (−28.6%); 5.6/4.6 vs 13.4/13.2 | TRUE | measure_level_rule_parsnip.log |
| 124 | bundled row: 23,192 / 11,096 (−52.2%; 43% of the loss drains off the tile); 25/24 vs 60/37 | TRUE | measure_audit.log 43.2% unowned; no interior fixed points (round 2) |
| 125 | MORR adding every FWA stream loses 0 ha (pooled 451.9) | TRUE | measure_morr.log |
| 126 | exact for every blue line on the bundled tile | TRUE | tests |
| 127 | under-floods by about a quarter | TRUE | |
| 128 | **Parsnip: 98.4% of lost cells "do drain to a stream"** | **UNSUPPORTED (label)** | 98.4% is the audit's `owned` (path within one cell of a stream), a superset of "drains to" (#22) |
| 129 | 94.7% come out dry under their own waterline | TRUE | |
| 130 | dry ones: waterline a median 5.9 m below pooled's | TRUE | |
| 131 | source a median 590 m away vs 156 m to the nearest stream | TRUE | |
| 132 | a cell takes the level where its path joins, not the reach beside it | TRUE | probe (bundled). Parsnip's own 590/156 alone does not show it |
| 133 | verdict: passes monotonicity and ff ordering, fails bounded change; default stays pooled | TRUE | |
| 134 | the two rejected candidates bracket pooled from opposite sides | TRUE | +67..143% vs −25..−29% |
| 135 | **"for one reason. Neither has a rule for which point along a watercourse sets a cell's level"** | **FALSE (max-of-IDW half)** | round 1 archive findings.md:176: with each group's **nearest-cell** level instead of IDW, **72% of the gain stays wet**. So max-of-IDW's over-flood is mostly not about which point. The branch deleted that "72% survives" sentence from this file |
| 136 | **"max-of-IDW takes a tributary's level from its steep upper reach"** | **FALSE** | same evidence: the nearest-cell level, not the upper reach, already floods 72% of it |
| 137 | drainage takes it from the downstream junction | TRUE | probe (bundled) |
| 138 | conditioned level −50% to −75% | TRUE | |
| 139 | raw −7.4% on Parsnip | TRUE | |
| 140 | plan review: p90 downstream excess 7 m on Parsnip | TRUE | review-1.md: 7.1 / 7.0 m |
| 141 | multi-threaded least cost and FillDepressions: 36,000–60,000 of 518,400 differ | TRUE | findings.md:118-123 |
| 142 | their fill branch panics ("Error unwrapping 'output'") | TRUE | findings.md:195 |
| 143 | lineage: Nagel silent on combining; the VCA pools into griddata; the blend is the port's | TRUE | pre-existing, moved |
| 144 | do not re-try per-watercourse max: over-floods | TRUE | |
| 145 | do not re-try drainage with the join level: under-floods by about a quarter | TRUE | |
| 146 | do not re-try a conditioned-DEM level | TRUE | |
| 147 | next candidate (drained-to watercourses, nearest-point level, max) is still monotone | TRUE | by construction: adding a watercourse adds a term to the max. See #135-136: round 1's 72% says the drainage restriction, not the nearest point, is what would have to stop over-flooding |

**Count: 147 claims.**
- 136 TRUE
- 8 FALSE: #22, #31, #41/#43 (one finding), #70, #79, #87, #94, #104, #135/#136 (one finding)
- 3 UNSUPPORTED: #27/#128 (one finding), #101

No code bug found.
- `fl_path_max` and `fl_pointer_next` were re-confirmed by the probes above.
- `fl_stream_rasterize(fun = "max")` keeps shared stream cells monotone.
- `fl_drainage_level`'s unused `route` argument is not a defect.

## Findings

- **[bug] R/fl_flood_depth.R:133-134**: the comment above the call says the candidate level is "its conditioned elevation plus the deepest flood depth…". `fl_drainage_level()` uses the 3x3 **minimum of the original DEM**, and `route$z` is unused. "cond" is the rule Phase 4b rejected (−75% of pooled). This comment describes the rejected rule directly above the code that replaced it.
- **[bug] CLAUDE.md:126-127** (written in round 2's fix): "the lost cells that drain to a stream but come out dry sit a median 5.9 m below pooled's waterline" is wrong. 5.9 m is the gap between the two waterlines (pooled minus drainage). The cells themselves sit a median **2.3 m** below pooled's waterline (measure_audit.log, "pooled depth on them: 0.2 / 2.3 / 6.9"). Say "their drainage waterline sits a median 5.9 m below pooled's", as the research file does.
- **[bug] research/flood_surface_interpolation.md:51-53**: "bracket pooled … for one reason. Neither has a rule for which point along a watercourse sets a cell's level: max-of-IDW takes a tributary's level from its steep upper reach". This contradicts round 1's own measurement (archive `2026-10-issue-68-flood-surface-blend/findings.md:176`): with each group's **nearest-cell** level instead of IDW, 72% of the gain stays wet. So max-of-IDW over-floods mostly through *which watercourse* may flood the mainstem floor, not *which point along it*. This branch deleted the sentence carrying the 72% from the same file. The "next candidate" rationale leans on this claim, so state the 72% and rescope the bracket to the drainage half.
- **[bug] R/fl_flood_depth.R:71** (also the test title at tests/testthat/test-fl_flood_depth.R:158): "A cell whose path meets no stream gets no waterline". Read against the sentence before it ("passes through the tributary or within one cell of it"), "meets" means enters, and that is false. Probe at HEAD, bundled ff4: 286 of 10,432 wet non-stream cells have a path that never enters a stream cell and are flooded through the 3x3 window. Write "passes within one cell of no stream".
- **[fragile] tests/testthat/test-fl_valley_confine.R:435-437**: "Drainage ownership takes, for each cell, the highest waterline among the streams on its downstream path". This is the old-rule wording round 2 removed from both `@param`s, still standing here. The level is the window-minimum ground plus the deepest depth of any stream within one cell of a path cell.
- **[fragile] tests/testthat/test-fl_flood_depth.R:148**: "the window's lowest ground is one cell down-valley, 0.2 m lower". The fixture is flat down-valley (line 87). In (29,20)'s window the lowest ground is column 21, one cell **toward the river** (103.8 m vs 104). The assertion is right; its explanation names the wrong direction.
- **[fragile] R/fl_flood_depth.R:193-195** (written in round 2's fix): "Multi-threaded breaching and filling are not deterministic … (each tool alone: 36,047 to 59,638 elevations)". findings.md:118-123 measured `BreachDepressions`, the route's own second pass, and `D8Pointer` at **0** differing cells multi-threaded. The range covers only least-cost breaching (± fill) and FillDepressions. Scope it to those tools.
- **[fragile] CLAUDE.md:124**: "It is exactly monotone" is unscoped. The roxygen limits monotonicity to `fl_valley_confine()` on a DEM without NA gaps, and the flood mask is not monotone on an added stream's own cells. MORR's 0 ha is one gap-free measurement.
- **[fragile] research/flood_surface_interpolation.md:43** ("98.4% of the lost cells *do* drain to a stream"), **R/fl_flood_depth.R:77** ("ground that does drain to a stream") and **CLAUDE.md:126** ("lost cells that drain to a stream"): the measured category is measure_audit.R's `owned`, meaning the path passes within one cell of a stream. That is a superset of draining to one (see the 286-cell probe). The numbers are right; the label is the concept's. "Whose path reaches a stream (within one cell)" would match.
- **[fragile] tests/testthat/test-fl_flood_depth.R:86-87** (trivial): the creek crosses the floor "to meet it", but it is columns 5:38 against the river at 40, so it stops one cell short. No assertion depends on it.
- **[fragile] tests/testthat/test-fl_flood_depth.R:196** (trivial): "A path longer than any power of two". n = 1000 is shorter than 1024; the intent is "a path whose length is not a power of two".
