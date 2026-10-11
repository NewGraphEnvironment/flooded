# Task: fl_valley_attribute() per-group cost grew 5x from MORR to BULK at the same crop size (#72)

The per-blue-line cost of `fl_valley_attribute()` grew about **5x** from MORR to BULK, but each
group's crop barely changed. So something other than crop size sets the per-group cost, and the
attribution model used to budget a region run does not transfer between watershed groups.

Measured in NewGraphEnvironment/floodplains#104 (order >= 2 network, `co_ff04`, 12 threads, by
`blue_line_key`). Evidence: floodplains `scripts/floodplain_lcc/logs/20261010_floodplain_probe-subset_{morr,bulk}.md`
and the arms' `timing.json`.

| | MORR | BULK |
|---|---|---|
| grid | 18.1 M cells | 38.3 M cells |
| blue lines (order >= 2) | 1,711 | 2,550 |
| attribution, order >= 2 | 33.0 min | 170.0 min |
| fit, seconds per blue line | 0.66 (five arms) | ~3.5 (arms 5 and 2) |
| summed crops, estimated | 69 M cells (~42 k per group) | 109 M cells (~46 k per group) |

The crop sums are estimates: each attributed polygon's bounding box plus the 2 km `crop_margin`,
standing in for the stream bounding box `fl_group_cells()` actually crops to. The fixed cost is
#71 and is separate from this.

So BULK's grid is 2.1x and its blue lines 1.5x, mean crop per group is about the same, and the cost
per blue line is about 5x. Attribution is now what decides whether a region run fits its 60 min
per-scenario bound: on BULK the order >= 2 floodplain takes 213 min per scenario, 170 of them here.

## Planning probes (context)

> **Superseded.** These probes ran about 5x slower than later runs of the same configuration
> (cause not established; see findings.md). The later runs show BULK and MORR within 20% per
> group, not 6.5x, and no 130 s gap.

