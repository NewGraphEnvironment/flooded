# Findings — fl_dem_aoi() lets GDAL choose the output grid (#67)

## Issue context

**If we do it:** a DEM fetched for the same AOI lands on the same grid whatever terra/GDAL the caller has, so a floodplain re-run on an upgraded machine reproduces cell for cell, and a provenance digest that moves means the elevations moved.
**If we never do:** every terra or GDAL upgrade silently shifts the grid every floodplain is delineated on. The delineation moves by a fraction of a percent with no data change, and `floodplains`' DEM digest cannot tell a toolchain move from an NRCan re-derivation.

## Problem

`fl_dem_aoi()` crops MRDEM-30 (EPSG:3979) with `snap = "out"` and then calls `terra::project(r_clip, target_crs$wkt)` with no template, resolution or alignment. GDAL's warper then chooses the output origin and resolution (it projects sample points along the source edges and derives an extent and a pixel size that preserve the pixel count, which is why the resolution comes out ~30.43 m rather than 30). That choice changed between GDAL 3.8.5 and 3.13.0, isolated below.

Measured 2026-10-09 on one machine for one AOI: the MORR coho network (`floodplains` `data/morr/aquatic_network.gpkg`, layer `streams_co3`), `buffer = 2000`, `target_crs = 3005`. The source is unchanged (S3 `Last-Modified` 2026-06-24).

| | published 2026-09-03 (terra 1.9.34) | 2026-10-09 (terra 1.9.50, GDAL 3.13.0) |
|---|---|---|
| xmin | 847158.237520556 | 847157.099813495 |
| ymin | 957244.209692687 | 957244.821618025 |
| res | 30.430634377 | 30.430634931 |
| ncell | 16,478,040 | 16,478,040 |

### Isolated: the GDAL version, not terra

