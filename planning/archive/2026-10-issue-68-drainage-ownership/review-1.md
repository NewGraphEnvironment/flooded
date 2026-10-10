# Plan review 1 (Plan agent, 2026-10-09)

Received as reply text (Plan agents cannot write); saved verbatim.

# Review: #68 round 2 plan (drainage-based flood ownership)

Note on what I reviewed: the working tree has moved past the plan. Phase 1 is done (ed5622a), Phase 2 tests are written (87a83ed), and there are uncommitted Phase 3 edits in `R/fl_flood_depth.R`, `R/fl_flood_model.R` and `R/fl_valley_confine.R`. I reviewed the plan, the findings, and that live code. The numbers below that are not in findings.md come from read-only, in-memory `Rscript -e` runs against the bundled tile and `inst/vignette-data/pars_*`. Nothing was written to disk.

## Bottom line

- **Monotonicity:** the rule is exactly monotone through `fl_flood_depth()`. Through `fl_valley_confine()` it is monotone only while the pre-cleanup stack has a fixed NA pattern. That holds on the bundled tile but not in general.
- **Over-flooding:** the bigger problem is a new route to it. A max over the whole downstream path selects the upper tail of the bed-elevation noise and misregistration of the stream lines.
  - On Parsnip the effect is several metres, and it is largest on the high-order mainstems.
  - On the bundled tile it is about 2 m at p90, which is 2.5x the ff2 flood depth.
  - That predicts a compressed `flood_factor` response, which is round 1's symptom by a different route.
  - The Phase 4 audit as written would not detect it: the owner's bed *is* the outlier, so "height above owner's bed" looks normal.
- **Fix that keeps monotonicity:** take the bed from the conditioned DEM along the path (the HAND convention). Details under B1.
- **Process:** the Phase 1 gate failed (79.1% < 90%) and was waived in findings.md:104 with no record that you were asked. The plan said "stop and report".

---

## Blockers

**B1. The max over the full downstream path spreads bed-noise outliers upstream with no limit**

W(x) = max over the path of L(c), where L = raw-DEM bed + ff·d. Along a channel the raw bed is noisy: integer-metre DEMs, MRDEM-30 water surfaces, FWA lines that sit on banks or terraces, bridge decks and road fills on lidar. One high bed value anywhere downstream raises W for its whole upstream drainage, down to that level. Pooled IDW used the same noisy values but averaged them locally; the max picks the top of the noise distribution.

I measured this as a lower bound. For each vertex of each blue line, ordered from the mouth upward (bed rises with that order: median ρ = 0.96–0.97), I computed the "downstream excess": the max over downstream vertices on the same blue line of (DEM + ff·d), minus the vertex's own value. This uses only the same line and ignores the mainstem below the confluence, so on a whole watershed the excess is larger.

| | ff·d (median) | excess p90 | share > 3 m | share > 10 m | share where excess > own ff·d |
|---|---|---|---|---|---|
| Bundled tile, ff6 | 1.77 m (Bulkley 2.49) | 2 m (max 5) | 0.6% | 0 | Bulkley 8.8% |
| Bundled tile, ff2 | ~0.6–0.8 m | ~2 m | — | — | **Bulkley 73%** |
| Parsnip, ff6 | 1.34 m | **7.1 m** | 25.8% | 6.2% (max 34 m) | 37% |
| Parsnip, ff2 | 0.45 m | 7.0 m | 25.8% | 6.2% | **47.5%** |

- On Parsnip the excess rises with stream order. The share of vertices above 3 m is 12% at order 3, 28% at order 4, 51% at order 5 and **65% at order ≥6**, so it hits the mainstem floodplain hardest.
- With waterbody vertices excluded it is still 18.6% above 3 m.
- The excess barely changes between ff2 and ff6, so it is noise in the bed, not growth in depth.

Consequences:
- Extent inflates most at low ff, so the gaps between ff2, ff4 and ff6 shrink. The ordering test still passes, because ordering holds by construction.
- The "bounded change" criterion is at risk on Parsnip and MORR.

**Proposed fix, monotone and HAND-consistent.** Change the candidate level to

  L'(c) = Z_cond(c) + D(c), where D = 3×3 focal max of (`flood_surface − dem`), i.e. ff·d at stream cells.

- Z_cond is the breached and filled DEM that `fl_flow_next()` already produces. It currently throws it away.
- Z_cond is non-increasing along a D8 path on a depressionless DEM, so W(x) − Z_cond(first hit) ≤ the max of D downstream.
- Backwater then comes only from real growth of ff·d at confluences, not from bed noise. It also removes FWA misregistration, because the bed becomes the path's thalweg cell, not the line's cell on the bank.
- It stays monotone: Z_cond does not depend on the streams, and D only grows as streams are added (rasterize uses `fun = "max"` for area and precip).
- No API change: `flood_surface − dem` recovers ff·d inside `fl_flood_depth()`.
- This is the standard HAND convention (Rennó / Nobre): the drainage cell's elevation is taken from the conditioned DEM.

