# Findings — Rewrite the Parsnip vignette as a data-product article (#92)

## Issue context

**If done:** the Parsnip article opens with what it found (how much floodplain, along which streams), answers a reader's questions in their order, and fails the build when a number or a claim in it stops being true. **If never:** it stays a story about how its cache was made: a paragraph of regeneration history (0.5.0, 0.7.0, #87), a list of cached files mid-article, a dated timing on superseded inputs, and counts and issue links that go stale.

## Problem

`vignettes/pars-floodplain.Rmd` (960 words of body text, 2 figures, 2 tables):

- **No answer up front.** It never says how much floodplain it maps, or what share of the watershed group that is.
- **Author history.** The regeneration history and "measured on the 0.7.0 inputs" serve the people who built it, not a reader.
- **Typed numbers.** Most numbers are typed into the prose, not computed from the saved data: 5,597 km², 6.3 %, 48,603.1 ha, 83 to 122 s and 9,386 segments.
- **Two tables a sentence could carry:** the four parameter values and the three flood-factor presets.
- **Caching in the middle.** The "Cached inputs" section sits between the method and the maps.
- **No software citation.** Nothing says how to cite `flooded`, or which `link` and `fresh` the data came from.

## Proposed

Rewrite it as a data-product article:

- **Shape.**
  - Open with the answer.
  - Headings are the reader's questions.
  - Inputs and how the article is built go at the end, in one short section.
  - It ends with "Software and how to cite it".
- **Computed, never typed.** Every number comes from `inst/vignette-data/`, and a `stopifnot()` guards each claim's premise.
- **The data script.** `data-raw/wsg_vignette_data.R` records:
  - a digest of each database source it reads;
  - the md5 of each file it writes;
  - the package versions and commits, and each package's concept DOI with where it was looked up.
- **A test** fails when the bundle or a database source has moved since the article's data was written.


## Standard read (2026-10-19)

- NGE's conventions for articles and package vignettes: open with the answer; headings are the
  reader's questions; a plain phrase over a term; list every check with the way it points; tables
  and figures earn their place; no footnotes or `\@ref`; data from `data-raw/` only; `stopifnot()`
  per quoted number; the bundle carries provenance; software named, linked and cited (concept DOI,
  last release at or before the build, commit). A worked example in another NGE package was the
  mechanical model.
- DataCite (client cern.zenodo): flooded concept 10.5281/zenodo.23302790 (v0.8.2, v0.8.3);
  link concept 10.5281/zenodo.23264990 (v0.63.0-v0.65.1 listed; v0.66.x not indexed). fresh: none.
- link: `v0.66.0...ee21eb1` and `v0.66.0...a17e917` are "ahead"; `v0.66.1...a17e917` is "behind",
  so the last release at or before both run commits is v0.66.0.
- `fl_flood_depth()` interpolates the flood surface over stream cells with NA level (IDW), so the
  8 NA-area segments take neighbouring levels; not an article claim (cut per review), kept in
  research/bundled_stream_data.md.
- Baseline counts: 960 body words, 441 file lines, 2 figures, 2 tables (scratchpad wc_rmd.R:
  YAML and chunks removed, link reference definitions removed).

## Errors Encountered

| Error | Resolution |
|-------|------------|
| `diff -q` in an agent shell is aliased to `git diff --no-index` | `cmp -s`, or `command diff` |

## The build (2026-10-19)

- `pars_valleys.tif` and `pars_dem.tif` are byte-identical in content to #87's: same grid, identical
  values. The #87 figure of 40,969.3 ha was the whole grid, which extends 2 km past the streams and so
  past the boundary; inside the watershed group it is 40,640.1 ha (451,557 cells), the figure the
  article states. Flood factors 2 / 4 / 6 / 7: 427,950 / 451,557 / 470,793 / 479,500 cells
  (38,515.5 / 40,640.1 / 42,371.4 / 43,155.0 ha).
