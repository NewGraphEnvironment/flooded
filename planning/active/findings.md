# Findings — fl_dem_aoi() read window transform (#78)

## Issue context

**If we do it:** `fl_dem_aoi()` returns the same DEM cells for the same AOI whichever PROJ sf links, not only whichever PROJ terra links.
**If we never do:** a PROJ upgrade on the sf side can change which edge cells of the returned DEM are `NA`, so a digest of the DEM moves with no data change. That is #67's symptom, at the edges instead of the whole grid.

## Where

In 0.7.0 the template grid and the warp are pinned (#67): `terra::project(r_clip, tmpl, method = "bilinear", pipeline = pipeline)`. The source read window is not. It comes from

```r
aoi_buf_in_r <- if (r_crs == aoi_crs) aoi_buf else sf::st_transform(aoi_buf, r_crs)
bs     <- sf::st_bbox(aoi_buf_in_r)
r_clip <- terra::crop(r, terra::ext(bs[["xmin"]] - pad, ..., ), snap = "out")
```

`sf::st_transform()` here takes PROJ's default operation, through sf's PROJ. For MRDEM-30 (NAD83(CSRS)) and a BC Albers AOI (NAD83), PROJ 9.5.1 and 9.8.1 disagree by about 1.3 m (the difference #67 measured). `r_clip` snaps outward to 30 m source cells with a two-cell pad, so a 1.3 m shift changes the window only when an edge falls within 1.3 m of a source cell boundary. Where it does, the template cells near that edge read different source cells, and some flip between a value and `NA`.

Not measured. This is from reading the function: whether any real AOI hits it, and whether a floodplain can reach those edge cells, has not been checked.

## Proposal

Transform the read window with the same pinned operation, inverted: `sf::st_transform(aoi_buf, r_crs, pipeline = <inverse of pipeline>)` when `pipeline` is set. Or widen `pad` enough that a metre-scale shift can never move a cell the template reads. A test can check it: run the window transform with and without the WGS 84 route and assert that the returned DEM is identical.

Relates: #67, NewGraphEnvironment/floodplains#117


## Plan-mode probe (2026-10-13/14)

On this machine sf links PROJ 9.5.1 (no shift for 3005 → 3979) and terra links 9.8.1, which is
exactly the split the issue names.

**Measured in plan mode (read-only probe):** bundled streams, buffer 100, a 30 m x-field source in
EPSG:3979, AOI translated over 60 sub-cell offsets (0–29.5 m, 0.5 m steps). The read window was
transformed shift-free and then through PROJ 9.8.1's WGS 84 route (`projinfo` operation 1, 5 m).
- **3 of 60 offsets** changed the returned DEM, by 47, 91 and 49 cells.
- **0** of those cells lie inside the buffered AOI. They are NA/value flips in the template's
  outer cells, past the two-cell pad.

So the hazard is real for the digest and should be invisible to a delineation. Widening `pad`
cannot fix it: a wider window still has an edge that can fall within 1.3 m of a cell boundary.
Only reading the whole template footprint would remove it, and #67 rejected that at ~2× the bytes.
That leaves pinning. `sf::st_transform(..., pipeline =, reverse = TRUE)` inverts a pipeline
correctly (probe: inverse of the pin = forward pin to 0 m; the +50 m affine string inverts to the
expected offset).

## Errors Encountered

| Error | Resolution |
|-------|------------|
| `sf_proj_pipelines: is.character(target_crs) is not TRUE` when `st_transform(x, 3979, pipeline=)` | pass the target as WKT (`sf::st_crs(3979)$wkt`) whenever a pipeline is given |
| Identity tests green on 0.7.0 with offsets from a search | offsets depend on the source grid's origin; search on the exact test fixture |
| `pipeline = ""` test green for the wrong reason (source built from the shifted AOI) | build the source from the unshifted AOI, then shift |
