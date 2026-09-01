# Task: fl_valley_confine(): default field= is wrong for the flood model and silently halves the floodplain (#47)

`fl_valley_confine(field = "channel_width")` defaults to a column that is wrong for the
flood model. `field` names the column rasterized into `stream_r`, which
`fl_flood_model()` -> `fl_flood_surface()` consumes as the **drainage-area term** of the
Hall bankfull regression (`R/fl_flood_surface.R:87-89`). Channel width (4-31 m on the
bundled tile) and upstream area (1,929-110,337 ha) are both plain positive numerics, so
the wrong one is raised to the 0.280 power without complaint and returns a smaller
floodplain with no error and no warning.

Nothing has been produced incorrectly - every caller in the repo and the `floodplains`
driver passes `field = "upstream_area_ha"` explicitly - but the default is live for the
first person who omits it, and 18 of the 20 calls in
`tests/testthat/test-fl_valley_confine.R` already exercise it.

Outcome: the argument is renamed `area_field`, has no default, and states hectares plus
the regression that consumes it. `field` survives one release as a deprecated alias that
warns and forwards, so the `floodplains` driver and any external script keep working
while they are updated. Same class as #41 and #49 - a plausible number entering a formula
that expects a different quantity.

## Approach

`fl_valley_confine()` gains a required third argument `area_field`; `field` moves to the
end of the signature, defaults to `NULL`, and when supplied warns and forwards. The
requirement is enforced **only on the `sf` branch** - a pre-rasterized `SpatRaster`
`streams` never reaches `fl_stream_rasterize()`, so requiring `area_field` there would
break two valid calls (`test-fl_valley_confine.R:35, :94`) for no benefit.

`fl_stream_rasterize()` keeps its `field` argument and its `"channel_width"` default -
it is deliberately generic (it rasterizes precip, stream order, and internal seed indices
too). The hazard is the *composition*, which is addressed with `@seealso` in both
directions rather than by changing that function.

No magnitude guard (issue option 2): a headwater basin of ~10 ha overlaps the
channel-width range, so the guard cannot separate its two inputs and would fail exactly
on the small streams where NA handling is already awkward.

## Phase 1: Tests first

- [ ] `area_field` omitted with `sf` streams errors, and the message names the column and
      its units (hectares)
- [ ] `area_field` omitted with a pre-rasterized `SpatRaster` still runs - the requirement
      is scoped to the `sf` branch
- [ ] `field = "upstream_area_ha"` warns (message names `area_field`) and returns a raster
      identical to `area_field = "upstream_area_ha"`
- [ ] Both supplied: warns, `area_field` wins
- [ ] Positional third argument still lands on `area_field`
- [ ] Guard that the two columns are not interchangeable - `"channel_width"` and
      `"upstream_area_ha"` give materially different cell counts on the bundled tile
      (channel width strictly fewer), which is the property that makes any default
      indefensible

## Phase 2: Implementation

- [ ] `R/fl_valley_confine.R` - signature becomes
      `fl_valley_confine(dem, streams, area_field, slope = NULL, ..., field = NULL)`;
      shim warns and forwards; missing-argument check on the `inherits(streams, "sf")`
      branch only; pass-through at the `fl_stream_rasterize()` call
- [ ] Roxygen: `@param area_field` states **upstream contributing area in hectares** and
      names `fl_flood_surface()` as the consumer; `@param field` marked deprecated;
      `@seealso` gains `fl_stream_rasterize()`; drop the "tracked in flooded#47" sentence
- [ ] `R/fl_stream_rasterize.R` - roxygen note that its output is *not* interchangeable
      when destined for the flood model, with `@seealso [fl_valley_confine()]` and
      `[fl_flood_surface()]`. Signature and default unchanged.

## Phase 3: Update in-repo callers

Rename **only** `fl_valley_confine(field =)` - `fl_stream_rasterize(field =)` calls stay
as they are, so no blind sed.

- [ ] `tests/testthat/test-fl_valley_confine.R` - 20 calls; note `:91` rasterizes on
      `"channel_width"` and `:91-101` asserts the raster path equals the `sf` path, so
      both sides move to `"upstream_area_ha"` in lockstep
- [ ] `tests/testthat/test-fl_valley_attribute.R:10, :186`
- [ ] Roxygen examples: `R/fl_valley_confine.R:89-106`, `R/fl_valley_attribute.R:101`
- [ ] `README.md:24`
- [ ] Vignettes: `valley-confinement.Rmd` (4), `stac-dem.Rmd.orig` **and** the baked
      `stac-dem.Rmd` (4 each), `pars-floodplain.Rmd:232`
- [ ] `data-raw/wsg_vignette_data.R:258`
- [ ] `CLAUDE.md:273` - the two-argument pipeline snippet, which this change makes an error

## Phase 4: Docs, notes, release bookkeeping

- [ ] `devtools::document()` - regenerate `man/fl_valley_confine.Rd`,
      `man/fl_valley_attribute.Rd`, `man/fl_stream_rasterize.Rd`; read the output for
      unexpected `Writing`/`Deleting` lines and check `NAMESPACE` is unchanged
- [ ] `NEWS.md` - new `# flooded 0.6.0` section: the rename, why the default was wrong,
      the deprecation window, and that no shipped result changes (nothing ever ran on the
      default)
- [ ] `inst/notes/floodplain_interpretation.md` - name `area_field` in the
      "Which regression does what" section so the argument and the regression input are
      linked in prose
- [ ] `DESCRIPTION` -> `0.6.0` as the **final** commit of the branch

## Phase 5: Downstream doc fix (separate repo)

- [ ] `soul/conventions/cartography.md:120` - `flooded::fl_valley_confine(dem, streams)`
      propagates into every repo's CLAUDE.md; update it to pass
      `area_field = "upstream_area_ha"`. Done through a **temp git worktree**
      (`git worktree add`) so a parallel session's checkout is never disturbed, on its own
      branch + PR.
- [ ] PR body notes `floodplains/scripts/floodplain_lcc/02_floodplain_model.R:148` as a
      follow-up - it keeps working on the deprecation warning, but should move to
      `area_field` before the shim is removed.

## Validation

- [ ] `Rscript -e 'devtools::test()' 2>&1 | grep -E "(FAIL|ERROR|PASS)" | tail -5`
- [ ] `Rscript -e 'lintr::lint_package()'` - no new lints vs `HEAD` baseline
- [ ] `Rscript -e 'devtools::check()'` - examples execute, vignettes build
- [ ] Measurement re-run on the bundled tile at package defaults: record cell counts and
      hectares for `area_field = "upstream_area_ha"` vs `"channel_width"`, and confirm the
      `field =` shim reproduces the `area_field` result exactly (`terra::values()` identical,
      not just equal counts)
- [ ] Restore-the-bug check on the new required-argument test: re-add a
      `area_field = "channel_width"` default and confirm the test goes red - patching both
      `asNamespace("flooded")` and `as.environment("package:flooded")`, and printing a
      value that proves the patched version ran
- [ ] `/code-check` clean on each commit; PWF checkboxes match landed work;
      `/planning-archive` on completion
