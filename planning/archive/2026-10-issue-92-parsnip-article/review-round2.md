# Code-check round 2 (#92): branch diff, with round 1's fixes reviewed hardest

I worked only on copies: `git archive HEAD` went to `/private/tmp/claude-501/rv2/flooded`, and the render went to
`/private/tmp/claude-501/rv2b/`. The vignette renders clean, and I read both figures at their rendered size.

I ran three ablation runs of `fl_valley_confine()` (scratch `probe2.R`). They used the bundled DEM, which is
truncated to integers, so they reproduce the bundle to within 11,573 cells of 451,557, not exactly:
- the full call;
- `channel_buffer = FALSE`;
- `waterbodies = NULL`.

I also checked DataCite, Zenodo and GitHub tags. The verdicts use the code, `pars_meta.rds` and the bundle. "Guard"
means a load-chunk `stopifnot()` or a test that fails if the sentence turns false.

## Sentence enumeration

### Article (`vignettes/pars-floodplain.Rmd`, rendered text)

| # | Line | Sentence (short) | Verdict and evidence | Guard |
|---|---|---|---|---|
| 1 | 2 | Title: "Floodplains of the Parsnip River watershed group" | TRUE | n/a |
| 2 | 110-111 | flooded maps floodplains from an elevation model and a stream network | TRUE | n/a |
| 3 | 111-113 | PARS is 5,597 km² of BC between Prince George and Mackenzie; the Parsnip flows north into Williston | TRUE. The km² comes from `aoi$area_ha`. The geography holds: the mainstem runs NW, so "north" is loose but fine. | number computed |
| 4 | 115-117 | At ff 4: 40,640 ha, 7.3 % of the WSG, along 2,314 km of order 3+ streams bull trout can reach | TRUE (cells == meta; order min 3; access 1/2; BT) | yes |
| 5 | 121 | starts from the 30 m cells that pass four tests | TRUE (AND of four masks, `R/fl_valley_confine.R`) | cell size computed |
| 6 | 123 | slope at most 9 % | TRUE (`fl_mask(slope, 9, "<=")`, percent) | formals guard |
| 7 | 124 | within 1,000 m of a stream in a straight line | TRUE (`fl_mask_distance`: `distance <= max_width/2`) | formals guard |
| 8 | 125-126 | cost distance counting steep ground as farther, cost under 2,500 | TRUE (`<`) | formals guard |
| 9 | 127-128 | below a water level 4 × the stream's bankfull depth above the stream, spread across the valley | TRUE: `surface = dem + ff*depth` at stream cells, IDW within 1 km, `depth > 0`. Stream cells pass by construction. | `ff == 4` |
| 10 | 128-130 | depth estimated from a stream's upstream area and precipitation via Hall's regression for width | TRUE (`fl_flood_surface`: W = 0.196 A^0.28 P^0.355, then H = 0.145 W^0.607). "a stream's" is fine after round 1. | none (n/a) |
| 11 | 132-134 | closes gaps, fills holes < 0.25 ha, drops patches < 0.5 ha, majority filter; in without passing / out despite passing | TRUE | formals guard |
| 12 | 134-135 | Last, adds the lakes and wetlands the streams flow through, 20.4 % of the floodplain | TRUE. Ablation: without waterbodies, 39,354 of the 91,911 wb cells are 0, so the guard can fire. | yes (`all(v_in[wb_cell]==1)`) |
| 13 | 135-136 | and the cells whose centre lies inside a stream's channel width | TRUE (`st_buffer(cw/2)`, rasterized by centre; all 9,386 widths > 0). Ablation: without the buffer, 9,367 of the 42,591 buffer cells are 0, so the round-1 guard can fire. | yes |
| 14 | 136-137 | Every setting but the flood factor is the package default | TRUE for the six `fl_params()` criteria (precip and waterbodies are inputs; the call is shown) | yes (formals) |
| 15 | 139-141 | order 3+ streams bull trout can reach in link's `default` config; link models fish access and habitat | TRUE | yes |
| 16 | 143 caption | full map: green floodplain, streams blue, **lakes and wetlands (light blue)**, resource roads grey, railways, parks and protected areas, reserves, boundary; roads other than resource roads left off | Mostly TRUE. The road codes drawn are RRS/RRD/RRN, and RU (5,618), RH1 and the trails are left off. **Colour OVERSTATED:** the waterbody fill is `#a3cdb9`, a pale mint green, at alpha 0x66 over the green floodplain. Only the border is blue (finding 8). "parks and protected areas" covers Tacheeda Lakes Ecological Reserve. | none |
| 17 | 183 | three presets: 2, 4 and 6 | TRUE | yes |
| 18 | 183-186 | factor 2 follows Rosgen's definition of flood-prone width, **twice the bankfull depth**, ≈ 50-year stage or less | Partly FALSE, inside a round-1 fix. Rosgen's definition is twice the *maximum* bankfull depth (`vca_parameter_rationale.md:41`, `floodplain_interpretation.md:53`). The 50-year part matches the quote. | literature |
| 19 | 186-187 | flooded calls 4 the functional floodplain and 6 the valley bottom; its own reading, not a published one | TRUE vs `flood_scenarios.csv`. "Not published" is arguable for 6 (Nagel's 5–7 valley-bottom range), but on 30 m Nagel says 7, so I accept it. | none (fl_scenarios()$description could pin it) |
| 20 | 187 | This article uses 4 | TRUE | yes |
| 21 | 187-188 | Nagel: factor 7 most appropriate for valley extent on 30 m DEMs | TRUE (quote at `vca_parameter_rationale.md:49`) | literature |
| 22 | 190-191 | 38,516 / 40,640 / 42,371 / 43,155 ha at ff 2, 4, 6, 7, every other setting unchanged | TRUE (`run_vca()` uses the same inputs) | 4 tied to grid; 2/6/7 accepted G6 |
| 23 | 191-192 | 4 → 7 adds 6.2 % | TRUE | yes (> 0) |
| 24 | 196-197 | SE corner holds the Parsnip's headwaters around Arctic Lake, on the Arctic/Pacific divide | TRUE (figure: ARCTIC LAKE 10 and Arctic Pacific Lakes Park at the inset's south edge) | none |
| 25 | 197-198 | floodplain follows channels, lakes, wetlands; sits against roads, railways, reserves and parks | TRUE. The inset holds 1,777 road/trail lines, 10 railway lines, 2 reserves (Hominka 11, Arctic Lake 10) and 2 provincial parks; the figure shows contact. | none |
| 26 | 200 | map does not record which test or tidying step left a cell out | TRUE | n/a |
| 27 | 202 caption | detail: floodplain, streams with named streams labelled, **lakes and wetlands (light blue)**, roads and trails (grey), railways, parks and protected areas, reserves | Roads and trails: TRUE (RRD 313, RRS 27, RU 1,332, T 33, TS 72). Parks: the inset holds only provincial parks, so TRUE. Colour: as row 16. | none |
| 28 | 248 | not compared with floodplain mapped on the ground | TRUE | n/a |
| 29 | 248-251 | Hall R² 0.47, 1,951 field measurements, Columbia basin; width→depth from a single Idaho basin | TRUE (`vca_parameter_rationale.md:25-32`, `floodplain_interpretation.md:217-219`) | literature |
| 30 | 251-252 | the flood factor multiplies whatever error those carry | TRUE | n/a |
| 31 | 256-257 | maps terrain, not floods; no discharge/routing/return period; level relative to the streams' bankfull depth | TRUE | n/a |
| 32 | 258-260 | starts only from the streams given; a smaller or unreachable stream does not seed; ground beside it is in the map **only as measured from those streams and through the tidying** | **FALSE, inside a round-1 fix.** A third route exists: the lakes and wetlands, ORed in after the tidying with no distance test. Ablation: they add 39,354 cells (3,542 ha), and 4,086 of those (368 ha) lie more than 1,000 m from any seed stream cell (max 2,046 m), so they were not measured from those streams (finding 1). | none |
| 33 | 261 | 30 m cells; nothing narrower than a cell is resolved | TRUE | cell size computed |
| 34 | 265-266 | DEM is NRCan MRDEM-30 | TRUE | ETag test |
| 35 | 266-269 | FWA segments from link's run of 2026-10-17; upstream area and precip from fwapg; lakes, wetlands, named streams from the atlas | TRUE | digest test |
| 36 | 269-270 | Roads, railways, reserves and **parks** are from the BC Data Catalogue | OVERSTATED (low). The "parks" layer holds an ecological reserve, and the captions now say "parks and protected areas". The "roads" layer holds 1,188 trails (T 363, TS 825). Origin unrecorded (`context_carried_from` all NA). | none |
| 37 | 270-273 | built by the script, which ran this call; **one run of it** took 1.1 minutes (Apple M1 Max) | Ambiguous. `vca_seconds` (67.8 s) times one `fl_valley_confine()` call. "it" reads as the script, which runs the VCA four times plus a DEM download (my rerun of three VCA calls on the same machine took 3 m 42 s). Finding 9. | `!is.na(cpu)` |
| 38 | 276-283 | the call shown | Equivalent to `run_vca(4)` (the defaults are passed explicitly) | `ff == 4`, formals |
| 39 | 286-292 | downloads: gpkg (floodplain, streams, lakes/wetlands, map layers), grid, DEM truncated to whole metres; floodplain mapped from unrounded values | TRUE (`terra::as.int`) | md5 test |
| 40 | 296-298 | flooded v0.8.3, at commit b43e810; DOI | TRUE today. The release is local `git describe`, not checked against GitHub as link's and fresh's are (finding 7). b43e810 is not pushed yet, so the link 404s until the branch is pushed. | `!anyNA(release)` |
| 41 | 299-301 | link v0.66.0 modelled at ee21eb1, recomputed at a17e917; DOI | TRUE. The concept DOI now resolves to v0.66.5 on Zenodo; there is no coverage claim for link, so this is fine. | DOI, `!isTRUE(dirty_also)`, which passes on NA (finding 4) |
| 42 | 302-303 | fresh v0.39.0 at e247ca1 | TRUE (round 1: tag identical to commit) | `!anyNA(release)` |
| 43 | 304-305 | fwapg at commit f9718cb: FWA in PostgreSQL, **with upstream area and precipitation** | OVERSTATED. f9718cb is what the link run recorded on 2026-10-17. Upstream area and precip were read on 2026-10-19 from tables the script itself says "no link run pins and that carry no load stamp" (`wsg_vignette_data.R:231-232`). The commit is a proxy for the data state (finding 3). | none (the digest test pins the rows, not the commit) |
| 44 | 307-311 | Cite flooded as `citation("flooded")` | Prints the render-time version (accepted G11) | n/a |
| 45 | 313-315 | DOI covers its releases from v0.8.2 on and resolves to the latest | TRUE: DataCite has v0.8.2 and v0.8.3; GitHub's newest tag is v0.8.3; Zenodo's concept resolves to v0.8.3. The guard pins only the minimum; a skipped later deposit would not fire it. | `!anyNA(doi_from)`, which passes if the column is absent (finding 4) |

