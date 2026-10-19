# Review: citation diff, round 2 (371bc92..111afcc; round-1 fixes in 111afcc)

Reviewed on copies under `/private/tmp/claude-501/rv_cite2/` (`git archive HEAD`); nothing in the repo
was written except this file.

## What was run

- Workflow `run:` block extracted with `yaml::read_yaml()`, run under `bash -e` in the copy: the
  `CITATION.cff` it writes is **byte-identical** (`cmp`) to the committed one; `cffr::cff_validate()`
  passes (cffr 1.4.2).
- Copy installed to a temp lib (`R CMD INSTALL`), vignette rendered against it: builds, every
  `stopifnot` term passes. Rendered table and prose read as quoted below; `citation("flooded")` text
  carries `doi:10.5281/zenodo.23302790`; "adds 6.2 %" = 43,155 / 40,640 - 1.
- Coverage guard mutation-tested on `pars_meta.rds$software`: link release `v0.62.9` -> FALSE;
  `doi_from` NA -> FALSE; `doi_from` column absent -> FALSE; `v0.10.0` vs `v0.9.0` -> TRUE (numeric
  compare, not string). `stopifnot(ff == 4)` with `ff <- NULL` passes (see 6).
- Zenodo API (`/api/records?q=parent.id:<recid>&allversions=true&size=25`), DataCite (the build's own
  query) and `gh release list` for flooded and link (see 4).

## Findings

### 1. "The names come from finer elevation data" is false for row 7 and for row 2 (medium) - INSIDE round-1 fix 1

`vignettes/pars-floodplain.Rmd:236`. "The names" covers the whole table just above it. Row 7's name is
"Valley extent on 30 m elevation models", set on 30 m data (Nagel, `vca_parameter_rationale.md:49`), so
it does not come from finer data. Row 2's name is Rosgen's flood-prone width, a field-surveyed width
(`vca_parameter_rationale.md:41`), not an elevation model. Row 6's "valley bottom" rests on Nagel's
5-7 range, whose 7 is the 30 m value. Only row 4 (Hall's 10 m, compensated for 25 m TRIM, per
`flood_scenarios.csv`) clearly fits. No guard can see it.
Fix: scope it ("The names for 2, 4 and 6 were set on field surveys and 10-25 m elevation data") or drop
the sentence and let the next one carry the point.

### 2. "here 4 is a conservative functional floodplain, and 6 comes close to a functional floodplain" restates a derived reading that the primary source does not support (medium) - INSIDE round-1 fix 1

