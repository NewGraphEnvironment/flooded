# Progress — Rewrite the Parsnip vignette as a data-product article (#92)

## Session 2026-10-19

- Read NGE's article standard (writing, README, pkgdown and R-package vignette conventions, and the
  pending conventions on tables, side analyses and software citation) and a worked example.
- Filed #92. Plan-mode outline approved; decided: stack on the #87 branch (PR #91 open), Parsnip only.
- Created branch `92-rewrite-the-parsnip-vignette-as-a-data` off `87-build-the-bundled-and-vignette-data-from`.
- Scaffolded PWF baseline with approved phases. User: "go all phases to pr".
- Next: Phase 1 (data script).

## Session 2026-10-19 (continued)

- Phase 1: data script records VCA args, cells at ff 2/4/6/7, source digests (one snapshot each),
  MRDEM ETag, file md5s, software with releases/commits/DOIs. Commits c012f36, 3f79b5e, 5d3b8e9; bundle 0a591fe.
- Plan review folded in (review-plan.md): definition, channels, labels, How good is it?, fresh commit, cell counts.
- Phase 2: tests (dbe7e6a). Phase 3: article rewrite (fa9148f). Phase 4: xciter dropped, README and CLAUDE.md updated (the ripple commit before the second build).
- Code-check rounds 1-4 (ce9f50f, 13b894c, b09e1d3, 1c0938b): 13 / 11 / 4 / 5 findings; ended by the
  37-field guard enumeration (planning/active/enumerate_guards.R).
- Validation: 599 tests pass, 0 skipped; R CMD check 0/0/3 (notes not from this branch); lintr 145; pkgdown clean.
- Filed #93, #94 for the other two vignettes.
