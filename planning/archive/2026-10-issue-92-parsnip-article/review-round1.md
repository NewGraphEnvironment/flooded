# Code-check round 1 (#92) — branch diff, sentence enumeration

Reviewer worked on copies only (`/private/tmp/claude-501/rv1/`): rendered the vignette from a
`git archive HEAD` copy in a folder named `flooded` (renders clean), read the bundle with
`load_all()`, queried fwapg read-only, GitHub API and DataCite.

## Sentence enumeration

Rendered text checked against `R/fl_valley_confine.R` and helpers, `pars_meta.rds` and the bundle.
"Guard" = a `stopifnot()` in the load chunk or a test that fails if the claim turns false.

| # | Where (Rmd line) | Sentence (short) | Verdict and evidence | Guard |
|---|---|---|---|---|
| 1 | title / VignetteIndexEntry | "Floodplains of the Parsnip River watershed group" | TRUE | n/a |
| 2 | 101 | flooded is an R package that maps floodplains from an elevation model and a stream network | TRUE | n/a |
| 3 | 102-104 | runs over PARS, 5,597 km² of BC between Prince George and Mackenzie, Parsnip flows north into Williston | TRUE (km² computed from aoi; geography correct) | number computed; geography unguardable |
| 4 | 106-108 | At ff 4, 40,640 ha, 7.3 % of the WSG, along 2,314 km of order 3+ streams bull trout can reach | TRUE. Mask is `touches = TRUE`: 74 boundary cells (0.016 %) whose centre is outside the AOI are counted; immaterial | yes: cells == meta, order min 3, access 1/2, species BT |
| 5 | 112 | starts from the 30 m cells that pass four tests | TRUE (AND of four masks) | cell size computed |
| 6 | 114 | slope at most 9 % | TRUE (`fl_mask(..., "<=")`, percent slope) | defaults-vs-formals |
| 7 | 115 | within 1 km of a stream in a straight line | TRUE (`distance <= max_width/2`). Fragile formatting, finding F10 | defaults-vs-formals (not the rounding) |
| 8 | 116-117 | cost distance counting steep ground as farther, cost under 2,500 | TRUE (`costDist` over percent-slope friction, `<`) | defaults-vs-formals |
| 9 | 118-119 | below a water level 4 × the stream's bankfull depth above the stream, spread across the valley | TRUE (surface = stream DEM + ff·depth, IDW within 1 km, depth > 0) | `ff == 4` |
| 10 | 119-121 | bankfull depth from **each** stream's upstream area and precipitation via Hall's width regression | OVERSTATED: 8 segments (0.36 km) have NA area, burn NA, are not seeds and get no depth of their own (F6) | none |
| 11 | 123-125 | closes gaps, fills holes under 0.25 ha, drops patches under 0.5 ha, majority filter; a cell can be in without passing, out despite passing | TRUE (`< hole_threshold`, `< min_area`, 3×3 modal) | defaults-vs-formals |
| 12 | 125-126 | Last, adds lakes and wetlands the streams flow through, 20.4 % of the floodplain | TRUE (waterbody_key join; ORed after cleanup; share computed) | yes: every lake/wetland cell is 1 |
| 13 | 126-127 | and the cells whose centre lies inside a stream's channel width | TRUE (measured: 42,602 buffer-centre cells, all 1; channel_width has no NA) | **none** (F5) |
| 14 | 127-128 | Every setting but the flood factor is the package default | TRUE for the six `fl_params()` criteria; precip and waterbodies are passed, but the call is shown | yes (formals) |
| 15 | 130-132 | streams are order 3+ that bull trout can reach in link's `default` config; link models fish access and habitat | TRUE | yes |
| 16 | 134 caption | full map: floodplain, hillshade, streams, lakes/wetlands, resource roads, railways, **parks**, reserves, boundary; roads other than resource roads left off | Mostly TRUE; "resource roads" = RRS/RRD/RRN by code (RRN absent), consistent. "parks" layer includes TACHEEDA LAKES ECOLOGICAL RESERVE (F4) | none |
| 17 | 174 | three preset levels 2, 4, 6 | TRUE | yes |
| 18 | 174-176 | A factor of 2 gives Rosgen's flood-prone width, ≈ 50-year flood stage or less [Nagel] | OVERSTATED: Rosgen's is 2 × *field* max bankfull depth; here 2 × regression-predicted depth on a 30 m DEM (F8) | none |
| 19 | 176-177 | flooded calls 4 functional floodplain, 6 valley bottom; its own reading, not published | TRUE vs `flood_scenarios.csv` (accepted B4) | none (could check `fl_scenarios()$description`) |
| 20 | 177 | This article uses 4 | TRUE | `ff == 4` |
| 21 | 177-178 | Nagel found 7 most appropriate for valley extent on 30 m DEMs | TRUE (quote in `inst/research/vca_parameter_rationale.md`) | literature, unguardable |
| 22 | 180-181 | floodplain 38,516 / 40,640 / 42,371 / 43,155 ha at ff 2, 4, 6, 7, everything else unchanged | TRUE (`run_vca()` reuses inputs) | 4 tied to grid; 2/6/7 untestable (accepted G6) |
| 23 | 181-182 | 4 → 7 adds 6.2 % | TRUE | yes (7 > 4) |
| 24 | 186-187 | SE corner holds headwaters around Arctic Lake, on Arctic/Pacific divide | TRUE: PARS Arctic Lake at (1279909, 1055073) is inside the inset bbox; Pacific Lake is just south in HERR | unguarded (could assert the lake point is in `inset_bbox`) |
| 25 | 187-188 | floodplain follows channels, lakes, wetlands; sits against roads, railways, reserves and parks | TRUE: inset holds 1,777 roads, 10 railways, 2 reserves, 2 parks | none |
| 26 | 190 | map does not record which test or tidying step left a cell out | TRUE | n/a |
| 27 | 192 caption | detail: ..., **all roads (grey)**, railways, parks, reserves (named), named streams labelled | OVERSTATED: the grey lines include 105 trails (T 33, TS 72) (F4) | none |
| 28 | 238 | not compared with floodplain mapped on the ground | TRUE (nothing in repo) | n/a |
| 29 | 238-241 | Hall R² = 0.47 across 1,951 sites, Columbia basin; width→depth from a single Idaho basin | TRUE per `vca_parameter_rationale.md` ("verified from purchased PDF"); it says 1,951 field *measurements*, the article says *sites*: UNVERIFIABLE here (Zotero MCP unavailable) | literature |
| 30 | 241-242 | flood factor multiplies whatever error those carry | TRUE | n/a |
| 31 | 246-247 | maps terrain, not floods; no discharge/routing/return period; level relative to **each** stream's bankfull depth | TRUE apart from "each" (as #10) | none |
| 32 | 248-250 | starts only from the streams given; ground beside a smaller stream is in the map **only through** slope, distance and height | OVERSTATED: closing and hole fill add cells that pass no test (the article says so at 124) (F7) | none |
| 33 | 251 | 30 m cells; nothing narrower than a cell is resolved | TRUE | cell size computed |
| 34 | 255-256 | DEM is NRCan MRDEM-30 | TRUE | ETag test |
| 35 | 256-259 | FWA segments from link's run of 2026-10-17; upstream area and precip from fwapg; lakes, wetlands, named streams from the atlas | TRUE | digests test |
| 36 | 259-260 | roads, railways, reserves, parks from the BC Data Catalogue | TRUE by schema (BCGW table/column names); meta records `carried`, origin NA | none |
| 37 | 260-263 | built by the data script, which ran this call; one run took 1.1 minutes (Apple M1 Max) | TRUE (67.4 s, `vca_seconds`) | none for `cpu` (F11) |
| 38 | 276-282 | downloads: gpkg (floodplain, streams, lakes/wetlands, map layers); valleys grid; DEM **rounded** to whole metres, model ran on unrounded | **FALSE**: `terra::as.int()` truncates (1.7 → 1, measured) (F1) | none |
| 39 | 286-288 | flooded v0.8.3 at commit 5d3b8e9: the floodplain model; DOI 10.5281/zenodo.23302790 | TRUE (dirty FALSE; DataCite concept). 5d3b8e9 is not on GitHub yet (HTTP 422); resolves once pushed | DOI and dirty guarded; release NA not guarded (F2) |
| 40 | 289-291 | link v0.66.0, modelled at ee21eb1, recomputed at a17e917; DOI | TRUE (compare: v0.66.0 ahead/at, v0.66.1 not). Recompute's own `link_dirty` not recorded (DB says FALSE) (F12) | DOI, run `link_dirty` |
| 41 | 292-293 | fresh 0.39.0, **which has no release**, at e247ca1 | **FALSE**: fresh has 46 tags; `compare/v0.39.0...e247ca1` = identical (F2) | none |
| 42 | 294-295 | fwapg at f9718cb: FWA in PostgreSQL with upstream area and precip | TRUE (commit exists on NewGraphEnvironment/fwapg) | none |
| 43 | 297-301 | Cite flooded as: `citation("flooded")` | Prints the render-time version, not the build's (accepted G11) | n/a |
| 44 | 303-304 | its DOI **covers every release** and resolves to the latest | **FALSE**: Zenodo holds v0.8.2 and v0.8.3 only; flooded has 23 tags (F3) | none |
| 45 | README:102-103 | "how much floodplain a whole watershed group holds, and how that changes with the flood level" | TRUE | n/a |
| 46 | CLAUDE.md:50 | pars-floodplain.Rmd: "every number from pars_meta.rds" | OVERSTATED (F9) | n/a |
| 47 | CLAUDE.md:90-95 | article states only what meta records; digest of **every query** it reads (with the SQL); test fails when a bundled file or **a reachable source** no longer matches; stopifnot fails when a sentence's premise does | OVERSTATED (F9) | n/a |
| 48 | research/bundled_stream_data.md:30-31 | meta records row counts and a digest of **every query's** rows that the test checks | OVERSTATED (F9) | n/a |
| 49 | data-raw header 19-22 | test fails when a written file or **a database source** no longer matches | OVERSTATED (F9) | n/a |

