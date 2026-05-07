#!/usr/bin/env Rscript
#
# data-raw/regenerate_bib.R
#
# Regenerate vignettes/references.bib from the union of [@key] markers in
# vignettes/pars-floodplain.Rmd and the citation_keys columns in
# `flooded::fl_params()` and `flooded::fl_scenarios()`. Pulls source
# records from Zotero via Better BibTeX (rbbt -> BBT).
#
# Run after adding/removing [@key] markers in the vignette or after
# changing flood_params.csv / flood_scenarios.csv:
#   Rscript data-raw/regenerate_bib.R
#
# Prerequisites:
#   - Zotero desktop running with BBT plugin enabled
#   - All keys must resolve to items in the Zotero library
#
# CI does not run this script — vignettes/references.bib is committed
# and pkgdown reads the static file. Re-run + commit whenever cites
# change.

stopifnot(requireNamespace("rbbt", quietly = TRUE))
stopifnot(requireNamespace("flooded", quietly = TRUE))

vignette_path <- here::here("vignettes", "pars-floodplain.Rmd")
out_path <- here::here("vignettes", "references.bib")

# Keys cited inline in the vignette
keys_vignette <- rbbt::bbt_detect_citations(
  paste(readLines(vignette_path), collapse = "\n")
)
message("  vignette: ", length(keys_vignette), " keys")

# Keys referenced from the package's parameter / scenario tables
keys_tables <- unique(unlist(strsplit(
  c(flooded::fl_params()$citation_keys,
    flooded::fl_scenarios()$citation_keys),
  ";"
)))
keys_tables <- keys_tables[!is.na(keys_tables) & nzchar(keys_tables)]
message("  fl_params + fl_scenarios: ", length(keys_tables), " keys")

all_keys <- sort(unique(c(keys_vignette, keys_tables)))
message("\nUnion: ", length(all_keys), " unique keys")

bib_text <- rbbt::bbt_bib(all_keys, .action = rbbt::bbt_return)
writeLines(bib_text, out_path)

n_entries <- length(grep("^@", readLines(out_path)))
message("Wrote ", n_entries, " entries to ", out_path)
