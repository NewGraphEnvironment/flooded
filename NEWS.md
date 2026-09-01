# flooded 0.5.0

**Results change. Every floodplain produced by 0.4.1 or earlier is over-mapped.**

- Fix the bankfull regression being fed the wrong units (#49). `fl_flood_surface()` passed
  **hectares** (`upstream_area_ha`) and **millimetres** (`map_upstream`) into the verbatim Hall et
  al. (2007) coefficients, which that paper and Nagel et al. (2014) both specify as taking drainage
  area in **km2** and mean annual precipitation in **cm/yr**. The conversion now happens inside the
  function, so callers keep passing the columns they already have.
- Bankfull **width** was 8.2224x too large and bankfull **depth** 3.5926x too large, everywhere, on
  every run this package has ever done. The shipped scenarios were therefore not what they claimed:

  | labelled | actual multiple of bankfull depth |
  |---|---|
  | `ff02` | 7.19 |
  | `ff04` | **14.37** |
  | `ff06` | 21.56 |

  Against Hall's field-validated 3 for historical floodplain and Nagel's 5-7 for valley bottom.
- **How much area this costs is dataset-dependent, and not a fixed ratio.** The error only reaches
  the boundary where the flood mask is the binding criterion. Measured on both shipped datasets,
  and every corrected run is a **strict subset** of the as-coded one - 0 cells gained anywhere:

  | dataset | scenario | as-coded | corrected | retained |
  |---|---|---|---|---|
  | bundled 10 m tile | `ff02` | 320.8 ha | 185.4 ha | 57.8% |
  | bundled 10 m tile | `ff04` | 476.8 ha | 231.9 ha | 48.6% |
  | bundled 10 m tile | `ff06` | 536.4 ha | 287.3 ha | 53.6% |
  | Parsnip WSG, MRDEM-30 | `ff04` | 48,603.1 ha | 41,142.9 ha | 84.7% |

  At 10 m the flood mask binds and the fix roughly halves the extent. At 30 m the slope and
  cost-distance criteria bind first, so most of the inflated flood height was already being clipped
  and the loss is ~15%.
- **Scenario values are unchanged at 2 / 4 / 6.** They were taken from the literature ladder
  (Rosgen 2, Hall 3, Nagel 5-7) in the first place; what changed is that they now behave as
  labelled. Raising `ff` to recover the old extent is not supported by anything - on MRDEM-30,
  corrected `ff04` through `ff07` span only 6.4% of area, so even `ff07` lands at 90% of the
  as-coded `ff04`.
- `precip` now defaults to `NULL`, which drops the precipitation term (multiplier exactly 1).
  The former default of `1` cannot express that once the input is read as millimetres: 1 mm is
  0.1 cm/yr, scaling depth by 0.6089 - *shallower* than omitting the term. `fl_flood_surface()`,
  `fl_flood_model()` and `fl_valley_confine()` all move together. Passing a precipitation raster or
  a scalar in mm is unaffected.
- Shipped vignette artifacts regenerated: `inst/vignette-data/pars_valleys.tif` and the
  `floodplain` layer of `pars.gpkg`. The as-coded run reproduces the previous artifact exactly
  (521,028 cells, 0 difference), which is what establishes the corrected one as a like-for-like
  replacement. This supersedes the 0.4.1 note below saying the shipped artifacts were still
  current — that was true of the #41 cost-distance fix and is not true of this one.
- `vignettes/stac-dem.Rmd` could not be regenerated: it is the baked half of the `.Rmd.orig`
  pattern, and re-baking needs the STAC endpoint plus a 1 m lidar re-run. It carries an explicit
  caveat instead. Its printed figures do not reproduce even under the old units — 54,637 published
  against 53,635 as-coded today — so roughly a thousand cells of that gap predate this release.
- `fl_flood_surface()` gains a units test pinned to hard literals computed from the published
  equation. No test in this package pinned an absolute value before now, and `_snaps/` was empty,
  which is why a 3.59x error survived a green suite. Note that Nagel's combined form
  `h_bf = 0.054 * A^0.170 * P^0.215` cannot serve as the oracle - it is an algebraic identity of the
  two-step form and so agrees in any units.
- Documentation corrected throughout: `inst/notes/methodology.md` stated the two channel-width
  formulas with **no input units at all**, which is the gap that let this survive. Historical
  measurements in that file taken under the defect are annotated rather than restated.

# flooded 0.4.1

- Fix `fl_cost_distance()` seeding on every zero-friction cell rather than only stream cells (#41).
  Seeds are encoded by setting stream cells to `0` and calling `terra::costDist(target = 0)`, which
  matches *every* zero cell — so any cell whose friction was already exactly zero acted as a free
  cost source. Friction exactly equal to `0` is now floored to `1e-6` before seeding. Flat ground
  stays cheap to cross (0.1 accumulated over a 100 km path at 10 m, against a default
  `cost_threshold` of 2500); it simply stops being a source. Negative friction is deliberately not
  floored, so `terra::costDist()`'s own rejection of a negative cost surface is left intact.
- The fix strictly *removes* spurious reach from the cost mask; it never adds any. Measured on the
  two DEMs this package ships, and the answer differs by dataset — check your own rather than
  assuming:

  | DEM | exact-zero slope cells | cost-mask change | delineation change |
  |---|---|---|---|
  | bundled `dem.tif` / `slope.tif`, 10 m | 0 of 45,726 | none | none |
  | `pars_dem.tif` (MRDEM-30, 30 m, 20.9 Mcell) | 80 of 10.7 M | -2,289 cells (214 ha), 0 added | none |

  So MRDEM-30 *does* contain exact zeros, the cost mask *does* move — and on both shipped datasets
  the delineation does not, because the slope, distance and flood criteria plus morphological
  cleanup absorb every affected cell. `fl_valley_confine()` returns the same 53,635 cells on the
  bundled tile and the same 521,028 cells on the Parsnip Watershed Group, with zero cells differing
  in either direction. The shipped vignette artifacts are therefore still current.
- Do not read that as a general guarantee. Where cost is the binding criterion — flatter terrain, a
  laxer `slope_threshold`, a larger `flood_factor` — results will move. Exposure is highest on
  integer-metre DEMs, hydro-flattened lake surfaces and void-filled plateaus. Check with
  `sum(terra::values(slope) == 0, na.rm = TRUE)`.
- The effect is largest under `fl_valley_attribute()`, where cost is what separates one watercourse's
  floodplain from another's: a flat patch inside a group's corridor would have spread that group's
  mask across ground its own streams never reach.
- Fix a stray one-space indent in `fl_valley_poly()`.

# flooded 0.4.0

- New `fl_valley_attribute()` — attribute a finished `fl_valley_confine()` delineation to the stream groups that produced it, so a floodplain can be filtered and queried per watercourse or reach rather than only per network (#40). Returns one `sf` row per group; rows overlap where ground is genuinely shared between watercourses, which near a confluence is most of it. The delineation is never recomputed, so changing the grouping key relabels the output without moving a boundary.
- Per-group VCA runs were measured and rejected: they disagree with the whole-network run in both directions, which would make a river's floodplain depend on what else was in the run. See the function's Details and the vignette section "Whose floodplain is it?" for the mechanism and its limits.
- Fix `fl_valley_poly()` on a delineation with no valley cells — it renamed an `sf` column by position, which detached the geometry column and made every accessor error.

# flooded 0.3.2

- Drop the internal `rtj/docs/dem-sources.md` reference from `fl_dem_aoi()` documentation and NEWS — MRDEM-30 is described as the default DEM source without pointing readers at a private doc they can't access.

# flooded 0.3.1

- Fix Parsnip River Watershed Group vignette: corrected geography (the south-east inset is the headwaters around Arctic Lake on the continental divide, not the Williston-bound confluences) and switched all prose mentions from `PARS` to "Parsnip River Watershed Group".

# flooded 0.3.0

- New `fl_dem_aoi()` — AOI-driven DEM fetch helper. Defaults to MRDEM-30 via `/vsicurl/` (a sensible default for watershed-scale BC work) but accepts any local path, `/vsicurl/` URL, or `/vsis3/` S3 URL via `source =`. Buffered crop happens in the source raster's CRS, reprojection after crop. Replaces hand-rolled per-project DEM plumbing (#34).
- New `vignettes/pars-floodplain.Rmd` — watershed-scale showcase running `fl_dem_aoi()` + `fl_valley_confine()` end-to-end on the Parsnip River WSG (5,597 km²). Designed to port to a bookdown report appendix (#34).
- New `data-raw/wsg_vignette_data.R` — generic, parameterised by `wsg <- "PARS"`. Re-runs the full pipeline for any 4-letter BC watershed group, namespaces outputs by WSG code (#34).
- bcfishpass model version + date are cached at data-raw time as `inst/vignette-data/<wsg>_meta.rds` so the vignette renders without a database connection (#34).

# flooded 0.2.1

- Startup quote ritual: `library(flooded)` prints a random fact-checked quote on attach. Italic quote, grey attribution, clickable blue `source` hyperlink (OSC 8). Suppress via `options(flooded.quote_show_source = FALSE)`.
- 157 shipped entries across 45 voices — 25 hip-hop (Kanye West, Royce da 5'9", Black Thought, Ab-Soul, ASAP Rocky, Danny Brown, The Weeknd, Kenny Beats, Freddie Gibbs, Madlib, Travis Scott, Flatbush Zombies trio, J. Cole, Bad Bunny, Don Toliver, Aaron Frazer, Post Malone, Mac Miller, Lil Yachty, Fre$h, Mustard, IDK, Joey Bada$$) + 20 climate voices (Hayhoe, Mann, Hansen, Schmidt, Marvel, Cobb, Rockström, Hassol, Oreskes, Wilkinson, Oppenheimer, Otto, Kalmus, Francis, Santer, Alley, McKibben, Wallace-Wells, Kolbert, Johnson).
- Curated via the soul `/quotes-enable` skill. 8 parallel research agents returned 157 candidates; 2 independent fact-check agents flagged 2 drops and several URL upgrades to primary sources (GQ, W Magazine, Rolling Stone, Vulture).
- `cli` added to Imports for OSC 8 hyperlinks and styling.

# flooded 0.2.0

* Add `waterbodies` and `channel_buffer` params to `fl_valley_confine()` —
  fill lake/wetland donut holes and correct sub-pixel stream channels (#21).
* Handle NA `channel_width` gracefully in channel buffer (order 1 streams).
* Update vignette with waterbody/channel buffer comparison, order 4+ filter
  rationale, and channel width model documentation.
* Regenerate test data via `fresh::frs_network()` with `frs_clip()`.
* Add VCA parameter legend CSV (`inst/extdata/flood_params.csv`) with units,
  defaults, and literature sources for all tuning parameters.
* Add `fl_scenarios()` and `fl_params()` for loading pre-defined flood
  factor scenarios and parameter metadata (#28).
* Add flood scenario CSV (`inst/extdata/flood_scenarios.csv`) with three
  scenarios: ff02 (active channel), ff04 (functional floodplain), ff06
  (valley bottom).
* Add flood factor comparison section to vignette with three-panel plot.
* Replace hardcoded summary table with `fl_params()` output.

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
