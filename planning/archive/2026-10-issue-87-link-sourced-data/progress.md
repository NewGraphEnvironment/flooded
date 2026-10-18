# Progress — Build the bundled and vignette data from our link-built tables, not bcfishpass (#87)

## Session 2026-10-18

- Plan-mode exploration — phases approved by user (decisions: `fresh_default`; link's column
  names and types)
- Created branch `87-build-the-bundled-and-vignette-data-from` off main
- Scaffolded PWF baseline from issue #87 with approved phases
- Next: start Phase 1

- 2026-10-18: Phase 1 committed (5dc6e8e, review fixes 95b0d5b); Parsnip script (80cf2d1); tile
  claims re-measured (d367030). GitHub outage 18:07Z–~19:05Z on 2026-10-17 delayed planning.
- Shared database (context layers) unreachable: user chose to carry the layers over; the script
  records `context_source = "carried"`, `context_carried_from = "2ef5c89 2026-10-13"`.
- Parsnip ran three times (link source; review fixes; a quoting fix for `context_carried_from`,
  whose unquoted `--format=%h %cs` made git exit 128). All three gave 455,215 valley cells.
- Filed fwapg#33 (lookup gap); edited #85's body for the new lineage.
- README figure regenerated from the final Parsnip files is byte-identical to the run-1 version,
  which landed in d367030 with `man/` rather than in the Parsnip commit.
- Phase 6: NOTICE per attribute with a scoped bcfishpass ODbL credit (plan review B1); README
  caption and data line; CLAUDE.md design-decision bullet. Root `Rplots.pdf` (untracked plot dump)
  moved to the scratchpad so `R CMD check` does not NOTE it.
- Code-check rounds 1 and 2 fixed (407ee26, 875ae1d); final Parsnip run from the clean tree at
  875ae1d: context layers carried per layer, origin `2ef5c89 2026-10-13` each; valleys
  byte-identical. Full suite 584/0/0. Round 3 (mechanism + enumeration) in flight; my own
  enumeration added a NOTICE <-> `run_id` cross-reference comment in both scripts.
- Validation: full suite 584/0/0 (at 407ee26; later commits touch only data-raw/, NOTICE and the
  Parsnip cache, which no test reads); `R CMD check` at 541cd59 0 errors / 0 warnings / 2 notes,
  both pre-existing (`CITATION.cff`, `pkgdown/` at top level); `check_pkgdown()` clean; lintr 145
  against main's 149, none added. Parsnip vignette re-rendered on the final meta.
- Code-check: 4 rounds, ended by enumeration (round 4). Rejected-copy harness re-run at 0ee7c55.
