# Review round 4 — #71 (branch diff b701391...HEAD, latest 267fc52)

## Findings

- **[low, pre-existing, outside the diff]** inst/notes/methodology.md:213 — the "See also" bullet
  says "flooded#44 — production-scale timing is unmeasured; the k=5 figure does not establish
  k=340". That is now false in present tense, and this branch is what makes it contradict the shipped
  docs. `?fl_valley_attribute` (Performance) now states a measured k = 340 MORR timing: 37.8 s, and
  855.8 s through 0.6.3. Issue #44's own status block reads "measured; the fixes are #71 and #72".
  `inst/notes/` ships with the package. Fix: reword it to point at the measured figures, e.g.
  "flooded#44 — production-scale timing measured on MORR k = 340; see `fl_valley_attribute()`
  Performance and #72 for the per-group cost". This is not a code bug.

## 267fc52 itself

Correct. `@param complete` (R/fl_valley_attribute.R:24-27) now says "the group of the nearest burned
stream cell", which matches `## Coverage` (lines 63-68) and `fl_nearest_group()`. That function
takes cell centres of `which(!is.na(values(idx_r)))` and uses `st_nearest_feature`. The Rd hunk
reproduces the roxygen text word for word. "so every valley cell is attributed" was already in the
text before this commit. It fails only in the degenerate case where no stream burns a cell, which
was handled the same way on b701391, so it is not a finding.

## Enumeration: every statement of the fallback rule or its cost

| Location | Text (abridged) | Verdict |
|---|---|---|
| R/fl_valley_attribute.R:24-27 `@param complete` (+ man Rd:44-47) | "group of the nearest burned stream cell" | consistent |
| R/fl_valley_attribute.R:32-35 `@return` (+ Rd:53-56) | "assigned to the nearest group when complete = TRUE" | no specific rule |
| R/fl_valley_attribute.R:61-69 `## Coverage` (+ Rd:86-94) | "nearest burned stream cell (centre to centre, the cells fl_stream_rasterize() burns) … either may win" | consistent |
| R/fl_valley_attribute.R:91-98 `## Performance` (+ Rd) | 37.8 s / 35.2 s / 0.4 s; "Through 0.6.3 that step took 805.6 s, because it measured distance over the whole grid" | consistent (historical full-grid is correctly past tense; matches bench_fallback.log per rounds 1 and 3) |
| R/fl_valley_attribute.R:88 | "approaches the full grid" | unrelated (crop efficiency) |
| R/fl_valley_attribute.R:196 code comment | "nearest group by distance" | no specific rule |
| R/fl_valley_attribute.R:219 cli message | "assigned to the nearest group" | no specific rule |
| R/fl_valley_attribute.R:333-344 `fl_nearest_group` @noRd | "same rule as terra::distance(… values = TRUE) … burned cell whose centre is nearest" | consistent (the NaN-on-burned-query-cell divergence noted in round 3 cannot be reached) |
| CLAUDE.md:112-115 (above marker) | "assigns those to the nearest group and reports the count" | no specific rule |
| inst/notes/methodology.md:161-162 | "complete = TRUE assigns them to the nearest group" | no specific rule |
| **inst/notes/methodology.md:213** | "production-scale timing is unmeasured" | **false (finding above)** |
| vignettes/valley-confinement.Rmd:489-494 | "assigned to the nearest watercourse" | no specific rule |
| tests/testthat/test-fl_valley_attribute.R:385-390 | test name "full-grid nearest-stream assignment"; comment "nearest burned cell is exactly as close" | consistent (the "full-grid" in the name is the oracle, which is correct) |
| tests/testthat/test-fl_valley_attribute.R:315-322, 338, 353 | "nearest-group", "the nearest group for some uncovered cells" | no specific rule; the tests pass under the shipped rule (rounds 1 and 2) |
| NEWS.md | no #71 entry yet (added in release bookkeeping) | n/a |
| README.md, _pkgdown.yml, research/ | no statement of the fallback rule or its cost | n/a |
| "has not been measured" anywhere outside planning/ | no hits | consistent (the old Performance sentence is gone) |
| `terra::distance` in R/ | fl_flood_depth.R:65 and fl_mask_distance.R:37 are unrelated; no remaining use in fl_valley_attribute.R code | consistent |
| planning/active/* | working notes; findings.md and task_plan.md describe the old full-grid pass as the problem being fixed | historical, does not ship (`^planning$` in .Rbuildignore per round 1) |
| CLAUDE.md below the marker | general terra/distance conventions | no claim about this function |

## Verdict

267fc52 is correct, and the fallback rule is now stated the same way everywhere it is stated
specifically. One stale claim about cost remains in shipped text, at inst/notes/methodology.md:213.
It predates the branch and is outside the diff.
