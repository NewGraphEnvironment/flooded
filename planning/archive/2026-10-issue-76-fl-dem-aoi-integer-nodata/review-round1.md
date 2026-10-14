# Code-check round 1 — #76 branch (reviewer, 2026-10-14)

## Findings

- **[fragile — prose, causal claim]** planning/active/upstream_terra_draft.md:17-19, and the same chain in
  R/fl_dem_aoi.R:243-246 (code comment) — the stated mechanism does not produce the reported symptom.
  The draft says the fill comes "from the source's NoData cast to the output type, the tag from
  `NaN`"; the code comment says terra "fills cells beyond the source with its NoData cast to the
  Float32 output, and tags the output NoData = NaN, so a NoData Float32 cannot hold exactly ...
  comes back as data". Under that model *every* integer NoData would come back as data, an exactly
  representable 65535 included (fill 65535, tag NaN). It does not: probed in a temp copy
  (terra 1.9.50 / GDAL 3.13.0), `project(<file-backed INT2U, NAflag 65535 copy of dem.tif>,
  "EPSG:3157", filename = g)` writes `NoData Value=nan` and the 45,116 cells beyond the source
  are **NaN in the file** (read with `NAflag(y) <- NaN`: 45,116 NA, max 1061.935), while the
  INT4U copy written the same way holds 4294967296 there (0 NA). So the fill is not simply "the
  NoData cast"; some step maps fill/NoData cells to NaN by value, and it is that comparison the
  Float32 rounding defeats (which is what the issue body itself hypothesised: "the nodata test
  probably compares against the rounded value"). The draft's own next paragraph ("INT2U ... are
  unaffected; those NoData values are exact in Float32") only makes sense under the
  comparison model, so the draft contradicts itself. Since the draft is meant for the terra
  maintainer, restate the mechanism as observed (fill cells equal to an exactly representable
  NoData are written NaN; a NoData that rounds in Float32 survives as its rounded value) rather
  than as two independent sources; the code comment's "so" needs the same correction. No code
  behaviour is affected.

## Checked and clean

- Restore-the-bug: in a temp copy with the `r_clip <- r_clip * 1` line deleted, all five #76
  blocks go red (3/5, 2/3, 1/2, 2/4, 2/3 failures, 0 errors); with it, 17/17 pass. Both sources
  in the INT8U / INT4S loop fail individually on the mutant (max 1.844674e+19 and 2147483648).
- `terraOptions(print = FALSE)` returns a list (`$todisk` FALSE here); `on.exit()` inside
  `test_that()` restores it (probed: FALSE after the block).
- In-memory crop: `datatype()` is `""` (probed), so the cast is skipped there, as the comment says.
- `NAflag()` on dem.tif reports NaN, and setting `NAflag(x) <- 4294967295` still gives max
  4294967296 (draft claims hold).
- Same-CRS source-resolution path returns a crop with no warp, so no fill cells; untouched correctly.
- Under a global `terraOptions(datatype = "INT4U", todisk = TRUE)` the result is NA beyond the
  source (max 1062, 290,432 NA) with and without the fix, so a non-float copy there is not a regression.
- Research §4 table values (INT8U 1.8e19, INT4S/2147483647 -> 2147483648, INT2U NA) reproduced.

/Users/airvine/Projects/repo/flooded/planning/active/review-round1.md
