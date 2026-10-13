# Code review round 3: branch 67-fl-dem-aoi-lets-gdal-choose-the-output-g vs main (HEAD 0141e7d)

The probes ran from `scratchpad/r3/`, against a `git archive HEAD` copy and two mutated copies of it.
No repo file was edited except this one. The running enumeration (`scratchpad/enumerate_frozen.R`)
was not touched. Environment: terra 1.9.50 (GDAL 3.13.0 / PROJ 9.8.1), sf (GDAL 3.8.5 / PROJ 9.5.1).

## Mechanism

**The shared assumption: a CRS property that decides whether a hand-built PROJ pipeline is valid
can be read from a stand-in rather than asked of the libraries that will run it.** The properties
are geographic-ness, axis order, datum identity and units. The stand-ins are `st_is_longlat()`, a
WKT regex, a CRS name, `proj4string` and `units_gdal`. The pipeline is written in PROJ-string
convention: easting, then northing, with `+units`. It is then handed across two boundaries,
`sf::st_transform()` and GDAL's warper inside `terra::project()`, and each applies the CRS's own
authority axis order around it. Round 1 used geographic-ness as the stand-in for axis order;
round 2 replaced it with the axis order itself. **The same assumption now sits one level up, in
the terminal enumeration.** It reads "no row failed" as "every pinned CRS passes", but rows that
error and the sf branch are invisible to it.

Where the mechanism reaches, and what I found at each place:

| place | stand-in | verdict |
|---|---|---|
| `is_nad83()` (WKT DATUM/ELLIPSOID regex) | datum name | OK. sf re-exports WKT1 and ESRI input as WKT2 (probe: a WKT1 BC Albers comes back WKT2 and pins). A miss fails safe, returning `""`. |
| `east_north()` (WKT AXIS regex) | axis text | OK. terra receives the same text (`target_crs$wkt`; `r_crs` is parsed from `terra::crs(r)`). |
| `aoi_crs == r_crs`, which gates the sf-pipeline branch | sf equality | OK. sf's `==` distinguishes axis order: EPSG:2953 against the same WKT with its axes swapped to east, north gives `FALSE`. Stripping the ID alone gives `TRUE`. So an AOI CRS with northing first cannot reach the pin through an east/north `r_crs`. |
| `st_is_longlat()` | geographic | Still needed. OGC:CRS83 is lon/lat, i.e. east, north, so only this guard catches it. |
| `step()` from `proj4string` | units, parameters | OK. I sampled 8 foot CRSs (4 `foot`, 4 `US survey foot`) in both directions, the second with the AOI in the source CRS, which exercises the sf branch. Pin against PROJ's choice: median ≤ 0.75 source units, same coverage, same grid. |
| `units_gdal` in `dem_res_default()` | units | Fails loud (an error), never wrong data. |
| template bbox and crop bbox | PROJ default op | OK. They differ from the pin by at most a datum shift, against a 2-cell pad. |
| harness CRS selection (`grepl("NAD83\|1983")` on names) | CRS name | OK. Over all 5,363 EPSG projected CRSs, every one of the 1,886 that `dem_pipeline_nad83(3979, ·)` pins is in the 1,935 the harness selects by name. 13 of the selected codes are unknown to sf's PROJ 9.5.1. |
| harness pass criterion | "failing = 0" | **Not OK.** See findings 1 to 3. |

## Findings

- **[severity: fragile]** planning/active/enumerate_pin.R:79-83 (with :54-58 and :71).
  **The terminal enumeration passes vacuously for 39% of the pinned CRSs, including 33 of the 35
  that round 2's defect hit.**

  `one()` never passes `res`. So for every foot-unit target, case A stops in `dem_res_default()`
  ("`target_crs` (US survey foot) and the source (metre) use different units"). Case A and case B
  share one `tryCatch`, so the whole row is lost, B included, and B would have failed the same way
  in any case.

  That row still has `pinned_a`/`pinned_b = TRUE`, but its `a_*`/`b_*` columns are NA. `fail()`
  then evaluates to `NA`, and `sum(..., na.rm = TRUE)` drops it. Counted with HEAD's
  `dem_pipeline_nad83()`, **744 of 1,886 pinned CRSs are in feet** (607 US survey foot, 137
  foot). All of them land in "errored" and none in "failing".

  Restore round 2's defect by deleting the `east_north` guard (copy `scratchpad/r3/mut2`) and run
  the harness on 2953, 22240, 23301, 23302 and 23333. It flags 2953 and 22240, with 0 cells
  against 25. The three ICS83 Illinois zones show only as errored, so the summary reads
  `failing A 2, B 2`. In the full run, the 33 Illinois ftUS zones (23301 to 23333) would be
  silent in the same way.

  The same NA arithmetic also drops any pinned row where **both** runs come back all-NA
  (`n_pin = n_prj = 0`). There `!(med < 10)` is `NA`, so a harness placement bug that empties
  every run would also report `failing 0`.

  Fix: pass `res` in the target's units (for example 100 in metres or 300 in feet) in both cases.
  Count a pinned row that errored, or that has `n_prj == 0`, as not passing, and print that count
  next to "failing".

