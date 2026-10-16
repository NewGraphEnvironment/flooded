# Package index

## Delineate

Map the floodplain from an elevation model and a stream network.

- [`fl_valley_confine()`](https://newgraphenvironment.github.io/flooded/reference/fl_valley_confine.md)
  : Delineate unconfined valleys using the Valley Confinement Algorithm
- [`fl_valley_poly()`](https://newgraphenvironment.github.io/flooded/reference/fl_valley_poly.md)
  : Convert a binary valley raster to polygons
- [`fl_stream_rasterize()`](https://newgraphenvironment.github.io/flooded/reference/fl_stream_rasterize.md)
  : Rasterize a stream network onto a DEM grid

## Get an elevation model

- [`fl_dem_aoi()`](https://newgraphenvironment.github.io/flooded/reference/fl_dem_aoi.md)
  : Fetch a DEM cropped to an AOI

## Per watercourse

Attribute one floodplain to each watercourse, and join per-reach flags
to it.

- [`fl_valley_attribute()`](https://newgraphenvironment.github.io/flooded/reference/fl_valley_attribute.md)
  : Attribute valley cells to the stream groups that produced them
- [`fl_valley_join()`](https://newgraphenvironment.github.io/flooded/reference/fl_valley_join.md)
  : Join per-segment attributes to valley cells by position

## Flood levels and parameters

- [`fl_scenarios()`](https://newgraphenvironment.github.io/flooded/reference/fl_scenarios.md)
  : Load flood factor scenarios
- [`fl_params()`](https://newgraphenvironment.github.io/flooded/reference/fl_params.md)
  : Load VCA parameter legend

## Pipeline steps

The steps
[`fl_valley_confine()`](https://newgraphenvironment.github.io/flooded/reference/fl_valley_confine.md)
runs, for running or inspecting one on its own.

- [`fl_mask()`](https://newgraphenvironment.github.io/flooded/reference/fl_mask.md)
  : Create a binary mask from a raster by thresholding
- [`fl_mask_distance()`](https://newgraphenvironment.github.io/flooded/reference/fl_mask_distance.md)
  : Binary mask by Euclidean distance from features
- [`fl_cost_distance()`](https://newgraphenvironment.github.io/flooded/reference/fl_cost_distance.md)
  : Accumulated cost distance from stream cells
- [`fl_flood_model()`](https://newgraphenvironment.github.io/flooded/reference/fl_flood_model.md)
  : Run the full flood model
- [`fl_flood_surface()`](https://newgraphenvironment.github.io/flooded/reference/fl_flood_surface.md)
  : Compute flood surface elevation at stream cells
- [`fl_flood_depth()`](https://newgraphenvironment.github.io/flooded/reference/fl_flood_depth.md)
  : Interpolate flood surface and compute depth above terrain
- [`fl_patch_rm()`](https://newgraphenvironment.github.io/flooded/reference/fl_patch_rm.md)
  : Remove small patches from a binary raster

## Raster helpers

Combine, subtract or filter binary rasters outside
[`fl_valley_confine()`](https://newgraphenvironment.github.io/flooded/reference/fl_valley_confine.md).

- [`fl_flood_assemble()`](https://newgraphenvironment.github.io/flooded/reference/fl_flood_assemble.md)
  : Union multiple binary rasters
- [`fl_flood_trim()`](https://newgraphenvironment.github.io/flooded/reference/fl_flood_trim.md)
  : Subtract mask layers from a binary raster
- [`fl_patch_conn()`](https://newgraphenvironment.github.io/flooded/reference/fl_patch_conn.md)
  : Keep only patches connected to anchor features