### Other files (sentences the branch changed)

| # | Where | Sentence (short) | Verdict and evidence | Guard |
|---|---|---|---|---|
| 46 | CLAUDE.md:50 | pars-floodplain: "numbers computed from the bundle" | Mostly TRUE. The literature figures (0.47, 1,951, 7, 50-year) are typed, and 2/4/6 come from `fl_scenarios()`. Low; covered by the next row's own carve-out. | n/a |
| 47 | CLAUDE.md:90-95 | script records VCA args and cells at 2/4/6/7; digest of every query whose rows reach the gpkg; ETag; md5; software | TRUE (carried layers are not queries in this run) | n/a |
| 48 | CLAUDE.md:97 | the test "fails when a bundled file, an fwapg query or MRDEM-30 no longer matches" | OVERSTATED. The DB and ETag tests skip on CI, on CRAN, and when the source is unreachable; the research note says "when it can reach it", CLAUDE.md does not (finding 5). | n/a |
| 49 | CLAUDE.md:98-99 | "The vignette's `stopifnot()` guards the premises of its data claims" | OVERSTATED, inside a round-1 fix. Unguarded data claims: rows 16, 19, 24, 25, 27, 32, 36, 43, and 45's completeness (finding 2). | n/a |
| 50 | CLAUDE.md:99-100 | literature figures are cited, not guarded; run from a committed tree | TRUE | n/a |
| 51 | README.md:102-103 | new title; "how much floodplain a whole watershed group holds, and how that changes with the flood level" | TRUE | n/a |
| 52 | research/bundled_stream_data.md:3 | Verified 2026-10-19; issues #87, #92, #85, fwapg#33 | TRUE | n/a |
| 53 | research/bundled_stream_data.md:30-32 | meta records row counts and a digest of every fwapg query that reaches the bundle, which the test checks when it can reach it | TRUE. The test also skips on CI/CRAN; minor. | n/a |
| 54 | script header 11-13 | DEM truncated to whole metres; the model runs on unrounded values | TRUE | n/a |
| 55 | script header 15-20 | meta contents | TRUE | n/a |
| 56 | script header 22-26 | the test fails when a written file, an fwapg query or the MRDEM-30 file no longer matches; context layers digested but not checked | TRUE with the skips (as row 48) | n/a |
| 57 | script 439-442 | "Each package is cited by its concept DOI, its last release …" | OVERSTATED, inside a round-1 fix: fresh and fwapg have no concept DOI and fwapg has no release (finding 6) | n/a |
| 58 | script 620 | `sources = sources, # every database query read: SQL and a digest of its rows` | FALSE. The `log`, `log_recompute`, `n_seg`, `fwapg_state` and `to_regclass` queries are read and not recorded. This is round 1's F9 sentence, left behind in one place (finding 6). | n/a |
| 59 | test:72-75 | "These fail when the bundle, or a source it was built from, is no longer what pars_meta.rds records" | OVERSTATED: the context-layer sources are excluded (finding 5) | n/a |
| 60 | test:101 | test name "every database source of the Parsnip bundle is unchanged" | OVERSTATED: it filters `db == "fwapg"`. True for this meta (every layer carried), false for any build that reads the share DB (finding 5). | n/a |
| 61 | test:120-121 | context layers "are drawn, never quoted" | OVERSTATED: the article states facts from them (rows 16, 25, 27, 36) | n/a |