- **[severity: fragile]** planning/active/enumerate_pin.R:66-72 against R/fl_dem_aoi.R:173-183.
  **The harness never runs the sf-pipeline branch.** Case A's AOI is in X and its target is X.
  Case B's AOI is in 3005 and its target is 3005. Both therefore take the first branch at :171,
  `target_crs == aoi_crs`, and the `aoi_crs == r_crs && nzchar(pipeline)` branch, which pushes
  the pin through `sf::st_transform()`, is never reached. That branch is where round 2's
  source-side fault put the template about 7,700 km from the AOI. It is also why `same_grid`
  cannot fail: pin and PROJ share one template by construction.

  Reviewer 2's point-through-sf sweep covered 3979 → C, and my foot probe covered 8 CRSs with
  the AOI in the source CRS, so this is a coverage gap, not a known bad result. Fix: add a case
  with the AOI in the source CRS (for example X → 3005 with the AOI in X), and keep its
  `same_grid` as a real check.

- **[severity: fragile]** planning/active/enumerate_pin.R:33 and :47 (an x-only test field).
  **A north-south displacement smaller than the crop pad passes wherever grid convergence is
  small.** The field holds only the source x. A northing error moves the sampled value only by
  `shift × sin(convergence)`, until the shift leaves the 2-cell (200 m) crop pad and shows up as
  NA.

  Mutation: append `+step +proj=affine +yoff=150` to the pin (copy `scratchpad/r3/mut`). Case A
  still passes for EPSG:26915 (median 4.0, under the 10-unit threshold) and EPSG:26914 (9.9). Case
  B catches both, because UTM 15N against BC Albers has large convergence. So a defect only on
  the target side would pass for CRSs near 95°W.

  The km-scale axis and unit class is still caught, through coverage. Fix: add a y band (or
  `init(r, "y")`) and test both.

- **[severity: bug, docs]** R/fl_dem_aoi.R:68-70 and man/fl_dem_aoi.Rd:89-91. *"So between
  projected CRSs on NAD83 realizations the operation is pinned by default (see `pipeline`) and
  changes only with flooded"* is false for the 35 northing-first CRSs (2953, 22240, 23301 to
  23333). HEAD now leaves those to PROJ, so their operation changes with PROJ, not with flooded.
  Reviewer 2 named this sentence ("The same goes for 'between projected CRSs on NAD83
  realizations the operation is pinned' (Rd details, CLAUDE.md)"). Round 2's fix qualified
  `@param pipeline` and the CLAUDE.md bullet, but not this `@details` sentence. Add "with easting
  then northing axes".

## Checked and found sound

- `dem_pipeline_nad83()` after round 2. The east/north test reads the same WKT terra receives, and
  sf's CRS equality cannot route an AOI CRS with northing first into the pinned sf branch. A
  regex miss always returns `""` (PROJ chooses); it never returns a wrong pin.
- Feet: the pinned `+units=ft` / `+units=us-ft` pipeline is correct through terra and through
  sf. On the 8 sampled CRSs (6797, 8334, 3646, 2281, 3586, 6503, 26864, 6432) it agrees with
  PROJ's choice to ≤ 0.75 ft. The defect is the harness's blindness to them, not the pin.
- Not a defect: every call through the sf-pipeline branch prints PROJ stderr noise
  (`hgridshift: could not find required grid(s)`, `pipeline: Bad step definition: inv`) while
  sf enumerates candidate operations. The result is still correct, and the default MRDEM
  → 3005 call with a 3005 AOI does not take that branch.
- The "0.2 mm" in the Rd and the "0.12 mm" in CLAUDE.md agree: findings.md measured 0.12 mm
  max, and the Rd says "within 0.2 mm".

Probes: `scratchpad/r3/cover.R` (pinned set against the harness list, and units), `feet.R`,
`eq.R` and `eq2.R` (sf equality and WKT1), `h.R` (the harness, parameterised by `PKG` and
`CODES`), and the mutation copies `mut/` (y shift) and `mut2/` (east/north guard removed).
