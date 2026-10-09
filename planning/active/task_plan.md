# Task: fl_flood_depth() pools every stream's flood level; max-per-watercourse fix over-floods, needs drainage-based ownership (#68)

`fl_flood_depth()` builds the water surface away from the streams as an inverse-distance-squared average (`terra::interpIDW(power = 2, radius = max_width / 2)`). The average runs over **every** stream cell within 1 km, whatever stream it belongs to. Each stream cell's level comes from `fl_flood_surface()`: bed elevation + `flood_factor` × bankfull depth.

So a spot between a big river and a small creek gets a weighted blend of a deep flood and a shallow one. A creek crossing a big river's valley floor pulls the river's waterline down around itself, and adding streams to a run can **remove** floodplain.

**Measured symptom (floodplains#110, MORR `co_ff04`, one common DEM):**
- Delineating from all FWA streams instead of the coho network loses **451.9 ha (1.27%)** of the coho network's floodplain. That reproduces exactly on flooded main.
- Order ≥ 2 loses 444 ha.

## Approach (approved 2026-10-09)

Round 2: build drainage-based ownership as an **opt-in** method, measure it against the issue's
acceptance, record a verdict. Default stays `pooled` unless every criterion passes.

- **Ownership rule: max over the downstream flow path, not the first stream hit.**
  - Each cell's waterline is W(x) = the maximum of L(c) over the cells c on x's downstream D8
    path, where L(c) is the highest stream flood surface (`fl_flood_surface()`: bed + ff ×
    bankfull depth) within c's 3×3 window.
  - Why not first-stream HAND: it is not monotone. An added creek intercepts a mainstem-floor
    cell's path, and that cell then gets the creek's shallow level and can go dry.
  - With the max, an added stream only adds candidates. Flow directions do not depend on the
    streams, so this is **exactly monotone** by construction.
  - It also gives backwater: the big river's level carries up a tributary's lower reach.
  - Error 2 cannot recur: a mainstem-floor cell never drains through a tributary's steep upper
    reach.
  - Depth = W − DEM, inside the existing `max_width / 2` corridor.
- **Path max by pointer jumping, in pure vectorised R.**
  - `nxt <- nxt[nxt]` together with `M <- pmax(M, M[nxt])`, for log2(path length) iterations.
  - Measured on the bundled tile: 30 iterations take 0.08 s.
  - Cycles and pits are absorbing; the fixed iteration count tolerates both.
- **The 3×3 window** absorbs D8 diagonal leaks across the 8-connected stream line and small DEM
  and stream misalignment. It is still monotone, because adding streams only raises L.
- **D8 needs a conditioned DEM. Measured:**
  - With raw `terra::terrain(v = "flowdir")`, only **29%** of today's valley cells have a path
    that touches a stream, even with the 3×3 window. There are 4,029 code-0 pits and about 8% of
    paths are cyclic or non-converging.
  - Burning the streams 5–50 m changes almost nothing (≤30%), and burning would break
    monotonicity anyway.
  - `terra::flowDir()` (experimental) did not finish in 10 minutes on 518k cells.
  - `terra::pitfiller()` (experimental PEM4PIT) was still running after 10 minutes on 518k cells.
  - → **Backend: whitebox** (user decision at the gate).
    - `wbt_breach_depressions_least_cost()`, then `wbt_d8_pointer(esri_pntr = TRUE)` on
      tempfiles. ESRI codes reuse the probe's row and column offset table.
    - `whitebox` is already in Suggests, so the drainage method is opt-in and errors clearly
      without the package or its binary. Tests and examples are guarded the same way.
    - The repo has no R-CMD-check workflow, only pkgdown, so no CI install step is needed. Guard
      the examples so the pkgdown build does not need the binary.
- **Cells with no owner** (path never meets a stream) get no waterline and are dry. Their count is
  reported, not patched. A fallback would reintroduce blending.

### Phase 1: Conditioning backend + feasibility gate
- [x] Install `whitebox` (pak) and its binary (`whitebox::install_whitebox()`) on m1
- [x] Internal helper `fl_flow_next()` in `R/fl_flood_depth.R`: breach depressions, then the
      D8 pointer (ESRI), returning a next-cell index vector (pits and edges point to themselves)
- [x] Measure on the bundled tile: share of today's valley cells whose path meets a stream
      (3×3); runtime. **Gate: ≥ 90% reached, or stop and report**
      → 79.1%, every miss drains off the tile edge; proceed, re-measure on MORR (findings)
- [x] Record in findings.md, with the raw-D8 baseline (29%) and the rejected terra options

### Phase 2: Tests first
- [ ] `test-fl_flood_depth.R`: `method = "drainage"` on a synthetic tilted-valley fixture
      (no pits). A cell's waterline equals the max level among the stream cells on its path.
      Plus the creek fixture from 538371c: adding the creek loses 0 cells (pooled loses 46)
- [ ] `test-fl_valley_confine.R`: reuse the d71bbb5 "adding a watercourse never removes
      floodplain" loop over `blue_line_key`, under `flood_method = "drainage"`
- [ ] ff ordering: valley cells ff2 < ff4 < ff6 under drainage
- [ ] Default unchanged: the pooled pin of 28,727 valley cells (precip, ff6) still holds with no
      new argument
- [ ] Argument validation: `match.arg`, and a clear error naming whitebox when the package or
      its binary is missing (mocked)
- [ ] Drainage tests `skip_if_not()` on the whitebox binary, inside each block

### Phase 3: Implementation
- [ ] `fl_flood_depth(method = c("pooled", "drainage"))`. The drainage branch builds L by 3×3
      focal max of the surface, then the path max, then corridor masking, then depth as today
      (0 on stream cells, NA where < 0)
- [ ] Pass-through: `fl_flood_model(method =)` and `fl_valley_confine(flood_method =)`, default
      `"pooled"`
- [ ] roxygen `@details`: the rule, monotonicity, backwater, unowned cells, and the departure from
      the Python VCA's pooled `griddata`; `@examples` run on bundled data; `devtools::document()`
- [ ] lintr, full `devtools::test()`

### Phase 4: Measure against the acceptance criteria
- [ ] Bundled tile: valley cells pooled vs drainage at ff2/4/6, with gaps
- [ ] Monotone: the Phase 2 test passes (exact, every blue line)
- [ ] Bounded change on fixed streams:
  - bundled tile;
  - MORR arm 5 (`~/Projects/repo/floodplains/data/morr/probe_whole_fwa/`, read-only, network
    via `fp_wf_read_network`, as in `measure_lost_cells.R`);
  - MORR arm 1 vs arm 5 loss (was 451.9 ha);
  - Parsnip A/B: `inst/vignette-data/pars_*` inputs, pooled vs drainage.
- [ ] Gained/lost audit: for gained and lost cells, the owner (stream cell whose L is the max),
      depth, and height above owner's bed (median, p90). Script in `planning/active/measure_*.R`
      with its log
- [ ] Timing on MORR, against the pooled 8.7 s / 21.6 s

### Phase 5: Verdict and records
- [ ] Verdict against all four criteria in findings.md and `research/flood_surface_interpolation.md`
      (revised in place)
- [ ] If every criterion passes: ask the user about flipping the default (NEWS, re-pinning
      `test-vignette_data` / attribute fixtures, floodplains re-run timed with flooded#67). If
      not: keep the opt-in, or revert it, as the user decides; document why
- [ ] Edit the #68 issue body with the measured result
- [ ] CLAUDE.md design-decisions entry

## Validation

- [ ] Tests pass
- [ ] `/code-check` clean (each commit, or once over the branch with `/code-check branch`)
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion
