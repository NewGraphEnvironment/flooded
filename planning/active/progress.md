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
