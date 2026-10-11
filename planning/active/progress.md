# Progress — fl_valley_attribute() per-group cost grew 5x from MORR to BULK at the same crop size (#72)

## Session 2026-10-11

- Plan-mode exploration — phases approved by user; parallel API fork answered: `workers = 1L` argument
- Planning probes on BULK coho arm at 0.6.4 (numbers in task_plan.md context)
- Created branch `72-fl-valley-attribute-per-group-cost-grew` off main
- Scaffolded PWF baseline from issue #72 with approved phases
- Next: start Phase 1

## Session 2026-10-11 (continued)

- Phase 1: arm 2 networks extracted (counts match the probe); bench harness with section
  checkpoints, CPU time and load; plan review folded in (review-plan.md). Baselines at main on six
  inputs. Finding: the issue's 5x per group was #71's old fallback plus contention; BULK order >= 2
  at main is 332.9 s, inside its budget.
- Phase 2: `do.call(rbind, parts)` -> `fl_rbind_pairwise()` (2c6a148), identical output; oracle and
  identity tests, both shown to fail on restored defects. Phase 3 gated out.
- Phase 4: branch runs, membership identical on all six inputs; BULK order >= 2 238-240 s.
- Phase 5: Performance docs, CLAUDE.md note, issue body revised (premise, Outcome).
- /code-check branch: 4 rounds (R1 5, R2 4, R3 5, R4 11 of a 94-claim enumeration), all prose
  claims; no code defects. Commits d62038b, a16f428, 41c2d59, 17308f0.
- Full suite at 8987433: FAIL 0 | PASS 323; R/ and tests/ unchanged since apart from roxygen.
- Next: /planning-archive (slug attribution-scale), /gh-pr-push.
