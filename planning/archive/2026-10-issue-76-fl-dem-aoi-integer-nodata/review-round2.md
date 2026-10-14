# Code-check round 2 — #76 branch (reviewer, 2026-10-14)

## Findings

- **[fragile — prose pointer]** research/dem_reprojection.md:104 (`**Produced by:**`) and :110-111
  ("A draft upstream report is in the same archive") — the citation hard-codes
  `planning/archive/2026-10-issue-76-fl-dem-aoi-a-whole-file-uint32-source-re/`, a directory that
  does not exist yet and will exist only if `/planning-archive` uses the full branch name as its
  slug. The skill asks for a "brief slug", and every prior archive shortened the branch name:
  branch `67-fl-dem-aoi-lets-gdal-choose-the-output-g` -> `2026-10-issue-67-fl-dem-aoi-grid`,
  branch `78-fl-dem-aoi-the-source-read-window-is-sti` -> `2026-10-issue-78-fl-dem-aoi-read-window`.
  If #76 follows that pattern, the research file's only provenance pointer (and the pointer to the
  upstream draft) is a dead path in a published file. Either archive under exactly this slug, or
  fix the path in §4 in the archive commit. No code behaviour affected.

## Checked and clean (probed in a temp copy; terra 1.9.50 / GDAL 3.13.0 / PROJ 9.8.1)

- The round-1 restatement of the mechanism holds, and is consistent across the code comment
  (R/fl_dem_aoi.R:243-248), the test-file comment, research §4, the upstream draft, roxygen
  @details and the CLAUDE.md trap. Probed `project(<file-backed copy of dem.tif>, "EPSG:3157")`
  over NoData values chosen to separate "integer type" from "not exact in Float32":
  | type | NoData | Float32 of it | max beyond | NA |
  |---|---|---|---|---|
  | INT4U | 4294967040 (exact) | 4294967040 | 1061.93 | 45,116 |
  | INT4U | 4294967295 | 4294967296 | 4294967296 | 0 |
  | INT4U | 16777217 | 16777216 | 16777216 | 0 |
  | INT4S | 16777217 | 16777216 | 16777216 | 0 |
  | INT4S | 100000001 | 1e8 | 1e8 | 0 |
  | INT4S | 2147483647 | 2147483648 | 2147483648 | 0 |
  | INT4S | -2147483648 | exact | 1061.935 | 45,116 |
  | INT2U | 65535 | exact | 1061.93 | 45,116 |
  | INT8U | default 18446744073709550514 | 2^64 | 18446744073709551616 | 0 |
  So "any integer NoData Float32 cannot hold does the same" (test comment), "only when they match
  its NoData in the Float32 output" (code comment), and the draft's INT8U / INT4S / INT2U claims
  all hold, including on NoData values the branch never tested; an exactly representable INT4U
  NoData is fine, confirming the trigger is representability, not UInt32.
- Research §4 "returned 2^32 ... on 0.6.6 and every release since": v0.7.0 (git archive, load_all)
  gives max 4294967296, 0 NA; main (0.7.1) is red per the branch's tests; the branch gives
  max 1061.94, 290,432 NA.
- The upstream draft's reprex re-run: every printed value matches (INT4U, 4294967296, 1049 twice,
  Float32 / `NoData Value=nan`, 815 cells, GDAL 3.13.0, 1049, `4.2949673e+09`).
- `test-fl_dem_aoi.R` with `NOT_CRAN=true`: 34 blocks, 0 failed/errored, 0 skipped.
- Same-CRS source-resolution path returns the crop unwarped (no fill cells), so leaving it
  uncast is correct; the `res = 30` same-CRS path goes through `project()` and is covered.
- Accepted tradeoffs (NEWS, withr, global `datatype = "INT4U"`, draft not posted) not re-raised.

