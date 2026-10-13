# enumerate_pin.R -- #67 code-check terminal enumeration (revised after round 3).
# For EVERY EPSG projected CRS X whose name marks a NAD83 realization (projinfo list, PROJ 9.8.1),
# run fl_dem_aoi() with the default pin and with pipeline = "" (PROJ's choice) on a small two-layer
# source raster holding its own x and y (so an east-west OR north-south misplacement shows), at
# X's area-of-use centre. Four cases, so both code paths that carry the pipeline are exercised:
#   A  3979 -> X,    AOI in X      (template bbox needs no transform; terra carries the pipeline)
#   A2 3979 -> X,    AOI in 3979   (AOI CRS == source CRS: sf::st_transform carries it too)
#   B  X -> 3005,    AOI in 3005
#   B2 X -> 3005,    AOI in X      (sf path again)
# A case PASSES only if it ran, PROJ's run has data, the pinned run covers >= 90% of PROJ's
# non-NA cells, the two extents agree to within 2 cells, and on their common cells both layers
# agree to < 10 source units median (a datum step is ~1-2 m; axis or unit faults are km).
# For an unpinned pair (pin == "") the two runs are the same call and the case is "left to PROJ".
# A pinned case that errored or has no PROJ data counts as NOT passing.
# Usage: Rscript planning/archive/2026-10-issue-67-fl-dem-aoi-grid/enumerate_pin.R <out_dir>
suppressMessages(pkgload::load_all(".", quiet = TRUE))
out_dir <- commandArgs(TRUE)[1]
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
lst <- system("projinfo --list-crs projected --authority EPSG", intern = TRUE)
lst <- lst[grepl("NAD83|1983", lst)]
codes <- as.integer(sub("^EPSG:([0-9]+) .*", "\\1", lst))
cat(length(codes), "candidate CRSs\n")

centre_of_use <- function(crs) {
  w <- crs$wkt
  bb <- regmatches(w, regexpr("BBOX\\[[^]]+\\]", w))
  if (!length(bb)) return(NULL)
  v <- as.numeric(strsplit(gsub("BBOX\\[|\\]", "", bb), ",")[[1]])  # S, W, N, E
  if (v[4] < v[2]) v[4] <- v[4] + 360
  c(lon = ((v[2] + v[4]) / 2 + 180) %% 360 - 180, lat = (v[1] + v[3]) / 2)
}
is_feet <- function(crs) grepl("f(oo|ee)t|ft", crs$units_gdal %||% "", ignore.case = TRUE)
unit_res <- function(crs) if (is_feet(crs)) 100 else 30
xy_field <- function(crs, pt) {
  half <- if (is_feet(crs)) 10000 else 3000
  p <- sf::st_coordinates(sf::st_transform(pt, crs))
  r <- terra::rast(terra::ext(p[1] - half, p[1] + half, p[2] - half, p[2] + half),
                   ncols = 60, nrows = 60, crs = crs$wkt)
  r <- c(terra::init(r, "x"), terra::init(r, "y"))
  names(r) <- c("x", "y")
  f <- tempfile(fileext = ".tif")
  terra::writeRaster(r, f, datatype = "FLT8S")
  f
}
one <- function(aoi, src, target) {
  tryCatch({
    rs <- unit_res(target)
    pin <- fl_dem_aoi(aoi, source = src, buffer = 200, target_crs = target, res = rs)
    prj <- fl_dem_aoi(aoi, source = src, buffer = 200, target_crs = target, res = rs, pipeline = "")
    e1 <- as.vector(terra::ext(pin)); e2 <- as.vector(terra::ext(prj))
    ext_ok <- all(abs(e1 - e2) <= 2 * rs)
    ce <- terra::intersect(terra::ext(pin), terra::ext(prj))
    a <- terra::crop(pin, ce, snap = "near"); b <- terra::crop(prj, ce, snap = "near")
    med <- NA_real_
    if (isTRUE(terra::compareGeom(a, b, stopOnError = FALSE))) {
      va <- terra::values(a); vb <- terra::values(b)
      ok <- stats::complete.cases(va) & stats::complete.cases(vb)
      if (any(ok)) med <- max(apply(abs(va[ok, , drop = FALSE] - vb[ok, , drop = FALSE]), 2, stats::median))
    }
    list(ran = TRUE, n_pin = sum(!is.na(terra::values(pin)[, 1])),
         n_prj = sum(!is.na(terra::values(prj)[, 1])), ext_ok = ext_ok, med = med, err = NA_character_)
  }, error = function(e) list(ran = FALSE, n_pin = NA, n_prj = NA, ext_ok = NA, med = NA,
                              err = conditionMessage(e)))
}
passes <- function(o) isTRUE(o$ran) && isTRUE(o$n_prj > 0) && isTRUE(o$n_pin >= 0.9 * o$n_prj) &&
  isTRUE(o$ext_ok) && isTRUE(o$med < 10)