`vignettes/pars-floodplain.Rmd:236-237`. Source chain: `inst/extdata/flood_scenarios.csv` (ff04, ff06
descriptions), `inst/notes/methodology.md:72-77`, `floodplain_interpretation.md` section 3 ("30 m MRDEM | up to
7" for "the same real floodplain") and `R/fl_scenarios.R:21-30` all treat Nagel's 30 m factor of 7 as
the 30 m equivalent of a **functional floodplain**. The primary quote (`vca_parameter_rationale.md:49`)
is about **valley extent**: "a flood factor of seven is most appropriate for 30-m DEMs ... (7 vs. 5)",
i.e. the 30 m equivalent of Clarke's/Nagel's 5 at 10 m. `vca_parameter_rationale.md:66` reads it that
way ("30m DEM: ff=7 needed for valley bottom"), and so does this article's own row 7 ("Valley extent on
30 m elevation models"). Applying Nagel's own 7:5 ratio to Hall's 3 gives about 4.2 at 30 m, so the
primary supports neither "6 comes close to a functional floodplain" nor clearly "4 is conservative".
Those package documents share one ancestor and corroborate each other only. The page now says that at
30 m, 7 is valley extent and 6 is close to a functional floodplain, and states that as fact while the
lead-in calls the names for 4 and 6 "its own reading". Nothing guards it, and nothing measured it: on
this grid 4 -> 6 adds 4.3 % and 4 -> 7 adds 6.2 % (`methodology.md:101`, the flood mask hardly binds at 30 m).
Fix: keep only what the primary supports, attributed: e.g. "Nagel et al. found 7 suited to 30 m data
where 5 suits 10 m, so on this model each level maps less ground than its name suggests." Drop the
"6 comes close" clause. File the package-wide inconsistency separately (CSV ff04/ff06 text,
`methodology.md:72-77`, `floodplain_interpretation.md` section 3, `fl_scenarios.R` table vs
`vca_parameter_rationale.md:66`).

### 3. The sentence hard-codes "30 m" and "here", and the new guard does not pin the resolution (low) - INSIDE round-1 fix 1

`vignettes/pars-floodplain.Rmd:89-90` and `:236`. The new term's comment says it covers "here 4 is ...,
and 6 ...", but it pins only `ff == 4` and the presence of names "4" and "6". The claim depends on the
grid being 30 m, and elsewhere the page prints `` `r cell_m` `` rather than a literal. A rebuild on
another `res` (`fl_dem_aoi(res =)`) would leave "On a 30 m model ... here 4 is ..." standing, with no
guard to fail. Today `terra::res(valleys)` is `30 30`.
Fix: add `isTRUE(all.equal(terra::res(valleys), c(30, 30)))` to that term, or print `` `r cell_m` ``
and pin it.

### 4. The coverage guard tests ordering, not archiving, and its lower bound is wrong (low-medium) - INSIDE round-1 fix 2

`vignettes/pars-floodplain.Rmd:123-128`. The comment says "the release each cites is one the DOI
archives". The term checks `release >= doi_from`. Measured against Zenodo:

- **Releases are skipped.** flooded's concept record (parent 23302790) holds 8 versions: v0.6.4, v0.6.5,
  v0.7.0, v0.7.2, v0.8.0, v0.8.1, v0.8.2, v0.8.3. GitHub releases v0.6.6 and v0.7.1 have no Zenodo
  record. A rebuild citing v0.7.1 would pass this guard although the DOI does not archive it.
- **`doi_from` is wrong.** `pars_meta.rds` says flooded `v0.8.2`, but Zenodo archives from **v0.6.4**.
  `first_archived()` in `data-raw/wsg_vignette_data.R:508-515` takes the minimum over DataCite's text
  search (`"New Graph Environment" OR NewGraphEnvironment`), which returns 3 flooded records (v0.8.2,
  and v0.8.3 twice) and misses the earlier ones. The likely reason is that those records predate the
  affiliation, but that is not verified. The same search returns link v0.63.0 to v0.65.1 and misses
  v0.66.0 to v0.66.5, which Zenodo holds. Here the error makes the guard stricter, not looser. But the
  round-1 record states "flooded from `doi_from` = v0.8.2" as fact (`review-citation-round1.md`
  finding 2), and so does `review-round4.md:55`, and round 1 suggested printing it.
- Today the page is right: flooded v0.8.3 is `10.5281/zenodo.23438854` and link v0.66.0 is
  `10.5281/zenodo.23425580`.

Fix: have the build read the archived versions from Zenodo itself
(`GET https://zenodo.org/api/records?q=parent.id:<concept recid>&allversions=true&size=25`, paged)
and store them. Guard `r$release %in% r$archived[[1]]`, or store `archived_release = TRUE/FALSE`. Drop
`doi_from`, or derive it from that list. Add one correction line to the archived round-1 record rather
than rewriting it.

### 5. The new message has no referent on Zenodo either, and the workflow comment says it does (low) - INSIDE round-1 fixes 4 and 6

`.github/workflows/update-citation-cff.yaml:29` and `:39`, `CITATION.cff:7`. Zenodo copies `message`
into each record's notes verbatim: every flooded record's notes read `To cite package "flooded" in
publications use:` today. On a Zenodo record page "the metadata from this file" names no visible file:
the record shows a zip, and `CITATION.cff` sits inside it. So the comment's "a message that reads whole
in Zenodo's record notes" is overstated. It reads whole only on GitHub, where it is CFF's reference
wording.
Fix: either drop the Zenodo claim from the comment, or use a message that carries its own referent,
built from the DOI so the DOI is not typed twice:
`x$message <- paste0("If you use flooded, please cite it by its DOI, ", x$doi, ".")`. Then regenerate
and `cmp`.

### 6. `ff == 4` now appears twice; the new copy runs before the type checks and passes on NULL (cosmetic)

`vignettes/pars-floodplain.Rmd:90` and `:100`. `stopifnot(logical(0))` passes, so with `flood_factor`
absent the new first term passes. Later terms still stop the build:
`meta$fp_cells[[as.character(NULL)]]` errors, and `setequal(names(args), ...)` fails. Also,
`all(c("4", "6") %in% names(meta$fp_cells))` is implied by
`identical(names(area_at), c("2", "4", "6", "7"))` together with
`identical(names(area_at), names(meta$fp_cells))`.
Fix: one `isTRUE(ff == 4)` term carrying both comments, plus the resolution term from 3.

### 7. Smaller text points (cosmetic; the first two are inside round-1 fix 1)

- `:222` "(used here)" now sits in a column headed "Named for", where it reads as part of the name.
  Move it to the "Where the level comes from" cell or the Flood factor cell ("4 (used here)").
- `:237` is about 115 characters, against the file's ~100-character wrap.
- `:226` (not a round-1 fix): row 2 credits Rosgen's multiplier but cites only Nagel. The reference
  convention for an unavailable original is "Rosgen (1994; as cited in Nagel et al. 2014)".

## Notes (not introduced by round 1)

- "DOI for all versions" (`:349`, `:353`) is Zenodo's own label. Literally, flooded's concept DOI holds 8
  of its 23 tags (10 GitHub releases; v0.1.0 to v0.6.3 predate it). The label was asked for, and
  finding 4's guard is what keeps the cited release inside it.

## Checked and clean

- Workflow block = committed `CITATION.cff`, byte for byte; valid CFF. The DOI is set after
  `x$doi <- NULL` (line order). The comment's "no CRAN-namesake DOI or page, the firm as publisher in
  preferred-citation" matches skill step 2a. "run this block, not the skill's" is right: the skill's
  `pc` intersect has no `"doi"` and sets no message, so a skill run would drop both.
  `/gh-pr-merge` relies on this workflow and does not run the skill recipe.
- Table cells: row 2's name and source match `vca_parameter_rationale.md:41`. "Recommended for 30 m
  data" matches "most appropriate for 30-m DEMs" (`:49`). "Where the level comes from" for 4 and 6 is
  "`flooded`'s preset", which matches `flood_scenarios.csv`. Hectares match `fp_area_ha`. "with every
  other setting unchanged" holds (round 1).
- The coverage guard handles NA, NULL, an absent column and zero rows, the last through the earlier
  `nrow(r) == 1L` term. `package_version` compares numerically.
- `grepl(concept_doi, cite_text)` fails against an installed flooded without `inst/CITATION`: the
  local library has 0.8.2 with no CITATION, so build the vignette against an install of this tree.
- `lst()` removal leaves no caller. Nothing else in the repo quotes the old message or "cite it as
  below".