## Mechanism

**Every one of these claims was written from the member of a set the author had in view, not from the set the
code defines.** In round 1 that was:
- roads ← resource roads, while the layer also holds trails;
- parks ← provincial parks, while the layer also holds an ecological reserve;
- "each stream", where 8 segments have no upstream area;
- "no release", where tags exist;
- "every release", where only two are archived.

**Round 1's fixes repaired the flagged sentence, not the mechanism.** Each fix reworded one instance and did not
re-enumerate the set or grep for the same sentence elsewhere. That produced three kinds of defect.

1. **A fix that lists the members it remembers.** The limits bullet (row 32) gained "and through the tidying".
   The add-on steps the code runs after the tests are tidying, the channel buffer and the waterbodies. The
   waterbodies were left out, and they are the route with no distance test (368 ha beyond 1 km).
2. **A fix that drops a qualifier from a definition.** Rosgen's definition is now "twice the bankfull depth"; the
   source says "twice the *maximum* bankfull depth" (row 18).
3. **A restated sentence in one file whose siblings remain in others.** Round 1 restated "a digest of every query
   it reads" in CLAUDE.md, the research note and the script header. The same sentence remains:
   - at script line 620 (row 58);
   - in the test's header and name (rows 59-60).

   The new CLAUDE.md sentence "the `stopifnot()` guards the premises of its data claims" (row 49) repeats round
   1's "fails when a sentence's premise does" one level down, with the same unguarded population.