I recommend measuring raw-bed versus conditioned-bed *before* Phase 3 tests get pinned to raw-bed semantics. `test-fl_flood_depth.R`'s `at(29, 20) == 0.3` encodes the raw-bed window max.

**B2. The Phase 1 gate failed and was waived, and the reason given for waiving it is untested**

- Plan line 57: "Gate: ≥ 90%, or stop and report". Measured: 79.1%. findings.md:104: "Decision: proceed".
- The rationale: "on a watershed-clipped DEM every path reaches the outlet through the network." Reaching the outlet is not the same as getting the right waterline. The 5,991 missed cells are swales and side drainage running parallel to the river, a median 582 m from a stream.
  - On a whole watershed they meet the river kilometres downstream.
  - With conditioned beds (B1) they get the river's level *at that junction*: lower by gradient × distance, so likely dry.
  - With raw beds they may be "rescued" by the noise in B1, which is the wrong reason.
- Lateral overbank flooding of back-swamps is a real limit of draining-based ownership, not a tile-edge artifact.
- `inst/vignette-data/pars_dem.tif` is watershed-clipped (20.9M cells, 10.18M NA). The reach share and the along-path distance to the first stream hit can be measured there now, without MORR. Do that, report to you, and get an explicit decision on the gate.

---

## Gaps

**G1. "Exactly monotone" holds for the flood mask but is overstated for the full pipeline.** Step by step:
- **Slope:** does not depend on streams.
- **Distance mask:** grows as streams are added.
- **Cost mask:** `fl_cost_distance.R:269` makes stream cells zero-cost seeds, so cost only falls as streams are added.
- **Flood mask:** monotone given the stream-independent D8 and rasterize `fun = "max"` (`fl_stream_rasterize.R:187`).
- **AND, closing:** max and min are monotone operators.
- **Hole fill:** monotone (a hole in B is a subset of the hole in A).
- **Patch removal:** monotone (patches only grow or merge).
- **Majority filter:** monotone provided ties break deterministically. I probed terra 1.9.50: edge ties are deterministic, 20 of 20 runs identical.
- **Binarize, DEM mask, channel buffer (OR):** monotone.

