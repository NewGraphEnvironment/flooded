# Findings — Add DEM source helpers (file, STAC) for AOI-driven workflows (#34)

## Issue context

### Problem

`fl_valley_confine()` and related flooded functions accept `SpatRaster` — the user is responsible for sourcing the DEM. Two patterns surface in real use:

- **Manual file copy** — `restoration_wedzin_kwa_2024/scripts/floodplain_lcc/02_floodplain_model.R:87-98` copies a pre-clipped DEM from a bcfishpass habitat-lateral output (`/Users/airvine/Projects/repo/bcfishpass/model/habitat_lateral/data/temp/BULK/dem.tif`) to the project's GIS folder. One-time, hardcoded to the upper Bulkley project.
- **STAC fetch** — `vignettes/stac-dem.Rmd` shows the rstac + gdalcubes pattern. Illustrative, but production drivers re-roll it.

Scaling to FWCP peace (Pars WSG to start, then more) means each project shouldn't have to hand-roll AOI-driven DEM fetch. Need helper(s) that take an AOI and return a `SpatRaster`, with the source abstracted.

### Acceptance (from issue)

- `fl_dem_aoi()` exported, tested with both file and STAC sources
- Vignette section showing AOI-driven DEM fetch (replaces ad-hoc per-project code)
- `buffer` arg with sensible default + docstring guidance
- Memory note in docstring: very large AOIs may need caller-side chunking (deferred to #B issue)

### Out of scope (from issue)

- DEM source registry / config module — defer until N=2+ projects need it
- Slope derivation — wedzin pre-derives it from the same source; separate concern
- Multi-AOI orchestration — covered in companion issue (WSG-scale pipeline)

## Architecture decisions resolved during planning

### Source-of-truth: `Projects/repo/rtj/docs/dem-sources.md`

After exploring the surface (potential new package, fresh-as-DEM-grabber, dedicated dem-bc package, S3 versioning), the rtj doc settled the architecture:

- **MRDEM-30** is the primary path for watershed-scale flooded work. Single 84 GB COG on `s3://canelevation-dem/mrdem-30/mrdem-30-dtm.tif`, public, no auth, `/vsicurl/` access. `terra::rast(URL)` opens lazily; `terra::crop()` range-reads only the AOI bytes. **No `rstac` needed for the primary path.**
- **LidarBC via `stac-dem-bc`** is the secondary/optional path for sub-10m riparian-scale work. `rstac` already in flooded's Suggests handles this.
- **Don't mirror MRDEM** — NRCan-hosted S3 is more durable than anything we'd build (rtj doc:67).
- **Reproject AFTER crop** (rtj doc:156) — never reproject the full 84 GB COG. Load-bearing gotcha.
- **TRIM archive** (29 WSGs only) is a one-time tarball at `s3://fresh-bc/archive/`, not STAC. Already-extracted local files work via `fl_dem_aoi(source = "/path/to/extracted/dem.tif")`.

### Buffer semantics resolved by user

`buffer` applies to whatever sf geometry is passed as `aoi`. Pass a polygon AOI for region-bounded crops; pass streams (sf LINESTRING) for tight, memory-efficient crops along the stream corridor. Wedzin's production optimization (`02_floodplain_model.R:43, 105` — `buf <- 2000; stream_ext <- ext(vect(streams)) + buf`) is exactly the streams-as-aoi case, now first-class via this API. Docstring must call out the memory/time tradeoff.

### Why no new package, why not fresh

- fresh is a **network engine** (FWA streams, snapping, traversal) — not a DEM grabber.
- MRDEM is `terra::rast(URL)` with no STAC needed — a single function in flooded is the right home.
- New package (`stacdembc`, `dempot`, etc.) is overhead without payoff when the primary path is one URL constant + 15 LOC.
- LidarBC STAC fetch stays as an example pattern in vignette + roxygen, not a wrapper function. If a second STAC-driven workflow appears later, promote to function.

## flooded codebase patterns confirmed

From the Explore agent survey:

- `fl_*` exports, one function per file, mirrored test in `tests/testthat/`
- SpatRaster-first arg convention; `stopifnot()` validation; return SpatRaster
- `@import terra` and `@importFrom sf ...` centralized in `R/flooded-package.R:2-3`
- Examples use `system.file()` via `testdata_path()` helper in `tests/testthat/setup.R:2-4`
- `inst/testdata/` has `dem.tif` (10m BC Albers), `slope.tif`, `streams.gpkg`, `waterbodies.gpkg`
- `vignettes/stac-dem.Rmd` already exists with the LidarBC STAC pattern at lines 95-184 — leave untouched

## Vignette caching pattern from `cd`

`~/Projects/repo/cd/data-raw/peace_fwcp_vignette_data.R` and `~/Projects/repo/cd/vignettes/peace-fwcp.Rmd` are the reference:

- data-raw script runs heavy network/computation work locally (regional climate analysis with ~144 COG range requests)
- Caches outputs as small .rds (271 KB for Peace) + small .tif (6 KB for Peace) to `inst/vignette-data/`
- **Total bundled output target <1 MB** — cd's full Peace + Kootenay analysis fits in 692 KB
- Vignette frontmatter: `bookdown::html_document2`, `bibliography: references.bib`, `link-citations: true` — directly portable to a Peace report appendix

For flooded's PARS vignette, the cached outputs are mostly sf objects (highly compressible) plus a small DEM tile for the hero map. Realistic cache budget 5-15 MB.

## Critical reference paths

- `Projects/repo/rtj/docs/dem-sources.md:50-65` — exact MRDEM access pattern to lift verbatim
- `Projects/repo/rtj/docs/dem-sources.md:67` — "do not mirror MRDEM" rationale
- `Projects/repo/rtj/docs/dem-sources.md:156` — reproject-after-crop gotcha
- `Projects/repo/cd/data-raw/peace_fwcp_vignette_data.R` — data-raw cache pattern
- `Projects/repo/cd/vignettes/peace-fwcp.Rmd` — vignette structure for report-appendix portability
- `Projects/repo/restoration_wedzin_kwa_2024/scripts/floodplain_lcc/02_floodplain_model.R:43, 87-107` — wedzin's manual pattern this replaces
- `Projects/repo/flooded/vignettes/stac-dem.Rmd:95-184` — existing LidarBC STAC pattern (left untouched, referenced in roxygen example)

## Bug to file separately

Planning-init skill's slug regex uses GNU `sed`-only `\+` syntax — fails silently on macOS BSD sed. Produced `34-add dem source helpers (file, stac) for` with literal spaces and parens until I switched to `sed -E`. Out of scope for #34; will file against soul.
