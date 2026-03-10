# flooded 0.1.1

* Replace raw SQL in `data-raw/network_extract.R` with `fresh::frs_network()`
  for stream network extraction via network subtraction.
* Add STAC DEM vignette comparing 25 m TRIM (resampled to 10 m) with native
  1 m lidar — includes site-level zoom and pop-up analysis quantifying
  anthropogenic barriers to floodplain connectivity.
* Add `bcdata` reproducibility script (`data-raw/testdata_bcdata.R`).
* Add resolution and restoration section to README.
* Pre-build STAC vignette for fast pkgdown rendering.

# flooded 0.1.0

* Initial release. Valley Confinement Algorithm (VCA) pipeline for floodplain
  delineation from DEM and stream network.