Two exceptions, both needing NA in the pre-cleanup stack:
- (a) `costDist` returns NA for regions cut off by NA friction. A stream bridging or entering such a region changes NA to 0 or 1. The closing's `focal(min, na.rm = TRUE)` at `fl_valley_confine.R:247` and the modal at :267 ignore NA, so a neighbour going from NA to 0 can erode a 1.
- (b) `fl_patch_rm()` turns NA into 0 only when *some* patch anywhere is small (`fl_patch_rm.R:400,405`, #65). That is a global switch that depends on the streams, and it then changes the majority vote next to the NA.

The bundled tile has no NA after the closing (only the slope ring, which focal fills), so the Phase 2 test cannot see either exception. MORR and Parsnip are watershed-clipped. In practice the #65 switch is probably on in both arms there, but say so.
- Scope the claim in roxygen and NEWS to: "the flood mask is monotone; the delineation is monotone on DEMs without NA gaps (#65)."
- Measure MORR arm 1 vs arm 5 loss at both the pre-cleanup flood mask and the final output, so any residual can be attributed.

**G2. NA DEM / lidar water gaps.**
- Whitebox breaching treats cells next to nodata as outlets. With NA over a river (lidar water returns; `na_block_fixture()` puts its 31×31 block on the Bulkley channel), floor-cell paths end at the gap edge. The river's stream cells there have NA surface, so the floor is unowned and dry.
- `test-fl_flood_depth.R` "drainage keeps NA DEM cells NA" is vacuous. The gap is NA because `surface − dem` is NA, whatever whitebox does with nodata. A wrong NA flag that whitebox read as a deep sink would still pass.
- Add:
  - a drainage run on `na_block_fixture()`, counting valid-DEM cells lost around the block against pooled;
  - the #63 assertion `expect_false(anyNA(v[-f$block]))` under `flood_method = "drainage"`;
  - an assertion that cells two or more cells outside the synthetic gap keep the same depth as without the gap.

**G3. NA flag round trip is unconfirmed for the implementation's write settings.** The probe confirmed "NA → NA pointer, neighbours don't point in" on rasters written with terra's default datatype. `fl_flood_depth.R:184` writes `FLT8S` with the default NA flag (likely NaN). Set an explicit `NAflag = -32768` (or similar) and assert `length(code) == ncell(dem)` after reading back.

**G4. The ESRI code mapping has no committed test, and a wrong mapping still produces monotone output.**
- The table at :197–200 matches WhiteboxTools' ESRI convention (1 E, 2 SE, 4 S, 8 SW, 16 W, 32 NW, 64 N, 128 NE, with row increasing southward).
- The current fixtures only exercise E/W: the creek floor is flat down-valley and the plane is tilted in columns. A N/S or diagonal swap would pass every test, including monotonicity and ff ordering.
- Split out a pure `fl_pointer_next(code, nr, nc)` and test all 8 codes plus 0, NA and the four edges. This needs no whitebox.
- Add a whitebox-guarded invariant: Z_cond[nxt] ≤ Z_cond for every cell on the bundled tile.

**G5. The audit cannot be produced from the current code.**
- `fl_path_max()` returns only the max, not which cell supplied it. Phase 4's "owner" needs the argmax: carry an index vector through the pointer jumping and take `arg[nxt]` where `m[nxt] > m`.
- The audit as specified (owner, depth, height above owner's bed) misses B1. Add for each gained or lost cell:
  - W − L_first, the level at the first stream window met, i.e. the carried excess;
  - distance along the path to the owner;
  - whether the owner's blue line or order differs from the Euclidean-nearest stream's;
  - owner bed minus Z_cond at the owner, the outlier indicator;
  - owner on a waterbody segment (`waterbody_key`): Morice Lake on MORR, and possibly Williston on Parsnip. Here a lake's level plus ff·d goes up every tributary mouth.
- Decompose lost cells into: unowned (path ends off-grid or at an NA edge), owned but lower, and removed by cleanup.

**G6. The monotone test runs with slack defaults.** CLAUDE.md says the defaults are not binding on this tile. Add a squeezed variant (`cost_threshold = 300`, precip on) so the masks that depend on the streams actually bind during the blue-line loop.

---

## Ordering

- **O1.** Do the B1 conditioned-bed comparison and the B2 Parsnip reach and distance measurement *before* finishing Phase 3 and pinning Phase 2 values. Both use data already in the repo.
- **O2.** The gate decision needs your sign-off (B2). Record it in findings.md as yours, not the agent's.
- **O3.** Pre-register numeric acceptance thresholds before Phase 4 runs (see A1). Otherwise the Phase 5 verdict is a judgement made after seeing the numbers.

## Assumptions

- **As1.** `breach_dist = 50L` is in **cells**: 500 m at 10 m, 1.5 km at 30 m, 50 m at 1 m lidar. It was tuned for best reach on the bundled tile, the tile it is measured on.
  - dist = 200 gave 11,627 code-0 cells even with `fill = TRUE`, which is anomalous and suggests a sensitive parameter.
  - Express it in map units or document the per-resolution meaning, and confirm 50 is not on a cliff on Parsnip.
- **As2.** "Error 2 cannot recur" is mostly right: floor cells don't drain through a tributary's steep upper reach. But with raw beds, a path running diagonally next to a misregistered tributary line on a fan picks up that line's bank-elevation bed. B1 removes this.
- **As3.** Backwater magnitude: with conditioned beds it is bounded by the growth in ff·d. Rough figures: about 3.2 m for the Bulkley at ff6 and about 3.6 m for the Parsnip mouth. That is physically defensible, but Phase 4 should report it separately.

## Scope and code notes (live working tree)

- `R/fl_valley_confine.R:145`: `flood_method` is inserted *between* `flood_factor` and `precip`, which breaks positional calls. Move it to the end, before the deprecated `field`.
- `R/fl_flood_depth.R:73`: a malformed roxygen line, `#'#' # Drainage ownership…`.
- `fl_flow_next()` reruns whitebox on every call. floodplains runs 6 scenarios (ch/co × ff02/04/06) on one DEM, and the monotone test runs 6 times.
  - Consider an internal cache, or an optional precomputed `flow` / pointer argument. That would also allow testing without whitebox and other backends.
- Memory: `fl_flow_next()` holds about 10 vectors the length of the grid (Parsnip 20.9M cells → about 1.7 GB), on top of `values()`. Note this in the MORR and #67 timing.

## Acceptance

- **A1.** The issue's criteria have no numbers.
  - Define "bounded" before measuring, for example net |Δ| ≤ 10% and gross gain+loss ≤ 20% of pooled, on each site.
  - Define "gaps of the same order", for example each ff gap within 0.5–2× pooled's.
  - Parsnip's pooled ff06–ff04 gap is already only 4.6%, so a ratio threshold is needed.
- **A2.** Phase 4 measures ff2/4/6 only on the bundled tile. Run ff2/4/6 on MORR and Parsnip too: B1 predicts compression to be worst at 30 m.
- **A3.** On the bundled tile, "bounded change" is confounded by the 21% of valley cells that drain off the tile. Report the change both including and excluding unowned cells.
- **A4.** MORR arm 1 vs arm 5: expect 0 ha at the flood-mask level. A non-zero final loss needs the G1 attribution.

### Critical Files for Implementation
- /Users/airvine/Projects/repo/flooded/R/fl_flood_depth.R
- /Users/airvine/Projects/repo/flooded/R/fl_valley_confine.R
- /Users/airvine/Projects/repo/flooded/R/fl_patch_rm.R
- /Users/airvine/Projects/repo/flooded/tests/testthat/test-fl_flood_depth.R
- /Users/airvine/Projects/repo/flooded/tests/testthat/test-fl_valley_confine.R
- /Users/airvine/Projects/repo/flooded/planning/active/task_plan.md
- /Users/airvine/Projects/repo/flooded/planning/active/findings.md