# Task: Rewrite the Parsnip vignette as a data-product article: answer first, computed numbers, cited software (#92)

## Problem

`vignettes/pars-floodplain.Rmd` (960 words of body text, 2 figures, 2 tables):

- **No answer up front.** It never says how much floodplain it maps, or what share of the watershed group that is.
- **Author history.** The regeneration history and "measured on the 0.7.0 inputs" serve the people who built it, not a reader.
- **Typed numbers.** Most numbers are typed into the prose, not computed from the saved data: 5,597 km², 6.3 %, 48,603.1 ha, 83 to 122 s and 9,386 segments.
- **Two tables a sentence could carry:** the four parameter values and the three flood-factor presets.
- **Caching in the middle.** The "Cached inputs" section sits between the method and the maps.
- **No software citation.** Nothing says how to cite `flooded`, or which `link` and `fresh` the data came from.

## Context (plan)

`vignettes/pars-floodplain.Rmd` reads as the story of how its cache was made: a paragraph of
regeneration history (0.5.0 / 0.7.0 / #87), a "Cached inputs" section mid-article, a dated
timing on superseded inputs, typed numbers (5,597 km², 6.3 %, 83–122 s), a count of NA-area
segments with an fwapg#33 link, and two tables a sentence could carry. It never states how much
floodplain it maps. Rewrite it to NGE's article standard (soul `writing.md` at da23ae5, soul#466 /
#471 / #40 applied by hand), using knowledge's chinook rearing article as the mechanical model.

Baseline (measured): 960 body words, 441 file lines, 2 figures, 2 tables.
Forecast: ~500–600 body words, 2 figures, 0 tables.

**Decided:**
- **Branch:** stacked on `87-build-the-bundled-and-vignette-data-from`. The PR targets that
  branch, and is retargeted to main once #91 merges.
- **Scope:** the Parsnip vignette only. Issues are filed for the other two vignettes.

## Outline the article will have

Title: "Floodplains of the Parsnip River watershed group".

Opening, no heading. It says what the R package `flooded` is, with a link to its site. Then
**The answer**: at flood factor 4, `flooded` maps *X* ha of floodplain in the Parsnip River
watershed group. That is *Y* % of its *Z* km², along *W* km of streams of order 3 and up that bull
trout can reach. Every one of those numbers is computed inline.

1. **What does the map show?** The definition in plain words: ground that meets all three tests.
   - It is gently sloped.
   - It is near a stream, both in a straight line and in a distance that counts steep ground as farther.
   - It lies below a water level set at 4 × bankfull depth, with bankfull depth from upstream area
     and precipitation [@hall].

   Lakes and wetlands on those streams are added, and so are the streams that seed the map.
   **Full map (kept):** where the floodplain lies is the product, and no sentence can carry that.
2. **Which flood level should I use?** The three presets, and why 4 is used here.
   - **Side analysis, inside this section:** the data script also runs flood factors 2, 6 and 7, so
     one sentence gives the area at each, computed.
   - The resolution note, with its citation: Nagel et al. put a 30 m grid's equivalent near 7.
   - **No table.** The parameter and scenario tables are cut and their values go into sentences
     (cited).
3. **How do I read it up close?** The south-east detail of the Arctic Lake headwaters.
   - **Detail map (kept):** it shows how the floodplain sits against channels, lakes, roads, rail
     and reserves at a working scale, which the full map cannot show at page width.
   - **Map titles removed:** the cartography rule puts the title in the caption.
4. **What should you know before using it?** Limits, one sentence each, about what the product does.
   - It is built only from streams of order 3 and up that bull trout can reach.
   - A 30 m grid smooths narrow valley floors.
   - It maps terrain, not how often ground floods.
   - It does not say which test excluded a cell.

   Each premise is checked against `inst/notes/floodplain_interpretation.md` and the code, and only
   what holds survives.
5. **Data and how it was built.** This is the one place for inputs, and it is short:
   - MRDEM-30;
   - the Freshwater Atlas through fwapg, with upstream area and precipitation;
   - `link`'s `default` configuration, with its version and date;
   - one link to `data-raw/wsg_vignette_data.R`;
   - one download line;
   - one clause on run time, computed from the recorded run.
6. **Software and how to cite it**, computed from meta. Each package gets a link, its last release
   at or before the build, its commit, and its concept DOI where one exists:
   - `flooded`: 10.5281/zenodo.23302790 (DataCite);
   - `link` v0.66.0: 10.5281/zenodo.23264990. Modelled at `ee21eb1` and recomputed at `a17e917`,
     both after the v0.66.0 tag and before v0.66.1 (checked through the GitHub compare API);
   - `fresh`: no release, so its commit;
   - fwapg: its commit, as an external tool.

   Then `format(citation("flooded"), style = "text")` and the concept DOI.
7. References.

**Cut:**
- the regeneration history;
- "Cached inputs" and the file list mid-article;
- the dated timing;
- the NA-upstream-area count and the fwapg#33 link (still in `research/bundled_stream_data.md`);
- the Arctic-drainage travelogue beyond one clause;
- "Why floodplains" (reduced to the clause in the opening);
- `xciter` helper chunks.

## Phase 1: Data script records what the article states
- [x] `data-raw/wsg_vignette_data.R`: pass the VCA arguments explicitly from `fl_params()`
      defaults plus `flood_factor = 4`, and save them in meta (`vca_args`).
- [x] Also run `fl_valley_confine()` at flood factors 2, 6 and 7 on the same inputs. Save each
      area within the watershed group boundary in meta. Only ff4 is written as `pars_valleys.tif`.
- [x] Record `fl_valley_confine()` elapsed seconds for ff4 and the machine's CPU name.
- [x] Source digests. For each database query (aoi, streams, waterbodies, named_streams, and the
      context layers when read live), save its SQL in meta and a Postgres digest of its rows:
      `md5(string_agg(md5(t::text), '' ORDER BY md5(t::text)))`.
      - Carried context layers record NA.
      - Record the MRDEM-30 COG's ETag.
- [x] Record the md5 of every file written (`pars.gpkg`, `pars_dem.tif`, `pars_valleys.tif`).
- [x] Software table in meta:
      - `flooded`: version, last tag at or before HEAD (`git describe`), commit, dirty flag;
      - `fresh`: installed version and RemoteSha, plus the run's `fresh_version`;
      - `link`: the run's version and both commits, with the tag checked to be at or before them
        through the GitHub compare API;
      - fwapg: commit.
- [x] Concept DOIs from DataCite (`client-id=cern.zenodo`; concept = the `IsVersionOf` relation),
      saved with the query URL and the date retrieved. The script stops if a package listed as
      having one returns no single concept DOI.
- [x] Commit the script, then run it from the committed tree, so the recorded commit is clean.
      Commit the regenerated bundle.

## Phase 2: Tests that fail when the article's data is superseded
- [x] `tests/testthat/test-vignette_data.R`: the md5 of each bundled Parsnip file equals meta's.
      Always runs.
- [x] The database digests equal meta's when fwapg / `fresh_default` is reachable. This test
      skips on CI and CRAN and when there is no connection; it also skips carried layers.
- [x] Meta's ff4 area equals the cells of `pars_valleys.tif` inside the AOI, so the two are one
      fact from one run.
- [x] Prove each fires: alter a copied bundle file, a digest and the area, and the test reddens
      (in scratch copies).

## Phase 3: Rewrite `vignettes/pars-floodplain.Rmd`
- [x] Apply the outline above, with `echo = FALSE` throughout, as in the chinook article.
- [x] Compute every number inline. Formatting helpers live in the load chunk.
- [x] Add a `stopifnot()` for each claim's premise. Among them:
      - the flood-factor areas rise with the factor;
      - meta's `species == "BT"`, `link_config == "default"`, min order 3 and access in {1,2};
      - the VCA args equal the `fl_params()` defaults, except `flood_factor`;
      - the inline area equals meta's ff4 area;
      - the software rows hold a DOI for `flooded` and `link`.
- [x] Remove `main =` map titles and shorten the captions so they say what is drawn and what is
      left off.
- [x] Prove a guard fires on a false premise (an altered meta copy) by rendering against it.

## Phase 4: Ripple
- [x] DESCRIPTION: drop `xciter` from Suggests and Remotes. Only this vignette used it; confirm
      with a grep.
- [x] README "Learn more" line, and CLAUDE.md's architecture line and design-decision bullet:
      match the new title and the meta fields.
- [x] `_pkgdown.yml`: check the articles listing still resolves.

## Validation
- [ ] Render with `rmarkdown::render()` after `pkgload::load_all()`, plus `pkgdown::build_article()`.
      In the HTML, confirm there are no `footnote-ref` and no literal `\@ref`.
- [ ] Word, line, table and figure counts before and after, against the forecast. Name what set
      the floor.
- [ ] `devtools::test()`, `R CMD check`, `pkgdown::check_pkgdown()`, lintr (no increase).
- [ ] `/code-check branch`. Reviewers work on copies, list every added or changed sentence with a
      verdict against the data and whether a guard fails if it turns false, and continue until an
      enumeration round finds nothing. Report the agent count.
- [ ] PWF checkboxes match landed work; `/planning-archive`; `/gh-pr-push`.

## Out of scope (named, not done)
- `valley-confinement.Rmd` and `stac-dem.Rmd` to the same standard. Each needs its own issue,
  filed at the end.
- The roads licence (#85). The download line points at the gpkg as today.