The terra upgrade and the GDAL upgrade arrived together, and the 2026-09-03 record names sf's GDAL rather than terra's (floodplains#117), so the table above cannot separate them. One machine can: on m1, sf links GDAL 3.8.5 and terra links GDAL 3.13.0. The same MRDEM crop (`fl_dem_aoi()`'s `crop(snap = "out")`, written to a tif) was reprojected to EPSG:3005 through each:

| | xmin | ymin | res |
|---|---|---|---|
| published (2026-09-03) | 847158.237521 | 957244.209693 | 30.430634377 |
| `gdalwarp` via sf, GDAL 3.8.5 | 847158.237521 | 957244.209693 | 30.430634377 |
| `terra::project()`, GDAL 3.13.0 | 847157.099813 | 957244.821618 | 30.430634931 |

GDAL 3.8.5 reproduces the published grid to six decimals and GDAL 3.13.0 does not, with the same input file on the same machine. The suggested output grid is a function of the GDAL version.

The origin moves ~1.1 m west and ~0.6 m north. `terra::compareGeom()` calls the two grids equal within its tolerance. Delineated with identical parameters (flooded 0.6.0), the floodplain comes out **35,618.0 ha against 35,769.1 ha (−0.42%)**.

## Proposal

Project onto an explicit, deterministic target grid instead of letting the warper choose one: a template in the target CRS from the buffered AOI's extent, snapped outward to multiples of a fixed resolution, passed to `terra::project()`.

```r
res <- 30
bb  <- sf::st_bbox(sf::st_transform(aoi_buf, target_crs))
e   <- terra::ext(floor(bb[["xmin"]] / res) * res, ceiling(bb[["xmax"]] / res) * res,
                  floor(bb[["ymin"]] / res) * res, ceiling(bb[["ymax"]] / res) * res)
tmpl  <- terra::rast(e, resolution = res, crs = target_crs$wkt)
r_out <- terra::project(r_clip, tmpl, method = "bilinear")
```

The grid is then a function of the AOI and two constants, so every GDAL lands on the same cells, and every area shares one grid aligned to multiples of 30 m.

That is a **results change** for every caller, since the grid moves once, so it needs a NEWS entry saying so. Worth measuring:
- whether the projected cell values also differ between GDAL versions on an identical target grid;
- whether a fixed 30 m resolution changes the delineation materially compared with today's ~30.43 m.

Found by floodplains#110's anchor, which replays step 2 against its recorded DEM digest.

Relates: floodplains#117 (the consequence for published floodplains and the provenance gap).




## Plan review 1 (2026-10-13)

`review-1.md` lists the findings and their dispositions. The one that changed the design (G2):
cropping the source to the template's footprint read 1.9–2.3× the source cells (MORR 8.77 M →
16.22 M, PARS 10.68 M → 24.72 M, reviewer's estimate), and every cell it added lay outside the
buffered AOI. The crop stays at the buffered AOI's bbox in the source CRS, padded 2 cells for
bilinear sampling.

## Old-code behaviour on the bundled tile (measured 2026-10-13)

`fl_dem_aoi(streams, source = dem.tif, buffer = 100, target_crs = 3157)` on main: res
10.0124303162, xmin 282320.031212, 24,039 NA cells. The new code gives exactly 10 m on
multiples of 10.

## Pre-existing: UInt32 nodata through terra::project

`inst/testdata/dem.tif` is UInt32 with nodata 4294967295. When `crop()` covers the whole source,
terra returns the file-backed raster, and `terra::project()` fills cells beyond the source with
4294967296 instead of NA. The old code does the same at `buffer = 2000`. It is not introduced
here, and MRDEM is Float32. To be filed as its own issue.

## Errors Encountered

| Error | Resolution |
|-------|------------|
| `identical(terra::ext(a), terra::ext(b))` FALSE for equal extents (compares S4 pointers) | Compare `as.vector(terra::ext())` |

## Phase 3 measurements — MORR coho ff04 (2026-10-13, m1)

Log: `planning/active/logs/20261013_measure_grid_morr.log` (harnesses `measure_grid.R`,
`measure_proj.R`, `probe_warp_proj.R`). terra 1.9.50 / GDAL 3.13.0 / PROJ 9.8.1; sf 1.1.2 /
GDAL 3.8.5 / PROJ 9.5.1; `sf_proj_network()` FALSE.

**Source bytes.** Old crop 8,777,100 source cells; new crop (padded 2 cells) 8,801,084 (×1.0027).
The output grid: old 16,478,040 cells, 46.5% NA (rotated crop); new 9,162,504 cells, 18.9% NA.

**(b) Grid only, same terra stack.**

| arm | grid | ha | vs old |
|---|---|---|---|
| old | GDAL 3.13.0's choice, 30.4306 m | 35,618.0 | (reproduces the issue's figure exactly) |
| mid | aligned, 30.4306 m | 35,658.7 | +0.11% |
| new30 | aligned, 30 m | 35,671.1 | +0.15% |

Totals barely move, but about 1,400 ha changes hands at the margins between any two arms
(old→new30: 34,212.3 shared, 1,405.7 old-only, 1,458.8 new-only). Most of it is the res change
(mid→new30: 1,419.5 / 1,432.0 ha), not the origin.

**(a) Values on one identical 30 m grid.**
- `fl_dem_aoi()` vs `terra::project` default: identical.
- terra default vs terra `by_util`: 98.6% of cells differ, max 3.34 m.
- terra vs sf gdalwarp: nearly every cell differs, max 11.3 m.
- sf default vs sf `-et 0`, within one stack: median 0.095 m, p99 1.07 m, max 4.23 m. That is the warp's 0.125-pixel approximation.
- terra default vs sf `-et 0`: median 0.21 m, p99 1.94 m, max 11.1 m.

**Mechanism: the PROJ database, not GDAL's warper.**
- One point near MORR, MRDEM CRS → 3005, sf (PROJ 9.5.1) minus terra (PROJ 9.8.1) gives
  **+1.13 m east, −0.61 m north**. The issue's grid move, published minus today, was +1.138 m,
  −0.612 m.
- PROJ 9.5.1's best operation is "Inverse of NAD83 to NAD83(CSRS) (4)", accuracy 2 m, and its
  pipeline has **no datum step**: inverse lcc, then aea, both on GRS80.
- PROJ 9.8.1 (`projinfo`, bbox −128,53,−125,56) offers only two candidates, both via WGS 84 with
  Helmert steps: "NAD83(CSRS) to WGS 84 (2) + Inverse of NAD83 to WGS 84 (1)", 5 m.