- `fl_valley_confine()` at flood factor 4: 71.5 s and 67.4 s over the two complete runs (Apple M1 Max, 8 threads).
- Lakes and wetlands are 20.4 % of the floodplain inside the boundary; every lake and wetland cell is
  floodplain (the guard checks it).
- Context layers were carried again (shared database unreachable); they get no source digest, only
  the gpkg md5.

## Restore-the-bug proofs (scratchpad `mutate.R`, each in a fresh copy of the package)

| mutation | fired |
|---|---|
| meta md5 of `pars_valleys.tif` | test: bundle md5 (1 failing) |
| meta digest of `streams` | test: database digests (1 failing) |
| meta `fp_cells[["4"]]` + 1 | test: cells vs grid (1 failing); render: `identical(fp_cells, ...)` |
| meta MRDEM ETag | test: DEM source (1 failing) |
| species CO / config bcfishpass / link_dirty | render: each guard by name |
| slope_threshold 10 | render: defaults-vs-`formals()` guard |
| flood_factor 6 | render: `ff == 4` |
| no "7" / area at 7 = area at 4 | render: each guard |
| flooded dirty / link DOI NA | render: each guard |
| one lake cell set to 0 (count moved to match) | render: `all(v_in[wb_cell] == 1L)` |
| control (unmutated) | 0 failing tests; renders |

The control render first failed in the citation chunk: `citation()` reads `packageDescription()` from
`dirname()` of the package path, so a copy whose folder is not named `flooded` returns NA. Renamed,
it renders. That was a fault in the probe, not in the article.

## Measure the simplification

Rendered the same way (`rmarkdown::render()` after `load_all()`), words a reader sees, code blocks
and references excluded:

| | before | after |
|---|---|---|
| prose and captions | 1,088 | 974 at the first draft; 1,031 after four review rounds |
| table words | 277 | 0 |
| reader-visible total | 1,365 | 1,031 (-24 %) |
| tables / figures | 2 / 2 | 0 / 2 |
| source body words / file lines | 960 / 441 | 918 / 345 |

The forecast was 500-600 body words, and the result missed it by about 60 %. Four things set the floor:
- The exact definition (the four tests, then the tidy-up and what is added), which the plan
  review's B1 and B2 made longer, not shorter.
- The new "How good is it?" section (B3).
- The software section, with release, commit and DOI per package.
- Map captions that do a legend's job.

## Code-check round 1 (2026-10-19) and its proofs

Round 1 found 13 issues (planning/active/review-round1.md), all fixed. Sentences:
- "rounded" became "truncated": `as.int` truncates.
- fresh is cited by its tag v0.39.0, which is identical to e247ca1.
- The DOI covers releases "from v0.8.2 on", computed from DataCite.
- Captions say "roads and trails" and "parks and protected areas".
- "each stream's" was dropped: the 8 NA-area segments seed nothing.
- The "only through" limit now names the tidying.
- Rosgen's definition is applied, not his width.
- "1,951 field measurements".
- 1,000 m printed in metres.

Overstated claims in CLAUDE.md, the research note and the script header were restated by their
definition. Script: paged tag lookup, recompute `link_dirty`, CPU fallback, `doi_from`.

New guards, each fired on a mutated copy (scratchpad `mutate2.R`, copies under a folder named `flooded`):

| mutation | fired |
|---|---|
| fresh release NA | `!anyNA(sw$release[...])` |
| flooded `doi_from` NA | `!anyNA(doi_from)` |
| recompute dirty | `!isTRUE(dirty_also)` |
| cpu NA | `!is.na(meta$cpu)` |
| one channel-buffer cell (not a lake) set to 0, count moved | `all(v_in[buf_cell] == 1L)` |
| control | 0 failing tests; renders |

## Code-check round 2 (2026-10-19)

11 findings (planning/active/review-round2.md), 7 inside or next to a round-1 fix. All fixed:
- The limit now names the lakes and wetlands. They are added with no distance test, and 4,086 of
  their cells lie more than 1,000 m from a seed stream.
- CLAUDE.md is restated: guards cover the numbers and their premises, the method description follows
  the code, and the checks skip on CI and CRAN.
