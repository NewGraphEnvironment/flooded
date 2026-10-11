# Review round 2 — #71 branch (b701391...HEAD)

## Clean
No issues found.

### What was checked (all probes run in a copy of the repo under the session scratchpad; working tree untouched)

(a) **Can the oracle test tell a broken implementation apart?** Yes. The oracle shares
`fl_stream_rasterize()`/`idx_r` with the code, but it does not read the code's output: it runs an
independent full-grid `terra::distance(values = TRUE)`, and `got` comes from the returned
polygons. On the fixture the 9,904 uncovered cells span all 5 groups (oracle: 8032 / 965 / 610 /
39 / 258), so a constant assignment cannot pass. Mutants of `fl_nearest_group()`, run through
`testthat::test_file(desc = ...)` with `NOT_CRAN=true`: HEAD 0 failed / 17 passed; query cells
shifted by one (`cells + 1L`) gives 1 failed; result reversed (`rev()`) gives 1 failed; nearest by x only
(`coords = c("x","x")`) gives 1 failed. One cell differs from terra at HEAD, and it is a tie
(gap < 1e-6), as accepted.

(b) **Group ordering.** The test's `c(sort(unique(keys[!is.na(keys)])), NA)` always appends NA.
The function appends it only when a key is NA. The test does not depend on the two agreeing:
`got` maps each output row's *name* to the test's own index, and the oracle uses the test's own
`idx_r`, so both sides of the comparison are in the test's index space. The bundled data does
have NA `gnis_name` (6 segments), so the NA level is exercised. When there are no NA keys, the extra
level matches no rows and adds nothing.

(c) **Scale.** The O(grid) work that remains is `terra::values(idx_r)` (18.1 M doubles, about
145 MB) and `fl_stream_rasterize()` over the full grid. Both were also in the old path, alongside
the full-grid `distance()`, and the function already reads `terra::values(valleys)` in full. The
part proportional to the network is `xyFromCell` on burned cells (42,615) plus a GEOS STRtree
nearest-feature query (14,170 queries). This is not a regression.

(d) **The bench claims.** In helper mode, cells are compared at cell level on identical inputs
(`a_old`, `a_new`, each of length 14,170, asserted). The `diff` predicate also catches NA/non-NA
mismatches, so `cells_differing: 0` is not vacuous. Between 493c88f (the tree that was benched) and HEAD,
R/ changed only in roxygen comments, so the measured helper is the shipped one. Doc figures
match `bench_fallback.log`.

(e) **cli under `capture_messages`.** The condition class is
`cliMessage/simpleMessage/message/condition`, so it is captured. The alert is not wrapped at
width 80. `n` is an integer from `length()`, so there is no scientific or big-mark formatting. The
fixed substrings match (verified output: "ℹ 9904 valley cells outside every group's thresholds -
9904 assigned to the nearest group.").

**No-CRS inputs.** I re-checked these: with both inputs lacking a CRS, `st_crs(NA) != ""` is TRUE, so `st_transform()`
errors before `fl_nearest_group()`'s `st_crs("")` (which would itself error). The behaviour is the same on b701391,
so it is not a regression.
