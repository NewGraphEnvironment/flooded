# Findings — fl_valley_confine() returns 0, not NA, where the DEM is NA (#63)

## Issue context

## Problem

`fl_valley_confine()` documents its return as `1` = valley, `0` = confined / hillslope, `NA` = outside analysis extent. Where the input DEM is `NA`, it actually returns **0**.

```r
dem <- terra::rast(system.file("testdata/dem.tif", package = "flooded"))
streams <- sf::st_read(system.file("testdata/streams.gpkg", package = "flooded"), quiet = TRUE)
dem[1:10, 1:10] <- NA
v <- flooded::fl_valley_confine(dem, streams, area_field = "upstream_area_ha")
unique(terra::values(v)[1:10])
#> 0
```

## Why it matters

- **No-data reads as measured non-valley.** A DEM with a coverage gap, such as the 2019 lidar in `stac-dem` (22% of the test tile has no lidar), gets that gap mapped as confined ground. A plot draws it the same grey as hillslope.
- **Any share computed over `ncell()`** or over non-NA cells counts the gap as not-floodplain.
- **The `stac-dem` cache build** (`data-raw/stac_dem_vignette_data.R`) records the lidar gap separately (`na_frac_*`, `n_10m_no_lidar`), so that vignette's numbers are not affected. Other callers working with patchy lidar would be.

## To decide

Fix the output (mask the result by `!is.na(dem)`), or correct the documentation. Fixing it changes cell counts wherever a DEM has `NA`. It does not change them for the bundled tile (no `NA`), so the `stac-dem` guard counts should hold. That needs checking.

Found during #51 (code-check round 4).


## Plan-mode probes (2026-10-08)

- Cause: `fl_patch_rm()` (`R/fl_patch_rm.R:46`) sets `is.na(patches)` cells to 0, which converts
  NA reaching it (NA slope -> NA mask product) to 0 when any patch is small enough to remove (no
  early return; #65); the 3x3 modal then smears 1s into the
  gap edge.
- Bundled tile, 31x31 NA block centred on a valley cell: 815 zeros / 146 ones / 0 NA in the block.
  `channel_buffer = FALSE`: 918 / 43 / 0 — 42 of the 43 on the block's outer ring (focal smear).
- 1,028 valid-DEM cells outside this block also change vs the no-NA run. Code-check round 3 measured
  the test fixture's block (a different location; round 4 confirmed 679 with the buffer on or off,
  since the buffer is OR'd in after cleanup): 679 cells change, 659 of them 0->1; the flood
  criterion differs on 488 (fl_flood_model reads the DEM directly), slope and cost on 25 cells of the
  128-cell ring, distance on none; median 670 m, max 940 m from the gap. An earlier "barrier" explanation was
  unmeasured and wrong in direction. Real algorithm behaviour, not this bug; out of scope.
- `pars_dem.tif` is 49% NA (10,180,862 of 20,888,140); `pars_valleys.tif` has 0 NA and **0 of
  441,054** valley cells on NA DEM, so published Parsnip hectares do not move. The cached tif still
  carries 0 (not NA) outside the DEM; not rebuilt here (needs the DB).
- stac-dem cache built at 0.6.1 / c0c0e46: `na_frac_5m` 0.223, `na_frac_1m` 0.0789, `n_5m` 186675,
  `n_1m` 3096003, `n_10m` 28727, `n_site_10m` 20586, `n_10m_no_lidar` 32.

## Errors Encountered

| Error | Resolution |
|-------|------------|

## stac-dem cache rebuild (2026-10-08, from 1ea1ae5)

Run: `data-raw/stac_dem_vignette_data.R` from a frozen copy, 14:23:40 → 14:47:55 UTC (24 min, tiles
pre-downloaded). Log: scratch only (not committed).

- `stac_meta.rds`: only `flooded_version` (0.6.1 → 0.6.2), `git_sha` (c0c0e46 → 1ea1ae5) and
  `date_built` changed. `n_5m` 186675, `n_1m` 3096003, `n_10m` 28727, `n_site_10m` 20586,
  `n_10m_no_lidar` 32, `popup_steep_share` 0.774, `site_steep_share` 0.236 all identical.
- `stac_valleys_5m.tif` (10 m grid): old 0/1/NA = 471,744 / 46,656 / 0 → new 356,359 / 46,656 /
  115,385. Every new NA was an old 0; no old 1 became NA; no non-NA cell changed.
- `stac_valleys_1m_site.tif`: old 108,970 / 31,030 / 0 → new 97,950 / 31,030 / 11,020. Same pattern.
- Vignette pop-up table recomputed under both caches: identical (fp25 20586, fp1 31030, pop-ups
  1984 = 9.64%, 1 m only 12428). Zero 25 m floodplain cells fall in the 1 m lidar gap, which is why
  the plan review's predicted `popup_steep_share` jump did not happen. `area_stac` 4.67 km2 unchanged.
- Vignette changes: `colNA = "tan"` on both lidar plots + captions; pop-up % denominator restricted
  to 25 m floodplain with 1 m lidar (same 9.6% here); per-tile shares labelled as including no-lidar
  cells. Rendered and checked: no stale note, numbers unchanged.
- New test pins the cache: both cached lidar rasters must contain NA (fails on the old cache, which
  had none).

## Parsnip cache (not rebuilt)

`pars_valleys.tif` still carries 0 (not NA) outside the DEM. 0 of 441,054 valley cells sit on NA
DEM, so the published hectares are unaffected; the vignette plots `col = c(NA, green)` and masks to
the AOI, so the 0s are not drawn. A rebuild needs the DB; it will pick up NA on the next run.