The same mechanism, applied to a proxy rather than a familiar member, reaches four more places:
- "fwapg at commit f9718cb … with upstream area and precipitation": the link run's commit stands in for the state
  of tables nothing pins (row 43).
- "parks" and "roads" in the data-sources sentence (row 36), which the captions were corrected away from.
- The caption colour "light blue" for waterbodies, taken from the border, not the fill (rows 16, 27).
- The dirty-flag guards: `!isTRUE(x)` stands in for "known clean" and passes on NA (finding 4).

## Findings

1. **[false-claim]** `vignettes/pars-floodplain.Rmd:258-260`: "ground beside it is in the map only as measured
   from those streams and through the tidying". `fl_valley_confine()` ORs the lakes and wetlands in after the
   tidying with no distance, cost or flood test.
   - Measured by ablation (`waterbodies = NULL` against the full call): they add 39,354 cells (≈3,542 ha), 4,086
     of them (≈368 ha) more than 1,000 m from any seed stream cell, up to 2,046 m.
   - A wetland on the network extends along smaller streams that seed nothing.

   **Fix:** "… only as measured from those streams, through the tidying, or as part of a lake or wetland they flow
   through". Optional guard: assert that some waterbody cell lies beyond `max_width / 2` of the rasterized streams.
   **Inside round-1 fix: y.**

