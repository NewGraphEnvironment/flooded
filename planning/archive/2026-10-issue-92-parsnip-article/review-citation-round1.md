# Review: citation diff, round 1 (371bc92, 65134ba, 0ff6772)

Reviewed on a copy (`/private/tmp/claude-501/rv_cite1/flooded`, from `git archive HEAD`); the repo was not touched.

## What was run

- Workflow `run:` block extracted with `yaml::read_yaml()` and run under `bash -e` in the copy: writes
  a `CITATION.cff` **byte-identical** (`cmp`) to the committed one; `cffr::cff_validate()` passes
  (cffr 1.4.2). The R uses only double quotes and backticks, so single-quoting the `-e` is safe; it
  is valid YAML (a literal block).
- `R CMD build --no-build-vignettes` then install to a temp lib: the tarball carries `inst/CITATION`,
  no `CITATION.cff`, no `pkgdown/`. `R CMD check --no-tests --ignore-vignettes`: Status OK (no
  CITATION complaint).
- `citation("flooded")` text: `Irvine A (2026). _flooded: ..._. New Graph Environment Ltd.
  doi:10.5281/zenodo.23302790 <...>, Version 0.8.3, <https://github.com/NewGraphEnvironment/flooded>.`
  `toBibtex()`: `@Manual{flooded, author = {Allan Irvine}, organization = {New Graph Environment Ltd.},
  version, note = {Version 0.8.3}, url (GitHub only), doi}`. Firm is not an author anywhere.
- `knitr::write_bib("flooded")` (knitr 1.52, xfun 0.60): writes `R-flooded` (no organization) **and**
  `flooded` (with organization, version, DOI), as the skill says.
- Rendered `vignettes/pars-floodplain.Rmd` from the copy against the temp lib: builds; the table's
  `[@nagel_etal2014LandscapeScale]` cells resolve to "(Nagel et al. 2014)"; hectares 38,516 / 40,640 /
  42,371 / 43,155 match `fp_cells * 0.09`; "adds 6.2 %" = 43,155 / 40,640 - 1.
- Zenodo's CFF reader (`zenodo/zenodo-rdm`, `site/zenodo_rdm/github/schemas.py`) takes only
  `abstract`, `authors` (name, affiliation, orcid), `keywords`, `license`, `title` and `message`
  (as `notes`); `doi` and `preferred-citation` are ignored. No `.zenodo.json` in the repo, so the
  CFF authors list (Irvine only, with affiliation) is what becomes creators. Correct.

## Findings

### 1. The "What it maps" column states fixed classes the package's own scenario table says not to read on 30 m data (medium)

