#' Attribute valley cells to the stream groups that produced them
#'
#' Takes a completed delineation from [fl_valley_confine()] and works out which
#' part of it belongs to which watercourse (or reach, or any other grouping of
#' the stream network). The delineation itself is never recomputed, so grouping
#' changes relabel the output without moving a boundary.
#'
#' @param valleys A binary (`0`/`1`) `SpatRaster`, the output of
#'   [fl_valley_confine()].
#' @param streams An `sf` linestring object — the same network the delineation
#'   was built from.
#' @param group Character. Name of the column in `streams` to group by, e.g.
#'   `"gnis_name"` or `"blue_line_key"`. `NA` values form their own group.
#' @param dem A `SpatRaster` of elevation, used only to derive `slope`. Ignored
#'   when `slope` is supplied; one of the two is required.
#' @param slope A `SpatRaster` of percent slope. If `NULL`, derived from `dem`.
#' @param max_width Numeric. Maximum valley width in map units (metres).
#'   Default `2000`. Must match the value used for the delineation.
#' @param cost_threshold Numeric. Maximum accumulated cost distance.
#'   Default `2500`. Must match the value used for the delineation.
#' @param crop_margin Numeric. Width in map units (metres) added around each
#'   group's bounding box before its cost distance is computed. Default
#'   `max_width`. See Details.
#' @param complete Logical. If `TRUE` (default), valley cells that no group
#'   reaches within the thresholds are assigned to the group whose streams are
#'   nearest, so every valley cell is attributed. If `FALSE`, they are left
#'   unattributed. See Details.
#'
#' @return An `sf` polygon object with one row per group: a `valley` column and
#'   a column named after `group`. Rows overlap where ground is shared between
#'   watercourses. Groups that yield no cells are omitted, with a warning naming
#'   them. The number of valley cells that fell outside every group's thresholds
#'   is attached as the attribute `"fl_fallback_cells"` — these are assigned to
#'   the nearest group when `complete = TRUE` and left unattributed otherwise, so
#'   the count reports the same quantity in both modes.
#'
#' @details
#' A cell is attributed to group `g` when it is a valley cell **and** it
#' satisfies, for `g`'s streams alone, the two stream-dependent criteria the
#' VCA already applies to the whole network:
#'
#' ```
#' member(cell, g) <=> valley(cell)
#'                     AND distance(cell, streams_g) <= max_width / 2
#'                     AND cost(cell, streams_g)     <  cost_threshold
#' ```
#'
#' A cell can satisfy this for more than one group, and near a confluence it
#' usually does — ground there genuinely belongs to both floodplains, so the
#' output rows overlap rather than partitioning the valley.
#'
#' The flood mask is deliberately **not** recomputed per group. Re-running the
#' delineation on a subset of the network changes it: the flood surface is
#' interpolated from every seed cell (see [fl_flood_depth()]), the distance and
#' cost criteria loosen as seeds are added, and morphological cleanup couples
#' patches. Attributing a single delineation instead keeps "the floodplain of
#' this river" independent of whatever else was in the run.
#'
#' ## Coverage
#'
#' [fl_valley_confine()] adds cells after intersecting its masks — morphological
#' closing, hole filling, the channel buffer, and waterbody polygons, which get
#' no spatial filter at all. Those cells can fall outside every group's distance
#' and cost thresholds. With `complete = TRUE` they are assigned to the group
#' with the nearest streams so the attribution covers the delineation exactly;
#' the count is reported and available as `attr(x, "fl_fallback_cells")`. Use
#' `complete = FALSE` to see only cost-reachable ground.
#'
#' ## Corridor cropping
#'
#' Each group's cost distance is computed on a crop around that group's own
#' streams, expanded by `crop_margin`. This is an approximation, not a bound: a
#' least-cost path can in principle leave the crop and return, and across
#' near-flat ground a long detour costs very little. On the bundled test data the
#' default of `max_width` — twice the corridor half-width — reproduced the
#' uncropped cost surface exactly, while `max_width / 2` left 200 corridor cells
#' differing by up to 217 cost units. Those particular cells sat far enough from
#' the threshold that membership did not change, but a tighter crop does drop
#' ground silently (at `crop_margin = 500` on the same tile, 33,860 cells).
#' Widen it if group corridors are unusually convoluted.
#'
#' ## Performance
#'
#' Attributing the bundled tile by `gnis_name` (5 groups, 518,400 cells) takes
#' about 0.7 s against 1.4 s for the delineation itself. That saving comes from
#' the crop, so it shrinks as a group's bounding box approaches the full grid —
#' a long sinuous mainstem is the worst case, and a run with hundreds of groups
#' on a multi-million-cell raster has not been measured. Supplying `slope`
#' avoids re-deriving it from `dem`.
#'
#' @seealso [fl_valley_confine()], [fl_valley_poly()], [fl_cost_distance()],
#'   [fl_mask_distance()]
#'
#' @examples
#' dem <- terra::rast(system.file("testdata/dem.tif", package = "flooded"))
#' streams <- sf::st_read(
#'   system.file("testdata/streams.gpkg", package = "flooded"),
#'   quiet = TRUE
#' )
#' precip_r <- fl_stream_rasterize(streams, dem, field = "map_upstream")
#' valleys <- fl_valley_confine(dem, streams,
#'                              area_field = "upstream_area_ha", precip = precip_r)
#'
#' # Which part of the floodplain belongs to which watercourse?
#' by_stream <- fl_valley_attribute(valleys, streams, group = "gnis_name",
#'                                  dem = dem)
#' by_stream[, c("gnis_name")]
#'
#' # One named river's floodplain, on its own — it ends where the river does
#' terra::plot(dem, main = "Bulkley River floodplain")
#' plot(sf::st_geometry(by_stream[!is.na(by_stream$gnis_name) &
#'                                by_stream$gnis_name == "Bulkley River", ]),
#'      add = TRUE, col = "#0000ff40", border = "blue")
#'
#' @export
fl_valley_attribute <- function(valleys, streams, group,
                                dem = NULL, slope = NULL,
                                max_width = 2000, cost_threshold = 2500,
                                crop_margin = max_width,
                                complete = TRUE) {
  stopifnot(
    inherits(valleys, "SpatRaster"),
    inherits(streams, "sf"),
    is.character(group), length(group) == 1L,
    is.numeric(max_width), length(max_width) == 1L, max_width > 0,
    is.numeric(cost_threshold), length(cost_threshold) == 1L, cost_threshold > 0,
    is.numeric(crop_margin), length(crop_margin) == 1L, crop_margin > 0,
    is.logical(complete), length(complete) == 1L
  )

  if (identical(group, "geometry")) {
    stop("`group` cannot be \"geometry\": it would collide with the output's ",
         "geometry column.", call. = FALSE)
  }

  if (!group %in% names(streams)) {
    stop("`group` '", group, "' not found in `streams`. Available columns: ",
         paste(setdiff(names(streams), attr(streams, "sf_column")), collapse = ", "),
         call. = FALSE)
  }

  if (is.null(slope)) {
    if (is.null(dem)) {
      stop("Supply either `slope` or `dem` so friction can be derived.", call. = FALSE)
    }
    stopifnot(inherits(dem, "SpatRaster"))
    if (!terra::compareGeom(valleys, dem, stopOnError = FALSE)) {
      stop("`dem` must have the same extent, resolution, and CRS as `valleys`.",
           call. = FALSE)
    }
    slope_deg <- terra::terrain(dem, "slope", unit = "degrees")
    slope <- tan(slope_deg * pi / 180) * 100
  } else {
    stopifnot(inherits(slope, "SpatRaster"))
    if (!terra::compareGeom(valleys, slope, stopOnError = FALSE)) {
      stop("`slope` must have the same extent, resolution, and CRS as `valleys`.",
           call. = FALSE)
    }
  }

  if (sf::st_crs(streams) != terra::crs(valleys)) {
    streams <- sf::st_transform(streams, terra::crs(valleys))
  }

  keys <- streams[[group]]
  levels_grp <- unique(keys)
  levels_grp <- c(sort(levels_grp[!is.na(levels_grp)]), levels_grp[is.na(levels_grp)][1])
  levels_grp <- levels_grp[!(is.na(levels_grp) & !any(is.na(keys)))]

  valley_cells <- which(terra::values(valleys, mat = FALSE) == 1L)

  # --- Per-group membership on a corridor crop ---
  cells_by_group <- vector("list", length(levels_grp))
  reasons <- rep(NA_character_, length(levels_grp))
  for (i in seq_along(levels_grp)) {
    g <- levels_grp[i]
    rows <- if (is.na(g)) is.na(keys) else !is.na(keys) & keys == g
    res <- fl_group_cells(streams[rows, ], valleys, slope,
                          max_width, cost_threshold, crop_margin)
    cells_by_group[[i]] <- res$cells
    reasons[i] <- res$reason
  }

  covered <- unique(unlist(cells_by_group, use.names = FALSE))
  uncovered <- setdiff(valley_cells, covered)

  # --- Coverage fallback: nearest group by distance ---
  n_assigned <- 0L
  if (length(uncovered) > 0L) {
    usable <- isTRUE(complete) && nrow(streams) > 0L &&
      !all(sf::st_is_empty(sf::st_geometry(streams)))
    if (usable) {
      idx_streams <- streams
      idx_streams$fl_group_idx <- match(keys, levels_grp)
      idx_r <- fl_stream_rasterize(idx_streams, valleys, field = "fl_group_idx")
      # No burned cells means nothing to measure distance from.
      if (!all(is.na(terra::values(idx_r, mat = FALSE)))) {
        nearest <- terra::distance(idx_r, target = NA, values = TRUE)
        assigned <- terra::values(nearest, mat = FALSE)[uncovered]
        for (i in seq_along(levels_grp)) {
          add <- uncovered[!is.na(assigned) & assigned == i]
          if (length(add) > 0L) {
            cells_by_group[[i]] <- c(cells_by_group[[i]], add)
            n_assigned <- n_assigned + length(add)
          }
        }
      }
    }
    cli::cli_alert_info(paste(
      "{length(uncovered)} valley cell{?s} outside every group's thresholds -",
      "{n_assigned} assigned to the nearest group."
    ))
  }

  # A group that still has no cells gets no row, which breaks the one-row-per-group
  # contract silently — at k in the hundreds that reads as "this river has no
  # floodplain" rather than "this river was not processed". Warn only after the
  # fallback has run: a group that scored zero on the thresholds can still pick up
  # cells there, and naming it as omitted would be false.
  empty_grp <- lengths(cells_by_group) == 0L
  if (any(empty_grp)) {
    dropped <- vapply(which(empty_grp), function(i) {
      why <- if (is.na(reasons[i])) "no valley cells" else reasons[i]
      paste0(levels_grp[i], " (", why, ")")
    }, character(1))
    warning("No valley cells attributed to ", length(dropped), " group",
            if (length(dropped) > 1L) "s" else "", ", omitted from the output: ",
            paste(dropped, collapse = "; "), call. = FALSE)
  }

  # --- Polygonize each group ---
  parts <- list()
  for (i in seq_along(levels_grp)) {
    cells <- cells_by_group[[i]]
    if (length(cells) == 0L) next
    poly <- fl_cells_poly(cells, valleys)
    poly[[group]] <- levels_grp[i]
    parts[[length(parts) + 1L]] <- poly
  }

  if (length(parts) == 0L) {
    empty <- list(valley = integer(0))
    empty[[group]] <- keys[0]
    empty$geometry <- sf::st_sfc(crs = sf::st_crs(valleys))
    out <- fl_check_out(sf::st_sf(empty, sf_column_name = "geometry"), group)
    attr(out, "fl_fallback_cells") <- length(uncovered)
    return(out)
  }

  out <- fl_check_out(do.call(rbind, parts), group)
  attr(out, "fl_fallback_cells") <- length(uncovered)
  out
}

