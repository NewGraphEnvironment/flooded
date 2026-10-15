# Code-check round 2: branch 81-readme-add-dem-fetch-flood-factor-scenarios

Reviewed `git diff c61cff4...1b435f3` (HEAD), with the round 1 fixes in `1b435f3` read first.
All runs were in a scratchpad copy of the repo (`cp -R`, `pkgload::load_all()`); nothing in the
repo was edited except this file.

## Mechanism (round 1)

Round 1's eight findings share one cause: a published sentence was restated from a prose
ancestor, or from the most familiar member of a set, instead of being read off the code or the
data that defines it.

- From prose: "without climbing" came from `floodplain_interpretation.md`, "attributes" from
  the issue and plan, and "6 km" from a script comment.
- From one member of a set: one lidar site stood for every coarse DEM, one machine-load state
  for the function's runtime, and "barriers" for natural barriers only. "Flooded's own output"
  and the data list described the parts the authors thought of first.

Round 2 finds the same mechanism inside the fixes. **Round 1's review text became the new
ancestor**:

- F7's prose ("the flood surface is driven by `upstream_area_ha`, `map_upstream` and
  `channel_width`") went into NOTICE word for word, and it is false for channel width (R2-2).
- F2's suggested replacement, "without crossing much steep ground", was adopted without
  checking it against `costDist` (R2-1).
- F6's "wall time rose with load" story was adopted without checking it against the r3 pair (R2-5).

Places the mechanism reaches that the round 1 sweep missed:

- In the diff:
  - `_pkgdown.yml:16` (R2-3)
  - `README.md:78-79` (R2-4)
  - `CLAUDE.md:58-59` (R2-5)
  - `inst/NOTICE.md:13` (R2-6)
- Ancestors outside the diff that will regenerate the defects:
  - `inst/notes/floodplain_interpretation.md:26` ("Is it reachable without climbing?"). The
    README links this file as the authority on "what can be claimed".
  - `R/fl_valley_join.R:1`, title "Join per-segment attributes" (its body says logical).
  - `data-raw/testdata.R:8` ("~6km section").

## Mechanical checks re-run

- README example under `load_all()` at HEAD: rows 264 / 112 / 130 / 50 / 99, and a whole
  floodplain of 287.27 ha. The pasted output matches exactly.
- Parsnip inputs: grid 3,749 x 3,761 at 30 m, 8,436 stream segments, 664 waterbodies (200 L, 464 W).
  `stac_valleys_1m_site.tif` and `stac_valleys_5m.tif` are both on a 10 m grid, as NOTICE says.
- The bench call (`bench_threads.R`) matches the `pars-floodplain.Rmd` `vca` chunk argument for argument.
- terra NEWS: `threads` "now defaults to 16 (instead of no limit)". OK.
- README figure (976 x 980): the legend renders and every prominent feature is in it. The alt
  text matches the image.

## Claims enumerated (64)

README (1-41)
1. The tagline matches the DESCRIPTION Title and the CITATION title. OK
2. "maps floodplains and unconfined valley bottoms ... Valley Confinement Algorithm". OK
3. "gentle": slope <= 9%. OK
4. "near a stream": `max_width/2` = 1,000 m. OK
5. "reachable from it without crossing much steep ground". **INACCURATE** (R2-1)
6. "low relative to it": flood mask. OK
7. "classifies terrain, does not simulate floods". OK
8. "screening map, not a field-validated floodplain". OK
9. "In the STAC vignette, floodplain that 25 m maps and 1 m lidar excludes marks where to look
   for roads, rail grades, dykes or fill". OK. It is scoped to the vignette and matches
   `stac-dem.Rmd:543-546`.
10. "and so where reconnection could be planned". OK (hedged)
11. "fetches an elevation model for an area": `fl_dem_aoi()`. OK
12. "three preset flood levels from active channel to valley bottom": `flood_scenarios.csv`
    ff02 / ff04 / ff06. OK
