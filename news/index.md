# Changelog

## flooded 0.2.0

- Add `waterbodies` and `channel_buffer` params to
  [`fl_valley_confine()`](https://newgraphenvironment.github.io/flooded/reference/fl_valley_confine.md)
  — fill lake/wetland donut holes and correct sub-pixel stream channels
  ([\#21](https://github.com/NewGraphEnvironment/flooded/issues/21)).
- Handle NA `channel_width` gracefully in channel buffer (order 1
  streams).
- Update vignette with waterbody/channel buffer comparison, order 4+
  filter rationale, and channel width model documentation.
- Regenerate test data via `fresh::frs_network()` with `frs_clip()`.

## flooded 0.1.1

- Replace raw SQL in `data-raw/network_extract.R` with
  `fresh::frs_network()` for stream network extraction via network
  subtraction.
- Add STAC DEM vignette comparing 25 m TRIM (resampled to 10 m) with
  native 1 m lidar — includes site-level zoom and pop-up analysis
  quantifying anthropogenic barriers to floodplain connectivity.
- Add `bcdata` reproducibility script (`data-raw/testdata_bcdata.R`).
- Add resolution and restoration section to README.
- Pre-build STAC vignette for fast pkgdown rendering.

## flooded 0.1.0

- Initial release. Valley Confinement Algorithm (VCA) pipeline for
  floodplain delineation from DEM and stream network.