## Findings

- **[false-claim]** vignettes/pars-floodplain.Rmd:282 (also the data script, line 509): "the elevation model,
  rounded to whole metres" is wrong. The script writes `terra::as.int(dem)`, which truncates toward zero.
  Measured: `as.int(c(1.7, -1.7, 2.5, 0.4))` gives `1 -1 2 0`, so every cell is rounded down by up to 1 m. —
  **Fix:** say "truncated to whole metres". The alternative is `round(dem)` in the script, but that needs a
  rebuild, a new md5, and a re-run of the bundle test.

- **[false-claim]** vignettes/pars-floodplain.Rmd:292 and data-raw/wsg_vignette_data.R (section 4b,
  "fresh has no release", `release = c(flooded_tag, link_tag, NA, NA)`): "fresh 0.39.0, which has no
  release" is false by the script's own definition of a release, which for flooded is a git tag. fresh has
  46 version tags, and `gh api repos/NewGraphEnvironment/fresh/compare/v0.39.0...e247ca19` returns
  `identical`, so v0.39.0 is exactly the commit used. The script gives `release` no guard either: `git describe`
  returns NA when there are no local tags, and the article would then print "flooded NA". — **Fix:** resolve
  fresh's tag the way link's is resolved (`paste0("v", run$fresh_version)`, then check it is at or before
  `run$fresh_sha` and the next tag is not). Print "fresh v0.39.0, at commit …" and drop "which has no
  release". Add `!anyNA(sw$release[sw$package %in% c("flooded","link","fresh")])` to the `stopifnot()`.

