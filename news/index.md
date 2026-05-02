# Changelog

## flooded 0.2.1

- Startup quote ritual:
  [`library(flooded)`](https://github.com/NewGraphEnvironment/flooded)
  prints a random fact-checked quote on attach. Italic quote, grey
  attribution, clickable blue `source` hyperlink (OSC 8). Suppress via
  `options(flooded.quote_show_source = FALSE)`.
- 157 shipped entries across 45 voices — 25 hip-hop (Kanye West, Royce
  da 5’9”, Black Thought, Ab-Soul, ASAP Rocky, Danny Brown, The Weeknd,
  Kenny Beats, Freddie Gibbs, Madlib, Travis Scott, Flatbush Zombies
  trio, J. Cole, Bad Bunny, Don Toliver, Aaron Frazer, Post Malone, Mac
  Miller, Lil Yachty, Fre$`h, Mustard, IDK, Joey Bada`$\$) + 20 climate
  voices (Hayhoe, Mann, Hansen, Schmidt, Marvel, Cobb, Rockström,
  Hassol, Oreskes, Wilkinson, Oppenheimer, Otto, Kalmus, Francis,
  Santer, Alley, McKibben, Wallace-Wells, Kolbert, Johnson).
- Curated via the soul `/quotes-enable` skill. 8 parallel research
  agents returned 157 candidates; 2 independent fact-check agents
  flagged 2 drops and several URL upgrades to primary sources (GQ, W
  Magazine, Rolling Stone, Vulture).
- `cli` added to Imports for OSC 8 hyperlinks and styling.

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
- Add VCA parameter legend CSV (`inst/extdata/flood_params.csv`) with
  units, defaults, and literature sources for all tuning parameters.
- Add
  [`fl_scenarios()`](https://newgraphenvironment.github.io/flooded/reference/fl_scenarios.md)
  and
  [`fl_params()`](https://newgraphenvironment.github.io/flooded/reference/fl_params.md)
  for loading pre-defined flood factor scenarios and parameter metadata
  ([\#28](https://github.com/NewGraphEnvironment/flooded/issues/28)).
- Add flood scenario CSV (`inst/extdata/flood_scenarios.csv`) with three
  scenarios: ff02 (active channel), ff04 (functional floodplain), ff06
  (valley bottom).
- Add flood factor comparison section to vignette with three-panel plot.
- Replace hardcoded summary table with
  [`fl_params()`](https://newgraphenvironment.github.io/flooded/reference/fl_params.md)
  output.

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
