# DEM reprojection: who chooses the grid, the datum step and the warp settings

**Verified:** 2026-10-14 · **Issues:** flooded#67, floodplains#117, flooded#76, flooded#78 · **Produced by:**
`planning/archive/2026-10-issue-67-fl-dem-aoi-grid/` — `measure_grid.R`, `measure_proj.R`,
`measure_pin.R`, `probe_warp_kernel.R` (MORR coho, MRDEM-30 → BC Albers), `rebuild_pars.R`
(Parsnip WSG), `enumerate_pin.R` + `classify_enum_fails.R` (all EPSG NAD83 projected CRSs), with
logs under that archive's `logs/20261013_*`. Measured with terra 1.9.50 (GDAL 3.13.0, PROJ 9.8.1)
and sf 1.1.2 (GDAL 3.8.5, PROJ 9.5.1) in one session.

Reprojecting a DEM involves three choices. Left to the toolchain, each one can move a
delineated floodplain with no change in the data.

## 1. The grid

`terra::project(x, crs)` with no template lets GDAL derive the origin and cell size from the
transformed source edges. MRDEM-30 came out at 30.4306 m for MORR and 30.5423 m for Parsnip. Because the
grid is derived from the coordinate operation, it moves when that operation moves.

**Measured.** MORR's grid moved +1.138 m east and −0.612 m north between the published run and
today. Delineated, that was 35,769.1 → 35,618.0 ha (−0.42%).

**What `fl_dem_aoi()` does:** the buffered AOI's bbox in `target_crs`, snapped outward to multiples
of `res` (default: the source cell size).

**Measured on MORR `co_ff04`, one session:**

| grid | ha | vs old |
|---|---|---|
| GDAL 3.13.0's choice, 30.4306 m | 35,618.0 | |
| aligned, 30.4306 m | 35,658.7 | +0.11% |
| aligned, 30 m | 35,671.1 | +0.15% |

Totals barely move, but about 1,400 ha changes hands at the margins between any two grids, mostly
from the cell size.

## 2. The datum step

MRDEM-30 is NAD83(CSRS) (EPSG:3979) and BC Albers is NAD83 (EPSG:3005).
- PROJ 9.5.1's best operation, "NAD83 to NAD83(CSRS) (4)" (2 m), has **no datum step**.
- PROJ 9.8.1 offers only routes through WGS 84 with Helmert steps (5 m).
- One point near MORR, sf minus terra, is +1.13 m east and −0.61 m north. That is the grid move
  in section 1.

On a fixed grid, the step itself moved MORR's floodplain only +0.02% (35,671.1 → 35,679.2 ha).

**Further afield it is not small.** For NAD83(2011) and NAD83(NSRS2007) in the Alaska and Aleutian
zones, PROJ 9.8.1's own choice sits 13–88 m from the shift-free answer when deformation grids are
absent (3.5 m for InGCS Bartholomew ftUS, 14 m for NAD83(CSRS)v6–v8 UTM 8N). PROJ 9.5.1 agrees
with shift-free to 0.00 m. So the answer depends on the PROJ version and on which grid files a
machine has.

**What `fl_dem_aoi()` does:** it pins the projection-only pipeline (`dem_pipeline_nad83()`) between
**projected** CRSs on NAD83 realizations whose first two axes are **east, north**. `pipeline = ""`
hands the choice back to PROJ.

**Measured over all 1,935 EPSG NAD83 projected CRSs, 4 cases each:** 7,501 of 7,544 pinned cases
pass. The other 43 are PROJ 9.8.1's own choice being the outlier (32) or a template row snapping
differently (11); none is unexplained.

**The AOI's own transforms are pinned too (#78).** The read window (the buffered AOI carried into
the source CRS) and, for an AOI in a third CRS, the grid (carried into `target_crs`) went through
sf's PROJ with its default operation until #78. An edge within the datum step of a source cell
boundary then crops one column or row differently. **Measured** with the bundled streams, buffer
100 m, a 30 m source in EPSG:3979, the AOI moved over 60 sub-cell positions, and the window taken
shift-free and through PROJ 9.8.1's WGS 84 route: 3 of 60 positions changed the returned DEM,
by 49, 91 and 47 cells (32, 60 and 31 of them NA/value flips). **None lay inside the buffered
AOI.** So it moves a digest, not a delineation that stays inside the buffer
(`planning/archive/2026-10-issue-78-*/measure_window.R`, log `logs/20261014_measure_window.log`).
A wider pad cannot remove it: any window edge can sit that close to a boundary. Only reading the
whole template footprint, about 2x the bytes, would. A supplied `pipeline` is inverted
(`reverse = TRUE`) for the window when the AOI is in `target_crs`.

