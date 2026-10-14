# Progress — fl_dem_aoi() read window transform (#78)

## Session 2026-10-13

- Plan-mode exploration — phases approved by user (scope widened to the third-CRS grid transform by user answer)
- Read-only probe: 3/60 sub-cell AOI offsets change the returned DEM under a 1.3 m window shift; 0 changed cells inside the buffered AOI
- Created branch `78-fl-dem-aoi-the-source-read-window-is-sti` off main
- Scaffolded PWF baseline from issue #78 with approved phases
- Next: start Phase 1
