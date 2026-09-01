# Progress — Bankfull regression units (#49)

## Session 2026-08-31

- Plan-mode exploration — phases approved by user
- Verified the issue's arithmetic independently: 8.2224x width, 3.5926x depth, as-coded ff04 ==
  corrected ff14.37
- Found two traps that would have produced a green suite over a broken fix (see `findings.md`):
  Nagel's combined form is an algebraic identity and cannot be the units oracle; no existing test
  pins an absolute value
- User decisions: keep ff 2/4/6 + resolution guidance; `precip = NULL` default; #47 stays separate
- Created branch `49-bankfull-regression-is-fed-hectares-and` off main
- Scaffolded PWF baseline with approved phases
- Next: Phase 1 — the literal-value units test, confirmed failing before any `R/` edit