13. "attributes one floodplain to each watercourse that shares it". OK
14. "carrying per-reach flags such as fish habitat": `fl_valley_join()` takes logical columns only. OK
15. Alt text. OK, checked against the PNG.
16. Caption "flood factor 4". OK
17. Caption "30 m from MRDEM-30". OK
18. Caption "lakes and wetlands included". OK
19. Caption "streams of order 3 and up that bull trout can reach": `streams_bt_vw`, access 1/2,
    order >= 3, and the order table is 3 to 7. OK
20. Caption "those above natural barriers to bull trout". OK
21. Install and pin lines. OK
22. "under active development". OK
23. "projected CRS with metre units". OK
24. "stream lines that carry upstream area in hectares". OK
25. "precipitation optional": `precip = NULL`. OK
26. "MRDEM-30 covers Canada ... no credentials". OK
27. "A 5 km reach": 5,307 m. OK
28. "default flood level (flood factor 6, valley bottom)": formal `flood_factor = 6`. OK
29. Example code and output: an exact match on re-run. OK
30. "the whole floodplain here is 287 ha": 287.27. OK
31. Learn more, valley-confinement. OK
32. Learn more, stac-dem, "the same reach from the 25 m provincial model and from lidar". OK
33. Learn more, stac-dem, "the steep-sided grades and fill that 1 m lidar resolves". **OVERREACH** (R2-4)
34. Learn more, pars-floodplain. OK
35. Function reference. OK
36. Ecosystem table (9 rows) and the pipeline line: unchanged since round 1. OK
37. Data and methods, VCA / BlueGeo / bcfishpass licences. OK
38. Hall et al. (2007) and Nagel et al. (2014). OK
39. MRDEM-30 link. OK
40. "provincial 25 m TRIM DEM, FWA, bcfishpass attributes (upstream area, precipitation,
    channel width, fish access), BC lidar". OK, with NOTICE named as the full list.
41. Citation and License lines. OK

DESCRIPTION, CITATION.cff, man/flooded-package.Rd (42-44)
42. Title. OK
43. Description and abstract: the same clauses as 2-8 and 11-14. Claim 5 is **INACCURATE** in
    all three (R2-1); the rest are OK.
44. Authors and roles (NGE Ltd. `fnd`; cffr authors are Irvine and NGE Ltd.). OK (accepted deferral)

inst/NOTICE.md (45-53)
45. FWA rows: OGL-BC. OK
46. bcfishpass attributes: ODbL / DbCL. OK, but the attribute list is incomplete (R2-6).
47. `map_upstream`, ClimateBC, #85. OK (accepted)
48. TRIM DEM, #85. OK (accepted; see Note 3)
49. MRDEM, railways, reserves and parks licences. OK
50. Roads, Access Only, #85. OK (accepted)
51. "the streams chosen by bcfishpass access and stream order". OK. Both `streams_co_vw` (testdata)
    and `streams_bt_vw` (Parsnip) are access views.
52. "the upstream area, precipitation and channel width that set the flood surface". **FALSE** (R2-2)
53. The ODbL Produced Work sentence; stac rasters resampled to 10 m; lidar not redistributed. OK

_pkgdown.yml (54-58)
54. Delineate. OK
55. Get an elevation model. OK
56. Per watercourse, "join per-reach attributes to it". **FALSE** (R2-3)
57. Pipeline steps, "the steps `fl_valley_confine()` runs". OK
58. Raster helpers: union (`fl_flood_assemble`), subtract (`fl_flood_trim`), connectivity
    filter (`fl_patch_conn`). OK

Timing (59-63)
59. Grid, segments, waterbodies, `flood_factor = 4`, M1 Max with 10 cores, flooded 0.8.1,
    terra 1.9.50, "~14 Mcells". OK
60. "108 to 134 s of CPU time" (108.5 to 134.2) and "83 to 122 s of wall time". OK as numbers.
61. "wall time, which rose with other work on the machine". **CONTRADICTED by r3** (R2-5)
62. "made no difference beyond that spread", and "whether terra ran 1 thread or 8".
    **OVERREACH** (R2-5)
