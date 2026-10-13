# Code-check round 1: #65 (diff 6b5cd1d...HEAD, planning/ and man/ skipped)

## Findings

- **[severity: fragile (false prose)]** R/fl_valley_confine.R:52-55 (roxygen `@return`), also the
  comment at :279-281 and tests/testthat/test-fl_valley_confine.R:434-436. The text says a cell a
  gap cuts off from every stream "has no cost distance, so it fails the cost criterion", and the
  test comment goes on to say "Unreachable fails the cost criterion, so it is 0". Read together, the
  roxygen tells the user that such a cell comes out 0. It does not when the gap is narrow. The
  cleanup filters run after the AND, and they reach across an NA ring up to 2 cells wide: the
  closing max fills the ring from the valley outside, the closing min then fills the island edge
  from the ring, and the modal filter does the same at the next depth. The test's island holds only
  because its ring is 3 cells wide, the smallest width that keeps the island all 0.
  Measured on HEAD (scratch copy) with the bundled tile: I took a 9 x 9 window with no stream cell
  and all valley at defaults (rows 307:315, cols 237:245) and set its 1-cell border ring to NA. That
  leaves a 7 x 7 island with no cost distance in any of its 49 cells. `fl_valley_confine()` returns
  **24 of the 49 island cells as 1** and 25 as 0, none NA. The "0 or 1" part of the claim holds.
  The parenthetical does not, and it is the kind of criterion-explains-the-pixel sentence that
  CLAUDE.md ("A non-valley cell has no single cause") says to compute or drop. Fix: say the cell
  fails the cost criterion but cleanup can still mark it 1 next to a gap of 1-2 cells, or drop the
  parenthetical. Reword the test comment so it is a claim about this fixture (3-cell ring).

- **[severity: fragile (false prose), low]** tests/testthat/test-fl_valley_confine.R:456-457. The
  comment says "size_threshold is read only by fl_patch_rm(), so the two outputs differ exactly when
  it removed one". Only one direction holds: a difference implies a removal. A removal does not
  imply a difference, because the 3x3 modal filter afterwards also erases a patch of 1-4 cells on
  the no-removal path. So both paths can give identical output even though a patch was removed. The
  assertion `any(v$p1 != v$p5000)` uses the sound direction and fails loudly if it ever misses, so
  the test is fine. Only the "exactly when" is wrong. Suggest "differ only if it removed one".

## Checked and found sound

- fl_patch_rm()/fl_patch_conn(): `ifel(is.na(m), x * 0L, x)` keeps NA input as NA, gives 0 for
  x == 0 and for removed patches, and keeps patches unchanged. It is equivalent to the old
  expressions on every non-NA cell.
- Restore-the-bug: I copied main's R/ files under HEAD's tests and ran them with
  `NOT_CRAN=true testthat::test_file`. All 6 new #65 tests fail: both fl_patch_rm, two of the three
  fl_patch_conn (the no-anchor one passes on main by design, since that path already kept NA), and
  all three fl_valley_confine. Each guard fires.
- Main vs HEAD outputs on `na_block_fixture()` and `island_fixture()` at size_threshold 1 and 5000:
  na_block is identical on both paths (0 cells differ). island_5000 is identical. island_1 differs in
  exactly the 625 island cells (NA on main, 0 on HEAD). Why the modal change (NA now kept through it
  instead of 0) cannot reach other cells: after the closing filter, any NA left is at least 3 cells
  deep inside the pre-cleanup NA region. So only cells that were themselves NA before cleanup can
  change. A DEM-valid cell next to a DEM gap is not one of them: its slope-NA ring is filled by the
  closing filter. So the cached lidar rasters (pinned at 115385 / 11020 NA) should not move from
  this change. That is inferred, not re-run, because the lidar build needs the STAC tiles.
- island_fixture's "more than 200 m from any stream": measured minimum 202.5 m. It holds.
