# Review round 2 — #51 stac-dem live vignette (review of round-1 fixes)

Reviewer: code-check subagent, 2026-10-06. Repo untouched except this file. Probes ran from the
scratchpad: the live site 10 m run (reproduces cached `n_site_10m` = 20,586) against
`inst/vignette-data/stac_valleys_1m_site.tif`.

## Findings

- **[fragile] vignettes/stac-dem.Rmd:495-496.** The rewritten clause says the 25 m map "shows only
  broad breaks in the floodplain — ones the lidar finds too". The second half is false. The cached
  1 m result maps most of those breaks *as floodplain*:
  - Take the 10 m non-valley cells inside the 10 m floodplain envelope (a 150 m morphological
    closing of `valleys_site_10m`). There are 3,643 of them, and only **1,009 (28%)** are also
    non-valley at 1 m. The rest are 1 m valley.
  - Per break, the share also non-valley at 1 m is, largest first: 548 cells 57%, 285 cells 6%,
    182 cells 12%, 180 cells 0%, 158 cells 40%, 135 cells 56%, 125 cells 14%, 121 cells 14%.
  - Round 1's broad E–W break shows the same pattern. Profiles at x = 979405 / 979605 / 979805
    (y 1056405 down to 1055825, 10 m steps):
    ```
    10m 11111000000011111111111100000001111111111110000000000000000
    1m  11111111111111111111111111100111111111111111111111111111111
    10m 11111111111111111111111111100000000011111110000000000000000
    1m  11111111111111111111111111111111101111111111111111111110000
    10m 00000000000000000111111111111111111000000001110000000000000
    1m  11111111111111111111111111111111111111001111111111100000000
    ```
    The 60–90 m band at 10 m is 1–2 cells at 1 m: the narrow diagonal road/rail line, not the
    broad break. So the broad break and the "narrow white lines" are often the same feature at two
    resolutions, and the lidar fills the remainder in.
  - A 10m-vs-1m agreement map (classes both / 10 m only / 1 m only / neither) shows the 10 m holes
    as mostly "1 m only". That includes the large enclosed gap at about 977500–978000 x
    1056700–1057200 and the holes in the eastern block.

  This is the same sentence round 1 flagged. The fix swapped one checkably false claim for another,
  and the new one contradicts the page's own table row "Floodplain found only at 1 m" (124.3 ha) and
  the paragraph above it about low ground the 25 m DEM misses. The second half of the fix holds:
  the 1 m lines are narrow (1–2 cells on the 10 m grid) and run diagonally WNW–ESE. A wording that
  survives the data: *"shows broad gaps in the floodplain; the lidar fills most of them in, and
  where a road or rail grade crosses one it narrows the gap to a line."*

  Related, pre-existing and not part of this diff: line 501 says 25 m features are "invisible". That
  is true where the 1 m line falls inside 10 m floodplain (red pop-up lines near 976600–977300 /
  1056800 and 977700–978300 / 1057200). In the lower right it is false, because there the 10 m shows
  the same grade as a broadened band.

## Verified (no issue)

- **`url_fun` semantics.** gdalcubes 0.7.5 `stac_image_collection()` calls
  `url_fun(s[[i]]$assets[[name]]$href)` on the raw asset href, at both call sites. The default
  `.default_url_fun` adds `/vsicurl/`, and that is what the round-1 fix bypasses. So
  `function(u) tiles[match(u, hrefs)]` (vignette:182) and
  `function(u) site_tiles[match(u, site_hrefs)]` (vignette:342) receive exactly the strings they
  `match()` against. `hrefs` is built from the same `f$assets$dem$href` used with
  `asset_names = "dem"`, so `match()` cannot return NA for an item in the collection. The script's
  `local[[u]]` (data-raw:137) uses the same href key.
- **Displayed code against the script.** The download target is `basename(href)` in both; the
  displayed code uses `tempdir()` and the script `STAC_DEM_TILE_DIR` (defaulting to
  `tempdir()/lidar`), which is immaterial. `cube_view` (EPSG:3005, `dt = "P1Y"`,
  `aggregation = "first"`, `resampling = "bilinear"`, extents, dx/dy) matches. The displayed code
  has no size check. That is safe, because `curl::curl_download()` writes `<dest>.curltmp` and
  renames only on success, so an interrupted download cannot leave a partial file that the
  `file.exists()` skip would then trust. `items_1m` equals `items_5m` in `stac_meta.rds`, so the
  "same two tiles, already downloaded" comment at the site chunk is accurate, and
  `site_tiles` resolves to the same paths as `tiles`.
- **Script header** ("VCA configuration and the tile download match the code shown"): holds, with
  the bbox-derivation difference round 1 already noted as harmless.
- **NEWS.** Cache files total 474 + 5,891 + 6,683 = 13,048 bytes, which matches "~13 KB". The two
  tiles are about 630 MB each, which matches "~1.3 GB".
- **Tests.** `test-vignette_data.R` passes against the current tree with `NOT_CRAN=true`:
  `[ FAIL 0 | PASS 6 ]`. The live site count of 20,586 equals the cached value.
- Neither cached raster has NA cells, so the light lines in the 1 m panel are 0-valued cells and
  not gaps in coverage.