63. CLAUDE.md, "gave no measurable speed-up ... so don't advise it". **OVERREACH** (R2-5)

data-raw/readme_figure.R (64)
64. The five legend labels. OK. "Floodplain (flood factor 4)" draws `pars_valleys == 1`, which
    includes the waterbody fill; lakes and wetlands are drawn over it.

## Findings

- **[inaccurate, introduced by the round 1 fix; medium]** `README.md:10-11`,
  `DESCRIPTION:22-23`, `CITATION.cff:14-15`, `man/flooded-package.Rd:11`: "reachable from it
  without crossing much steep ground".
  - `fl_cost_distance()` is `terra::costDist()` over percent slope, so the cost is
    Σ slope% x metres. That is about 100 x the slope-weighted rise and fall along the path,
    and `cost_threshold = 2500` is about 25 m of it.
  - Steepness is one factor of the product, not the criterion. A long route over gentle ground
    fails (1.25 km at 2% costs 2,500). A short steep bank passes (a 20 m rise at 100% over 20 m
    costs 2,000).
  - Measured on the bundled tile at defaults: 150,198 cells are gentle (<= 9%) and within
    1,000 m. Of them, 85,560 fail cost, and 10,074 of those failures have a route that crosses
    no cell steeper than 9%. That is shown by a cost surface with friction 1e-6 on gentle cells
    and slope% on steep ones, where those cells cost < 1.
  - Where cost alone is binding (cells passing slope, distance and flood at ff6) the effect is
    357 cells, 3 of them on gentle-only routes. So the sentence misnames the criterion more
    than it changes this tile's map.
  - Round 1's "without climbing" was nearer the definition (cost / 100 is roughly metres of
    up and down). Its defect was the direction ("descending costs the same"), not the quantity.
  - Fix: name the quantity, e.g. "reachable from it with little rise and fall along the way".
    Or drop the clause, per `readme.md`: "When a correction needs a qualifier, consider
    dropping the claim".

- **[false-claim, introduced by the round 1 fix; low-medium]** `inst/NOTICE.md:31-33`: "the
  upstream area, precipitation and channel width that set the flood surface, come from the
  bcfishpass database".
  - Channel width does not enter the flood surface. `fl_flood_surface()` uses area and precip
    only (`R/fl_flood_surface.R:101-102`).
  - `channel_width` feeds only the channel buffer, which is ORed in after the masks are
    intersected (`R/fl_valley_confine.R:285-299`). CLAUDE.md calls it "DEM correction only".
  - The sentence is round 1 F7's evidence text, copied verbatim.
  - The licence substance is unaffected, because the outputs still derive from bcfishpass.
  - Fix: "... the upstream area and precipitation that set the flood surface, and the channel
    width that buffers each stream, come from ...".

- **[false-claim, round 1 F3 class missed by the sweep; low-medium]** `_pkgdown.yml:16`:
  "Attribute one floodplain to each watercourse, and join per-reach attributes to it".
  - `fl_valley_join()` stops on non-logical `cols` (`R/fl_valley_join.R:158-170`).
  - The README, DESCRIPTION and CITATION were changed to "flags" in 1b435f3; this published
    description (the reference index) was not.
  - The ancestor is the function's own title, `R/fl_valley_join.R:1`, "Join per-segment
    attributes ..." (outside the diff).
  - Fix: "join per-reach flags to it".

- **[overreach, round 1 F1 class; low-medium]** `README.md:78-79` (Learn more):
  "the steep-sided grades and fill that 1 m lidar resolves".
  - The vignette does not identify what the lidar resolves. It calls the pop-ups "the
    candidate barriers ... Some will be natural high ground" (`stac-dem.Rmd:502-505`).
  - It also says "Whether a given line is a road, a dyke or a natural bank is a question for
    the map and the field" (`:547-549`).
  - It measured steep ground (77% of pop-ups on the 1 m slope test), not grades or fill.
  - The opening's sentence (claim 9) is hedged correctly; this one asserts the identity.
  - Fix: "the steep ground 1 m lidar resolves, where raised grades or fill may be".