rows <- list()
for (k in seq_along(codes)) {
  code <- codes[k]
  X <- tryCatch(sf::st_crs(code), error = function(e) NULL)
  c0 <- if (is.null(X)) NULL else centre_of_use(X)
  if (is.null(c0)) {
    rows[[k]] <- data.frame(code = code, case = NA, pinned = NA, pass = NA, ran = FALSE,
                            n_pin = NA, n_prj = NA, med = NA, err = "no CRS or area of use")
    next
  }
  pt <- sf::st_sfc(sf::st_point(c0), crs = 4326)
  s3979 <- sf::st_crs(3979); s3005 <- sf::st_crs(3005)
  cases <- list(
    A  = list(pin = dem_pipeline_nad83(s3979, X), aoi = X, src = s3979, tgt = X),
    A2 = list(pin = dem_pipeline_nad83(s3979, X), aoi = s3979, src = s3979, tgt = X),
    B  = list(pin = dem_pipeline_nad83(X, s3005), aoi = s3005, src = X, tgt = s3005),
    B2 = list(pin = dem_pipeline_nad83(X, s3005), aoi = X, src = X, tgt = s3005)
  )
  src_f <- list()
  out <- lapply(names(cases), function(cn) {
    cs <- cases[[cn]]
    pinned <- nzchar(cs$pin)
    if (!pinned) return(data.frame(code = code, case = cn, pinned = FALSE, pass = NA, ran = NA,
                                   n_pin = NA, n_prj = NA, med = NA, err = NA_character_))
    key <- cs$src$wkt
    f <- tryCatch(xy_field(cs$src, pt), error = function(e) NULL)
    if (is.null(f)) return(data.frame(code = code, case = cn, pinned = TRUE, pass = FALSE, ran = FALSE,
                                      n_pin = NA, n_prj = NA, med = NA, err = "source field failed"))
    aoi <- sf::st_buffer(sf::st_transform(pt, cs$aoi), if (is_feet(cs$aoi)) 3 else 1)
    o <- one(aoi, f, cs$tgt)
    data.frame(code = code, case = cn, pinned = TRUE, pass = passes(o), ran = o$ran,
               n_pin = o$n_pin, n_prj = o$n_prj, med = o$med, err = o$err)
  })
  rows[[k]] <- do.call(rbind, out)
  if (k %% 100 == 0) cat(k, "done\n")
}
d <- do.call(rbind, rows)
utils::write.csv(d, file.path(out_dir, "enumerate_pin.csv"), row.names = FALSE)
p <- d[d$pinned %in% TRUE, ]
cat(sprintf("CRSs %d | case rows %d | pinned %d | pinned PASS %d | pinned NOT passing %d (errored %d) | left to PROJ %d | no area of use %d\n",
            length(codes), nrow(d), nrow(p), sum(p$pass), sum(!p$pass), sum(!p$ran),
            sum(d$pinned %in% FALSE), sum(is.na(d$case))))
cat("pinned per case:\n"); print(table(p$case, p$pass, dnn = c("case", "pass")))
cat("max median |pin - PROJ| among passing:", max(p$med[p$pass], na.rm = TRUE), "\n")
print(utils::head(p[!p$pass, ], 30))
