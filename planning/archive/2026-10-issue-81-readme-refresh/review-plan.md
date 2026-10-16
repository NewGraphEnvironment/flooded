# Plan review (Plan agent, 2026-10-15) — summary as received, and disposition

Blockers
- B1 Opening must not claim flooded detects cut-off floodplain / barriers; no "where to act" advice; not "functional floodplain" for default output (default flood_factor = 6, valley bottom); no "works anywhere" (MRDEM-30 is Canada only). -> opening phrased as "where to look", from stac-dem.Rmd:540-546; example text names the default level; "portable"/"any DEM" dropped.
- B2 NOTICE.md puts bcfishpass stream attributes under OGL-BC; bcfishpass data is ODbL + DbCL; map_upstream is ClimateBC precipitation (terms unchecked). -> verify, split the row.

Gaps
- G1 NOTICE.md at root gives an R CMD check NOTE; LICENSE.note is buildignored, so MIT/Apache notices drop from the tarball. -> verify with R CMD check.
- G2 README License omits NOTICE -> already included.
- G3 citation("flooded") lists only aut -> Citation points at CITATION.cff.
- G4 LICENSE says Copyright Allan Irvine; adding NGE Ltd. as cph would disagree -> operator's call; NGE Ltd. added as fnd only, LICENSE left alone, raised in the report.
- G5 Installation lacks "what a run needs" -> add.
- G6 stale timings also in valley-confinement.Rmd:497-509 and pars-floodplain.Rmd:226-229 -> Phase 4.
- G7 Ecosystem wording: keep flooded's role as in fresh's README -> kept.
- G8 "Portable" uncheckable -> dropped.
- G9 add devtools::check().
- G10 Data and methods: Nagel 2014, ClimateBC precip, LidarBC.
- G11 Figure legend "functional" and lakes/wetlands unioned; caption must say floodplain was never modelled along order 1-2 / inaccessible streams.

Ordering
- O1 gh repo edit --description is public at once -> do it at merge, noted in the PR.
- O2 file the soul authors_roles issue before the PR.
- O3 link check with curl -sIL (github.io 301s).

Assumptions
- A1 cffr roles c("aut","cre","fnd") gives exactly Irvine + NGE Ltd.; keep the existing "New Graph Environment" cph entry verbatim (bcfishpass notice).
- A2 This machine has 10 cores: time threads 1 vs 8, wall time, fresh Rscript per repeat, raw cached grid; Int16 cached DEM won't reproduce pars_valleys.tif cell for cell.
- A3 keep version claims out of the caption. A4 load_all prints a startup quote; keep out of pasted output.

Scope: fl_dem_aoi() may cover #15 (fl_dem_fetch, future) -> report. pars-floodplain.Rmd links the raw gpkg (roads, #85) -> no README link to it.
pkgdown: list the 11 pipeline functions explicitly; consider fl_stream_rasterize under Delineate.
Acceptance: forecast word count; checks for tells, identical Title/tagline/About, no alpha, CITATION authors, R CMD check.