2. **[false-claim]** `CLAUDE.md:98-99`: "The vignette's `stopifnot()` guards the premises of its data claims"
   overstates the guards. These data claims have no guard:
   - the "light blue" waterbody colour;
   - flooded's preset labels ("functional floodplain", "valley bottom");
   - the Arctic Lake / SE-corner sentence;
   - "sits against roads, railways, reserves and parks";
   - the data-sources sentence;
   - the fwapg commit;
   - the completeness of "from v0.8.2 on";
   - finding 1's sentence.

   **Fix:** "guards the premises of its computed numbers and its claims about the model and the software", and
   name the unguarded map-description sentences. Alternatively, add the cheap guards: an `fl_scenarios()$description`
   check for the labels; Arctic Lake 10 (a reserve in the bundle) inside `inset_bbox`; `nrow()` > 0 of the cropped
   roads, railways, reserves and parks. **Inside round-1 fix: y.**

3. **[overstated]** `vignettes/pars-floodplain.Rmd:304-305`: "fwapg, at commit f9718cb: … with upstream area and
   precipitation". `meta$fwapg_sha` is "as recorded by the link run" (2026-10-17). The upstream-area and precip
   tables were read on 2026-10-19 (`fwapg_read$read_at`) and are pinned by no commit, as the script's own comment
   at lines 231-232 and `research/bundled_stream_data.md` say. **Fix:** "fwapg, at the commit link's run recorded
   (f9718cb): the Freshwater Atlas in PostgreSQL; upstream area and precipitation were read from it on
   `r meta$fwapg_read$read_at`". **Inside round-1 fix: n.**

4. **[guard fails toward pass]** `vignettes/pars-floodplain.Rmd:87, 104-106`: the guards read NA or missing
   values as clean.
   - `!isTRUE(meta$link_dirty)`, `!isTRUE(sw_row("flooded")$dirty)` and `!isTRUE(sw_row("link")$dirty_also)`
     pass on NA. A `log`/`log_recompute` row whose `link_dirty` is NULL, as in an older link run, would print
     "recomputed at a17e917" as if from a clean tree.
   - `!anyNA(sw_row("flooded")$doi_from)` and `!is.na(meta$cpu)` pass when the field is absent. `$` returns NULL,
     `!anyNA(NULL)` is TRUE, and `stopifnot(logical(0))` passes. The article would then print "from  on" or "()".

   **Fix:** `isFALSE(...)` for the dirty flags. For the strings,
   `is.character(x) && length(x) == 1L && !is.na(x)` (a small `has1()` helper). **Inside round-1 fix: y** for
   `dirty_also`, `doi_from` and `cpu`; n for the other two.

