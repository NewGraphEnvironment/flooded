# data-raw/quotes

Source and provenance for the startup quotes shown on `library(flooded)`.

## Files

- `quotes_build.R` — **source of truth**. R tibble with provenance columns.
- `quotes_audit.csv` — generated, full audit trail. In-repo, Rbuildignored.
- `../inst/extdata/quotes.csv` — generated, slim shipped (quote, author, source). Read by `R/zzz.R` on attach.

## To add / edit / remove a quote

1. Edit the `quotes` tibble in `quotes_build.R`
2. Every row must have a primary-source URL confirmed via fetch on the `verification_date`
3. Run `Rscript data-raw/quotes_build.R`
4. Commit all three files together

## Runtime toggle

```r
options(flooded.quote_show_source = FALSE)  # suppress source hyperlink
```

Default is `TRUE`. Clickable blue `source` hyperlink renders in RStudio console (OSC 8).

## Standards

- Primary source required; book quotes OK when canonical and cross-circulated
- No padding — drop rather than pad
- UTF-8 throughout
