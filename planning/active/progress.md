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
