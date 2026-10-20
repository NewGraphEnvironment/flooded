# Code-check round 4 (#92): sibling enumeration of round 3's fixes, sentence pass, guards

I worked only on copies. HEAD b09e1d3 was extracted with `git archive` to `/private/tmp/claude-501/rv4/flooded`, and
`knitr::purl()` turned the vignette into `pars.R` there. The load chunk was run with meta values mutated
(`a2.R`). The overview map and the inset map were drawn to `main.png` and `detail.png`, and the label placement
was measured (`a3.R`). Reserve markers were checked in `a4.R`. DataCite was queried read-only for the NGE records
archived on Zenodo.

## Sibling enumeration

| Round-3 fix | Claim or property it fixed | Other places that state or rely on it | Verdict |
|---|---|---|---|
| CLAUDE.md:95 "concept DOI … where Zenodo archives one" | DOIs exist only for some packages | `data-raw/wsg_vignette_data.R:19-21` (same fix); script :441-442; vignette :311-316 (DOIs printed for flooded and link only); research file (no DOI claim) | TRUE everywhere. DataCite today has flooded, link, floodplains, crate, wet, stacs and stac_pointcloud_bc, and no fresh or fwapg. Note: the script never looks for a DOI for fresh or fwapg (`for (pkg in c("flooded", "link"))`, :519). So "where Zenodo archives one" holds only because that hard-coded set happens to match. DataCite is read as one page of 500 with no paging; it holds 36 records. Neither is a defect today. |
| script :23-25 skip qualifier | the test skips on CI, on CRAN, and where a source is unreachable | `test-vignette_data.R:72-75` ("skip on CI, on CRAN and where the source cannot be reached"); CLAUDE.md:97-98; `research/bundled_stream_data.md:31-32` ("when it can reach it") | TRUE, and consistent. The script and CLAUDE.md name only CI and CRAN in their parenthesis. "Where it can reach them" covers the other three skips (no DBI or fresh installed, no connection, no `fresh_default` schema). |
| CLAUDE.md:99-100 "Numbers … pinned by its md5; its `stopifnot()` refuses a missing or malformed meta value and guards each sentence's premise" | what the guards cover | vignette :87 comment ("Each sentence below reads these as true"): TRUE. Vignette :108 comment ("every value the data and software sections print"): **FALSE** (finding 2). CLAUDE.md:90 ("computes its numbers from the bundle, which `pars_meta.rds` pins"): OVERSTATED, low. The areas at 2, 6 and 7 and the "adds 6.2 %" are read from meta, not computed. The 2/6/7 cell counts are pinned by nothing (accepted G6), and the md5 sentence at :99 does not claim them. | The sentence itself is **FALSE** (finding 1). |
| vignette :91-92, :104-105, :109-112 guards for absent columns, empty sets, release and SHA | a guard must fail on an absent premise | vignette :94 `all(names(args) %in% names(fm))` (finding 3); `url` and `repo` (finding 2); test :122-127 (finding 4); test :134 (finding 5). Vignette :91 `nrow(streams) > 0` passes on `NULL` (`logical(0)`), but `sf::st_length(NULL)` at :58 errors first, so the chunk still stops. | Four siblings still pass on an absent value. |
| vignette :192-194 Rosgen "borrows the multiplier" | flooded's factor 2 is not Rosgen's definition | `inst/notes/floodplain_interpretation.md:53` ("Anchored to" … "Maps to a return period? **Yes**") and `inst/notes/methodology.md:59` (`ff02` "Active channel margin (~50-yr flood, Rosgen)") | Both still read flooded's ff2 as a 50-year level. Those lines are unchanged on this branch, so this is out of scope and noted only. The branch's own text is TRUE. |
| vignette :245-257 labels placed on their line | a label must sit on the feature it names, not at a proxy | the reserve markers at :170 use `st_centroid(of_largest_polygon = TRUE)`, the same proxy class | **Holds today.** Every inset label is 0.00 m from its own line and 0.0 m from a blue stream of the same name. The 5 names in the inset are exactly the 5 names on blue streams. All 5 reserve centroids lie inside their polygons (`a4.R`). A centroid is not guaranteed to be inside a polygon, but nothing here fails. |

