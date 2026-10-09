# Review round 2: branch 68 (drainage method), diff 484c2de...HEAD plus HEAD (87bd456)

Read in full: R/fl_flood_depth.R, R/fl_flood_model.R, R/fl_valley_confine.R, tests/testthat/setup.R,
tests/testthat/test-fl_flood_depth.R, tests/testthat/test-fl_valley_confine.R, research/flood_surface_interpolation.md,
CLAUDE.md paragraph, and the logs measure_audit, measure_morr, measure_level_rule_*, measure_route_robust.

Runs were made in a `git archive HEAD` copy in the scratchpad, one R process at a time:
- `test-fl_flood_depth.R` passed, and so did `test-fl_valley_confine.R` (all drainage tests ran, whitebox present).
- Probe: `fl_flow_route()` has **0** interior self-pointing cells on the bundled tile, on `round(dem)`, and on a
  synthetic flat lake. BreachDepressions resolves flats, so no path stops on a flat. `next` is double, so
  `(r2 - 1) * nc` cannot overflow integer.
- I checked these and found nothing wrong:
  - `fl_pointer_next` (ESRI mapping, and the NA/off-grid handling, where `TRUE | NA` is TRUE).
  - `fl_path_max`: its synchronous update, the break on `identical(nxt2, nxt)`, which happens after the last
    needed merge, and the loop cap.
  - The `on.exit` env restore, and `wbt_system_call()` passing `--max_procs` from `R_WHITEBOX_MAX_PROCS`.
  - The match.arg pass-throughs.
  - Monotonicity of each `fl_valley_confine()` step (hole fill, patch removal and modal are all monotone in a
    superset of 1s).
- Round 1's fixes are correct as written: the testthat pin, the monotone scope, the low-bias wording, and 98.4%
  vs 94.7%.

Numbers checked against the logs and found correct:
- −28.6% / 29% fewer (441,054 → 314,772)
- −25.6% MORR, 0 ha vs 451.9 ha
- 590 m / 156 m
- 2.5x ff gaps (13.4/5.6, 13.2/4.6)
- bundled −52.2%, 43% unowned (= drains off the tile, since no interior fixed points)
- gaps 25/24 vs 60/37 and 6.8/5.2 vs 9.9/8.4
- −50% / −75% (lcfill cond ff4 −50.1%, breach cond ff4 −74.9%)
- raw −7.4%

No code defect found. The findings are claims of the same kind round 1 fixed, left in places it did not touch.

## Findings

- **[bug, doc claim] R/fl_flood_depth.R:66-67** (and man/fl_flood_depth.Rd): "A tributary's level never reaches
  valley floor that does not drain through it." This is false because of the 3x3 window in `fl_drainage_level()`.
  - Any path cell within one cell of a stream takes that stream's depth, even when its path runs beside the
    stream or past its end without entering it.
  - Everything upstream of that cell then inherits the level.
  - Measured on the bundled tile at ff4 with precip, drainage method: **286 of 10,432 wet non-stream cells (2.7%)**
    have a downstream path that never enters *any* stream cell. They are flooded by a stream they do not drain
    through. That count is a lower bound, because paths that enter one stream but take their level from another
    beside it are not counted.
  - Fix: scope the sentence, for example "...except through the one-cell window beside the channel", or drop it.
  - In the same paragraph (line 63), "fl_valley_confine() counts stream cells as valley" is also not true. Stream
    cells are only forced into the flood mask, and slope, cost and cleanup can still drop them. The monotone
    conclusion still holds, because every step is monotone, but its stated reason is wrong.

- **[bug, doc claim] R/fl_flood_depth.R:18-19 (`@param method`) and R/fl_valley_confine.R:47-49 (`@param flood_method`)**,
  plus both .Rd files: "gives each cell the highest flood surface among the streams on its downstream flow path"
  and "takes the highest waterline among the streams on its downstream flow path".
  - Both describe the stream's own waterline. The level is actually the window-minimum ground plus the deepest
    depth, which Details step 2 now says is biased low. It also comes from streams *beside* the path, not only
    on it.
  - Round 1 corrected this in Details but left the two argument summaries saying the opposite. Those summaries
    are what `?fl_valley_confine` readers see first.

- **[bug, wrong number scope] CLAUDE.md:126**: "a median 5.9 m below pooled's on Parsnip" is unscoped, so it reads
  as all cells.
  - The 5.9 m median is over the owned-but-dry **lost** cells only (measure_audit.log, parsnip block,
    "pooled waterline - drainage waterline (m): 1.7 / 5.9 / 23.4" under "owned-but-dry lost cells").
  - Round 1 scoped the research file to "On the dry ones" but did not update this restatement.

- **[fragile, wrong number] R/fl_flood_depth.R:191-192** (code comment): "two identical calls on the bundled tile
  gave 36,000 to 60,000 different cells".
  - findings.md:115-123 shows that two identical route calls differed in **60,541 and 69,960** cells.
  - 36,047–59,638 is the range across the individual tools, which the research file states correctly.
  - The comment attaches the per-tool range to whole calls.

Note, not a defect yet: the research header cites `planning/archive/2026-10-issue-68-drainage-ownership/measure_*.R`,
which does not exist until the archive step. `/planning-archive` must use exactly that slug, or the citation dangles.
