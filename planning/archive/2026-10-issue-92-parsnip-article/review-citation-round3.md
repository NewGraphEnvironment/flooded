# Review: citation diff, round 3 (full diff 371bc92..d6d11ef; round-2 fixes in 4005f97 and d6d11ef)

Reviewed on a copy at `/private/tmp/claude-501/rv_cite3/flooded` (`git archive HEAD`). Nothing in the repo
was written except this file.

## What was run

- **Workflow.** The `run:` block was extracted with `yaml::read_yaml()` and run under `bash -e` in the copy.
  The `CITATION.cff` it writes is byte-identical to the committed one (`cmp`), and
  `cffr::cff_validate()` passes (cffr 1.4.2).
- **Build and check.** `R CMD build` (vignettes rebuilt), then `R CMD check --no-manual` with the tests:
  **Status: OK**, with no notes on this machine. The tarball carries `inst/CITATION`, and no
  `CITATION.cff` or `pkgdown/`. findings.md's "one note, 'unable to verify current time'" is
  network-dependent, so it is not contradicted.
- **Render.** The copy was installed to a temp lib and the vignette rendered against it. It builds and
  every `stopifnot` term passes.
  - Table: 38,516 / 40,640 / 42,371 / 43,155 ha.
  - "adds 6.2 %" = 43,155 / 40,640 - 1.
  - The Rosgen cell renders "(Rosgen, as cited in Nagel et al. 2014)".
  - `citation("flooded")` carries `doi:10.5281/zenodo.23302790`.
- **Zenodo, live.**
  - `zenodo_versions()` was extracted verbatim. It returns the same sets as the cache: flooded has 8
    versions (v0.6.4 to v0.8.3) and link has 11 (v0.63.0 to v0.66.5).
  - Each hit's `conceptdoi` is the concept DOI queried, so `parent.id` = concept recid holds.
  - `hits.total` is an int.
  - Without `allversions=true` the total is 1, so the flag is needed.
  - On a 73-version concept (10.5281/zenodo.3509134, 3 pages), two runs gave 73 values each, 73
    unique, with identical sets, although the order within a page differs between calls.
  - Paging and limits: `size=26` is rejected (HTTP 400, "Page size cannot be greater than 25"), and a
    page past the end returns 0 hits. So "at most 25 a page" is true, and the empty-page exit works.
- **Guard mutations** (on `pars_meta.rds$software`):

  | mutation | guard |
  |---|---|
  | unchanged | TRUE |
  | flooded's v0.8.3 removed from `archived` | FALSE |
  | link's `archived` empty | FALSE |
  | `archived` column absent | FALSE |
  | release NA | FALSE |
  | release v0.7.1 (a GitHub release Zenodo skipped) | FALSE |
  | link given flooded's list | FALSE |
  | `"v0.8.3 "` (trailing space) | FALSE |
  | NA inside `archived` alongside v0.8.3 | TRUE (correct) |

  The guard tests membership, which is what its comment says.
- **`zenodo_versions()` failure modes.**
  - A non-200 response stops in `get_json()` with the status and URL. That covers a 429, and a 400 from
    a bad `size`.
  - `hits.total` NULL: `if (NA || ...)` errors, which is loud.
  - A missing `hits.hits` gives an empty vector and returns early. That is silent in the build script,
    but the vignette guard then fails.
  - A record with no version becomes NA. That can only make the guard fail, never pass it falsely.
  - 40 x 25 = 1,000 matches the stop message.
- **Text.**
  - `gh issue view 96`: "Flood factor 7 on 30 m data: package docs call it the functional floodplain;
    Nagel et al. measured valley extent", OPEN. That matches findings.md.
  - PR #95 is open on this branch.
  - The Zenodo v0.8.3 record's `notes` = the old CFF `message`, verbatim. That supports the workflow
    comment.
  - The build is recorded at 4005f97 and clean. The md5s of the three cache files match `md5_files`.

## Findings

### 1. The Rosgen secondary citation drops the year (low) - INSIDE round-2 fix (finding 7c)

`vignettes/pars-floodplain.Rmd:223`. `[Rosgen, as cited in @nagel_etal2014LandscapeScale]` renders
"(Rosgen, as cited in Nagel et al. 2014)".

- The secondary-citation form in the reference conventions carries the original's year: "Smith et al.
  (2003; as cited in Doctor 2022)". Round 2 proposed "Rosgen (1994; ...)".
- Nagel's own sentence gives the years: "Rosgen (1994, 1996) defined the flood prone extent..."
  (`inst/research/vca_parameter_rationale.md:41`).
- Without a year, a reader cannot find the original, which is the point of the form.

No guard is possible.

**Fix:** `[Rosgen 1994, 1996, as cited in @nagel_etal2014LandscapeScale]`. A bib entry for Rosgen is
optional, since the convention asks for both entries.

### 2. Round 2's remedy for its finding 4 asked for a correction line on the archived records; none was added (low) - INSIDE round-2 fix 4

Several archive files still state the DataCite-derived figures as fact:

- `planning/archive/2026-10-issue-92-parsnip-article/review-citation-round1.md:50` ("flooded from
  `doi_from` = v0.8.2, link from v0.63.0").
- `review-round1.md:57` and `:83-84` ("Zenodo holds v0.8.2 and v0.8.3 only"; "v0.1.0 to v0.8.1, 21
  tags, were never deposited"). These are false: Zenodo holds v0.6.4 to v0.8.1 too.
- `review-round2.md:65`, `review-round3.md:47`, `review-round4.md:55` ("covers v0.8.2 on").

findings.md:241ff gives the corrected counts, but it does not say they supersede these. A reader of the
archive meets the false "never deposited" first.

**Fix:** one line in findings.md's round-2 bullet. For example: "This supersedes 'from v0.8.2' and 'v0.1.0
to v0.8.1 were never deposited' in review-round1 to 4 and review-citation-round1; DataCite's text search
missed them." Keep the records unedited.

### 3. The table's names for 4 and 6, and "`flooded`'s preset", are typed literals that nothing ties to the scenario table the page already loads (low) - not a round-2 fix

`vignettes/pars-floodplain.Rmd:217-225`. The page renders live at each pkgdown build and reads
`scen <- flooded::fl_scenarios()`. The guard pins only `scen$flood_factor == c(2, 4, 6)` (`:102`).

If `inst/extdata/flood_scenarios.csv` renames ff04 or ff06, the table goes on saying "Functional
floodplain" and "Valley bottom, including terraces", sourced to "`flooded`'s preset", and nothing fails.
flooded#96 proposes editing exactly that CSV's ff04/ff06 text, though that issue concerns the
`ecological_process` text, not the description.

**Fix:** add
`identical(scen$description, c("Flood-prone width / active channel margin", "Functional floodplain", "Valley bottom extent"))`
to the "three presets" term.

## Enumeration: every text the diff adds or changes

| Where | Claim | Verdict | Guarded? |
|---|---|---|---|
| Rmd:210 | three presets 2, 4, 6 times bankfull depth | TRUE (`fl_scenarios()`) | yes (`:102`) |
| Rmd:210-211 | the names for 4 and 6 are flooded's own reading, not a published one | TRUE per `floodplain_interpretation.md` §5 (see note) | no (prose) |
| Rmd:211-212 | table adds 7, Parsnip floodplain at each, every other setting unchanged | TRUE (`modifyList(vca_args, list(flood_factor = ff))`) | rows yes (`identical(names(area_at), ...)`); settings no |
| Rmd:212 | "This article uses 4" | TRUE | printed live; `ff == 4` |
| Rmd:217-221 | Named for: flood-prone width ~50-yr or less / functional floodplain / valley bottom incl. terraces / valley extent on 30 m | TRUE (Nagel quotes at rationale :41, :49; CSV ff04/ff06) | no (finding 3) |
| Rmd:222-226 | sources: Rosgen as cited in Nagel / preset / preset / recommended for 30 m data | TRUE; Rosgen year missing (finding 1) | no |
| Rmd:227-230, kable | hectares; caption | TRUE (= `fp_area_ha`) | yes |
| Rmd:233-234 | 4 to 7 adds 6.2 % | TRUE | printed live; `area_at[["7"]] > ...` |
| Rmd:345, :349 | "DOI for all versions:" | Zenodo's label; literally 8 of 23 flooded tags | release-in-archive guard (mutation-tested) |
| Rmd:359 | `cat(cite_text)` | TRUE | DOI-in-citation guard |
| Rmd:121 comment | guard checks the release is one Zenodo archives under that DOI | TRUE (`parent.id` = concept recid, conceptdoi verified) | is the guard |
| Rmd:126 comment | citation names the DOI listed above | TRUE | is the guard |
| data-raw:508-509 comment | Zenodo itself; DataCite misses records; at most 25 a page | TRUE (measured) | n/a |
| data-raw:530 `archived_from` | the URL template | TRUE | n/a |
| workflow :27-31 comment | step 2a's recipe plus DOI after the drop plus message naming DOI; Zenodo copies message to notes; run this block locally | TRUE | n/a |
| CITATION.cff | message, doi, preferred-citation, affiliation | TRUE; byte-identical to workflow output; valid | workflow regenerates |
| inst/CITATION | skill's file plus DOI | TRUE | DOI-in-citation guard |
| DESCRIPTION, Rd | affiliation on Irvine | TRUE (skill's canonical block) | n/a |
| .Rbuildignore | excludes CITATION.cff, pkgdown | TRUE (tarball listing) | n/a |
| findings.md:224-248 | each bullet | TRUE: workflow byte for byte; #96 filed; flooded 8 from v0.6.4, link 11 to v0.66.5; the guard fires on an absent release or column | no, but see finding 2 |
| commit 4005f97 / d6d11ef messages | DataCite found flooded from v0.8.2, none of link v0.66.x; paging by 25; grid and DEM unchanged (gpkg rewritten) | TRUE (dem and valleys not in diff; md5s match) | n/a |

## Notes (not findings)

- **Row 6's name is not purely flooded's reading.** The lead-in says the names for 4 and 6 are "its own
  reading, not a published one". Row 6's "valley bottom" sits inside Nagel et al.'s published "5-7
  recommended". The CSV cites Nagel for ff06, and so does `vca_parameter_rationale.md`'s "Nagel's
  recommended ff=5-7 maps this broader extent". The reading is defensible on §5's "No paper maps
  specific ff values", and earlier rounds accepted it, so it is noted here only. A one-word scope ("the
  name it gives 4...; 6 sits in Nagel et al.'s 5-7 range") would remove the doubt.
- **The build script never checks the cited release itself.** `zenodo_versions()` does not check that
  the cited release is in what it returns, so a release that Zenodo has not yet deposited fails at
  vignette render, not at build time. An optional
  `if (!software$release[i] %in% archived) stop(...)` in the 4b loop would fail earlier.
- **Page order.** The Zenodo order within a page is not stable between calls (the cache and the live run
  differ), but the sets were identical in every run, including 3 pages of 73. No `sort=` is needed at
  current sizes.