- So GDAL's suggested grid moved because the datum operation moved. The issue's "isolated: the GDAL
  version" table changed GDAL and PROJ together (review B2).

**(c) The fixed grid with values from the other stack** (`measure_proj.R`): terra 30 m 35,671.1 ha
→ sf gdalwarp 35,809.9 ha (+0.39%; 183.1 terra-only, 321.8 sf-only); with `-et 0`, 35,792.8 ha
(+0.34%). The grid fix alone does **not** make a re-run reproduce across toolchains. The operation
choice moves the floodplain about as much as the grid did (−0.42% in the issue).

## Gate decision 2 (2026-10-13): pin the datum step, allow an override, record versions

The user's framing: provenance tracks versions; it does not freeze our evolution. We want to be able
to recreate a result and to tell what changed. With PROJ choosing, recreating needs the same PROJ,
and a moved digest cannot separate NRCan from a PROJ upgrade. Pinned, any machine recreates it, and
a change of datum step is a flooded commit with a NEWS line.

- `fl_dem_aoi(pipeline = NULL)` pins the projection-only pipeline (no datum step) between two NAD83
  realizations on GRS80 (`dem_pipeline_nad83()`). `""` hands the choice to PROJ, and a string is used
  as given.
- Recording: floodplains to record terra's GDAL/PROJ (follow-up issue).
- The pinned pipeline gives 0 m from PROJ 9.5.1's own shift-free "NAD83 to NAD83(CSRS) (4)" on a
  test point. Test: a synthetic x-field in 3979 projected to 3005 matches the shift-free answer
  (median 3 cm, p99 6 cm: Float32 rounding of the warp output at x ~ -1.9e6, per code-check round 1) and misses it by ~0.71 m when PROJ 9.8.1 chooses.
  Mutation (default → `""`) turns the pin tests red.

## Phase 3 continued — what the pin buys on MORR (log entries (d) and (e))

- terra pinned vs terra unpinned (`measure_grid.R` new30 arm), same 30 m grid: 35,671.1 → 35,679.2 ha
  (**+0.02%**). On the fixed grid the datum step barely moves the delineation; the issue's −0.42%
  came through the **grid**, which the datum step had moved.
- terra pinned vs sf gdalwarp `-ct <same pipeline>`: median 0.21 m, max 9.9 m per cell; floodplain
  +0.37%. **This is not GDAL's version.** With nearest-neighbour, terra (GDAL 3.13.0) and gdalwarp
  (GDAL 3.8.5) are identical in every cell. With bilinear, gdalwarp `-wo XSCALE=1 -wo YSCALE=1
  -et 0` reproduces terra to median 0.02 mm, max 0.12 mm. terra's warper uses an exact transformer
  and scale 1. gdalwarp's defaults (`-et 0.125`, a kernel widened when the scale exceeds 1)
  produce the difference.
- So the earlier (a) and (c) differences, "terra vs sf gdalwarp, +0.34 to +0.39%", measured warp
  **settings**, not the GDAL/PROJ version. They were misread at first as residual cross-toolchain
  drift, which is what prompted gate decision 2. The decision still stands on its own reasoning:
  the datum step moves the grid when GDAL picks it, and moves the values ~1.3 m.
- `terra::project(by_util = TRUE)` with `warpOpts = c("-et", "0")` still differs from gdalwarp with
  `-et 0` (nearest: 381,737 cells differ). Its options did not reproduce the utility's; not pursued.

Net: with the template **and** the pin, a DEM from `fl_dem_aoi()` reproduces across GDAL
3.8.5 ↔ 3.13.0 and PROJ 9.5.1 ↔ 9.8.1 to within 0.12 mm per cell (shown for the warper; terra on
GDAL 3.8.5 was not run directly, since m1 has only terra on 3.13.0).

## Code-check round 1 (2026-10-13) — `review-round1.md`

