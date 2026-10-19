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

- soul `writing.md` at origin/main (da23ae5 bullets: open with the answer; plain phrase over a term;
  list every check with the way it points), `readme.md` rule 9, `pkgdown-publishing.md` (no
  footnotes), `r-packages.md` Vignettes (no `\@ref`, data-raw only, stopifnot per quoted number,
  bundle carries provenance), soul#466 / #471 / #40 bodies, knowledge's chinook rearing article
  (vignette, data script, test) as the mechanical model.
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