- **[false-claim]** vignettes/pars-floodplain.Rmd:303: "its DOI, which covers every release" is false. DataCite
  (`client-id=cern.zenodo`) lists only v0.8.2 and v0.8.3 as versions of concept 10.5281/zenodo.23302790.
  v0.1.0 to v0.8.1, 21 tags, were never deposited. — **Fix:** say "which covers every release from v0.8.2
  and resolves to the latest". Better, compute the earliest version from the DataCite records the script
  already fetches and store it in `meta$software`.

- **[false-claim]** vignettes/pars-floodplain.Rmd:192 and :134 (captions): two layers are labelled by their
  most familiar member.
  - Detail map: "all roads (grey)" also draws 105 trail features in the inset (`transport_line_type_code`
    T = 33, TS = 72).
  - Both maps: "parks (light green)" also draws `TACHEEDA LAKES ECOLOGICAL RESERVE` on the full map. The
    source, `ta_park_ecores_pa_svw`, holds parks, ecological reserves and protected areas.

  **Fix:** say "roads and trails (grey)" in the detail caption and "parks and protected areas (light green)" in
  both. The other option is to filter the layers to match the words.

- **[fragile]** vignettes/pars-floodplain.Rmd:125-127: the claim "and the cells whose centre lies inside a
  stream's channel width" has no guard. The channel buffer is auto-detected from a `channel_width`
  column (`fl_valley_confine.R`, `channel_buffer = NULL`). If a rebuild dropped that column or filled it with
  NA, the buffer would be skipped silently and the sentence would turn false with nothing failing. The plan
  review's G8 asked for this guard, and the disposition says "guards updated", but there is none in the
  `stopifnot()`. I checked the claim directly: it is true today, with 42,602 buffer-centre cells and all of
  them equal to 1. — **Fix:** add `"channel_width" %in% names(streams)` and `!anyNA(streams$channel_width)`.
  A stronger guard rasterises `sf::st_buffer(streams, streams$channel_width / 2)` onto `valleys` and asserts
  that every covered non-NA cell is 1. That costs one rasterize, as for the waterbodies.

- **[false-claim, low]** vignettes/pars-floodplain.Rmd:119-120 and :247 say "each stream's upstream area" and
  "each stream's bankfull depth". 8 segments (0.36 km, `meta$n_upstream_area_na`) have NA area, so
  `fl_stream_rasterize()` burns NA for them. Those cells are then not stream cells at all: not seeds for
  distance, cost or flood, and they take an IDW level from their neighbours. Cutting the fwapg#33
  sentence (planned) left the quantifier with no exception. — **Fix:** drop "each" (write "the stream's" or
  "streams'"), or keep one clause with `meta$n_upstream_area_na` computed inline and guarded `> 0`.