5. **[overstated, low]** The test's own text has the scope round 1 corrected elsewhere:
   - `tests/testthat/test-vignette_data.R:72-75` ("or a source it was built from") and the test name at :101
     ("every database source") overstate it, since the body keeps only `db == "fwapg"`;
   - :120-121 says the context layers are "never quoted", but the article states facts from them (rows 25, 36).
   - `CLAUDE.md:97` omits that the database and ETag checks skip on CI, on CRAN and when the source is
     unreachable.

   **Fix:** name the test "every fwapg source …", say "an fwapg source" in the header, and add "on a machine that
   reaches them" in CLAUDE.md. **Inside round-1 fix: y** (missed siblings of F9).

6. **[false-claim, low]** Two script comments overstate what the script does:
   - `data-raw/wsg_vignette_data.R:620`: "every database query read: SQL and a digest of its rows". Five other
     queries are read and not recorded.
   - :439 "Each package is cited by its concept DOI, its last release …" covers fwapg (no DOI, no release) and
     fresh (no DOI).

   **Fix:** "every query whose rows reach the gpkg", and "flooded and link by concept DOI; flooded, link and
   fresh by release". **Inside round-1 fix: y** (:439 was rewritten in round 1; :620 is F9's sentence left
   behind).

7. **[fragile, low]** `data-raw/wsg_vignette_data.R:157`: flooded's release is `git describe --tags --abbrev=0`.
   - It uses local tags only.
   - It accepts any tag name: there is no `--match 'v[0-9]*'`.
   - It is not checked against GitHub, unlike link and fresh.

   A clone missing the newest tag, or a non-release tag, would print a wrong release that `!anyNA()` accepts.
   Today it is correct: v0.8.3 is the newest tag on GitHub, and there are no non-v tags locally. **Fix:**
   `--match 'v[0-9]*'`, plus a cross-check against `repo_tags("NewGraphEnvironment/flooded")`: the tag is in that
   list and no later one is at or before `flooded_sha`, which reuses `last_release()`. **Inside round-1 fix: n.**

8. **[caption false, low]** `vignettes/pars-floodplain.Rmd:143, 202`: both captions say "lakes and wetlands
   (light blue)". The fill is `#a3cdb9`, a pale mint green, drawn at alpha 0x66/0x88 over the green floodplain,
   which every waterbody cell is. In the rendered detail map, lakes read as green-teal with a blue outline. **Fix:**
   use a blue fill (for example `#a6cee3`), or caption them "(outlined in blue)". **Inside round-1 fix: n.**

9. **[ambiguous, low]** `vignettes/pars-floodplain.Rmd:270-273`: in "built by the script, which ran this call; one
   run of it took 1.1 minutes", the "it" can be read as the script. The 67.8 s is one `fl_valley_confine()` call.
   The script also downloads the DEM and runs the model at three more flood factors. **Fix:** "the call took
   `r ...` minutes (…)". **Inside round-1 fix: n.**

10. **[overstated, low]** `vignettes/pars-floodplain.Rmd:183-185`: in "follows Rosgen's definition of flood-prone
    width, twice the bankfull depth", Rosgen's definition is twice the **maximum** bankfull depth (quote at
    `inst/research/vca_parameter_rationale.md:41`). **Fix:** "Rosgen's flood-prone width, measured at twice the
    maximum bankfull depth, which roughly matches …". **Inside round-1 fix: y.**

11. **[overstated, low]** `vignettes/pars-floodplain.Rmd:269-270`: "Roads, railways, reserves and parks are from
    the BC Data Catalogue". The captions were corrected to "parks and protected areas" and "roads and trails", but
    this sentence still names the layers by their familiar member. **Fix:** "Roads and trails, railways, reserves,
    and parks and protected areas …". **Inside round-1 fix: y** (a sibling the fix did not reach).

No defects found in these:
- **The round-1 guards I could test.** The ablations show the channel-buffer and waterbody guards discriminate:
  9,367 and 39,354 cells turn 0.
- **`repo_tags()` paging**, which is empty-page-terminated.
- **`last_release()` for fresh**, where v0.39.0 is identical to e247ca1.
- **`first_archived()`**: DataCite returns all 36 records in one page.
- **The formals guard and the `ff == 4` guard.**
- **The cpu fallback off macOS.**
