## Outcome

Rewrote `vignettes/pars-floodplain.Rmd` as a data-product article.
- **It opens with the answer:** at flood factor 4, 40,640 ha of floodplain, 7.3 % of the Parsnip
  River watershed group, along 2,314 km of streams bull trout can reach.
- **Its headings are the reader's questions:** what the map shows, which flood level to use, how to
  read it, how good it is, and its limits.
- **Inputs and how it was built** take one short section at the end, followed by the software and
  how to cite it.

The regeneration history, the mid-article cache section, the dated timing, the issue link for the
missing upstream areas and both tables are gone.

Every number is computed from the bundle.
- **`data-raw/wsg_vignette_data.R` records:**
  - the VCA arguments and the floodplain cells at flood factors 2, 4, 6 and 7;
  - a Postgres digest of every fwapg query whose rows reach the gpkg;
  - the MRDEM-30 ETag and the md5 of each file written;
  - the software (release, commit, and concept DOI where Zenodo archives one).
- **`tests/testthat/test-vignette_data.R` fails** when any of that moves.

What was learned:
- **The review loop.** A plan review and four code-check rounds were needed. Rounds 2 to 4 each found
  defects inside or next to the previous round's fixes, always the same mechanism: a set described by
  the member in view (roads that include trails, "each stream" with exceptions, "every release" with
  two archived, guards that pass on an absent field), with each fix reworded in place.
- **What ended it.** For guards, an enumeration that extracts the 37 fields the article reads from
  its source and mutates each one (`enumerate_guards.R`). For sentences, round 4 found all of them
  true.

## Measurement

- **The grid did not change.** The rebuilt `pars_valleys.tif` and `pars_dem.tif` are identical in
  value to #87's.
- **The headline area was measured differently.** #87's 40,969.3 ha was the whole grid, which
  reaches 2 km past the streams and so past the boundary. Inside the boundary it is 451,557 cells,
  40,640.1 ha. That is the figure the article quotes, and it is recorded in
  `research/bundled_stream_data.md`.
- **Floodplain by flood factor:** 2 / 4 / 6 / 7 give 38,515.5 / 40,640.1 / 42,371.4 / 43,155.0 ha.
  Going from 4 to 7 adds 6.2 %.
- **Lakes and wetlands** are 20.4 % of the floodplain at flood factor 4.
- **Run time:** one `fl_valley_confine()` call took 71.5 s and 67.4 s in two runs (Apple M1 Max,
  8 threads).
- **Words a reader sees,** rendered the same way, without code or references: 1,365 before (1,088
  prose and captions plus 277 table words) and 1,031 after, a 24 % cut. Tables went from 2 to 0, and
  figures stayed at 2.
- **The forecast missed.** The plan forecast 500-600 body words. Four things set the floor: the
  exact definition the reviews required, the "How good is it?" section, the software citations, and
  map captions that do a legend's job.
- **Review spend:**
  - 6 review agents: the plan review and code-check rounds 1 to 4.
  - Findings by round: 13, 11, 4, 5.
  - Every guard and test added was shown to fail on a mutated copy (tables in `findings.md`).

## Evidence

- `review-plan.md`, `review-round*.md`: each review, with its findings.
- `findings.md`: what was done about each finding, and the mutation tables.
- `enumerate_guards.R`: the enumeration of the 37 fields, each mutated.

Closed by: PR (see `/gh-pr-push`), Closes #92. Follow-ups: #93, #94.
