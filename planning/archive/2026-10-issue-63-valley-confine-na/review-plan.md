# Plan review (Plan agent, 2026-10-08) — condensed, with disposition

| # | Finding | Disposition |
|---|---------|-------------|
| 1 | Pop-up % denominator `fp_25m` still counts 25 m floodplain without 1 m lidar, numerator now drops gap cells | Phase 4: check after rebuild, restrict denominator to lidar-covered cells |
| 2 | `popup_steep_share` was understated pre-fix (gap cells popup=TRUE, steep=NA → in denominator, not numerator); will rise | Phase 4: verify mechanism vs delta; `site_steep_share`, `n_10m_no_lidar` should not move |
| 3 | Shares over `ncell()` (n_5m/ncell_5m, n_1m/ncell_1m) still include gap in denominator | Phase 4: reword or use valid-cell denominator |
| 4 | NA plots page-white; prose reads "white lines" as barriers | Phase 4: explicit `colNA` on lidar plots + captions |
| 5 | Stale "VCA treats NA as outside" comment in build script | Fixed (confirmed false pre-fix) |
| 6 | `fl_patch_conn()` `ifel(!is.na(kept), x, 0L)` turns NA back to 0 | Confirmed (R/fl_patch_conn.R:68); file follow-up issue |
| 7 | `fl_patch_rm()` NA→0 only when a small patch exists (early return keeps NA); contradicts its @return | Confirmed (R/fl_patch_rm.R:41,46); file follow-up issue |
| 8 | NEWS: tell callers to use `na.rm` | Phase 5 |
| 9 | Rebuild after the fix commit, with `.git` available (meta records SHA, r_dirty) | Adopted: commit first, run frozen script copy from repo root |
| 11 | INT1U + NA write → check nodata flag after rebuild | Phase 4 |
| 13 | Ring of valid-DEM / NA-slope cells reported as measured — a choice | NEWS / @details note |
| 14 | multi-layer dem | Not adopted: dem is single-layer by contract throughout |
| 18 | Nothing pins the rebuilt cache contains the fix | Phase 4: `anyNA` test in test-vignette_data.R |
| 19/20 | Fixture: median can be x.5; bounds | Fixed: integer index, stopifnot bounds |
| 21 | Conditional vignette prose ("larger"/"smaller") may flip | Phase 4 |
| 22 | Run examples, not just tests | Phase 3 |
| 12,15,16,17 | Datatype, Parsnip, other consumers safe, barrier cells out of scope | No action |