**Measured against the fix, with a real PROJ split:** every unpinned sf transform routed through
terra's PROJ 9.8.1 (+0.71, −1.05 m here), the same 60 positions through `fl_dem_aoi()` itself.
0.7.0 changed the DEM at 3 of 60 (dx = 3.5, 21.5, 28.5: the probe's three), the fix at **0 of 60**
(`measure_window_real_proj.R`, log `logs/20261014_measure_window_real_proj.log`). On sf's own PROJ
9.5.1 the fix is output-neutral: six call shapes identical to 0.7.0. A WGS 84 source still leaves
the read window to sf's PROJ (CSRS or NAD83 to WGS 84 has no pin). Its grid is pinned when the AOI
is in a projected NAD83 CRS of its own; an AOI in the WGS 84 source's CRS leaves both to sf's PROJ.

**Why geographic and northing-first CRSs are excluded.** A supplied pipeline meets a CRS's
authority axis order (lat/lon; or northing first, as in EPSG:2953 and the Illinois ICS83 zones) on
some library paths and east/north on others. The result is an all-NA raster or one ~7,700 km
away, with no error. Code review found this twice, the second time inside the first fix. Decide
pipeline validity from the axes, never from a stand-in such as `st_is_longlat()`.

## 3. The warp settings

With the pipeline pinned, terra (GDAL 3.13.0) and `gdalwarp` (GDAL 3.8.5) are **identical in every
cell with nearest-neighbour**.

With bilinear they differ: median 0.21 m and max 9.9 m per cell, which is +0.37% of MORR's
floodplain. That difference is the settings, not the version:
- terra's warper uses an exact transformer at scale 1;
- `gdalwarp` defaults to `-et 0.125` and widens the kernel with scale;
- `gdalwarp -wo XSCALE=1 -wo YSCALE=1 -et 0` reproduces terra to a median of 0.02 mm and a max of
  0.12 mm.

So compare warps like for like, and re-derive a kept DEM through `fl_dem_aoi()`, not `gdalwarp`.

## 4. Integer nodata through terra's warp (#76)

**Verified:** 2026-10-14, terra 1.9.50 / GDAL 3.13.0 / PROJ 9.8.1 · **Produced by:**
`planning/archive/2026-10-issue-76-fl-dem-aoi-a-whole-file-uint32-source-re/reprex_terra_uint32.R`

`terra::project()` of a **file-backed** `INT4U` raster with NoData 4294967295 leaves the cells no
source cell maps to at **4294967296**, that NoData rounded to Float32, in an output tagged
`NoData=nan`, so they read back as data. As observed, cells beyond the source that still equal
the NoData in Float32 are written as NaN (a file-backed `INT2U`, NoData 65535: all 45,116 NaN);
the rounding is what defeats that match. terra's internals were not read. The bundled `dem.tif` is such a source:
`fl_dem_aoi(streams, dem.tif, buffer = 2000, target_crs = 3157)` returned 2^32 beyond the tile
on 0.6.6 and every release since.

It is terra's, not GDAL's: `gdalwarp` from the same GDAL 3.13.0 build, Float32 output, tags
NoData 4.2949673e+09 and the fill is masked. What triggers it is an integer NoData that Float32
cannot hold exactly, not the crop:

| source | max beyond the source |
|---|---|
| `INT4U`, file-backed (whole-file crop, or any crop terra writes to disk) | 4294967296 |
| `INT8U`, file-backed (terra's default NoData) | 1.8e19 |
| `INT4S` with NoData 2147483647 | 2147483648 |
| `INT4S` with NoData −2147483648, `INT2U`, `FLT4S` | `NA` |
| the same `INT4U` values in memory (`x * 1`), or `datatype = "FLT8S"` | `NA` |

The issue first read it as a whole-file crop effect, because a subset crop is usually in memory.
Under `terraOptions(todisk = TRUE)` the subset crop (`buffer = 100`) gives 2^32 as well, so a
fix keyed on "in memory" would have missed large AOIs. `fl_dem_aoi()` reads an integer crop
through a float copy before projecting. MRDEM-30 and other float sources are untouched. A
draft upstream report is in the same archive (`upstream_terra_draft.md`); posting it is
pending approval.

## Consequences

- With template + pin, a DEM from `fl_dem_aoi()` reproduces across GDAL 3.8.5 ↔ 3.13.0 and PROJ
  9.5.1 ↔ 9.8.1 to within 0.12 mm per cell. The warper was shown that way; terra on GDAL 3.8.5 was
  not run. Until #78 that held for **terra's** PROJ only: the AOI's transforms went through sf's,
  and moved edge cells. Since #78 it holds for both where the AOI's pairs are projected NAD83 with
  easting-then-northing axes.
- Record terra's GDAL and PROJ (`terra::gdal(lib = "all")`) with any kept DEM (floodplains#117),
  and sf's PROJ (`sf::sf_extSoftVersion()`) too when the AOI's CRS pair is not pinned
  (geographic, northing-first or non-NAD83 on either side).
- The first diagnosis, "the GDAL version", was wrong. Its comparison changed GDAL and PROJ
  together, and a later +0.35% "residual drift" was warp settings. Both are kept in the archive's
  `findings.md` as the record of how the cause was found.