- **[false-claim, low]** vignettes/pars-floodplain.Rmd:248-250: "is in the map only through its slope,
  distance and height relative to those streams" contradicts line 124, where the article itself says the
  tidying puts in cells that pass no test. Closing and hole fill can add ground beside a smaller stream. —
  **Fix:** add "or the tidying", for example "only through its slope, distance and height relative to those
  streams, and the tidying around them".

- **[false-claim, low]** vignettes/pars-floodplain.Rmd:174-175: "A factor of 2 gives Rosgen's flood-prone
  width". Rosgen's width is measured at twice the *field-measured maximum* bankfull depth. Here the factor
  multiplies a regression-predicted depth on a 30 m DEM, so it gives Rosgen's definition applied to a
  predicted depth, not Rosgen's width. — **Fix:** say "A factor of 2 follows Rosgen's definition of
  flood-prone width (twice bankfull depth), which roughly matches …".

- **[false-claim]** CLAUDE.md:50 and 90-95, research/bundled_stream_data.md:30-31,
  data-raw/wsg_vignette_data.R:19-22: these overstate what the build records and what the test checks.
  - "every number from pars_meta.rds" and "the Parsnip article states only what pars_meta.rds records" are
    false. The WSG km², the stream km, the lake and wetland share and the cell size are computed from the
    gpkg and tifs, which meta pins only by md5. R² 0.47, 1,951, the factor 7 and Rosgen's 50-year figure
    are literature literals.
  - "a Postgres digest of every query it reads (with the SQL)" is false. The `fresh_default.log`,
    `log_recompute`, `n_seg`, fwapg row-count and `to_regclass` queries get no digest. For context layers,
    meta records a placeholder in place of the SQL, and a carried layer gets no digest at all, which is
    every layer in this build.
  - "fails when … a reachable source no longer matches" (CLAUDE.md) and "a database source" (the script
    header) are false. The test keeps only `db == "fwapg"`, so the share-database sources are never checked.
  - "the vignette's stopifnot() fails when a sentence's premise does" is false for the unguarded sentences
    in this table (F5, and rows 18, 24, 41, 44).

  **Fix:** restate each by its definition. The article quotes meta and the bundle files whose md5 meta
  records. Meta records a digest of every fwapg query whose rows reach the bundle, and the test checks
  those plus the MRDEM ETag. Context layers read live record a digest that nothing checks.

- **[fragile]** vignettes/pars-floodplain.Rmd:115: `n0(args$max_width / 2 / 1000)` rounds to whole km. A
  default of 1500 would print "1 km" for 0.75 km, and the defaults-vs-`formals()` guard would still pass,
  because it compares meta with the code, not with the printed text. — **Fix:** print
  `format(args$max_width / 2 / 1000, drop0trailing = TRUE)`, or write metres with `n0(args$max_width / 2)` m.

- **[fragile]** data-raw/wsg_vignette_data.R:550-552 (`cpu`): off macOS, `sysctl -n
  machdep.cpu.brand_string` exits non-zero. The `tryCatch(warning =)` then returns `NA_character_`, which
  has length 1, so the `Sys.info()` fallback never runs. The article would print "(NA)", and the vignette
  has no guard for it. — **Fix:** use `if (length(cpu) != 1L || is.na(cpu)) cpu <- …`, and add
  `!is.na(meta$cpu)` to the `stopifnot()`.

- **[fragile, low]** data-raw/wsg_vignette_data.R section 4b: the `log_recompute` query does not select
  `link_dirty`, though the column exists (FALSE for m1-20261017T092007.555-1b04b0). The article cites
  "recomputed at a17e917" with no clean-tree check on that commit, while the modelling commit has one. —
  **Fix:** select `rc$link_dirty`, store it as `software$dirty_also` (or in meta), and guard
  `!isTRUE(...)`.

- **[fragile, low]** data-raw/wsg_vignette_data.R section 4b: `tags?per_page=100` reads one page, and link now
  has 101 tags. It works today only because GitHub lists the newest tags first, which leaves v0.1.0 on page 2.
  That order is not documented. If v0.66.1 fell onto page 2, `next_tag` would become a later tag or NA, and
  the "last release" check would pass without checking anything. — **Fix:** paginate (loop `&page=N` until
  an empty page), or read `git ls-remote --tags`.

No defects found in:
- the digest SQL, which is identical in the script and the test;
- `read_source()`, whose `REPEATABLE READ` is the first statement after `BEGIN`, with rollback on error;
- the md5 and cell-count tests;
- the ETag test;
- `on.exit()` inside `test_that()`, which fires (probed);
- the `stopifnot()` guards that exist (the `dirty` and `link_dirty` columns are logical, so `isTRUE`
  can fire);
- the DataCite concept-DOI lookup.
