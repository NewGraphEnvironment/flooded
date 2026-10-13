## Outcome

`fl_dem_aoi()` no longer lets GDAL or PROJ choose how a DEM is reprojected (#67).
- **Grid:** it projects onto the buffered AOI's bbox in `target_crs`, snapped outward to multiples
  of a new `res` argument. `res` defaults to the source cell size, so MRDEM-30 lands on exactly
  30 m; a geographic target must pass `res`.
- **Datum step:** pinned to the projection-only pipeline between projected east/north CRSs on NAD83
  realizations. A new `pipeline` argument overrides it; `""` hands the choice to PROJ.
- **Parsnip cache:** rebuilt from cached inputs.
- **Notes and docs:** relabelled.

**What was learned:** the issue's diagnosis, "the GDAL version moved the grid", was wrong. The
comparison had changed GDAL and PROJ together, and the cause is PROJ's NAD83(CSRS)→NAD83
operation:
- PROJ 9.5.1 applies no shift;
- PROJ 9.8.1 routes through WGS 84, ~1.3 m away;
- GDAL's suggested grid follows the operation.

A second apparent residual (+0.35%) turned out to be `gdalwarp`'s default warp settings, not
toolchain drift; that misreading prompted the pin decision, which the user then made on its own
merits ("provenance tracks versions": pin, allow an override, record versions). Code review found
the pin's validity check built twice on a stand-in (geographic, then still blind to northing-first
projected CRSs); the loop ended by enumerating all 1,935 EPSG NAD83 projected CRSs. The durable
verdict is `research/dem_reprojection.md`.

## Measurement

MORR coho `co_ff04`, terra 1.9.50 (GDAL 3.13.0 / PROJ 9.8.1), one session:

| DEM | ha | vs GDAL's grid |
|---|---|---|
| GDAL 3.13.0's chosen grid, 30.4306 m | 35,618.0 | |
| aligned, 30.4306 m | 35,658.7 | +0.11% |
| aligned, 30 m | 35,671.1 | +0.15% |
| aligned, 30 m, datum step pinned | 35,679.2 | +0.17% |

- **Margin churn:** about 1,400 ha changes hands between any two grids. Source cells read: ×1.0027.
- **Datum step:** sf (PROJ 9.5.1) minus terra (PROJ 9.8.1) is +1.13 m east, −0.61 m north at one
  point, which matches the issue's grid move (+1.138, −0.612).
- **With the pin:** gdalwarp on GDAL 3.8.5 with terra's settings (`-et 0`, `XSCALE=YSCALE=1`)
  reproduces terra on GDAL 3.13.0 to a max of 0.12 mm. Nearest-neighbour is identical in every cell.
  gdalwarp's defaults differ by up to 9.9 m per cell (+0.37% of floodplain).
- **Parsnip:** ff04 41,142.9 → 40,888.2 ha (−0.6%); DEM 20.9 → 14.1 Mcell; the ff04–ff07 span
  6.4% → 6.3%; ff04–ff06 4.6% → 4.4%.
- **Enumeration:** 7,544 pinned cases over 1,935 CRSs; 7,501 pass. The other 43 are PROJ 9.8.1's
  own choice 3.5–88 m off (32) or a template row snapping differently (11); 0 unexplained.
- **The wrong turns, kept in `findings.md`:**
  - "GDAL version" (retracted);
  - "fixed grid still drifts +0.35% across toolchains" (retracted: warp settings);
  - round 1's longlat guard (a stand-in, fixed in round 2).

## Evidence

`logs/20261013_*` in this directory. The harnesses are the `*.R` files here. Reviews:
`review-1.md` (plan), `review-round{1,2,3}.md` (code-check).
