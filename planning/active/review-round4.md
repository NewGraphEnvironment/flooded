# Review round 4 (closing check): branch 68, HEAD = 5068901

Scope: every sentence added or changed by `git show HEAD` in R/, tests/, CLAUDE.md, research/ and
planning/active/findings.md; the resolution of round 3's 11 findings; the issue body's "Round 2" and
"Next candidate" sections.

Evidence used: R/fl_flood_depth.R at HEAD, planning/active/measure_audit.R + measure_audit.log,
measure_morr.log, measure_level_rule_*.log, findings.md:110-125 (determinism table), round 1 archive
`planning/archive/2026-10-issue-68-flood-surface-blend/findings.md:156-188`.

One probe, in a `git archive HEAD` copy in the scratchpad (pkgload, NOT_CRAN=true, one process,
WhiteboxTools at 1 thread via `fl_flow_route()`): the west-tilted plane of the test
"a cell whose path never nears a stream gets no waterline", row 10, flood depth by column:

```
col 15-18  NA
col 19     4.9   (next cell: col 18, i.e. it drains west, away from the stream)
col 20     0     (stream)
col 21     4.9
col 22     4.8
```

## 1. Sentences added or changed in HEAD

| # | where | claim | verdict | reason |
|---|---|---|---|---|
| 1 | R/fl_flood_depth.R:71-72 | a cell whose path never comes within one cell of a stream gets no waterline and is not flooded | TRUE | `depth_near` is a 3x3 focal max of `flood_surface - dem`, NA unless a stream cell is in the window; probe cols 15-18 NA |
| 2 | R:72-74 | includes ground draining off the edge and ground whose path runs into an NA gap | TRUE | re-flowed only (round 3 #23-24) |
| 3 | R:78-79 | **"Almost all of the lost cells (94.7%) have a path that passes within one cell of a stream"** | **FALSE (relabelled measurement)** | measure_audit.log, Parsnip: owned (path within one cell) = 100 − 1.6 = **98.4%**; 94.7% is "owned **but dry**". This is the exact relabel round 1 caught (findings.md:277: "caught 94.7% labelled as the share that drains") |
| 4 | R:79-80 | their waterline comes out a median 5.9 m below pooled | TRUE | owned-but-dry, pooled − drainage p50 5.9 |
| 5 | R:80-81 | a cell takes the level of the reach its flow path joins, not of the reach beside it | TRUE | round 3 probe (bundled, p90 0.062 m over the join point); Parsnip 590 vs 156 m consistent |
| 6 | R:135-136 | candidate from `fl_drainage_level()`; waterline = highest candidate on the downstream path | TRUE | L138 |
| 7 | R:194-196 | two identical calls of the original route differed in 60,541 and 69,960 of 518,400 | TRUE | findings.md:115-116 |
| 8 | R:196-197 | least-cost breaching and depression filling alone changed 36,047 to 59,638 elevations | TRUE | findings.md table: 59,638 / 49,570 / 36,047 |
| 9 | R:197-198 | BreachDepressions and D8Pointer changed none | TRUE | same table: 0 / 0 |
| 10 | R:194 | "Multi-threaded breaching and filling are not deterministic" | TRUE as qualified | the next sentence restores the per-tool scope (#8-9) |
| 11 | R:198 | a run would not be monotone against itself | TRUE | Phase 3: 4 of 5 lines failed |
| 12 | CLAUDE.md:124-125 | monotone in added streams: the flood mask off the added stream's own cells | TRUE | roxygen L60-63; MORR 0 flood-mask cells (measure_morr.log) |
| 13 | CLAUDE.md:125-126 | and the valley output on a DEM without NA gaps (MORR 0 ha lost, pooled 451.9 ha) | TRUE | matches roxygen scope; measure_morr.log; per-blue-line tests |
| 14 | CLAUDE.md:126 | −25.6% MORR, −28.6% Parsnip at ff4 | TRUE | re-flowed |
| 15 | CLAUDE.md:127-128 | lost cells that come out dry have a drainage waterline a median 5.9 m below pooled's | TRUE | owned-but-dry p50 5.9; the 1.6% unowned have no waterline, so the sentence can only cover the owned |
| 16 | findings.md:320 | the two candidates bracket pooled from opposite sides | TRUE | +67..143% vs −25..−29% |
| 17 | findings.md:321 | max-of-IDW lets any watercourse flood the ground near it, drained to it or not | TRUE | per-group IDW within max_width/2, cell max |
| 18 | findings.md:321-322 | a steep tributary's own waterline sits above the mainstem floor beside it | TRUE | archive: all gained cells won by tributaries, median depth 4.9 m |
| 19 | findings.md:322-323 | **"72% of round 1's gain survives with nearest-cell levels"** | **UNSUPPORTED (scope dropped)** | archive:170-176 measured it on the reviewer's own prototype at **ff6**, on the 21,863 gained **flood-mask** cells. "Round 1's gain" reads as the valley gain (+67..143%, ff2-ff6) of the table above it |
| 20 | findings.md:324-325 | drainage fixes which watercourse may flood a cell but takes the level where the path joins it | TRUE | as #5 |
| 21 | research:22 | **"72% of it survives with nearest-cell levels instead of IDW"** | **UNSUPPORTED (scope dropped)** | as #19; "it" follows "+67% (ff6) to +143% (ff2)" two lines up |
| 22 | research:43-44 | 98.4% of the lost cells have a path within one cell of a stream (the audit's "owned") | TRUE | 100 − 1.6 |
| 23 | research:44-45 | 94.7% come out dry under their own waterline | TRUE | "owned but dry" |
| 24 | research:45 | the rest are removed by cleanup | TRUE | the rest of the owned, 3.7% = `!unowned & !dry` (measure_audit.R:57-60). Wet and pooled-valley, and slope/distance/cost do not depend on the method, so only cleanup can drop them |
| 25 | research:46 | drainage waterline a median 5.9 m below pooled's | TRUE | |
| 26 | research:46-47 | pooled had them a median 2.3 m under water | TRUE | "pooled depth on them 0.2 / 2.3 / 6.9" |
| 27 | research:54-55 | max-of-IDW lets any watercourse flood ground near it, drained to it or not | TRUE | as #17 |
| 28 | research:55-56 | **"A steep tributary's own waterline, even its nearest cell's, sits metres above the mainstem floor beside it"** | **UNSUPPORTED (magnitude)** | "metres" was measured for the IDW surface (median 4.9 m on gained cells). For nearest-cell levels only "72% stay wet" (depth > 0) was measured, no magnitude |
| 29 | research:57-58 | drainage takes the level from the reach where the path joins, not beside the cell | TRUE | as #5 |
| 30 | test-fl_flood_depth.R:86-87 | creek crosses toward the river along row 30, stopping one cell short | TRUE | row 30, cols 5:38; river col 40 |
| 31 | test-fl_flood_depth.R:148 | window's lowest ground is one cell toward the river, 0.2 m lower | TRUE | col 21 = 103.8 vs 104; creek cells are not incised |
| 32 | test-fl_flood_depth.R:148-150 | more than the creek's 0.1 m, so (29,20) gets the river's 104 and is not flooded | TRUE | creek candidate 103.9 < 104; depth 0 |
| 33 | test-fl_flood_depth.R:158 | test title: a cell whose path never nears a stream gets no waterline | TRUE for the cell asserted | col 10's path runs west to the edge, never within one cell of col 20; probe NA |
| 34 | test-fl_flood_depth.R:196 | a 1,000-cell path, longer than nine doublings, still reaches its end | TRUE | 2^9 = 512 < 1000; needs 10 doublings, loop cap is ceiling(log2(1000)) + 2 = 12 |
| 35 | test-fl_valley_confine.R:436-438 | highest candidate level along the path (lowest ground within one cell + deepest stream depth within one cell) | TRUE | `fl_drainage_level` + `fl_path_max` |
| 36 | test-fl_valley_confine.R:438-439 | flow directions from the DEM alone, so an added watercourse can only add | TRUE | unchanged |

**Count: 36 claims. 32 TRUE, 1 FALSE (#3), 3 UNSUPPORTED (#19, #21, #28; #19/#21 are one finding).**

Drift kinds inside the fixes:
- **Relabelled measurement:** #3. The relabel fix moved the right label onto the wrong number. It
  reintroduces the error round 1 caught.
- **Dropped scope:** #19/#21. The 72% lost its ff6 and flood-mask scope when it was restored.
- **A stale rule:** #28 carries the IDW magnitude ("metres") onto the nearest-cell variant.

### Not in the diff, but beside a fix: same mechanism as round 3 #22

| # | where | claim | verdict | reason |
|---|---|---|---|---|
| 37 | test-fl_flood_depth.R:160-161 (body of the test HEAD retitled) | **"ground west of it drains away from it and is never flooded, however low"** | **FALSE** | probe: column 19 drains west (next = col 18), yet its window holds the stream, so it gets 101.8 + 5 = 106.8 against ground 101.9 and is **flooded 4.9 m**. Only from column 18 west is it dry. Round 3 rated this TRUE (#84). The assertion (col 10) is unaffected |

## 2. Round 3's 11 findings

| # | round 3 finding | status |
|---|---|---|
| 1 | R:133-134 "conditioned elevation" comment | RESOLVED: the comment now defers to `fl_drainage_level()` |
| 2 | CLAUDE.md 5.9 m "below pooled's waterline" | RESOLVED: now "a drainage waterline a median 5.9 m below pooled's" |
| 3 | research "bracket … for one reason" / "steep upper reach" | RESOLVED: the sentence is gone and the 72% is restated. The new text adds #21 and #28 |
| 4 | R:71 and test title "meets no stream" | RESOLVED for both cited lines. The retitled test's own body comment (#37) still states the defect |
| 5 | test-fl_valley_confine.R:435-437 old-rule wording | RESOLVED |
| 6 | test-fl_flood_depth.R:148 "down-valley" | RESOLVED |
| 7 | R:193-195 determinism scope | RESOLVED |
| 8 | CLAUDE.md "exactly monotone" unscoped | RESOLVED in CLAUDE.md. Still unscoped in the issue status line (I1 below) and in findings.md:318 |
| 9 | "drain to a stream" label (research:43, R:77, CLAUDE.md:126) | **NOT RESOLVED at R:78-79.** research and CLAUDE.md are fixed. R now pins 94.7% to "has a path within one cell of a stream" (#3), and that share is 98.4% |
| 10 | creek "to meet it" | RESOLVED |
| 11 | "longer than any power of two" | RESOLVED |

## 3. Issue #68 body: "Round 2" and "Next candidate" sections

| # | claim | verdict | reason |
|---|---|---|---|
| I1 | status: **"It is exactly monotone."** | **UNSUPPORTED (scope dropped)** | the same unscoped claim round 3 #101 fixed in CLAUDE.md. It is monotone for the flood mask off the added stream's own cells and for the valley on a DEM without NA gaps |
| I2 | what was built (4 bullets) | TRUE | matches code |
| I3 | monotone: MORR 0 ha / 0 flood-mask cells (pooled 451.9 ha / 13,569); exact for every blue line | TRUE | measure_morr.log; tests |
| I4 | **"gaps 1.3–2.9× pooled's"** | **FALSE (lower bound)** | for the shipped rule: MORR 9.9/6.8 = 1.46, 8.4/5.2 = 1.62; Parsnip 13.4/5.6 = 2.39, 13.2/4.6 = 2.87; bundled (rawmin) 60.4/25.1 = 2.41, 36.7/23.9 = 1.54. The range is **1.4–2.9×**. 1.3 matches only the superseded `raw` rule's bundled 31.7/23.9 = 1.33 (a stale rule). findings.md:313 carries the same 1.3 |
| I5 | MORR −27.7/−25.6/−23.4; Parsnip −33.5/−28.6/−22.7; bundled −52%, 43% of the loss off the tile edge | TRUE | logs; 43.2% unowned, no interior fixed points (round 2) |
| I6 | 98.4% within one cell; 94.7% dry under their own waterline | TRUE | |
| I7 | dry cells: drainage waterline median 5.9 m below pooled's; pooled had them median 2.3 m under water | TRUE | |
| I8 | set by a cell a median 590 m away vs 156 m to the nearest stream | TRUE | 589.9 / 155.7 |
| I9 | a valley-floor cell takes the level of the reach its path joins | TRUE | as #5 |
| I10 | round 1: any watercourse floods ground near it, drained to it or not | TRUE | |
| I11 | "a steep tributary's own waterline (72% of the gain survives with nearest-cell levels) sits metres above the mainstem floor" | UNSUPPORTED (as #19 + #28) | 72% is ff6 flood-mask cells; "metres" is the IDW magnitude, not the nearest-cell one |
| I12 | conditioned-DEM level −50% to −75% | TRUE | lcfill cond ff4 −50.1%; breach cond ff4 −74.9% |
| I13 | multi-threaded BreachDepressionsLeastCost and FillDepressions: 36,000–60,000 of 518,400 differ; fill branch panics | TRUE | findings.md:118-123, 193-200 |
| N1 | drainage decides which watercourses (those on its downstream path); proximity decides the point; waterline = max over them | TRUE as a design | unmeasured, stated as such |
| N2 | still monotone, because added streams only add candidates | TRUE by construction | `rasterize(fun = "max")` keeps shared cells' levels, and a max over a growing set only grows |
| N3 | expected effects (river's level beside it; tributary floods only ground draining through it) | TRUE as expectations | "Not measured" is stated |

Outside the two sections (not graded): the round 1 section's "each tributary's own waterline, carried
from its steeper upper reach (17–43 m/km)" is the phrasing round 3 #136 rejected in research. The next
bullet's 72% softens it there.

## 4. Code bugs

None found.
- `fl_drainage_level`, `fl_path_max` and `fl_pointer_next` behave as documented on the probe plane.
- Column 19's flooding (#37) is the documented within-one-cell rule, not a defect.

## Findings

- **[FALSE] R/fl_flood_depth.R:78-79**: "Almost all of the lost cells (94.7%) have a path that passes within one cell of a stream". The share with such a path is **98.4%**. 94.7% is the share owned **and dry** (measure_audit.log, Parsnip: unowned 1.6 / owned-but-dry 94.7 / wet-removed-by-cleanup 3.7). This reintroduces the relabel round 1 caught (findings.md:277), and it leaves round 3's finding 9 unresolved here. Suggested: "98.4% of the lost cells have a path that passes within one cell of a stream, and most of them (94.7% of all lost) come out dry: their waterline is a median 5.9 m below the pooled one".
- **[FALSE] tests/testthat/test-fl_flood_depth.R:160-161**: "ground west of it drains away from it and is never flooded, however low". Probe: column 19 drains west but is flooded 4.9 m, because its 3x3 window holds the stream. Only from column 18 west is it dry. This is round 3 #22's mechanism in the body of the test HEAD retitled; round 3 rated it TRUE (#84). Suggested: "ground more than one cell west of it drains away from it and is never flooded".
- **[UNSUPPORTED] research/flood_surface_interpolation.md:22, planning/active/findings.md:322-323, issue #68 "Why it under-floods"**: "72% of it / of round 1's gain survives with nearest-cell levels" drops the measurement's scope. Round 1 archive findings.md:170-176 measured it on the reviewer's prototype at **ff6**, on the 21,863 gained **flood-mask** cells, not on the +67..143% valley gain. Add "at ff6, of the gained flood-mask cells".
- **[UNSUPPORTED] research/flood_surface_interpolation.md:55-56** (also issue #68, same paragraph): "A steep tributary's own waterline, even its nearest cell's, sits metres above the mainstem floor". "Metres" is the IDW magnitude (median 4.9 m on gained cells). With nearest-cell levels only "stays wet" (> 0) was measured. Drop "metres" from the nearest-cell clause, or say "sits above".
- **[UNSUPPORTED] issue #68 status line**: "It is exactly monotone" is unscoped. This is round 3 #101, fixed in CLAUDE.md but not in the issue; findings.md:318 has the same wording. Scope it as CLAUDE.md now does: the flood mask off the added stream's own cells, and the valley on a DEM without NA gaps.
- **[FALSE] issue #68 Round 2 table, also planning/active/findings.md:313**: "gaps 1.3–2.9× pooled's". For the shipped rule the ratios are MORR 1.46 / 1.62, Parsnip 2.39 / 2.87 and bundled 2.41 / 1.54, so the range is **1.4–2.9×**. 1.3 matches only the superseded `raw` rule's bundled ff6/ff4 (31.7/23.9).
