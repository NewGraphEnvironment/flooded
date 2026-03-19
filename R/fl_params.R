#' Load VCA parameter legend
#'
#' Returns a tibble of Valley Confinement Algorithm parameters with units,
#' defaults, literature sources, and descriptions. The bundled CSV documents
#' every tuning parameter in [fl_valley_confine()] with DEM resolution
#' guidance from Nagel et al. (2014) and Hall et al. (2007).
#'
#' @param path Character. Path to a custom parameter CSV. When `NULL`
#'   (default), loads the bundled `inst/extdata/flood_params.csv`.
#'
#' @return A tibble with columns: `parameter`, `unit`, `default`, `source`,
#'   `citation_keys`, `effect`, `description`.
#'
#' @examples
#' params <- fl_params()
#' params[, c("parameter", "unit", "default")]
#'
#' @export
fl_params <- function(path = NULL) {
  if (is.null(path)) {
    path <- system.file("extdata", "flood_params.csv", package = "flooded",
                        mustWork = TRUE)
  }
  if (!file.exists(path)) {
    stop("File not found: ", path, call. = FALSE)
  }
  utils::read.csv(path, stringsAsFactors = FALSE) |>
    tibble::as_tibble()
}
