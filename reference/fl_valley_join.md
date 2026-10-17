# Join per-segment attributes to valley cells by position

Takes a delineation, its attribution by
[`fl_valley_attribute()`](https://newgraphenvironment.github.io/flooded/reference/fl_valley_attribute.md),
and a set of stream segments carrying logical attributes (habitat flags,
for example), and gives every valley cell the attributes of the segment
beside it. This answers "which part of the floodplain sits beside
segments with attribute X", which a join on the group key does not.

## Usage

``` r
fl_valley_join(valleys, attributed, segments, group, cols = NULL)
```

## Arguments

- valleys:

  A binary (`0`/`1`) `SpatRaster`, the output of
  [`fl_valley_confine()`](https://newgraphenvironment.github.io/flooded/reference/fl_valley_confine.md).

- attributed:

  The `sf` output of
  [`fl_valley_attribute()`](https://newgraphenvironment.github.io/flooded/reference/fl_valley_attribute.md)
  for `valleys`, one row per group, in the CRS of `valleys`.

- segments:

  An `sf` linestring object carrying the `group` column and the logical
  attribute columns. Transformed to the CRS of `valleys` if needed;
  empty geometries are dropped.

- group:

  Character. Name of the group column shared by `attributed` and
  `segments`, e.g. `"blue_line_key"`. Keys are matched with
  [`match()`](https://rdrr.io/r/base/match.html), so they must have the
  same type in both; an `NA` key matches the `NA` group. Segments whose
  key no row of `attributed` carries are ignored.

- cols:

  Character. Names of the logical columns in `segments` to join. If
  `NULL` (default), every logical column other than `group`. Flags
  stored as `0`/`1` integers need
  [`as.logical()`](https://rdrr.io/r/base/logical.html) first. The
  nearest-segment search does not depend on `cols`, so join several
  flags (several species, say) in one call rather than one call each.

## Value

A list:

- `nearest`:

  A data frame with one row per attributed valley cell: `cell` (cell
  index into `valleys`), the owning group (a column named after
  `group`), `dist` (map units from the cell centre to the owning
  segment) and one column per element of `cols`. The rule for areas.

- `any`:

  A data frame with one row per attributed valley cell: `cell` and one
  column per element of `cols`, `TRUE` where any claiming group's
  nearest segment is `TRUE`. The "connected to" view.

- `check`:

  Named integer: `valley_cells`, `attributed_cells` (distinct cells
  inside `attributed`), `missing` (valley cells no group claims) and
  `extra` (claimed cells outside the valley). Both of the last two are
  zero when `attributed` covers the delineation, as
  `fl_valley_attribute(complete = TRUE)` does unless no stream cell
  burns for its fallback (it then reports the cells it left out). The
  check sees only the union of the claims: a simplified or reprojected
  copy of `attributed` can move cells between groups and still pass.

- `ties`:

  Integer. Cells whose two nearest claiming groups are exactly equally
  near.

- `no_segments`:

  Keys of claiming groups with no segment in `segments`.

Rows of both tables are in cell order.

## Details

Each valley cell is claimed by one or more groups (the rows of
`attributed` it falls inside). For each claiming group, the cell takes
the attributes of that group's segment nearest its centre. Only claiming
groups compete: the nearest segment anywhere can sit on a line the
delineation never used (a stream below a network's order floor, say),
and that line's attributes say nothing about ground it did not shape.

Where several groups claim a cell, there are two answers, and both are
returned:

- **`nearest`** gives the cell one owner, the claiming group whose
  nearest segment is nearest. Every cell is counted once, so per-group
  or per-reach areas add up to the floodplain: use it for areas. Exactly
  equal distances go to the lowest key (numeric order for numbers,
  C-locale order for text, level order for a factor, `NA` last), and the
  number of such cells is returned as `ties`. `seg` is the row of
  `segments` that owns the cell (`NA` where the owning group has no
  segments), so any per-segment value, a numeric grade or a length as
  much as a flag, joins to the cells it owns.

- **`any`** is `TRUE` where any claiming group's nearest segment is
  `TRUE`: ground connected to an attribute through at least one
  watercourse. A cell can be counted under several groups' flags, so it
  does not partition.

A `nearest` `TRUE` is always an `any` `TRUE`.

Joining on the group key instead gives a group's whole floodplain any
attribute found anywhere on it. On the Bulkley watershed group's
whole-network floodplain (30 m, `ff04`, by `blue_line_key`) that read
16,705 ha as sockeye spawning, against 572 ha by position (`nearest`).

### Missing values

A segment's `NA` is copied as is under `nearest`, and combined by
[`any()`](https://rdrr.io/r/base/any.html) under `any` (`NA` unless a
claimer says `TRUE`). A claiming group with no segments has nothing to
measure from: it never owns a cell another claimer has segments for, it
is left out of `any`, and a cell only it claims gets `NA` attributes,
`dist = Inf` and that group as owner. Such groups are listed in
`no_segments`.

Valley cells outside every row of `attributed` (possible with
`fl_valley_attribute(complete = FALSE)`) get no row, and claimed cells
outside the valley are dropped; either case warns and is counted in
`check`.

A cell is inside a row of `attributed` when its centre is, so the claims
of an unmodified
[`fl_valley_attribute()`](https://newgraphenvironment.github.io/flooded/reference/fl_valley_attribute.md)
output are exactly the cells it attributed. Duplicate rows for one group
count once.

Distances are planar, measured from cell centres with
[`sf::st_nearest_feature()`](https://r-spatial.github.io/sf/reference/st_nearest_feature.html)
and
[`sf::st_distance()`](https://r-spatial.github.io/sf/reference/geos_measures.html);
a lon/lat `valleys` is refused.

## See also

[`fl_valley_attribute()`](https://newgraphenvironment.github.io/flooded/reference/fl_valley_attribute.md)

## Examples

``` r
dem <- terra::rast(system.file("testdata/dem.tif", package = "flooded"))
streams <- sf::st_read(
  system.file("testdata/streams.gpkg", package = "flooded"),
  quiet = TRUE
)
precip_r <- fl_stream_rasterize(streams, dem, field = "map_upstream")
valleys <- fl_valley_confine(dem, streams,
                             area_field = "upstream_area_ha", precip = precip_r)
attributed <- fl_valley_attribute(valleys, streams, group = "blue_line_key",
                                  dem = dem)

# A per-segment flag: channels wider than 20 m
streams$wide <- !is.na(streams$channel_width) & streams$channel_width > 20
j <- fl_valley_join(valleys, attributed, streams, group = "blue_line_key",
                    cols = "wide")
#> ℹ 48 cells tied between claiming groups - assigned to the lowest key.
j$check
#>     valley_cells attributed_cells          missing            extra 
#>            28727            28727                0                0 

# Floodplain beside a wide channel (ha): one owner per cell, then any claimer
cell_ha <- prod(terra::res(valleys)) / 1e4
c(nearest = sum(j$nearest$wide) * cell_ha, any = sum(j$any$wide) * cell_ha)
#> nearest     any 
#>  190.55  260.82 

# Joining on the key instead credits each blue line's whole floodplain
wide_keys <- unique(streams$blue_line_key[streams$wide])
by_key <- terra::cells(valleys, terra::vect(
  attributed[attributed$blue_line_key %in% wide_keys, ]
))
length(unique(by_key[, "cell"])) * cell_ha
#> [1] 263.85

# Map it
r <- terra::rast(valleys)
r[j$nearest$cell] <- j$nearest$wide
terra::plot(r, main = "Floodplain beside a wide channel (nearest)")

```