- fwapg is cited at the commit link's run recorded, plus the date its tables were read.
- The flag guards use `isFALSE()`, and the string guards are `has1()`. Before, NA or an absent
  field passed.
- The test's header and name are fwapg-only.
- Script comments fixed, and `git describe --match` restricts to version tags.
- Captions give the lake fill colour.
- The run time is the `fl_valley_confine()` call.
- Rosgen's "maximum".
- The data-section layer names now match the captions.

Mechanism (round 2): claims written from the member in view, not the set the code defines. Round 1
reworded the flagged sentence rather than re-listing the set, so the same defect reappeared one step
over.

Proofs (scratchpad `mutate3.R`): `link_dirty` NA, flooded `dirty` NA, link `dirty` NA and
`dirty_also` NA each fire `isFALSE()`. With `cpu`, `doi_from` or `read_at` absent, `has1()` fires.
The control renders, with 0 failing tests. No rebuild was needed: none of the fixes changes what
the script records.

## Code-check round 3 (2026-10-19)

The enumeration covered 54 set and quantity phrases: 50 hold, and 4 findings were made, 3 of them
inside or next to round 2's fixes. All are fixed:
- Stream labels now sit on their lines, as one merged line per name with `st_point_on_surface()`
  (0 m off the line, where they were 1.3-3.0 km off), with a white halo.
- Guards now refuse:
  - an absent column (`access`, `channel_width`, `waterbody_type`) and an empty layer;
  - a missing or empty release, a malformed commit or `commit_also`, and an absent
    `link_run_date` or `vca_seconds`.
- CLAUDE.md: numbers computed from the bundle are pinned by its md5, and the guards refuse missing
  meta values and test premises.
- The script header carries the skip qualifier and "concept DOI where Zenodo archives one".
- Rosgen: "borrows the multiplier of Rosgen's flood-prone width, which he measured at twice the
  maximum bankfull depth".

Proofs (scratchpad `mutate4.R`): each of the 8 mutations fires its guard, and the control renders
with 0 failing tests.

## Code-check round 4 (2026-10-19), and the enumeration that ended the loop

Round 4 found every sentence of the article true. Its 5 findings were about guards, 2 of them
inside round 3's fixes:
- CLAUDE.md's "refuses a missing or malformed meta value and guards each sentence's premise" was
  false: it widened a quantifier again.
- The guard comment said "every value printed", but `url` and `repo` were unchecked.
- The settings guard was a subset test, so a missing setting passed.
- The fwapg test looped over the rows present, so a dropped `streams` row passed.
- The DEM test skipped, instead of failing, on an absent URL.

Fixes:
- `setequal()` on the settings, with each one numeric and finite.
- A form check (`fits()`) on every printed meta field: url, repo, commit, release, DOI, `doi_from`,
  dates, CPU, seconds, areas.
- `expect_setequal()` on the five fwapg sources.
- The DEM URL and ETag are asserted before fetching.
- CLAUDE.md names the guarded set by its members, and says what is not guarded.

Mutation proofs for the test changes (scratchpad `mutate5.R`): a dropped `streams` row and an
absent DEM URL each fail their test.

**The enumeration that ended the loop** (`planning/active/enumerate_guards.R`):
- The fields the article reads are extracted from the Rmd source by regex, not listed by hand:
  every `meta$`, `sw_row()$` and `args$` field, plus `commit` and `repo` for each package, which
  `commit_link()` reads. That gives 37 fields.
- Each field was set to NA and then removed, one at a time, in a copy, and the article's setup and
  load chunks were run each time.
- All 74 mutations stopped the chunk. The control on the restored meta passed.

The mechanism the rounds kept finding was a set described by the member in view, with each fix
re-worded in place. It is closed for guards by deriving the field list from the source. For
sentences, round 4 found all of them true.

Review spend:
- 6 review agents: the plan review and code-check rounds 1 to 4.
- One more than the usual five, because rounds 2, 3 and 4 each found defects inside the previous
  round's fixes.
- Findings by round: 13, 11, 4, 5.
