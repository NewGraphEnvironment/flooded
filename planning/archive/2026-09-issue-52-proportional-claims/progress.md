# Progress — 'proportional claims stand' needs the counter-case (#52)

## Session 2026-09-01

- Plan-mode exploration — measured both sides of the `fp_pct_aoi` claim from cached artifacts
  rather than taking the issue's numbers on trust; 8.67% -> 7.35% confirmed.
- Two forks put to the user: which figure pair to quote (8.67% with sources named), and release
  bookkeeping (none — docs-only).
- Created branch `52-floodplain-interpretation-proportional-claims-counter-case` off main.
- Scaffolded PWF baseline with approved phases.
- Next: Phase 1, amend section 4 of `inst/notes/floodplain_interpretation.md`.
- Phase 1 — rewrote section 4's "proportional claims stand" sentence as a test (does the denominator
  sit inside or outside the region the fix moved), with one worked example of each shape.
- Phase 2 — swept `methodology.md`, `pars-floodplain.Rmd` and `NEWS.md`: no other instance. Updated
  `CLAUDE.md`'s design-decision entry to match.
- **Six `/code-check` rounds**, 36 findings, 14 of them bugs. Round 1 found the published figure was
  the *clipped* layer (48,116 ha / 8.6%), not the raw one I had measured. Round 4 named the
  mechanism behind every round's findings — fixes that widened a scope quantifier over an
  unenumerated population. Round 6 terminated it by reproducing 0.4.1 exactly and measuring the
  whole appendix rollup.
- `devtools::test()`: FAIL 0 | WARN 0 | SKIP 0 | PASS 274.
- Docs-only: no version bump, no NEWS entry. v0.6.0 stands.
