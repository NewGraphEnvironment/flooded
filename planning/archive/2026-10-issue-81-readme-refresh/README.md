# #81 — README refresh against soul's `readme.md`

## Outcome

The README was rewritten to soul `conventions/readme.md` (soul#416), which landed the day this
work started and reshaped the issue. In place of a capability inventory there is now:

- a summary opening that calls the output a screening map, not a field-validated floodplain;
- a Parsnip floodplain figure made by committed code (`data-raw/readme_figure.R`, gq styles);
- a tiny example on the bundled reach, with its real output;
- Learn more, Ecosystem, Data and methods, Citation and License sections, in the convention's order.

The Performance and Bankfull regression sections left the README; the roxygen and methodology
keep them.

The rest of the branch:

- **DESCRIPTION.** Title and Description changed with the tagline; New Graph Environment Ltd. was
  added as `fnd`.
- **Citation.** The citation workflow passes `authors_roles = c("aut", "cre", "fnd")`, so
  `CITATION.cff` lists exactly Allan Irvine and NGE Ltd. With the convention's `cph`, it would also
  have listed every third-party copyright holder (soul#426).
- **Licences.** `inst/NOTICE.md` records the licence of every redistributed dataset. Checking
  them turned up the Digital Road Atlas, which the BC catalogue lists as Access Only, plus two
  unconfirmed licences (the TRIM DEM and ClimateBC precipitation): #85. `LICENSE.note` now ships
  in the tarball.
- **Reference index.** The pkgdown index is grouped by purpose.
- **Timing note.** The stale threads timing was re-measured and rewritten in the roxygen, two
  vignettes and CLAUDE.md.

Three `/code-check` rounds corrected 16 published claims. Four of them sat inside an earlier round's fixes,
because the reviewer's own suggested wording had been adopted unchecked, and the loop ended on a
92-claim enumeration.

## Measurement

- **Threads timing** (`bench_threads.*`):
  - Inputs: `fl_valley_confine()` on the cached Parsnip River grid (3,749 x 3,761 at 30 m,
    flood factor 4).
  - Machine and software: Apple M1 Max with 10 cores, terra 1.9.50.
  - Wall time: 85.6 / 119.5 / 115.4 s at `threads = 1`, and 88.7 / 122.2 / 82.6 s at
    `threads = 8`. The 1-minute load average was 6-17 before the runs.
  - No threads effect could be separated from the load. terra 1.9.x already defaults to 16
    threads.
  - The old note (~3.5 -> ~1 min at 12 threads) dated from 0.0.0.9000 and did not reproduce.
  - Wrong turn: the first rewrite said threads "made no difference" and quoted CPU time. Round 2
    showed that this claimed an absence the data do not support: one matched pair favoured
    8 threads by 33 s, and CPU time cannot show a parallel speed-up. The wording now says the
    effect could not be separated from load.
- **README length:** body prose went from 406 to 600 words, against a 450-500 forecast. The
  required sections added ~300 words, and each review fix made a claim state the code's
  definition rather than dropping it.
- **Review:** the three rounds checked 62, 64 and 92 claims, with 8, 6 and 2 findings. Round 2
  found 4 defects inside round 1's fixes.

## Evidence

`planning/archive/2026-10-issue-81-readme-refresh/bench_threads*` (script, log, environment);
`review-*.md` (plan review and three code-check rounds).

Closed by: PR for #81
