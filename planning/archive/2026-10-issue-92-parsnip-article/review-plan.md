# Plan review (#92) — Plan agent, delivered in reply, written here by the session

Spawned 2026-10-19T17:24Z, returned after the data build had run (it saw the pre-run meta).

## Blocker
- B1 Definition over-claims: the code ANDs four masks, then closing/hole fill add cells that pass no test, patch removal and the 3x3 majority filter drop cells that pass all four, then channel buffer and waterbodies are ORed in (R/fl_valley_confine.R). "A cell is floodplain when it passes four tests" is false; limit "only where it passes the four tests" likewise.
- B2 "channels at their width are added" false at cell level: 50,335 of 79,451 stream cells (63.4%) inside the boundary are floodplain (buffer rasterized by cell centre; stream cells still face the slope test).
- B3 No "How good is it?" section: Hall regression R² = 0.47, n = 1,951 (Columbia basin); depth from width with Knighton coefficients from one Idaho basin; not checked against mapped floodplain on the Parsnip.
- B4 Flood-level labels attributed to Nagel; "functional floodplain" is flooded's reading ("No paper maps specific ff values to ecological processes"). Nagel's 7 for 30 m is for valley extent. "Maps less than their method would" over-broad. ff_hi taken from the script's list rather than the literature.

## Gap
- G1 Model ran on the float DEM; pars_dem.tif is written as INT2S, so the download does not reproduce pars_valleys.tif exactly.
- G2 ETag untested; DEM URL duplicated from R/fl_dem_aoi.R — pass it as `source`.
- G3 fresh commit is the installed RemoteSha, not the run's `fresh_sha`.
- G4 link tag check proves "at or before", not "last".
- G5 Nothing fails if flooded's code changes after the build.
- G6 Areas at 2/6/7 untestable; store integer cell counts.
- G7 Digest and read are two statements (snapshot); extra_float_digits; context SQL embeds 241,400-char WKT; carried layers have no digest.
- G8 Guards that cannot fail: channel_buffer; vca_args vs the CSV it came from (compare formals()); typed flood_factor = 4 in the shown chunk; add link_dirty.
- G9 Lakes and wetlands are 20.4% of the floodplain (91,911 of 451,557 cells).
- G10 "no single reason" wrong; water level is above the stream and spread out; Hall gives width, depth via coefficients.
- G11 citation() prints the installed version, no DOI; concept DOI resolves to the latest release.
- G12 fwapg commit f9718cb is on NewGraphEnvironment/fwapg (a newgraph merge), not smnorris main.
- G13 "north-eastern British Columbia" wrong.

## Ordering / Assumption / Scope
- O1-O3 run after script fixes; readme figure only if valleys change.
- A1 DB digest test reddens at the next provincial run (intended), skips on CI. A2 merge commits keep the recorded flooded commit. A3 DataCite 35 records. A4 monotone areas true by construction. A5 NA-area segments immaterial (17 cells, all floodplain). A6 `%||%` needs R >= 4.4.
- Old 83-122 s timing in R/fl_valley_confine.R, man, valley-confinement.Rmd; research/bundled_stream_data.md:30; NEWS.

## Disposition (session)
- B1, B2, B4, G10, G13: prose rewritten (channel clause cut; definition says "starts from cells that pass four tests", tidy-up includes the majority filter and its consequence; labels are flooded's presets, Nagel's 7 is for valley extent on 30 m DEMs; comparison "than flood factor 7 with the same settings").
- B3: "How good is it?" section added.
- G1: download line says the DEM is rounded to whole metres and the model ran on the unrounded values.
- G2, G3, G4, G6, G7, G12: data script fixed, committed, re-run.
- G5: accepted: the article cites the commit it was built at; a test failing on every R/ edit would block unrelated work. Recorded here.
- G8, G9, G11: guards and prose updated; G9 computed inline.
- Timing ripple: out of scope (dated record already tied to pre-#87 inputs in #87); research file line updated.
