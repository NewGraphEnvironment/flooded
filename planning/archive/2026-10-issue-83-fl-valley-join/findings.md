# Findings — Join per-segment attributes to the valley by position, not by group key (#83)

## Issue context

**If we do it:** joining stream-segment attributes (habitat flags, or any per-segment value) to a delineated floodplain is one function call. Every consumer gets the same rule, the one that keeps per-reach areas additive.
**If we never do:** each consumer re-derives the join, and the obvious version (join by blue line) is badly wrong: it gives a floodplain polygon any attribute found anywhere on its blue line.

## Problem

`fl_valley_attribute()` returns one floodplain row per watercourse group (for example `blue_line_key`), and rows overlap where ground is shared. A common next question is "which part of this floodplain sits beside segments with attribute X?", such as spawning or rearing habitat flags carried per stream segment.

Joining by the group key answers a different question. Measured in NewGraphEnvironment/floodplains, whole-network `all_ff04`, 2026-10-14:

| group | flag | by blue line (ha) | by position, nearest segment (ha) |
|---|---|---|---|
| BULK | coho spawning | 57,482 | 26,937 |
| BULK | sockeye spawning | 16,705 | 572 |

On MORR, joining by blue line reads 82% of the floodplain as chinook spawning.

## Proposal

An exported function that joins segment attributes to valley cells **by position**:

- **Inputs:** the valley raster, the `fl_valley_attribute()` output, and an `sf` of line segments carrying the group column plus any number of logical attribute columns.
- **Rule:** each valley cell takes the attributes of the nearest segment on **each group that claims it**. Only claiming groups compete; the nearest segment anywhere can be on a line the network floor left out.
- **Shared cells, two resolutions:**
  - `nearest`: one owner per cell (the nearest of the claiming groups' nearest segments). This is the rule for areas, because per-reach areas then add up to the floodplain. Ties go to the lowest group key, and the count is reported.
  - `any`: TRUE where any claiming group's nearest segment says so. This is the "connected to" view.
- **Return:** per-cell attributes for each resolution, plus an integrity check (every valley cell attributed, none outside), the tie count, and the groups with no segments.

The working implementation is 77 lines in NewGraphEnvironment/floodplains `scripts/floodplain_lcc/fp_habitat_join.R`, run on four watershed groups (`scripts/floodplain_lcc/logs/*_habitat_join-query_*.md`). The work is to generalize it: arbitrary attribute columns rather than `spawning`/`rearing`, and any group column rather than `blue_line_key`.

## Not in scope

- No dependency on link or any habitat model. Segments arrive as plain `sf`, so habitat exports from different model configs all work.
- Segment lines cut from FWA blue lines by route measure is a separate question, for the caller.

## Done when

- The function is exported with a runnable example on the package test data.
- Its tests pin `nearest` against `any`, the tie rule, a group with no segments, and a cell claimed by none.
- The floodplains driver calls it in place of its local helpers, and the results match the 2026-10-14 logs.

## Source implementation

floodplains `scripts/floodplain_lcc/fp_habitat_join.R` (origin/main 8db7165): `fp_hj_grid_cells()`
(cells per group via `terra::cells(r, terra::vect(v))`, integrity check), `fp_hj_join_range()`
(per claiming group `sf::st_nearest_feature()` + `st_distance(by_element = TRUE)`, order by
cell, dist, key; ties counted; no-segment groups get dist = Inf and FALSE flags). Callers:
`habitat_join-query.R`, `habitat_join-demo.R`. Logs: `scripts/floodplain_lcc/logs/*_habitat_join-query_*.md`
(morr/bulk/kisp 2026-10-14 on flooded 0.7.0; dunc 2026-10-12 on 0.6.5). MORR: 532,577 cells,
78.7% claimed by 2+, 1,877 tied cells, 0 groups without segments.

## Errors Encountered

| Error | Resolution |
|-------|------------|
