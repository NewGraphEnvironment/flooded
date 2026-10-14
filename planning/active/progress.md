# Progress — fl_dem_aoi(): a whole-file UInt32 source reprojects its nodata as 4294967296, not NA (#76)

## Session 2026-10-14

- Plan-mode exploration — phases approved by user; user asked to run all phases to the PR
- Created branch `76-fl-dem-aoi-a-whole-file-uint32-source-re` off main
- Scaffolded PWF baseline from issue #76 with approved phases
- Next: start Phase 1

## Session 2026-10-14 (cont.)

- Phase 1: terra-only reprex; upstream search (no existing issue); draft in `upstream_terra_draft.md`
  (not posted). Verdict as §4 of `research/dem_reprojection.md` (existing topic file). Commit 8229f69
- Plan review (`review-plan.md`): 11 findings; 3 probed and confirmed (multi-layer `if`, same-CRS
  `res` path, INT4S nodata 2^31-1)
- Phase 2: tests against a Float32-stored reference; red on main (8 failures, 0 errors). Commit 2cdd327
- Phase 3: cast integer crops to float before `project()`; mutation table in a copy. Commit e3c4ab4
- Phase 4: CLAUDE.md trap, INT4S correction; NEWS left to `/gh-pr-merge`. Commit 10dc471
- Only caller outside the package function is `data-raw/wsg_vignette_data.R` on MRDEM-30 (Float32):
  no cached vignette output changes
- `/code-check branch` round 1 spawned 15:15:05Z
- Full suite at e3c4ab4: FAIL 0, WARN 0, SKIP 0, PASS 461
- Round 1 (`review-round1.md`): 1 finding, confirmed by probe (file-backed INT2U is written NaN
  beyond the source): the prose's causal chain ("fill = NoData cast, tag = NaN, so ...") was wrong;
  the fill is matched to the NoData by value and Float32 rounding defeats the match. Fixed in the
  code comment, test comment, research §4 and the upstream draft
- Round 2 (`review-round2.md`): 1 finding (not inside round 1's fix): research §4 pointed at an
  archive path `/planning-archive` would not create. Archive slug fixed now as
  `2026-10-issue-76-fl-dem-aoi-integer-nodata`; archive under exactly that name. Round 2 also
  probed more NoData values (16777217, 1e8+1 -> rounded; 4294967040 -> NaN), consistent with §4
- Round 3 (`review-round3.md`): mechanism named — prose restating a fact decided elsewhere, written
  apart from its source. Enumerated every restatement in the diff; 2 disagreed, both confirmed:
  CLAUDE.md's test-block count (161 -> 166 with this branch) and the roxygen sentence, the one copy
  that dropped "file-backed" (an in-memory crop was always NA). Fixed; neither inside a prior fix
- Round 4 (`review-round4.md`): 2 findings, the first **inside round 3's fix**: the new roxygen
  said "past the source" where, on disk, the 2^32 cells are past the crop (probe: all 9,533 inside
  dem.tif's footprint); CLAUDE.md's trap said "inside the tile, or in memory" where it needs "and".
  Mechanism: "source" meant the file in our prose and the raster handed to `project()` in terra's.
  Ended by enumeration: every added line in R/, man/, tests/, research/, CLAUDE.md with an extent
  word (beyond / past / outside / footprint / source ends), 16 hits, each now names the crop, the
  area read, the projected raster, or the file in a whole-file case. Tests 34/34
