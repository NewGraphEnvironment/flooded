# Code-check round 3 — #76 branch (reviewer, 2026-10-14)

## Mechanism behind rounds 1-2

Both earlier findings were **a fact owned somewhere else, restated in prose and written separately
from that owner, with nothing tying the copy back to it**. In round 1 the owner was terra's
behaviour: the copy was written from a model of it rather than from a probe, then repeated in four
documents. In round 2 the owner was the archive step's slug, which the research path quoted before
that step had run. Each copy is right only while it happens to agree with its owner.

So this round listed every restatement in the diff (numbers, counts, quantifiers, conditions,
versions, paths, cross-references) and checked each against its owner. Two disagree.

## Findings

- **[fragile: prose, stale count]** CLAUDE.md:50: "(18 test files, **161** test_that blocks)".
  The test files own this count. It was exact on main (161 at merge-base 277018b, counted per
  file with `grep -c '^test_that('`). This branch adds 5 blocks to `test-fl_dem_aoi.R` (29 -> 34),
  so the tree now has **166**. The diff edits CLAUDE.md 135 lines further down and leaves
  this line alone, so the branch makes the count wrong.
  Fix: 161 -> 166.

- **[fragile: prose, over-broad quantifier]** R/fl_dem_aoi.R:69-70 (roxygen `@details`) and
  man/fl_dem_aoi.Rd:90-91: "projected directly, terra writes a NoData such as UInt32 4294967295
  as 4294967296, a value, **wherever the output reaches past the source**". This copy is the
  only one that drops the condition that the raster must be **file-backed**. The code comment,
  the test comment, research §4, the CLAUDE.md trap and the upstream draft all keep it.
  The probe contradicts "wherever". On main (no cast, `git archive 277018b`, terra 1.9.50 /
  GDAL 3.13.0), `fl_dem_aoi(streams, dem.tif, buffer = 100, target_crs = 3157)` projects the
  integer crop directly. That crop is in memory (`datatype()` is `""`, `inMemory()` TRUE), and the
  call returns **9,533 NA, max 905**: NA beyond the source, not 4294967296. Only the file-backed
  cases give 2^32: the whole-file crop (`buffer = 2000`: max 4294967296, 0 NA) and the same
  `buffer = 100` call under `terraOptions(todisk = TRUE)` (max 4294967296, 0 NA).
  This is the published help page, so a reader learns that every direct reprojection of an
  integer DEM is affected. Fix: "projected directly from a file, ..." or similar, then
  `devtools::document()`. Behaviour is not affected.

## Checked and clean (probed in a temp copy where noted)

- The fix itself: `any(grepl("^INT", terra::datatype(r_clip))))` comes before the only
  `terra::project()` call. The same-CRS early return (`terra::crop()` only) never warps, so it
  never fills. Branch result on `buffer = 2000`: max 1061.941, 290,432 NA. Under `todisk = TRUE`
  with `buffer = 100`: max 905, 9,533 NA, identical to main's in-memory result.
- Code comment "An in-memory crop reports datatype "" and is already fine": probed `""`, `inMemory`
  TRUE, and main gives NA there (above).
- Research §4 "returned 2^32 ... on 0.6.6 and every release since": v0.6.6 (`git archive v0.6.6`,
  `load_all`) gives max 4294967296 with 0 NA. The tags after it are v0.7.0 (probed in round 2) and
  v0.7.1, which is main and red under the branch's tests.
- Research §4 claim "Under `terraOptions(todisk = TRUE)` the subset crop (`buffer = 100`) gives
  2^32 as well": reproduced on main (max 4294967296, 0 NA).
- CLAUDE.md trap: `describe(dem.tif)` reads `Type=UInt32`, `NoData Value=4294967295`. The
  recipe (`buffer = 2000`, `todisk = TRUE`, Float32 reference) matches the tests.
- Upstream draft cross-references: rspatial/terra #2166 ("conflicting information of describe() vs.
  NAflag()") and #2074 ("NAflag() result different than stated in GeoTiff header") exist and are
  on point. The plan-review findings' #2207 and #2030 also exist with the titles the findings give.
  terra's GitHub NEWS.md has 1.9-54 as its top version. Its entries since 1.9-50 contain nothing
  on project/warp/NoData except #2207 (INT2U crop to disk), so "its NEWS does not mention
  this" holds.
- research/README.md row, man/ Rd: they match the roxygen text that is there now.
- Test count claims in the planning records ("34 blocks", "34/34"): `test-fl_dem_aoi.R` has 34.
- Other callers: the only caller outside the package function is `data-raw/wsg_vignette_data.R`,
  which uses MRDEM-30 (Float32) and is untouched by the cast.
- Accepted tradeoffs (NEWS, withr, global `datatype = "INT4U"`, draft not posted, archive path in
  §4 created by the archive step, planning/active path references) not re-raised.

