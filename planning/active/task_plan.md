# Task: floodplain_interpretation.md: 'proportional claims stand' needs the counter-case (fp_pct_aoi moves with the hectares) (#52)

`inst/notes/floodplain_interpretation.md` section 4 says, correctly, that proportional claims stand —
citing `restoration_wedzin_kwa_2024`, where disturbed-as-a-share-of-AOI moved 27.51% -> 27.50% under
the 0.5.0 units fix.

That is true for land-cover **composition within** the floodplain. It is not true for a ratio whose
denominator sits outside the floodplain, and the memo does not distinguish the two. The live case:
**floodplain as a share of watershed group**, which every fish-passage report appendix publishes as
`fp_pct_aoi` alongside the hectares. Measured on the Parsnip WSG as committed in the peace report, it
goes **8.67% -> 7.35%** — falling the same ~15% as the area, because the watershed does not shrink.

Downstream instances: NewGraphEnvironment/fish_passage_peace_2025_reporting#47,
NewGraphEnvironment/fish_passage_skeena_2025_reporting#18,
NewGraphEnvironment/fish_passage_fraser_2025_reporting#37.

## Phase 1: Amend section 4 of `inst/notes/floodplain_interpretation.md`

- [x] Rewrite the "absolute hectare claims… proportional claims stand" sentence so it states the
      test rather than the conclusion: a ratio is stable only if its **denominator is also inside
      the affected region**.
- [x] Keep the `restoration_wedzin_kwa_2024` composition figure (27.51% -> 27.50%) as the *stable*
      example, explaining why it holds — the over-mapped margin carried almost the same land-cover
      mix as the core.
- [x] Add the counter-case with sources named so the arithmetic reconciles against section 4's own
      Parsnip bullet (which cites flooded's 48,603.1 ha run, 62 ha above the peace report's
      committed layer): peace report as committed 48,540.8 ha = **8.67%**; corrected 41,142.9 ha =
      **7.35%**; same 5,596.6 km2 group.
- [x] Name `fp_pct_aoi` literally, so someone grepping a report appendix lands on it.
- [x] Keep the existing scenario-to-scenario sentence (unaffected — every scenario carried the same
      error).

## Phase 2: Consistency sweep

- [x] Check `inst/notes/methodology.md` and `vignettes/pars-floodplain.Rmd` for the same
      over-generalization.
- [x] Confirm `CLAUDE.md`'s design-decision entry still matches the memo's wording after the edit.
- [x] `/code-check` on the staged diff.

## Phase 3: Close out

- [x] Commit with the `task_plan.md` checkbox flips (atomic).
- [x] No version bump, no NEWS entry — docs-only; flag as such in the PR body.
- [x] `/planning-archive`, then `/gh-pr-push`.

## Validation

- [x] Tests pass
- [x] `/code-check` clean on each commit
- [x] PWF checkboxes match landed work
- [x] `/planning-archive` on completion