#' Assert the output kept its geometry and group columns
#'
#' Three rounds of review found the same family of defect: an `sf` mutated in
#' place losing track of which column is the geometry. Cheaper to assert than to
#' keep remembering the rule.
#'
#' @param out The `sf` about to be returned.
#' @param group Name of the group column.
#'
#' @return `out`, unchanged.
#' @noRd
fl_check_out <- function(out, group) {
  if (!identical(attr(out, "sf_column"), "geometry") || !group %in% names(out)) {
    stop("Internal error: attribution output lost its geometry or group column.",
         call. = FALSE)
  }
  out
}

#' Cell indices a single stream group reaches
#'
#' @param streams_g An `sf` subset for one group.
#' @param valleys The binary valley `SpatRaster`.
#' @param slope Percent-slope `SpatRaster` matching `valleys`.
#' @param max_width,cost_threshold VCA thresholds.
#' @param crop_margin Width added around the group's bounding box.
#'
#' @return List of `cells` (integer cell indices into `valleys`) and `reason`
#'   (`NA` when cells were found, otherwise why none were).
#' @noRd
fl_group_cells <- function(streams_g, valleys, slope, max_width, cost_threshold,
                           crop_margin) {
  none <- function(reason) list(cells = integer(0), reason = reason)
  if (nrow(streams_g) == 0L) return(none("no stream segments"))

  # Empty geometries are routine after st_intersection() clipping, and
  # terra::ext() errors on them rather than returning an empty extent — one bad
  # row would otherwise abort every other group.
  streams_g <- streams_g[!sf::st_is_empty(sf::st_geometry(streams_g)), ]
  if (nrow(streams_g) == 0L) return(none("all geometries empty"))

  e <- terra::ext(terra::vect(sf::st_geometry(streams_g)))
  e <- terra::extend(e, crop_margin)
  e <- terra::intersect(e, terra::ext(valleys))
  # terra::intersect() returns NULL, not an empty extent, when they miss.
  if (is.null(e)) return(none("streams outside the valley raster"))

  slope_c <- terra::crop(slope, e, snap = "out")
  valleys_c <- terra::crop(valleys, e, snap = "out")

  streams_g$fl_seed <- 1
  seeds <- fl_stream_rasterize(streams_g, slope_c, field = "fl_seed")
  # fl_stream_rasterize() uses touches = FALSE, so segments that never cross a
  # cell centre burn nothing.
  if (all(is.na(terra::values(seeds, mat = FALSE)))) {
    return(none("segments do not cross a cell centre"))
  }

  member <- valleys_c *
    fl_mask_distance(seeds, threshold = max_width / 2) *
    fl_mask(fl_cost_distance(slope_c, seeds), threshold = cost_threshold,
            operator = "<")

  local_cells <- which(terra::values(member, mat = FALSE) == 1L)
  if (length(local_cells) == 0L) return(none("no valley cells within the thresholds"))

  list(cells = terra::cellFromXY(valleys, terra::xyFromCell(member, local_cells)),
       reason = NA_character_)
}

#' Polygonize a set of cell indices
#'
#' Builds the raster on the cells' own bounding box rather than the full grid,
#' so per-group polygonization stays proportional to the group's footprint.
#'
#' @param cells Integer vector of cell indices into `template`.
#' @param template The full-grid `SpatRaster`.
#'
#' @return An `sf` polygon object with a `valley` column.
#' @noRd
fl_cells_poly <- function(cells, template) {
  xy <- terra::xyFromCell(template, cells)
  half <- terra::res(template) / 2
  e <- terra::ext(min(xy[, 1]) - half[1], max(xy[, 1]) + half[1],
                  min(xy[, 2]) - half[2], max(xy[, 2]) + half[2])
  tmpl <- terra::crop(template, e, snap = "out")

  r <- terra::rast(tmpl)
  terra::values(r) <- NA_integer_
  r[terra::cellFromXY(tmpl, xy)] <- 1L

  fl_valley_poly(r)
}
