# Terminal enumeration for #92: every meta / software / args field the article reads, set to NA and
# removed in turn; the article's setup and load chunks must stop on each. One copy, meta restored after each.
S <- commandArgs(TRUE)[1]
d <- file.path(S, "mut", "enum", "flooded")
rmd <- file.path(d, "vignettes", "pars-floodplain.Rmd")
pkgload::load_all(d, quiet = TRUE)
# the fields this article reads, extracted from its source, not listed by hand
src <- paste(readLines(rmd), collapse = "\n")
used <- unique(c(
  regmatches(src, gregexpr('meta\\$[a-zA-Z_]+(\\$[a-zA-Z_]+)?', src))[[1]],
  regmatches(src, gregexpr('sw_row\\("[a-z]+"\\)\\$[a-z_]+', src))[[1]],
  regmatches(src, gregexpr('args\\$[a-z_]+', src))[[1]]))
# commit_link() reads commit and repo for every package
used <- c(used, sprintf('sw_row("%s")$%s', rep(c("flooded", "link", "fresh", "fwapg"), each = 2), c("commit", "repo")))
used <- setdiff(unique(used), c("meta$software", "meta$vca_args"))
code <- knitr::purl(rmd, output = tempfile(fileext = ".R"), quiet = TRUE, documentation = 0)
lines <- readLines(code)
upto <- grep("^stopifnot\\(", lines)[1]
upto <- upto + which(lines[upto:length(lines)] == ")")[1] - 1L
chunk <- paste(lines[1:upto], collapse = "\n")
mp <- file.path(d, "inst/vignette-data/pars_meta.rds")
orig <- readRDS(mp)
run <- function() tryCatch({ eval(parse(text = chunk), envir = new.env()); "PASSED" },
                           error = function(e) paste("stopped:", substr(conditionMessage(e), 1, 70)))
setf <- function(m, field, how) {
  if (grepl("^sw_row", field)) {
    pkg <- sub('sw_row\\("([a-z]+)"\\).*', "\\1", field); col <- sub(".*\\$", "", field)
    i <- m$software$package == pkg
    if (how == "NA") m$software[[col]][i] <- NA else m$software <- m$software[!i | TRUE, setdiff(names(m$software), col)]
  } else if (grepl("^args", field)) {
    col <- sub("args\\$", "", field)
    if (how == "NA") m$vca_args[[col]] <- NA else m$vca_args[[col]] <- NULL
  } else {
    path <- strsplit(sub("^meta\\$", "", field), "$", fixed = TRUE)[[1]]
    if (length(path) == 1) { if (how == "NA") m[[path]] <- NA else m[[path]] <- NULL }
    else { if (how == "NA") m[[path[1]]][[path[2]]] <- NA else m[[path[1]]][[path[2]]] <- NULL }
  }
  m
}
cat("control:", run(), "\n")
res <- do.call(rbind, lapply(sort(used), function(f) {
  out <- vapply(c("NA", "absent"), function(h) { saveRDS(setf(orig, f, h), mp); r <- run(); saveRDS(orig, mp); r }, "")
  data.frame(field = f, na = out[["NA"]], absent = out[["absent"]])
}))
print(res[, c("field", "na", "absent")], right = FALSE)
cat("\nfields:", nrow(res), " passed (guard missing):", sum(res$na == "PASSED" | res$absent == "PASSED"), "\n")