## Sentence pass (`vignettes/pars-floodplain.Rmd`)

"Guard" means a `stopifnot()` term or a test that fails if the sentence turns false.

| Line | Sentence (short) | Verdict | Evidence | Guard fails if false? |
|---|---|---|---|---|
| 119-120 | flooded maps floodplains from an elevation model and a stream network | TRUE | `fl_valley_confine()` signature | n/a |
| 120-122 | Parsnip WSG, 5,597 km², between Prince George and Mackenzie; the Parsnip flows north into Williston Reservoir | TRUE | `aoi$area_ha`; geography | km² by gpkg md5; geography none |
| 124-126 | 40,640 ha, 7.3 %, 2,314 km of order 3+ streams bull trout can reach | TRUE | fp_cells 451,557 = meta; species BT; access 1/2; min order 3 | yes |
| 130 | starts from 30 m cells that pass four tests | TRUE | AND of four masks | n/a |
| 132-139 | slope ≤ 9 %; within 1,000 m; cost under 2,500; below 4 × bankfull depth; depth from area and precipitation through Hall | TRUE | args = formals; precip passed | yes for values. **No if an arg is absent** (finding 3) |
| 141-143 | closes gaps, fills holes < 0.25 ha, drops patches < 0.5 ha, majority filter; a cell can be in or out without matching the tests | TRUE | round 3 row 6 | values yes |
| 143-145 | adds lakes and wetlands the streams flow through (20.4 %), and cells whose centre is inside a channel width | TRUE | `all(v_in[wb_cell]==1)`, `all(v_in[buf_cell]==1)`, both non-empty | yes |
| 145-146 | every setting but the flood factor is the package default | TRUE | vapply against formals | yes for recorded args |
| 148-150 | streams of order 3+ bull trout can reach in link's `default` config; link models fish access and habitat | TRUE | meta | yes |
| 152 cap | colours and layers; roads other than resource roads left off | TRUE | code (RRD, RRS, RRN filter) | drawn, n/a |
| 192-195 | three presets 2/4/6; factor 2 borrows Rosgen's multiplier (twice max bankfull depth, ≈ 50-year stage or less) | TRUE | `fl_scenarios()`; Nagel quote in `floodplain_interpretation.md:53` | presets yes; literature cited |
| 195-196 | flooded's names for 4 and 6 are its own reading | TRUE (accepted round 2) | `flood_scenarios.csv` | none |
| 196-197 | Nagel: 7 the most appropriate for valley extent at 30 m | TRUE | literature | cited |
| 199-201 | 38,516 / 40,640 / 42,371 / 43,155 ha at 2, 4, 6, 7; 4 → 7 adds 6.2 % | TRUE | meta. Test :98 ties areas to cells | 4 yes; 2/6/7 G6. An NA at 2 or 6 prints "NA ha" and passes `stopifnot()`; the test catches it unless both cells and area are NA |
| 205-206 | SE corner holds the Parsnip's headwaters around Arctic Lake, on the Arctic/Pacific divide | TRUE | `detail.png`: Arctic Lake 10 and Arctic Pacific Lakes park at the south edge | **none** |
| 206-207 | floodplain follows channels, lakes, wetlands; sits against roads, railways, reserves, parks | TRUE | round 3 row 20 (contacts measured) | **none** |
| 209 | map does not record which test or step left a cell out | TRUE | output is a 0/1 grid | n/a |
| 211 cap | named streams labelled; roads and trails; etc. | TRUE | labels on their lines (table above) | none |
| 263-267 | not compared with ground mapping; R² 0.47, 1,951 measurements, Columbia basin; depth conversion from one Idaho basin; the factor multiplies the error | TRUE | `vca_parameter_rationale.md` | cited |
| 271-272 | maps terrain, not floods; no discharge, routing or return period | TRUE | inputs are DEM, area, precip | n/a |
| 273-275 | starts only from the streams given; beside others only via measurement, tidying or a lake or wetland | TRUE | round 3 row 24 | none |
| 276 | 30 m cells; nothing narrower resolved | TRUE | `terra::res` | computed |
| 280-285 | MRDEM-30; link run of 2026-10-17; area and precip from fwapg; lakes, wetlands, named streams from the atlas; context layers from the BC Data Catalogue | TRUE (context origin by schema; meta records `carried` and NA, accepted rounds 1-2) | meta | date `has1` only (`"x"` passes); context **none** |
| 285-288 | built by the script, which ran the call below; the call took 1.1 minutes (Apple M1 Max) | TRUE | `vca_seconds` 67.8 | yes (character `"67.8"` passes `stopifnot()`, then render errors) |
| 301-307 | downloads: gpkg (floodplain, streams, lakes and wetlands, map layers), grid, DEM truncated to whole metres | TRUE | 9 layers; `as.int` truncates | md5; layer list and truncation **none** |
| 311-313 | flooded v0.8.3 at b43e810; DOI | TRUE | meta; DataCite | `has1`/`is_sha` yes. A release of `"garbage"` or a DOI of `"x"` passes |
| 314-316 | link v0.66.0, modelled at ee21eb1, recomputed at a17e917; DOI | TRUE | meta | yes; url and repo not guarded |
| 317-318 | fresh v0.39.0 at e247ca1, the engine link runs on | TRUE | meta | yes; repo NA prints `github.com/NA/commit/…` and passes |
| 319-321 | fwapg at f9718cb as link's run recorded it; tables read 2026-10-19 | TRUE | meta | `is_sha`, `has1(read_at)` (`"x"` passes) |
| 323-331 | cite with `citation()`; the DOI covers v0.8.2 on and resolves to the latest | TRUE (G11 accepted) | DataCite | `has1(doi_from)` |