`vignettes/pars-floodplain.Rmd:213-218`. The old prose said "`flooded` calls 4 the functional
floodplain and 6 the valley bottom" (a naming claim). The column header now asserts what each level
*maps* on this article's 30 m MRDEM. `inst/extdata/flood_scenarios.csv` says the opposite for this
resolution: ff04 "On 30m MRDEM ... is a conservative functional floodplain there rather than a
centred one"; ff06 "On 30m MRDEM this is also close to the resolution-equivalent functional
floodplain, so read it against the DEM resolution rather than as a fixed ecological class."
`floodplain_interpretation.md` §3 (DEM table: 30 m needs "up to 7" for the same real floodplain)
agrees. Inside the table, rows 6 ("Valley bottom, including terraces") and 7 ("Valley extent on
30 m elevation models", Nagel's valley-bottom answer for 30 m) both claim the valley bottom on the
same DEM, which a reader cannot reconcile.
Fix: retitle the column to what it is, e.g. "Named for" / "What the level is named for", and add
one clause to the lead-in or the 7 row that on a 30 m model each level maps less than its name
(Nagel's 7 for 30 m is the resolution compensation), per the CSV.

### 2. "DOI for all versions" sits beside a release nothing checks it covers; the coverage guard was dropped (low-medium)

`vignettes/pars-floodplain.Rmd:340-344` and the removed guard at old line 121
(`fits(sw_row("flooded")$doi_from, ...)`) plus the removed prose "covers its releases from
v0.8.2 on". The concept DOI covers only releases Zenodo archived: flooded from `doi_from` = v0.8.2,
link from v0.63.0 (`pars_meta.rds`), not v0.1.0 onward, so "all versions" is Zenodo's term, not a
literal claim. The labels are what was asked for, but the page now implies the listed release
(v0.8.3, v0.66.0) is under that DOI and nothing checks it; `software$doi_from` is still built by
`data-raw/wsg_vignette_data.R:518-523` and is now read by nothing.
Fix: guard coverage instead of format, for both packages, e.g.
`package_version(sub("^v", "", sw_row(p)$release)) >= package_version(sub("^v", "", sw_row(p)$doi_from))`
for `p` in flooded and link. Optionally keep "(releases from `r doi_from` on)" after the label.

### 3. `lst()` is orphaned by this diff (low)

`vignettes/pars-floodplain.Rmd:83`. Its only use (the removed "Parsnip's floodplain is ... at flood
factors ..." sentence) is gone; `grep` finds no other call. Remove it.

### 4. The new CFF `message` dangles on Zenodo (low)

`CITATION.cff:7` and `.github/workflows/update-citation-cff.yaml` (`x$message <- ...`). Zenodo
copies `message` into each release record's notes (`notes = SanitizedHTML(data_key="message")`),
where "please cite it as below" points at nothing. The CFF reference message, "If you use this
software, please cite it using the metadata from this file.", is a complete sentence that reads
correctly in both places, e.g. "If you use flooded, please cite it using the metadata from this
file." Change it in the workflow, regenerate, and keep both in step.

### 5. Row 7 names Nagel twice (cosmetic)

`vignettes/pars-floodplain.Rmd:221`. Renders as "Nagel et al.'s choice for 30 m data (Nagel et al.
2014)". Use "Chosen for 30 m data [@nagel_etal2014LandscapeScale]" or a narrative
`@nagel_etal2014LandscapeScale`.

### 6. The workflow is not the skill's recipe, though its comment says "Same recipe" (low)

`.github/workflows/update-citation-cff.yaml:27-29`. It adds a `message` override (and `doi` in
`preferred-citation`, which the comment covers). A local `/citation-cff` run, whose recipe sets no
message, rewrites `message` to cffr's default, and the workflow flips it back at the next
DESCRIPTION push: churn. Either name the message override in the comment and remember it locally,
or raise it in soul for the skill.

## Notes (not introduced by this diff)

- `cite_text` prints the *installed* version ("Version 0.8.3"); the bullet above it prints the
  version that built the cache (`sw_row("flooded")$release`). They agree today and diverge at the
  next release unless the cache is rebuilt. The old code had the same behaviour.

## Checked and clean

- DESCRIPTION Authors@R: Irvine has the firm as `affiliation`; the firm is `cph`/`fnd` only.
- CITATION.cff: authors and contact name only Irvine (ORCID, affiliation); `doi` set;
  `preferred-citation` has type software, publisher the firm, the DOI, version, date, url,
  repository-code, license. No CRAN DOI/repository/identifiers.
- Workflow sets `x$doi` after the CRAN drop; default `authors_roles` (aut, cre) excludes the firm.
- inst/CITATION matches the skill plus `doi`; R CMD check accepts it; url takes the first URL only.
- `.Rbuildignore`: `^CITATION\.cff$` and `^pkgdown$` are anchored and escaped; nothing the build
  needs is excluded (pkgdown builds from source; `pkgdown/` holds only favicons).
- Guard `identical(names(area_at), c("2", "4", "6", "7"))` can fail and pins the row order the
  hard-coded labels assume; `ff == 4` (line 99) pins "(used here)".
- Guard `grepl(concept_doi, cite_text, fixed = TRUE)` can fail (no DOI in `inst/CITATION`, or a
  stale installed flooded without it); the DOI has no whitespace, so the text wrap cannot split it.
- Lead-in "the names it gives 4 and 6 are its own reading, not a published one" agrees with
  `floodplain_interpretation.md` §5 ("The ecological labels on our scenarios are our interpretive
  framework"). Row 2 matches the Rosgen quote in `vca_parameter_rationale.md:41`; row 7 matches
  the Nagel quote at line 49. "with every other setting unchanged" matches
  `data-raw/wsg_vignette_data.R:561` (`modifyList(vca_args, list(flood_factor = ff))`).
