# Code-check round 3 (#92): enumeration of every set and quantity, round 2's fixes reviewed hardest

Worked only on copies: `git archive HEAD` to `/private/tmp/claude-501/rv3/flooded`, the load chunk run from
`knitr::purl()` there, the detail map re-drawn to `/private/tmp/claude-501/rv3/detail.png`. Data from
`pars_meta.rds`, `pars.gpkg`, `pars_valleys.tif`; fwapg read-only through `fresh::frs_db_conn()` (scratch
`d1.R`-`d9.R` in that directory). "Guard" = a load-chunk `stopifnot()` or a test that fails when the phrase
stops holding.

## Enumeration

### Article (`vignettes/pars-floodplain.Rmd`)

| # | Line | Phrase (set / quantity) | Set the code or data defines | Covers all and only? | Guard |
|---|---|---|---|---|---|
| 1 | 115 | 5,597 km² | `aoi$area_ha / 100` (FWA attribute) | yes | gpkg md5 |
| 2 | 118-120 | 40,640 ha, 7.3 % of the WSG | 451,557 cells inside the aoi mask (incl. 74 touches-ring cells whose centre is outside: negligible) | yes | `identical(fp_cells, meta)` |
| 3 | 119-120 | 2,314 km of streams of order 3 and up that bull trout can reach | 9,386 segments, all inside the aoi; order 3-7; access 1 (6,633) / 2 (2,753); access 0 (3,114) excluded. 8 NA-area segments (355 m, 17 cells) are in the km but seed nothing; 0.015 % of the length | yes | order min, access, species, config |
| 4 | 124 | the 30 m cells that pass four tests | AND of four masks (`R/fl_valley_confine.R:243`) | yes | none needed |
| 5 | 126-133 | four tests, thresholds 9 % / 1,000 m / 2,500 / factor 4 | `fl_mask` `<=`, `fl_mask_distance` `<= max_width/2`, cost `<`, flood + stream cells | yes | formals, `ff == 4` |
| 6 | 135-137 | closes gaps, fills holes under 0.25 ha, drops patches under 0.5 ha, majority filter | focal max/min, `count*area < hole_threshold`, `fl_patch_rm` `<`, modal | yes, and in that order | formals |
| 7 | 137-138 | "the lakes and wetlands the streams flow through", 20.4 % of the floodplain | 668 polygons (204 L, 464 W) keyed by the streams' `waterbody_key`. fwapg: the streams intersect 6 more wetlands and 1 lake (Williston, 37,471 ha) by geometry, every one with **0 m** of stream inside (touch only), so the keyed set is exactly the set flowed through. 91,911 cells, same with unclipped polygons | yes | `all(v_in[wb_cell]==1)`, types L/W |
| 8 | 138-139 | cells whose centre lies inside a stream's channel width | `st_buffer(cw/2)` of the 9,386 segments with width > 0 (all), rasterized by centre | yes | `all(...)`, `sum > 0` |
| 9 | 139-140 | every setting but the flood factor is the package default | the six `fl_params()` criteria (precip/waterbodies accepted as inputs, round 2 row 14) | yes | formals |
| 10 | 142-144 | order 3+ streams bull trout can reach in link's `default` config | as row 3 | yes | yes |
| 11 | 146 cap | resource roads (grey); roads other than resource roads left off | drawn: RRD 728 + RRS 628 (RRN in the filter, absent). Left off: RU 5,618, RH1 78, RLO 43, RA2 12, RSV 6, RPD 1, RST 1, trails 1,188 | yes | none (drawn, not quoted) |
| 12 | 146 cap | First Nations reserves (marked with a diamond and named) | 5 reserves, all with `english_name`, all labelled | yes | none |
| 13 | 146 cap | parks and protected areas | 4 provincial parks + Tacheeda Lakes Ecological Reserve | yes | none |
| 14 | 146 cap | lakes and wetlands (pale green, outlined in blue) | fill `#a3cdb9`, border `#2171B5` | yes | n/a |
| 15 | 186 | three preset levels: 2, 4, 6 | `fl_scenarios()$flood_factor` | yes | yes |
| 16 | 186-189 | factor 2 "follows Rosgen's definition ... twice the **maximum** bankfull depth" | flooded multiplies the **predicted** depth (Hall width -> Knighton depth, `fl_flood_surface`) | **no** (finding 4) | literature |
| 17 | 189-190 | flooded calls 4 functional floodplain, 6 valley bottom | `flood_scenarios.csv` descriptions | yes (round 2 accepted the "not published" half) | none |
| 18 | 190-191 | Nagel: 7 most appropriate for valley extent on 30 m | quote, `vca_parameter_rationale.md:49` | yes | literature |
| 19 | 193-195 | 38,516 / 40,640 / 42,371 / 43,155 ha at 2, 4, 6, 7; 4 -> 7 adds 6.2 % | `meta$fp_area_ha` | yes | 4 tied to grid; "7" present and larger |
| 20 | 199-201 | floodplain sits against roads, railways, reserves and parks | inset: 311 of 1,777 road/trail lines, 4 of 10 railway lines, both reserves (0 m, 21 m), 1 of 2 parks (Arctic Pacific Lakes 0 m; Monkman 4.2 km) within 30 m | yes (each class has contact) | none |
| 21 | 205 cap | streams (blue) with named streams labelled | inset: 5 names labelled, all 5 on blue streams; 5 distinct names on blue streams, none unlabelled | yes as a set; **placement wrong** (finding 1) | none |
| 22 | 205 cap | roads and trails (grey) | all codes drawn in the inset | yes | none |
| 23 | 252-254 | R² 0.47, 1,951 measurements, Columbia basin; depth from a single Idaho basin | `vca_parameter_rationale.md:25-32` | yes | literature |
| 24 | 261-263 | only the streams given seed; beside a smaller/unreachable stream only via measurement, tidying, or a lake/wetland | code: seeds = non-NA area cells; post-tidy ORs = channel buffer (of given streams: "measured from those streams") + waterbodies | yes | none |
| 25 | 264 | 30 m cells | `terra::res` | yes | computed |
| 26 | 268-273 | DEM MRDEM-30; streams from link's run of 2026-10-17; area/precip from fwapg; lakes, wetlands, named streams from the atlas; roads and trails, railways, reserves, parks and protected areas from the BC Data Catalogue | `date_end` 2026-10-17 03:53:58 UTC (RPostgres returns UTC, so the date is not machine-zone dependent); layer contents as rows 11-13 | yes | ETag test; digest test |
| 27 | 275-276 | the `fl_valley_confine()` call took 1.1 minutes (Apple M1 Max) | `vca_seconds` 67.8, one call | yes | `has1(cpu)`; seconds **unguarded** (finding 2) |
| 28 | 289-295 | downloads: gpkg (floodplain, streams, lakes and wetlands, map layers), grid, DEM truncated | 9 layers: aoi, streams, waterbodies, railways, roads, reserves, parks, named_streams, floodplain | yes | md5 test |
| 29 | 299-301 | flooded v0.8.3 at b43e810; DOI | meta; b43e810 not on GitHub yet (422) until pushed | yes | release via `!anyNA` (finding 2) |
| 30 | 302-304 | link v0.66.0 modelled at ee21eb1, recomputed at a17e917 | `log_recompute.link_version` = 0.66.0, `link_dirty` FALSE (fwapg read) | yes | commits **unguarded** (finding 2) |
| 31 | 305-306 | fresh v0.39.0 at e247ca1 | meta | yes | no row-existence guard (finding 2) |
| 32 | 307-309 | fwapg at f9718cb as link's run recorded it; area/precip read from its tables on 2026-10-19 | `fwapg_sha` from `log`; `read_at` 2026-10-19T18:05:12Z; f9718cb exists on both fwapg repos | yes | `has1(read_at)`; commit unguarded |
| 33 | 317-319 | DOI covers releases from v0.8.2 on | round 2 accepted | yes | `has1(doi_from)` |