Every sentence is TRUE. No sentence is FALSE or OVERSTATED. Nothing fails if the sentences at 205-207, 211 and
280-285 (context origin), or the layer list at 301-307, turn false. Round 2 finding 2 already listed those
sentences as unguarded.

## Guards

`stopifnot()` terms: each meta value was mutated, the load chunk re-run, and the result recorded (`a2.R`).

| Mutation | Result |
|---|---|
| `vca_args$slope_threshold` or `$hole_threshold` absent | **passes** (the text prints "at most  %") |
| `vca_args$max_width` NA | stops |
| `software$url` NA, or the column absent | **passes** |
| `software$repo` NA, or the column absent | **passes**, prints `[e247ca1](https://github.com/NA/commit/…)` |
| `fp_area_ha["2"]` NA | **passes** `stopifnot()`; the test (:98) fails |
| `fp_area_ha["4"]` = 1 | **passes** `stopifnot()` (prints "1 ha" in the flood-level passage); the test (:98) fails |
| release `"garbage"`, `concept_doi` `"x"`, `doi_from` `"x"`, `read_at` `"x"`, `link_run_date` `"x"` | **pass** (format never checked) |
| `vca_seconds` `"67.8"` (character) | passes; the inline `round()` then errors, so the render stops |
| `fp_cells["4"]` NA, `fp_area_ha["4"]` absent, fwapg row absent, duplicate fresh row, `cpu` absent, `link_dirty` absent | stops |

Tests:

| Expectation | Can it fail on a false premise? |
|---|---|
| :84 `expect_setequal(names(md5_files), …)` and :87 md5 | yes (NULL fails setequal) |
| :97 fp cells vs grid | yes (an absent `flood_factor` gives `[[character(0)]]`, an error) |
| :98 `fp_area_ha == fp_cells * res` | yes, except when both are NA for the same factor (`NA == NA*x` is identical) |
| :122-127 fwapg digests | **no, for a missing row**. The loop runs over the rows present, and `expect_gt(nrow, 0)` only stops an empty set (finding 4) |
| :134-137 ETag | **skips when `dem_source$url` is absent**: `curlGetHeaders(NULL)` errors "invalid url argument", which reads as "not reachable" (finding 5). An absent ETag header fails, correctly. |

## Findings