All seven findings reproduced or accepted, and fixed (44f5902 and the commit after it):
- **Bug:** a geographic NAD83 side (4269 target, 4617 source) gave an **all-NA** raster with the pin. (The mechanism as first written here, "GDAL applies lat/lon order and sf does not", was wrong; see round 2.) Reproduced: 0 vs 356,902 cells. `dem_pipeline_nad83()` now returns `""` when either side is geographic. Test added.
- **Bug:** `terra::project(pipeline=)` arrived in terra 1.9-25 (terra NEWS). DESCRIPTION now has `terra (>= 1.9-25)`.
- **Fragile:** the datum regex missed "North American Datum **of** 1983 (CSRS) version N" (e.g. EPSG:22209). Fixed and tested.
- **False comment:** the pin test's residual is Float32 rounding, not warp approximation. Fixed.
- **Test passing for the wrong reason:** the "string used as given" arm passed the pin itself. It now passes the pin plus a 50 m affine shift.
- **Low:** the Rd claimed "about 30.43 m"; Parsnip came out at 30.54 m. Now "30.4 to 30.5 m, depending on the AOI".
- **Low:** the log's git labels name the HEAD at run time, while the runs measured uncommitted working-tree code. `measure_grid.R`/`measure_proj.R` measured what landed in cb53fb7 (no pin). `measure_pin.R`/`probe_warp_kernel.R` measured the pin as committed in 30df085. A note is appended to the log.

## Code-check round 2 (2026-10-13) — `review-round2.md`: a defect inside round 1's fix

Round 1 guarded on `st_is_longlat()`, a **proxy**. The property is axis order. Projected NAD83 CRSs
with northing first were still pinned (35 of 1,920 non-deprecated EPSG NAD83/GRS80 projected
CRSs, per the reviewer; e.g. EPSG:2953 and the Illinois ICS83 ftUS zones).
- As a target: all NA. Reproduced: 0 of 380,042 cells pinned, 261,921 with `""`.
- As a source: the template lands about 7,700 km away, and data fills it there.

Fixed: pin only when both CRSs' first two WKT axes are `east`, `north`. The longlat guard is
kept, because it also excludes the `unitconvert` steps the builder no longer writes. Tests for 2953
as target and source. The prose mechanism is now "a pipeline can meet a CRS's authority axis order
on some paths", not the round-1 claim about sf.

Because a round found a defect inside a fix, the loop ends by enumeration, not by a quiet round:
`planning/active/enumerate_pin.R`.

## Code-check round 3 (2026-10-13) — `review-round3.md`: the mechanism

The reviewer's statement of it: whether a hand-built PROJ pipeline is valid for a CRS was decided
from a stand-in (`st_is_longlat`, WKT regexes, names, `proj4string`, `units_gdal`) rather than from
the libraries that run it, sf and GDAL's warper, each of which applies the CRS's authority axis
order around the pipeline.
- **Round 1** used geographic as a stand-in for axis order.
- **Round 2** tests the axis order itself.
- **Round 3** found the assumption one level up, in the enumeration harness: "no failing row" was
  read as "every pinned CRS passes".

In the package code every place the mechanism reaches was checked and found sound. `is_nad83` and
`east_north` read sf's normalised WKT2, and a miss is the safe direction. `st_is_longlat` is still
needed (OGC:CRS83 is lon/lat with east/north axes). Pipelines in feet are correct through both sf
and terra, and the gate on the sf branch distinguishes axis-swapped CRSs.

Fixed:
- **The `@details` sentence** said every projected NAD83 pair is pinned; it now says east/north
  axes only.
- **The harness, which could pass vacuously:** every foot CRS errored with no `res` (744 of 1,886
  pinned), and an errored or all-NA row dropped out as NA. It never exercised the sf branch, and an
  x-only field could not see a north–south shift. Rewritten: `res` in the target's units; four
  cases per CRS (A, A2, B, B2), so the AOI-in-source-CRS sf branch runs; an x **and** y field; and
  a pinned case that errored or has no PROJ data counts as not passing.
- **Proven able to fail** on 7 CRSs (3005, 2953, 26910, 23301, 2227, 22209, 3979):
  - unmutated: 20 of 20 pinned cases pass;
  - with the axis guard removed: 8 fail (2953 and 23301, all four cases);
  - with `+proj=affine +yoff=150` added to the pin: all 20 fail.