### Load-chunk comments and code comments in the article

| # | Line | Phrase | Verdict |
|---|---|---|---|
| 34 | 37 | "every layer clipped to the watershed group" | yes (all nine via `clip()`; DEM and grid masked) |
| 35 | 60, 63 | "burned as fl_valley_confine() burns them (by cell centre)" | yes (default `touches = FALSE`); clipped buffers are a subset of the unclipped ones, so the guard can only be stricter |
| 36 | 86-105 | per-guard comments | yes, each names its sentence |
| 37 | 241 | "one label per name, **at the middle of its first segment**" | **false** (finding 1) |

### Other files (branch-changed lines)

| # | Where | Phrase | Verdict |
|---|---|---|---|
| 38 | CLAUDE.md:50 | "numbers computed from the bundle" | accepted in round 2 (literature figures carved out below) |
| 39 | CLAUDE.md:91-95 | records VCA args and cells at 2, 4, 6, 7; digest of every query whose rows reach the gpkg; ETag; md5 of each file it writes | yes (5 fwapg queries; context layers carried this run) |
| 40 | CLAUDE.md:95 | "the software: release, commit, and concept DOI from DataCite" | **sibling of round 2's F6 fix**: fresh and fwapg have no DOI, fwapg no release (finding 3) |
| 41 | CLAUDE.md:97-98 | test fails when a bundled file no longer matches, and where reachable (skips on CI and CRAN) when an fwapg query or MRDEM-30 moved | yes |
| 42 | CLAUDE.md:99-100 | "`stopifnot()` guards **the numbers it prints** and the premises behind them" | **overstated, round-2 text** (finding 2) |
| 43 | README.md:102-103 | how much floodplain a WSG holds, and how it changes with the flood level | yes |
| 44 | research/bundled_stream_data.md:30-32 | digest of every fwapg query that reaches the bundle, checked when the test can reach it | yes (5 queries) |
| 45 | script :11-13 | DEM truncated, model on unrounded values | yes |
| 46 | script :15-20 | meta: ... "the software (release, commit, concept DOI)" | **sibling of round 2's F6 fix** (finding 3) |
| 47 | script :22-23 | test "fails when a written file, an fwapg query or the MRDEM-30 file no longer matches" | **sibling of round 2's F5 fix**: no skip qualifier, which CLAUDE.md and the test header now carry (finding 3) |
| 48 | script :162 | every query whose rows end up in the bundle is recorded | yes |
| 49 | script :439-444 | release; DOI where Zenodo archives one; flooded's is the last local version tag; fwapg by link's commit | yes |
| 50 | script :616-622 | vca_args, fp_cells, one run, sources = every query whose rows reach the gpkg | yes |
| 51 | test :72-75 | fail when a bundled file, an fwapg query or the MRDEM-30 file moves; skips on CI, CRAN, unreachable | yes (also skips without DBI/fresh or `fresh_default`; "cannot be reached" covers it) |
| 52 | test :101 | "every fwapg query of the Parsnip bundle" | yes (`db == "fwapg"`: aoi, streams, lakes, wetlands, named_streams) |
| 53 | test :120-121 | context layers from PG_*_SHARE, not checked | yes |
| 54 | DESCRIPTION | xciter dropped | yes: no use left outside `planning/` |