The issue fitted a per-blue-line attribution cost of 0.66 s (MORR) against 3.5 s (BULK) from
**flooded 0.6.0** timings. Those runs still carried the #71 full-grid fallback, so the fit mixes the
two costs. Probes during planning (read-only, current main = 0.6.4, #71 in, 12 threads, BULK
coho arm = floodplains' cached `streams_co3`, 428 blue lines, `arm5_floodplain.tif`):

| | BULK coho, 0.6.0 | BULK coho, 0.6.4 |
|---|---|---|
| attribution, `complete = TRUE` | 2,842 s | **323.7 s** |
| `complete = FALSE` | — | 277.2 s (0.65 s/group; MORR coho is 0.10 s/group) |

- The premise survives: per group, BULK is still about 6.5x MORR with #71 in.
- The magnitude for order >= 2 is probably smaller than the 170 min in the issue, since most of the
  0.6.0 BULK time was the fallback. It needs re-measuring.
- Summed `fl_group_cells()` time is 108 s. The Bulkley mainstem alone takes **18.1 s** on a
  12.1 M-cell bounding-box crop (a third of the grid). Small groups (crop < 200 k cells, 413 of 428)
  average 0.19 s, which is about 5 s per M crop cell against 1.5 s per M on the mainstem. So there
  is a per-group overhead that does not scale with the crop.
- `fl_cells_poly()` sums to 37 s: 13.5 s `as.polygons`, 12.9 s `st_make_valid`.
- **About 130 s of the 277 s is in neither** and is unexplained so far.
- The fallback is 46 s on BULK against 2.6 s on MORR, for 3,698 cells. It runs once over the full
  grid (`fl_stream_rasterize` onto 38 M cells plus `values()`). That is secondary.
- Budget: the 60 min per-scenario bound minus BULK's DEM (37.2 min) and delineation (5.9 min)
  leaves about **17 min** for order >= 2 attribution.

The database is reachable, so floodplains' `fp_wf_read_network()` + `fp_wf_keep(arm = 2)` can rebuild
the order >= 2 networks: BULK 31,631 segments / 2,550 blue lines, MORR 20,812 / 1,711.

## Phase 1: Profile harness and baseline
- [x] Extract the arm 2 (order >= 2) networks for BULK and MORR once from the DB, using floodplains'
      own `fp_wf_read_network()` / `fp_wf_keep()`. Write them to
      `floodplains/data/<area>/probe_whole_fwa/arm2_streams.gpkg` (gitignored). Assert the segment
      and blue-line counts above.
- [x] `planning/active/bench_attribution.R`, modelled on #71's `bench_fallback.R`, with three modes (as built: `e2e` covers e2e + cells, with section checkpoints; `rprof`; `steps` is the per-step replica):
      - `e2e`: total time plus per-group cell counts (CSV) for a two-tree comparison.
      - `cells`: per-group cell indices (rds), for the per-cell membership check.
      - `profile`: a timed replica of each `fl_group_cells()` step (crop slope, crop valleys,
        rasterize, `terra::distance`, `costDist`, masks, `values`, `cellFromXY`) and of
        `fl_cells_poly()`, recorded per group against crop cells, plus the loop's own share. The
        replica asserts the real `fl_group_cells()` cells for each group it times.
- [x] (Replaced, per plan review G1/G4: section checkpoints inside one timed call on every input, CPU time and load recorded; `steps` mode kept in the harness.) Profile BULK arm 2: the 50 largest groups by crop plus a random 100 of the rest. Add an
      `Rprof` pass over 200 small groups, to name the fixed per-group overhead and the 130 s gap.
- [x] Baseline `e2e` and `cells` at main on BULK arm 2, MORR arm 2, MORR coho and the bundled tile.
- [x] Record findings. Edit the issue body if the premise or the magnitude has changed.

## Phase 2: Remove per-group overhead the profile names (no interface change)
- [x] (As built: the profile named no full-grid or fixed-cost step repeated per group. The one
      step worth changing was `do.call(rbind, parts)`, once per call, now pairwise.) Fix each full-grid or fixed-cost operation repeated per group that the profile names, one
      commit each with its measured saving. Candidates to test first: cropping the in-memory
      full-grid `slope`/`valleys` per group (pre-index or file-back once), per-call
      CRS checks and `sf` subsetting in the loop, and terra's per-op overhead at 12 threads on tiny
      crops.
- [x] Tests: everything in `test-fl_valley_attribute.R` stays green. (As built: an every-group uncropped full-grid oracle with an interior-crop non-vacuity check, which needs no snapshot, plus a pairwise-rbind identity test.) Add a test that pins per-group
      membership to a pre-change snapshot on the bundled tile, taken at both the package defaults
      and a binding `cost_threshold = 300` (see the test-data traps).

## Phase 3: Groups in parallel (only if Phase 2 leaves BULK order >= 2 over ~17 min)
- [-] NOT NEEDED (gate not reached: BULK order >= 2 is 4.0 min against ~17 min). New argument `workers = 1L` (decided at the plan gate: 1 is today's serial path; callers opt in). Use PSOCK workers via base `parallel`, never forks
      (macOS + GDAL). Write `slope` and `valleys` to FLT8S tempfiles once and have workers open them
      by path; FLT8S keeps slope bit-identical, where FLT4S would change membership. Assemble
      results in group order, so output is identical to serial. Clean up workers and tempfiles
      with `on.exit`.
- [-] Not needed. Tests: parallel output equals serial for every group on the bundled tile, and invalid
      `workers` is rejected.

## Phase 4: Measure and verify
- [x] Re-run `e2e` and `cells` at the branch on BULK arm 2, MORR arm 2, MORR coho and the bundled
      tile. Require identical per-group, per-cell membership, or measure any difference and state it.
- [x] Measure BULK order >= 2 attribution, with #71 in, against the 60 min per-scenario bound
      (DEM and delineation included).
- [x] (As built: e2e jsons, section CSVs, figures.csv and the rbind identity log are committed; the
      slow planning/Rprof runs were not kept, and `steps` never ran on a quiet machine.) Profile and bench logs committed next to the bench script in `planning/active/`.

## Phase 5: Docs
- [x] Revise the Performance section of `fl_valley_attribute()` with the measured BULK and MORR
      figures, and `devtools::document()`.
- [x] CLAUDE.md design note: point at the new bench harness, as #71's line does.
- [x] (As built: the numbers behind this decision are the clean ones in findings.md "Out of scope",
      not the contended 37 of 277 s below; parallel was not built.) Out of scope unless the profile reverses it: the buffer-shaped crop (#44 option 1) and a
      cell-table output. Polygonizing is 37 of 277 s, and the mainstem's 18 s is far below the
      budget once groups run in parallel. Record the decision and the numbers behind it in
      findings, and in the issue body.

## Validation
- [x] Tests pass (`devtools::test()`), lintr clean
- [x] `/code-check` clean (once over the branch with `/code-check branch`)
- [x] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion

## Verification (how)

The `e2e`/`cells` comparison between main and the branch on four inputs (bundled tile, MORR coho,
MORR arm 2, BULK arm 2) is the membership check. The BULK arm 2 `e2e` time against the 17 min
attribution budget is the acceptance number. Bench runs are sequential, on one host, with nothing
else running in R. #71's first "before" run was spoiled by a concurrent probe.
