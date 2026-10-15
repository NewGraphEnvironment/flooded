#' Join per-segment attributes to valley cells by position
#'
#' Takes a delineation, its attribution by [fl_valley_attribute()], and a set of
#' stream segments carrying logical attributes (habitat flags, for example), and
#' gives every valley cell the attributes of the segment beside it. This answers
#' "which part of the floodplain sits beside segments with attribute X", which a
#' join on the group key does not.
#'
#' @param valleys A binary (`0`/`1`) `SpatRaster`, the output of
#'   [fl_valley_confine()].
#' @param attributed The `sf` output of [fl_valley_attribute()] for `valleys`,
#'   one row per group, in the CRS of `valleys`.
#' @param segments An `sf` linestring object carrying the `group` column and the
#'   logical attribute columns. Transformed to the CRS of `valleys` if needed;
#'   empty geometries are dropped.
#' @param group Character. Name of the group column shared by `attributed` and
#'   `segments`, e.g. `"blue_line_key"`. Keys are matched with [match()], so
#'   they must have the same type in both; an `NA` key matches the `NA` group.
#'   Segments whose key no row of `attributed` carries are ignored.
#' @param cols Character. Names of the logical columns in `segments` to join.
#'   If `NULL` (default), every logical column other than `group`. Flags stored
#'   as `0`/`1` integers need [as.logical()] first. The nearest-segment search
#'   does not depend on `cols`, so join several flags (several species, say) in
#'   one call rather than one call each.
#'
#' @return A list:
#'   \describe{
#'     \item{`nearest`}{A data frame with one row per attributed valley cell:
#'       `cell` (cell index into `valleys`), the owning group (a column named
#'       after `group`), `dist` (map units from the cell centre to the owning
#'       segment) and one column per element of `cols`. The rule for areas.}
#'     \item{`any`}{A data frame with one row per attributed valley cell: `cell`
#'       and one column per element of `cols`, `TRUE` where any claiming group's
#'       nearest segment is `TRUE`. The "connected to" view.}
#'     \item{`check`}{Named integer: `valley_cells`, `attributed_cells` (distinct
#'       cells inside `attributed`), `missing` (valley cells no group claims) and
#'       `extra` (claimed cells outside the valley). Both of the last two are
#'       zero for a `complete = TRUE` attribution of the same delineation. The
#'       check sees only the union of the claims: a simplified or reprojected
#'       copy of `attributed` can move cells between groups and still pass.}
#'     \item{`ties`}{Integer. Cells whose two nearest claiming groups are
#'       exactly equally near.}
#'     \item{`no_segments`}{Keys of claiming groups with no segment in
#'       `segments`.}
#'   }
#'   Rows of both tables are in cell order.
#'
#' @details
#' Each valley cell is claimed by one or more groups (the rows of `attributed`
#' it falls inside). For each claiming group, the cell takes the attributes of
#' that group's segment nearest its centre. Only claiming groups compete: the
#' nearest segment anywhere can sit on a line the delineation never used (a
#' stream below a network's order floor, say), and that line's attributes say
#' nothing about ground it did not shape.
#'
#' Where several groups claim a cell, there are two answers, and both are
#' returned:
#'
#' - **`nearest`** gives the cell one owner, the claiming group whose nearest
#'   segment is nearest. Every cell is counted once, so per-group or per-reach
#'   areas add up to the floodplain: use it for areas. Exactly equal distances go
#'   to the lowest key (numeric order for numbers, C-locale order for text, `NA`
#'   last), and the number of such cells is returned as `ties`.
#' - **`any`** is `TRUE` where any claiming group's nearest segment is `TRUE`:
#'   ground connected to an attribute through at least one watercourse. A cell
#'   can be counted under several groups' flags, so it does not partition.
#'
#' A `nearest` `TRUE` is always an `any` `TRUE`.
#'
#' Joining on the group key instead gives a group's whole floodplain any
#' attribute found anywhere on it. On the Bulkley watershed group's whole-network
#' floodplain (30 m, `ff04`, by `blue_line_key`) that read 16,705 ha as sockeye
#' spawning, against 572 ha by position (`nearest`).
#'
#' ## Missing values
#'
#' A segment's `NA` is copied as is under `nearest`, and combined by [any()]
#' under `any` (`NA` unless a claimer says `TRUE`). A claiming group with no
#' segments has nothing to measure from: it never owns a cell another claimer
#' has segments for, it is left out of `any`, and a cell only it claims gets
#' `NA` attributes, `dist = Inf` and that group as owner. Such groups are listed
#' in `no_segments`.
#'
#' Valley cells outside every row of `attributed` (possible with
#' `fl_valley_attribute(complete = FALSE)`) get no row, and claimed cells
#' outside the valley are dropped; either case warns and is counted in `check`.
#'
#' A cell is inside a row of `attributed` when its centre is, so the claims of
#' an unmodified [fl_valley_attribute()] output are exactly the cells it
#' attributed. Duplicate rows for one group count once.
#'
#' Distances are planar, measured from cell centres with
#' [sf::st_nearest_feature()] and [sf::st_distance()]; a lon/lat `valleys` is
#' refused.
#'
#' @seealso [fl_valley_attribute()]
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
#' attributed <- fl_valley_attribute(valleys, streams, group = "blue_line_key",
#'                                   dem = dem)
#'
#' # A per-segment flag: channels wider than 20 m
#' streams$wide <- !is.na(streams$channel_width) & streams$channel_width > 20
#' j <- fl_valley_join(valleys, attributed, streams, group = "blue_line_key",
#'                     cols = "wide")
#' j$check
#'
#' # Floodplain beside a wide channel (ha): one owner per cell, then any claimer
#' cell_ha <- prod(terra::res(valleys)) / 1e4
#' c(nearest = sum(j$nearest$wide) * cell_ha, any = sum(j$any$wide) * cell_ha)
#'
#' # Joining on the key instead credits each blue line's whole floodplain
#' wide_keys <- unique(streams$blue_line_key[streams$wide])
#' by_key <- terra::cells(valleys, terra::vect(
#'   attributed[attributed$blue_line_key %in% wide_keys, ]
#' ))
#' length(unique(by_key[, "cell"])) * cell_ha
#'
#' # Map it
#' r <- terra::rast(valleys)
#' r[j$nearest$cell] <- j$nearest$wide
#' terra::plot(r, main = "Floodplain beside a wide channel (nearest)")
#'
#' @export
fl_valley_join <- function(valleys, attributed, segments, group, cols = NULL) {
  stopifnot(
    inherits(valleys, "SpatRaster"),
    inherits(attributed, "sf"),
    inherits(segments, "sf"),
    is.character(group), length(group) == 1L,
    is.null(cols) || is.character(cols)
  )

  if (group %in% c("cell", "dist", "geometry")) {
    stop("`group` cannot be \"", group, "\": the name is taken by an output column.",
         call. = FALSE)
  }
  if (!group %in% names(attributed)) {
    stop("`group` '", group, "' not found in `attributed`.", call. = FALSE)
  }
  if (!group %in% names(segments)) {
    stop("`group` '", group, "' not found in `segments`.", call. = FALSE)
  }

  seg_df <- sf::st_drop_geometry(segments)
  if (is.null(cols)) {
    cols <- setdiff(names(seg_df)[vapply(seg_df, is.logical, logical(1))], group)
    if (length(cols) == 0L) {
      stop("No logical attribute columns in `segments`; supply `cols`.", call. = FALSE)
    }
  }
  absent <- setdiff(cols, names(seg_df))
  if (length(absent) > 0L) {
    stop("`cols` not found in `segments`: ", paste(absent, collapse = ", "), call. = FALSE)
  }
  not_lgl <- cols[!vapply(seg_df[cols], is.logical, logical(1))]
  if (length(not_lgl) > 0L) {
    stop("`cols` must be logical columns; not logical: ", paste(not_lgl, collapse = ", "),
         call. = FALSE)
  }
  clash <- intersect(cols, c("cell", "dist", group))
  if (length(clash) > 0L) {
    stop("`cols` cannot include ", paste(clash, collapse = ", "),
         ": the name is taken by an output column.", call. = FALSE)
  }

  if (terra::is.lonlat(valleys)) {
    stop("`valleys` must be in a projected CRS: distances are planar.", call. = FALSE)
  }
  crs_v <- sf::st_crs(terra::crs(valleys))
  if (sf::st_crs(attributed) != crs_v) {
    stop("`attributed` must be in the CRS of `valleys`.", call. = FALSE)
  }
  if (sf::st_crs(segments) != crs_v) {
    segments <- sf::st_transform(segments, crs_v)
  }
  segments <- segments[!sf::st_is_empty(sf::st_geometry(segments)), ]

  # --- Claims: (group, cell) pairs, and the integrity check ---
  keys <- attributed[[group]]
  lvls <- unique(keys)
  lvls <- c(sort(lvls[!is.na(lvls)], method = "radix"), lvls[is.na(lvls)][1])
  lvls <- lvls[!(is.na(lvls) & !anyNA(keys))]

  if (nrow(attributed) > 0L) {
    # small = FALSE: a polygon covering no cell centre claims nothing (terra then
    # returns a NaN cell), rather than the cell it overlaps.
    cb <- terra::cells(valleys, terra::vect(attributed), touches = FALSE, small = FALSE)
    cb <- cb[!is.na(cb[, "cell"]), , drop = FALSE]
    claim <- data.frame(cell = cb[, "cell"], rank = match(keys[cb[, "ID"]], lvls))
  } else {
    claim <- data.frame(cell = numeric(0), rank = integer(0))
  }
  claim <- claim[!duplicated(cbind(claim$cell, claim$rank)), ]

  valley_cells <- which(terra::values(valleys, mat = FALSE) == 1L)
  claimed <- unique(claim$cell)
  check <- c(valley_cells = length(valley_cells),
             attributed_cells = length(claimed),
             missing = length(setdiff(valley_cells, claimed)),
             extra = length(setdiff(claimed, valley_cells)))
  if (check[["missing"]] > 0L) {
    warning(check[["missing"]], " valley cells are claimed by no group and get no row.",
            call. = FALSE)
  }
  if (check[["extra"]] > 0L) {
    warning(check[["extra"]], " claimed cells lie outside the valley and are dropped.",
            call. = FALSE)
  }
  claim <- claim[claim$cell %in% valley_cells, ]

  # --- Per claiming group: its nearest segment to each cell ---
  seg_rank <- match(segments[[group]], lvls)
  if (nrow(segments) > 0L && length(lvls) > 0L && all(is.na(seg_rank))) {
    warning("No segment's `", group, "` matches a key in `attributed`; check that ",
            "the two columns have the same type.", call. = FALSE)
  }
  seg_by_rank <- split(seq_len(nrow(segments)), factor(seg_rank, levels = seq_along(lvls)))
  cells_by_rank <- split(claim$cell, factor(claim$rank, levels = seq_along(lvls)))

  parts <- vector("list", length(lvls))
  for (k in seq_along(lvls)) {
    cc <- cells_by_rank[[k]]
    if (length(cc) == 0L) next
    idx <- seg_by_rank[[k]]
    if (length(idx) == 0L) {
      parts[[k]] <- data.frame(cell = cc, rank = k, dist = Inf, seg = NA_integer_)
      next
    }
    pts <- sf::st_as_sf(as.data.frame(terra::xyFromCell(valleys, cc)),
                        coords = c("x", "y"), crs = crs_v)
    nn <- idx[sf::st_nearest_feature(pts, segments[idx, ])]
    parts[[k]] <- data.frame(
      cell = cc, rank = k,
      dist = as.numeric(sf::st_distance(pts, segments[nn, ], by_element = TRUE)),
      seg = nn
    )
  }
  claimers <- unique(claim$rank)
  no_seg <- claimers[lengths(seg_by_rank[claimers]) == 0L]
  no_segments <- lvls[sort(no_seg)]

  o <- do.call(rbind, c(parts[!vapply(parts, is.null, logical(1))],
                        list(data.frame(cell = numeric(0), rank = integer(0),
                                        dist = numeric(0), seg = integer(0)))))
  o <- o[order(o$cell, o$dist, o$rank), ]
  attr_vals <- lapply(stats::setNames(cols, cols), function(col) segments[[col]][o$seg])

  # --- nearest: the first claim per cell after ordering by distance, then key ---
  first <- !duplicated(o$cell)
  second <- c(FALSE, first[-length(first)]) & !first
  prev_dist <- c(NA, o$dist[-nrow(o)])
  ties <- sum(second & is.finite(o$dist) & o$dist == prev_dist)

  nearest <- data.frame(cell = o$cell[first])
  nearest[[group]] <- lvls[o$rank[first]]
  nearest$dist <- o$dist[first]
  for (col in cols) nearest[[col]] <- attr_vals[[col]][first]

  # --- any: OR over the claiming groups that have segments ---
  # `o` is in cell order, so cumsum(first) is each claim's row in `nearest`. A
  # cell with no claimer that has segments has nothing to combine: NA.
  row_of <- cumsum(first)[!is.na(o$seg)]
  n_seg <- tabulate(row_of, nbins = nrow(nearest))
  any_tab <- data.frame(cell = nearest$cell)
  for (col in cols) {
    x <- attr_vals[[col]][!is.na(o$seg)]
    n_true <- tabulate(row_of[x %in% TRUE], nbins = nrow(nearest))
    n_na <- tabulate(row_of[is.na(x)], nbins = nrow(nearest))
    v <- n_true > 0L
    v[n_true == 0L & (n_na > 0L | n_seg == 0L)] <- NA
    any_tab[[col]] <- v
  }

  if (ties > 0L) {
    cli::cli_alert_info(
      "{ties} cell{?s} tied between claiming groups - assigned to the lowest key."
    )
  }
  if (length(no_segments) > 0L) {
    cli::cli_alert_info(
      "{length(no_segments)} claiming group{?s} with no segments: {.val {no_segments}}."
    )
  }

  list(nearest = nearest, any = any_tab, check = check, ties = as.integer(ties),
       no_segments = no_segments)
}