## Guards

Each `stopifnot()` term and test, asked whether it can fail on the case it exists for.

| Guard | Can it fail? |
|---|---|
| `identical(meta$species, "BT")`, `identical(meta$link_config, "default")` | yes, also on absent |
| `isFALSE(meta$link_dirty)`, the three software `isFALSE()` | yes, on NA and absent |
| `min(streams$stream_order) == 3` | yes (absent -> `Inf`; NA -> NA) |
| `all(streams$access %in% c(1L, 2L))` | **passes on an absent column** (`NULL %in% x` is `logical(0)`) |
| `all(names(args) %in% names(fm))` + `vapply(... isTRUE(==))` | vapply yes. `all(...)` alone passes on absent `vca_args`, but `meta$fp_cells[[character(0)]]` then errors, so the chunk still stops |
| `ff == 4` | yes |
| `identical(as.integer(fp_cells), meta$fp_cells[[...]])` | yes |
| scenarios, `"7" %in%`, `area_at[["7"]] > ...` | yes |
| `all(waterbodies$waterbody_type %in% c("L","W"))` | **passes on an absent column** |
| `all(v_in[wb_cell] == 1L)` | yes (round 2 ablation: 39,354 cells turn 0); vacuous with no waterbodies, but the printed share is then 0.0 %, not false |
| `all(v_in[buf_cell] == 1L)`, `sum(buf_cell) > 0` | yes |
| `!anyNA(sw$release[sw$package != "fwapg"])` | **passes on an absent `release` column, on `""`, and with the fresh row missing** (round-2 line) |
| `has1()` on both DOIs, `doi_from`, `cpu`, `read_at` | yes |
| not guarded, though printed | `meta$vca_seconds`, `meta$link_run_date`, every `commit` / `commit_also`, the fresh and fwapg rows' existence |
| test: md5 of 3 files | yes |
| test: fp cells vs grid | yes |
| test: fwapg digests | yes; `expect_gt(nrow(src), 0)` stops an empty set passing |
| test: MRDEM ETag | yes; an absent header gives `character(0)` and fails |

## Findings

1. **[figure defect, low]** `vignettes/pars-floodplain.Rmd:241-244`: the comment says "one label per name, at the
   middle of its first segment". The code labels at `sf::st_centroid()` of the whole cropped named-stream line.
   The centroid of a curving river is not on it. Measured: the 5 labels sit 1.3, 3.0, 2.7, 1.3 and 2.4 km from
   their own lines, in a 50 km inset. In the re-drawn map, "Parsnip River" sits on the ridge north-east of the
   Parsnip, and "Table River" and "Hominka River" sit on hillside above their valleys. A reader can attach a
   label to the wrong valley, and the caption's "named streams labelled" leads them to try.
   **Fix:** place each label on its line, for example
   `pts <- sf::st_point_on_surface(sf::st_geometry(dedup))` (GEOS returns a point on a line) or
   `sf::st_line_sample(sf::st_cast(dedup, "LINESTRING"), sample = 0.5)`. Then make the comment say what the code
   does. **inside-round-2-fix: n.**

