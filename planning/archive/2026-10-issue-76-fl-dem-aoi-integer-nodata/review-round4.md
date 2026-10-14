# Code-check round 4 — #76 branch (reviewer, 2026-10-14)

Probed in temp copies of the branch (d899ad9) and of main (`git archive 277018b`),
terra 1.9.50 / GDAL 3.13.0. Probe scripts were session-local and not kept.

## Findings

- **[fragile: prose, wrong location, inside round 3's fix]** R/fl_dem_aoi.R:69-71 (roxygen
  `@details`) and man/fl_dem_aoi.Rd:90-92: "projected directly from a file (a crop of the whole
  source, **or one terra keeps on disk**), terra writes a NoData such as UInt32 4294967295 as
  4294967296, a value, **wherever the output reaches past the source**". For the on-disk case the
  fix just added, the affected cells are not past the source. On main under
  `terraOptions(todisk = TRUE)`, `fl_dem_aoi(streams, dem.tif, buffer = 100, target_crs = 3157)`
  returns 9,533 cells at 4294967296 and 0 NA. Rasterizing dem.tif's footprint (projected to
  3157) onto that output puts **all 9,533 inside the footprint and 0 outside it**. The whole
  265,122-cell output lies within the tile. Those cells are past the *area read* (the crop),
  not past the source. The sentence just before this one already makes that distinction ("where
  the grid's corners reach past the area read from the source"), so this clause contradicts it.
  For the whole-file crop the two are the same, which is why only the new on-disk example shows
  the problem. This is the published help page. Fix: "wherever the output reaches past the area
  read" (or "past the crop"), then `devtools::document()`. Behaviour is not affected.

- **[fragile: prose, wrong condition]** CLAUDE.md:190-191 (Test-data traps): "A reprojection test
  that **stays inside the tile**, or keeps the crop in memory, cannot see that class". The
  first disjunct is contradicted by the branch's own second #76 test. That test
  (`buffer = 100`, `todisk = TRUE`) stays entirely inside the tile (above: 0 output cells
  outside the footprint) and, on main, sees the class (9,533 cells at 2^32). The bug hides only
  when the crop is a subset **and** in memory. A subset crop on disk shows it inside the tile.
  So "stays inside the tile, or ..." should be "and". A reader who follows the current wording
  concludes that a tile-interior test is blind, and that is false. The same "source" vs "area
  read" slip is in research/dem_reprojection.md §4: the table's header is "max beyond the
  source", and its first row includes "any crop terra writes to disk", where the 2^32 cells lie
  inside the source file. The section's first sentence uses "source" in terra's sense (the
  raster given to `project()`), which makes the header defensible, but the row's own
  parenthetical uses "source" for the file.

## Checked and clean

- Roxygen "those cells are `NA` whatever its NoData value", probed on the branch
  (`buffer = 2000`, `target_crs = 3157`). An INT4U source with **no NoData at all**
  (`gdal_translate -a_nodata none`) gives max 1061.941 and 290,432 NA. INT2U/65535 gives the
  same, and so does dem.tif (INT4U/4294967295). On main the first two match and dem.tif gives
  max 4294967296 with 0 NA. So "whatever" holds, the no-NoData case included.
- "a crop of the whole source, or one terra keeps on disk" covers every file-backed path in
  `fl_dem_aoi()`: `r_clip` is always a `terra::crop()` of `terra::rast(source)`. `source` must be
  a character path (`stopifnot(is.character(source))`), so no in-memory SpatRaster reaches it.
  A `/vsicurl/`, `/vsis3/` or VRT source follows the same crop logic: a whole-file crop stays
  file-backed, a subset is in memory unless terra writes it to disk. The listed cases are
  complete. The only error is the location clause above.
- Code comment "On disk the copy is Float32": a subset crop under `todisk = TRUE` is INT4U on
  disk, and `* 1` of it gives `datatype()` FLT4S. Holds.
- Code comment "beyond the source" uses `source` in terra's sense (the raster given to
  `project()`, i.e. the crop), so it is correct there. The test-file comment is the same.
- CLAUDE.md:50 count: 18 `test-*.R` files and 166 `^test_that(` blocks (34 in
  `test-fl_dem_aoi.R`). Holds.
- man/fl_dem_aoi.Rd text matches the roxygen source.
- Research §4, the upstream draft and the code-comment representability claims were
  re-walked against rounds 1-3's probe tables. No new disagreement apart from the table
  header above.
- Not raised, outside the prose set named for review: `planning/active/task_plan.md`'s Context
  still states the pre-round-1 model ("fills unmapped cells with the source nodata cast to
  Float32"), which the INT2U probe disproved. It is a plan-time record and goes into the archive
  as the story, so no change is needed. A later reader of the archive should know it was
  superseded, which `progress.md`'s round-1 entry records.
- Accepted tradeoffs not re-raised.

