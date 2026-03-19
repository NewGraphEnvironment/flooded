# Task: fl_scenarios() and fl_params() — CSV loaders for VCA parameters

**Issue:** flooded#28
**Branch:** flood-scenarios

## Goal
Add two exported functions (`fl_scenarios()`, `fl_params()`) and one new CSV
(`flood_scenarios.csv`) to give users access to VCA parameter metadata and
pre-defined flood factor scenarios. Close #28.

## Phases

### Phase 1: Create flood_scenarios.csv
- [x] Create `inst/extdata/flood_scenarios.csv`
- [x] Columns: scenario_id, flood_factor, slope_threshold, max_width, cost_threshold, size_threshold, hole_threshold, run, description, ecological_process, citation_keys
- [x] Three rows: ff02 (active channel), ff04 (functional floodplain), ff06 (valley bottom)
- [x] Non-flood_factor params use defaults from flood_params.csv

### Phase 2: fl_params()
- [x] Create `R/fl_params.R`
- [x] Load flood_params.csv by default, accept custom path
- [x] Return tibble
- [x] roxygen with @export

### Phase 3: fl_scenarios()
- [x] Create `R/fl_scenarios.R`
- [x] Load flood_scenarios.csv by default, accept custom path
- [x] Return tibble
- [x] roxygen with @export

### Phase 4: Tests
- [x] Create `tests/testthat/test-fl_params.R` (4 tests)
- [x] Create `tests/testthat/test-fl_scenarios.R` (7 tests)
- [x] Default load returns tibble with expected columns
- [x] Custom path override works
- [x] Invalid path errors cleanly
- [x] Scenarios match flood_params.csv defaults for non-flood_factor params

### Phase 5: Document and verify
- [x] devtools::document() — NAMESPACE, fl_params.Rd, fl_scenarios.Rd
- [x] devtools::test() — 154 pass (22 new)
- [x] lintr::lint_package() — no new warnings
- [ ] Commit with Fixes #28

## Constraints
- Do NOT modify fl_valley_confine()
- Do NOT add vignette (separate issue)
- Do NOT bump version