1. **[overstated, inside round-3 fix]** `CLAUDE.md:99-100` says "its `stopifnot()` refuses a missing or
   malformed meta value and guards each sentence's premise". Both halves are measured false.
   - **"refuses a missing or malformed meta value".** An absent `vca_args` member passes, and so do an NA or
     absent `url` or `repo`. A malformed release, DOI, `doi_from`, `read_at` or `link_run_date` passes too. Only
     commits are format-checked (`is_sha`).
   - **"guards each sentence's premise".** Round 2 finding 2 flagged the earlier wording ("guards the premises of
     its data claims") with a list of unguarded sentences. Round 3 widened the quantifier to "each sentence" while
     those sentences remain unguarded: Arctic Lake and the south-east corner (:205-206), "sits against roads,
     railways, reserves and parks" (:206-207), the context-layer origin (:284-285), and the download layer list
     and truncation (:301-307).

   This is the widening mechanism from memory again.
   **Fix:** add the guards from findings 2 and 3, and format checks where cheap:
   - `grepl("^v[0-9]+\\.[0-9]+\\.[0-9]+$", release)`;
   - `grepl("^10\\.5281/zenodo\\.[0-9]+$", concept_doi)`;
   - `grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}", c(link_run_date, read_at))`;
   - `is.numeric(meta$vca_seconds)`.

   Then state the scope by its members, for example "refuses an absent or empty value among those it prints and a
   commit that is not a full SHA, and guards the premises of the sentences about the streams, the model's
   settings, the lakes and channel buffer, and the software. The map descriptions (Arctic Lake, what the
   floodplain sits against) and the context layers' origin are not guarded."

2. **[overstated comment + guard gap, inside round-3 fix]** `vignettes/pars-floodplain.Rmd:108`. The comment
   says "every value the data and software sections print", but `url` (:149, :283, :311-319) and `repo` (in
   every `commit_link()` and `recompute_link`) are printed and not checked. An NA repo prints
   `https://github.com/NA/commit/…` and the chunk passes.
   **Fix:** `all(vapply(c("flooded", "link", "fresh", "fwapg"), function(p) has1(sw_row(p)$url) &&
   has1(sw_row(p)$repo), logical(1)))`.

3. **[guard fails toward pass, sibling of round-3 fix]** `vignettes/pars-floodplain.Rmd:94`.
   `all(names(args) %in% names(fm))` is a subset test, so a meta whose `vca_args` lacks `slope_threshold`,
   `max_width`, `cost_threshold`, `hole_threshold` or `size_threshold` passes. The vapply at :95 then iterates
   over fewer names, and :132-142 print blanks.
   **Fix:** `setequal(names(args), flooded::fl_params()$parameter)`, or require the five printed names
   explicitly. Then "Every setting but the flood factor is the package default" also covers a fixed set.

4. **[guard fails toward pass on a shrunk set]** `tests/testthat/test-vignette_data.R:122-127`. The test is
   named "every fwapg query of the Parsnip bundle", but a meta missing the `streams` (or any other) row passes:
   the loop checks only the rows present. This is the same subset-shrink class as round 3's
   `sw$release[sw$package != "fwapg"]`.
   **Fix:** `expect_setequal(src$name, c("aoi", "streams", "lakes", "wetlands", "named_streams"))`. lakes and
   wetlands are absent only for a WSG with no waterbody keys, and the Parsnip has 668.

5. **[guard skips on an absent value, low]** `tests/testthat/test-vignette_data.R:134-135`. When
   `meta$dem_source$url` is absent or NA, `curlGetHeaders()` errors on the argument and the test skips as "not
   reachable", where it should fail.
   **Fix:** `expect_true(is.character(meta$dem_source$url) && length(meta$dem_source$url) == 1L &&
   nzchar(meta$dem_source$url))` before the fetch, or skip only on a network error class.

No code defects in the round-3 label placement:
- `split` → `st_union` → `st_line_merge` gives one LINESTRING per name for all 5 names.
- `st_point_on_surface` puts each point on its own line (0.00 m), and the points stay aligned with
  `names(by_name)`.
- The halo offset is 0.7 x 1.1 px at 150 dpi: thin, as the reserve labels' comment says, and visible in
  `detail.png`.

The reserve markers still use a centroid, and all 5 are inside their polygons today.