- **[overreach, timing; medium]** `R/fl_valley_confine.R:91-95` (and
  `man/fl_valley_confine.Rd:133-137`), `vignettes/valley-confinement.Rmd:500-503`,
  `vignettes/pars-floodplain.Rmd:227-228`, `CLAUDE.md:58-59`. Evidence:
  `planning/active/bench_threads.log`.
  1. "wall time, which rose with other work on the machine" is contradicted by one run. The
     fastest of the six runs, r3 at threads 8 (82.6 s), started at load 12.26, above both r1
     runs (load 6 to 7, 85.6 and 88.7 s). A 1-minute load average taken before a run is not
     the load during it.
  2. "made no difference beyond that spread" asserts an absence the data do not show.
     - The paired differences at matched load (threads 8 minus threads 1, wall) are +3.1 s,
       +2.7 s and -32.8 s. In r3 (load about 12 for both) threads 8 was 28% faster.
     - The honest reading is "not separable from the load-driven spread".
     - `valley-confinement.Rmd` and `pars-floodplain.Rmd` now give the **CPU-time** spread as
       the yardstick for a speed claim. Threads shorten wall time; they do not lower CPU time.
       So "108 to 134 s of CPU time, whether terra ran 1 thread or 8" cannot show that threads
       did nothing.
     - The discriminating statistic is CPU/wall: 1.27 / 1.05 / 1.15 at threads 1 against
       1.26 / 1.10 / 1.36 at threads 8. These overlap, and that, not the CPU range, is the
       evidence.
     - "It took 108 to 134 s of CPU time" in `pars-floodplain.Rmd` reads as how long the call
       takes. The wall time was 83 to 122 s.
  3. `CLAUDE.md:58-59` turns this into a standing directive: "gave no measurable speed-up ...
     so don't advise it as one". It carries no load caveat (load 6 to 16 on 10 cores, the
     case in which extra threads cannot help), and future sessions follow it as settled.
  - Fix:
    - Quote wall time for runtime.
    - Say a threads effect was not separable under load 6 to 16, and that one of the three
      pairs favoured threads 8 by 33 s.
    - Or drop the threads sentence until an unloaded run exists.
    - Soften `CLAUDE.md` to "not shown to help; measured only under load".

- **[incomplete licence table; low]** `inst/NOTICE.md:13`.
  - The parenthetical list of bcfishpass attributes ("channel width, fish access, spawning,
    rearing, mapping codes, dams downstream") omits `upstream_area_ha` (both stream files) and
    `gradient` (`pars.gpkg` streams).
  - `NOTICE.md:31-32` and `README.md:112` both say upstream area comes from bcfishpass, yet no
    table row assigns it a licence.
  - Fix: add "upstream area, gradient" to the list.

## Notes (not findings)

1. The ancestors listed under Mechanism are outside the diff, and their defects are pre-existing:
   `floodplain_interpretation.md:26`, `R/fl_valley_join.R:1` and `data-raw/testdata.R:8`.
   Fixing them stops the next README edit inheriting the same phrases.
2. `CLAUDE.md` Architecture says "`fl_flood_trim.R` — remove disconnected patches". That is
   pre-existing and wrong: the function subtracts masks, and `fl_patch_conn` keeps connected
   patches. It is not in the diff.
3. On #85: `data-raw/testdata_bcdata.R:5-8` says the 25 m provincial DEM is fetched "from BC
   Data Catalogue WCS", while NOTICE's row says "Not found in the BC Data Catalogue". Worth
   reconciling when #85 is worked; it stays an accepted tradeoff here.
4. `vignettes/stac-dem.Rmd:71` still sets `terra::terraOptions(threads = 12)`. That is
   pre-existing, not a claim, and harmless.
