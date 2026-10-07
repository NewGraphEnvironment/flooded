# Review round 1 — #51 stac-dem live vignette

Reviewer: code-check subagent, 2026-10-06. Worked in a copy (scratchpad), repo untouched except this file.

## Findings

- **[fragile] vignettes/stac-dem.Rmd:475** — new prose "The 25 m TRIM DEM ... shows the floodplain
  without a single linear break" is contradicted by the live 10 m site figure it describes. Profiles of
  `valleys_site_10m` (identical to the cached `n_site_10m` = 20,586 run) at x = 979405 / 979605 / 979805
  (y 1056405 -> 1055825, 10 m steps) read
  `11111000000011111111111100000001111111111110000000000000000`,
  `11111111111111111111111111100000000011111110000000000000000`,
  `00000000000000000111111111111111111000000001110000000000000`
  — a continuous 0-band roughly 40-90 m wide running ~700 m east-west through the floodplain in the
  lower right of the top panel (it is a break in both the 10 m and 1 m maps). The old text ("one
  continuous green mass") was also wrong for the corrected run; the rewrite replaced it with a claim
  that is still checkably false against the page's own figure.

- **[fragile] vignettes/stac-dem.Rmd:170 and :322 vs data-raw/stac_dem_vignette_data.R:96-133** — the
  displayed (eval = FALSE) mosaic code calls `stac_image_collection(items$features, asset_names = "dem")`
  with the default `url_fun`, i.e. reads the tiles over `/vsicurl/`. The script that produced the cached
  results deliberately does not: it downloads each tile and passes a `url_fun` to the local copy,
  because (its own comment) these strip-organised tiles read over `/vsicurl/` can leave gdalcubes with a
  partial mosaic that "looks complete" (failed chunk reads only on stderr). So the code a reader copies
  from the page is the path the author found unreliable, and can reproduce different numbers with no
  error — while the script header asserts "Configuration matches the vignette exactly". Either show the
  download step / `url_fun` on the page, or say on the page that the cache was built from local copies
  and why. (Smaller drift, harmless today: the page derives the 5 m search bbox from
  `project(dem_10m, "EPSG:4326")`, the script from `project(rast(ext(dem_10m)), ...)`; both returned the
  same two items.)

## Verified (no issue)

- Live 10 m counts reproduce the cache exactly: n_10m 28,727 = meta; n_site_10m 20,586 = meta. CI
  ubuntu (GDAL 3.8.4 / GEOS 3.12.1) prints `Valley cells: 28727` on the published valley-confinement
  page, so the exact-equality guard is not platform-fragile for the whole-tile count.
- NEWS numbers all derive from the artifacts: 5 m 46,656 cells on the 10 m grid = 4.67 km2; 10 m
  2.87 km2; 1 m site 31,030 cells = 310.3 ha; site 10 m 205.9 ha; pop-ups 1,984 cells = 19.8 ha =
  9.64% of 205.9 ha; 1 m-only 12,428 cells = 124.3 ha. "Previously 6.26 vs 5.46" and "36.1 ha, 9.7%"
  match the baked vignette on main. 18.9 min cache build is in progress.md (note: with tiles already
  local; first run adds the ~1.3 GB download). Cache is 13,048 bytes (12.7 KiB; "~12 KB" is a
  truncation, not material).
- "Lidar mostly agrees where 10 m finds floodplain": 688 10m-only vs 18,617 5m-only cells. That 688 is
  also an upper bound on 10 m floodplain falling in the 22% no-lidar area, so "barely overlaps" holds.
  Site pop-ups show no block pattern that would indicate the 8% no-lidar area being counted as pop-ups.
- `warnings_1m` and `warnings_5m` are `chr(0)` (methodology.md claim holds); fl_valley_confine does not
  suppress warnings internally, so the empty capture is meaningful.
- Cached rasters: no NA, values {0,1}, `compareGeom` TRUE against `dem` and `crop(dem, site_ext)`.
- test-vignette_data.R passes against the package installed to a temp library, run from a temp dir
  with only setup.R + the test file (R CMD check layout); `system.file(mustWork = TRUE)` resolves.
  No R-CMD-check workflow exists, so the test is local-only; pkgdown CI does not need gdalcubes.
- No duplicate chunk labels in stac-dem.Rmd. rtj#229 resolves to the stac-elevation-bc restructure.
  inst/vignette-data is not build-ignored.
