## Outcome

`vignettes/stac-dem.Rmd` was the last pre-baked vignette, and it was broken three ways on the
site: numbers from before the 0.5.0 units fix (not reproducible even under the old units), two
figure PNGs never committed (404), and a literal `@ref(...)`. It now runs the 10 m VCA live and
reads the 5 m / 1 m lidar results from a ~13 KB cache built by `data-raw/stac_dem_vignette_data.R`.
`tests/testthat/test-vignette_data.R` fails, and the page shows a callout, when the live 10 m
counts drift from the counts the cache was built against. Two upstream changes surfaced on the way:
the STAC collection is now `stac-elevation-bc` with asset `dem` (the old name returns zero items,
not an error), and the lidar COGs are strip-organised, so the script downloads them first. The
larger lesson came from code-check: four rounds each found a false claim in the vignette's prose,
two of them inside the previous round's fix, because the figures were being described by eye. The
prose had read every non-floodplain cell as "above the flood surface"; measured, the pop-ups are
mostly excluded on the 1 m **slope** criterion. What ended it was computing the claim in the
build script and enumerating every result-describing sentence (36), not another review round.
`fl_valley_confine()` returning 0 rather than NA on NA DEM cells was found and filed as #63.

## Measurement

| | published (pre-0.5.0) | now (0.6.1 source, c0c0e46) |
|---|---|---|
| 10 m tile valley | 54,637 cells / 5.46 km2 | 28,727 / 2.87 km2 |
| 5 m lidar valley | 250,564 cells / 6.26 km2 (on 10 m grid) | 186,675 / 4.67 km2 |
| site 25 m / 1 m | 373 / 388.3 ha | 205.9 / 310.3 ha |
| pop-ups | 36.1 ha (9.7%) | 19.8 ha (9.6%) |
| floodplain only at 1 m | — | 124.3 ha |

- Lidar coverage: 22.3% of the test tile and 7.9% of the site have no 2019 lidar, measured
  identically from gdalcubes and from locally downloaded tiles. This retracted a first diagnosis
  of a "partial read". The gap overlaps 32 of the 28,727 10 m floodplain cells.
- Pop-up mechanism: 77.4% sit on 1 m ground steeper than 9%, against 23.6% across the whole 25 m
  floodplain. On the 25 m DEM their median slope is 5.0%. Cost and distance pass for 100% of them.
- The lidar fills 72% of the broad gaps in the 25 m floodplain envelope (2,634 of 3,643 cells).
- The 1 m run no longer emits `[costDist] did not converge` (methodology.md updated).
- Cache build: 18.9 to 21.3 min with local tiles, plus ~1.3 GB of download.

## Evidence

`inst/vignette-data/stac_meta.rds` (provenance, counts and shares, written by the build script);
`review-round*.md` in this directory (every claim the reviewers measured, with profiles).

Closed by: PR for #51 (branch `51-stac-dem-rmd-ships-pre-0-5-0-figures-and`)