2. **[guard fails toward pass + overstated, low]** These guards and the CLAUDE.md sentence round 2 wrote about
   them do not agree.
   - `vignettes/pars-floodplain.Rmd:106`: `!anyNA(sw$release[sw$package != "fwapg"])` is the same class as the
     `!anyNA()` guards round 2 replaced with `has1()`. It passes when:
     - the `release` column is absent (`NULL`);
     - a release is `""`;
     - the fresh row is missing (the subset just shrinks).

     The article would then print "`fresh` , at commit :".
   - `:90` `all(streams$access %in% c(1L, 2L))` and `:102` `all(waterbodies$waterbody_type %in% c("L", "W"))`
     pass on an absent column.
   - These printed values have no guard at all:
     - `meta$vca_seconds` (absent prints "took  minutes");
     - `meta$link_run_date`;
     - `commit` / `commit_also` (an NA prints `[NA](…/commit/NA)`);
     - `fwapg_sha`.
   - `CLAUDE.md:99-100` says "The vignette's `stopifnot()` guards the numbers it prints and the premises behind
     them". The stream km, km², waterbody share and minutes are printed, and nothing guards them. Only their
     premises can be guarded.

   **Fix:**
   - `all(vapply(c("flooded", "link", "fresh"), function(p) has1(sw_row(p)$release), logical(1)))`;
   - `all(grepl("^[0-9a-f]{40}$", c(sw$commit, sw_row("link")$commit_also)))` and `nrow(sw) == 4L`;
   - `"access" %in% names(streams)` and `"waterbody_type" %in% names(waterbodies)`, or `has1`-style length checks;
   - `is.numeric(meta$vca_seconds) && length(meta$vca_seconds) == 1L && !is.na(meta$vca_seconds)`;
   - `has1(meta$link_run_date)`.

   Then reword CLAUDE.md to "guards the premises of the numbers and statements it prints, and that every value
   it prints is present". **inside-round-2-fix: y** (line 106 and the CLAUDE.md sentence were both written in
   round 2).

3. **[overstated, low]** Round 2 fixed two sentences. Each has an unreached sibling, which is the round-2
   mechanism again.
   - `data-raw/wsg_vignette_data.R:22-23`: "tests/testthat/test-vignette_data.R fails when a written file, an
     fwapg query or the MRDEM-30 file no longer matches". Round 2 added the skip qualifier (CI, CRAN,
     unreachable) to CLAUDE.md and to the test header, and not here.
   - `data-raw/wsg_vignette_data.R:19-20` "the software (release, commit, concept DOI) the build rests on" and
     `CLAUDE.md:95` "the software: release, commit, and concept DOI from DataCite". Round 2 rewrote `:439` to
     "its concept DOI where Zenodo archives one", because fresh and fwapg have none and fwapg has no release.
     These two still state it for every package.

   **Fix:** add "(skipped on CI, on CRAN and where the source cannot be reached)" at :22. At :19-20 and in
   CLAUDE.md, say "release and commit, and the concept DOI where Zenodo archives one". **inside-round-2-fix: y**
   (missed siblings of round 2's F5 and F6).

4. **[overstated, low; one premise unverified here]** `vignettes/pars-floodplain.Rmd:186-188`: "A factor of 2
   follows Rosgen's definition of flood-prone width, twice the maximum bankfull depth".
   - flooded's level is `flood_factor` times the **predicted** bankfull depth: Hall's width regression, then
     H = 0.145 W^0.607 (`fl_flood_surface`). The article itself says this at :130.
   - Adding "maximum" in round 2 made the quote right. It also made "follows" assert that flooded's factor 2
     reproduces a definition built on a different depth. A regression depth from width is a mean-section depth
     in hydraulic geometry, not a thalweg maximum. I could not confirm that from a source in the repo.
   - The package's own note says "anchored to" (`inst/notes/floodplain_interpretation.md:53`).

   **Fix:** "A factor of 2 borrows the multiplier of Rosgen's flood-prone width, which he measured at twice the
   maximum bankfull depth and which roughly matches a 50-year flood stage or less". **inside-round-2-fix: y.**

No defects in:
- the remaining 50 enumeration rows;
- the script's tag, DOI and digest code (paging, `--match` quoting through `system2`, the compare checks,
  REPEATABLE READ snapshots);
- the test bodies.

The waterbody set, the named-stream label set and the "sits against" contacts were each computed and hold.
