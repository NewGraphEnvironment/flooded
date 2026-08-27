# Task: fl_valley_attribute() — attribute valley cells to the stream groups that produced them (#40)

A delineation from `fl_valley_confine()` answers only "where is this network's floodplain?", not
"where is the **Morice River's** floodplain?". Package-side half of
NewGraphEnvironment/floodplains#40; the driver half (config surface, key column on the gpkg) stays
there.

Mechanism: delineate once on the full network (delineation never changes), then attribute each
valley cell to every stream group that can reach it, reusing the two stream-dependent geometric
criteria per group. The flood mask stays global — recomputing it per group is what makes per-group
runs unstable (measured; see findings.md).

## Phase 1: Issue + PWF baseline

- [x] Draft the mechanism issue, cross-referencing NewGraphEnvironment/floodplains#40
- [x] File as #40; create branch `40-fl-valley-attribute-attribute-valley-cel` off main
- [x] Lock the name `fl_valley_attribute()` pre-baseline (verb form, matches `fl_valley_confine()`)
- [x] Land PWF baseline (task_plan.md, findings.md, progress.md)
- [x] Spawn concurrent Plan-agent review -> `planning/active/review-40.md` (do not wait on it)

## Phase 2: Tests first — the contract

`tests/testthat/test-fl_valley_attribute.R`, failing until Phase 3. Bundled `inst/testdata/`
(`dem.tif`, `streams.gpkg` — has `gnis_name`, `blue_line_key`, `stream_order`).

- [x] **Coverage, no orphans** — every valley cell falls in >=1 group
- [x] **Containment** — each group's polygons lie within the global valley extent
- [x] **Overlap preserved** — confluence cells belong to >=2 groups; count > 0
- [x] **Degenerate grouping** — a single constant group reproduces `fl_valley_poly()` output
- [x] **Grouping invariance** — `gnis_name` vs `blue_line_key` give the same union
- [x] **Crop safety** — one group attributed on a cropped window == on the full grid
- [x] **Errors / edges** — missing `group` column, non-`sf` streams, geometry mismatch, `NA` group
      values, a group whose streams fall outside the valley
- [x] **Delineation untouched** — `fl_valley_confine()` output unchanged by this branch

## Phase 3: Implement `fl_valley_attribute()`

- [ ] `R/fl_valley_attribute.R` — validate inputs, `compareGeom()`, `group` names a column
- [ ] Derive slope from `dem` as `fl_valley_confine.R:135-138` when `slope = NULL`
- [ ] Per group: crop to the group's bbox + margin (`max_width`), reusing `fl_stream_rasterize()`,
      `fl_mask_distance()`, `fl_cost_distance()`, `fl_mask()`, `fl_valley_poly()`
- [ ] Intersect with the cropped global valley raster, polygonize, tag with the group value
- [ ] Return `sf`, one row per group; overlapping rows where ground is shared
- [ ] `NA` group values form their own group (keeps the coverage guarantee); documented
- [ ] roxygen: runnable `@examples` on bundled data, `@seealso`, note that `max_width` /
      `cost_threshold` must match the VCA run
- [ ] `devtools::document()`

## Phase 4: Verify, document, release

- [ ] Re-run the measurements against the new function; confirm coverage / overlap numerically
- [ ] Time it and note the scaling shape (MORR: k=33 by `gnis_name`, k=340 by `blue_line_key`)
- [ ] Vignette section in `vignettes/valley-confinement.Rmd` — natural language, no `\@ref()`
      (does not resolve under `html_vignette2`); `fig.cap` on chunks
- [ ] `lintr::lint_package()`, `devtools::test()`, `devtools::check()` clean
- [ ] `NEWS.md` + version bump 0.3.2 -> 0.4.0 as the **final** commit

## Phase 5: Hand off to the driver

- [ ] **Edit** floodplains#40's body to fold in the measurement + the shipped API (findings are the
      spec, not commentary); comment only as the cross-repo pointer

## Validation

- [ ] Tests pass
- [ ] `/code-check` clean on each commit
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion, then `/gh-pr-push`
