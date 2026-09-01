# Code review — round 2: bankfull units fix (flooded#49)

Reviewed the staged diff (`/tmp/cc_diff2.txt`, 21 files) against
`soul/conventions/code-check.md`. Round 1's four findings are confirmed fixed and are
not re-reported.

This round was scoped to **numerical consistency across documents, CSV integrity,
residual old-units assumptions, and the runnability of the changed examples.** Every
figure listed in the brief was recomputed rather than read. All of them reproduce (see
"Verified" below). One remaining document publishes pre-fix output as current, and three
smaller cross-document mismatches are listed after it.

---

## Findings

### 1. [fragile] `vignettes/stac-dem.Rmd` — a shipped, pkgdown-published vignette still presents pre-fix output as current 0.5.0 results, and cannot regenerate itself

`stac-dem.Rmd` is the **baked** half of the `.Rmd.orig` pattern: its chunks are plain
` ```r ` blocks with `#>` output already embedded, so `R CMD check` and the pkgdown build
render them as-is. Nothing in this diff re-bakes it, and it carries a
`%\VignetteIndexEntry{}`, so it publishes.

Every quantitative result in it was produced by the defective model:

| line | published figure |
|---|---|
| :85 | `10 m DEM valley cells: 54637 / 518400 ( 10.5 %)` |
| :189 | `5 m DEM valley cells: 250564 / 2073600 ( 12.1 %)` |
| :205 | `Valley area (bundled 10 m DEM): 5.46 km²` |
| :207 | `Valley area (STAC 5 m DEM): 6.26 km²` |
| :317 | `1 m DEM valley cells: 3,883,179 / 1.4e+07 ( 27.7 %)` |

I ran the vignette's own 10 m baseline configuration (`field = "upstream_area_ha"`,
`slope = slope_10m`, `slope_threshold = 9`, `max_width = 2000`, `cost_threshold = 2500`,
`flood_factor = 6`, `precip = precip_r`) under the corrected code: **28,727 cells**
against the published 54,637 — the published figure is ~1.9x the corrected one, in a
vignette whose whole argument is a *comparison of mapped areas across resolutions*.

Why this is the notable one rather than a nitpick:

- `NEWS.md` 0.5.0 opens `**Results change. Every floodplain produced by 0.4.1 or earlier
  is over-mapped.**` — and the site will carry a vignette silently contradicting it.
- The other two vignettes were handled. `pars-floodplain.Rmd` got both regenerated
  artifacts and a caveat paragraph (:78-80); `valley-confinement.Rmd` runs live, and I
  confirmed its chunks now produce corrected numbers (28,727 with precip / 19,838
  without, so its "noticeably narrower" prose still holds). `stac-dem.Rmd` got neither.
- `README.md:56` points readers at it as *the* worked example for the resolution
  argument, so it is a linked destination, not a backwater.

This is round 1's finding 2 (README publishing the pre-fix formula) one file over — the
class `code-check.md` calls "Documentation Staleness".

Cheapest fix that does not require the STAC network and a 1 m lidar re-run: a caveat
block at the top of `stac-dem.Rmd` in the same shape as `pars-floodplain.Rmd:78-80`,
stating the outputs predate the 0.5.0 units fix and are over-mapped. Re-baking from
`.Rmd.orig` is the complete fix if the STAC endpoint is reachable.

### 2. [fragile] `vignettes/pars-floodplain.Rmd:80` — "roughly 16%" disagrees with every other statement of the same quantity, and rounds the wrong way

```
earlier versions of this vignette are over-mapped by roughly 16%.
```

Measured: 41,142.9 / 48,603.1 = **84.65% retained**, i.e. a **15.35%** loss. `NEWS.md:38`
says "the loss is ~15%"; `methodology.md:94` and `NEWS.md:34` both give 84.7% retained.
16% is not a rounding of 15.35 — it crosses it. Two shipped documents now state
different values for one measured quantity, and the vignette is the reader-facing one.

Also worth a second look while there: that vignette publishes **no numeric figures at
all** (maps only), so "figures published from earlier versions" reads as a claim about
numbers that were never printed. If the intent is "the mapped extent you see here was
larger", say that.

### 3. [fragile] `README.md:48` — "required inputs" contradicts the new `precip = NULL` default two lines later

```
Both `upstream_area` (hectares) and `precip` (mean annual precipitation, mm) are required inputs to the
regression, and both are converted internally to the km2 and cm/yr the published coefficients expect.
Omitting precipitation underestimates flood depth by ~2.35x.
```

`precip` is now optional and defaults to `NULL` — the sentence describing omitting it
immediately follows the sentence calling it required. The README is the one document a
user reads before the roxygen, and this is the argument whose default this release
changed. `upstream_area` genuinely *is* required; `precip` is not.

---

## Minor — cross-document numeric mismatches, non-blocking

Listed because the brief asked for places two documents state different values for one
quantity. Neither is wrong, both are inconsistent.

- **`~2.35x` vs `~2.4x`** for the precipitation sensitivity. `README.md:50` and
  `R/fl_flood_surface.R:41` say `~2.35x`; `vignettes/valley-confinement.Rmd:188` and
  `:332` say `~2.4x`. Both are defensible readings of the same fact — I measured
  **2.366** as the mean over all stream cells and **2.354** for the Bulkley mainstem at
  `flood_factor = 6`, which is presumably where 2.35 came from. Worth stating one number
  in one way, since a reader hitting both will not know they are the same measurement.
- **`inst/notes/floodplain_interpretation.md:188`** — "The Bulkley drains **57×**
  Cesford Creek and gets **1.95×** the bankfull depth." That ratio is **units-invariant**
  (`depth ∝ A^0.170 P^0.215`, so the fix cannot move it) and it was already slightly off:
  57.2^0.16996 = **1.989**, or 1.980 carrying Cesford's own 543 mm precip. The section 9
  table added by this diff gives 0.42 / 0.21, which reads as 2.0 — so the memo now
  disagrees with itself in adjacent sections. Pre-existing line, untouched by the diff;
  flagging only because the new table put it next to a contradicting figure.

---

## Verified — recomputed, not read

Recorded so a later round does not redo them.

**Arithmetic — every figure in the brief reproduces.**

| claimed | computed |
|---|---|
| width factor 8.2224 | `100^0.280 * 10^0.355` = 8.2224265 |
| depth factor 3.5926 | `8.2224265^0.607` = 3.5925680 |
| as-coded ff 7.19 / 14.37 / 21.56 | 7.1851 / 14.3703 / 21.5554 |
| `precip = 1` width mult 0.4416 | `0.1^0.355` = 0.4415704 |
| `precip = 1` depth mult 0.6089 | `0.4415704^0.607` = 0.6088566 |
| test literal 0.2740248754 | `0.145 * (0.196*100^0.280*50^0.355)^0.607` = 0.27402487539 |
| intermediate W 2.8535824338 | 2.8535824338 |
| as-coded counterpart 0.9844530049 | 0.98445300489 |
| test literal 0.1179471463 | `0.145 * (0.196*100^0.280)^0.607` = 0.1179471463 |
| Nagel identity 0.054 / 0.170 / 0.215 | 0.053922 / 0.16996 / 0.215485 — the test's comment is correct, it *is* an identity and cannot serve as a units oracle |
| retained 57.8 / 48.6 / 53.6 / 84.7 % | 57.79 / 48.64 / 53.56 / 84.65 |
| ff04→ff07 span 6.4% | 6.412% |
| ff06 88.5%, ff07 90.1% | 88.50 / 90.08 |
| wedzin kwa 84% | 83.89 |
| cells→ha at 10 m and 30 m | consistent to 5 s.f. in all 7 rows (30 m rows all imply 0.093283 ha/cell — the MRDEM clip's real 30.54 m pixel, not a nominal 30 m) |

**The bundled-tile table in `floodplain_interpretation.md` §9 and `NEWS.md` reproduces
exactly, including the strict-subset claim.** Ran `fl_valley_confine()` at ff 2/4/6
under the corrected code, and against an as-coded emulation (inputs pre-scaled ×100 /
×10, which is algebraically the pre-fix path):

```
ff02  as-coded  32081 (320.8 ha) | corrected  18543 (185.4 ha) | retained 57.8% | gained 0
ff04  as-coded  47681 (476.8 ha) | corrected  23192 (231.9 ha) | retained 48.6% | gained 0
ff06  as-coded  53635 (536.4 ha) | corrected  28727 (287.3 ha) | retained 53.6% | gained 0
```

Every cell, every hectare figure, and "0 cells gained anywhere" all hold on this dataset.
The Parsnip and `restoration_wedzin_kwa_2024` subset claims are internally consistent but
not independently re-run here (minutes-scale, and the wedzin kwa inputs live in another
repo).

**Worked bankfull depths (§9) reproduce.** At the memo's stated 531 mm: Cesford
(1,929 ha) 0.2099 / 0.8395 / 1.2592 → 0.21 / 0.84 / 1.26 ✓; Bulkley (110,337 ha) 0.4175 /
1.6699 / 2.5049 → 0.42 / 1.67 / 2.50 ✓. The roxygen's "5.7 m against 31.3 m for the
Bulkley" also holds: computed width 5.710 m, `max(streams$channel_width)` = 31.32.

**Regenerated binary artifacts are correct and surgical.**

- `pars_valleys.tif`: 441,054 cells at 932.83 m²/cell = **41,142.89 ha** — matches
  `NEWS.md` and `methodology.md` to the decimal. Values still `{0,1}`, layer name
  `valley`.
- `pars.gpkg`: all 9 layers present with unchanged names, row counts and CRS. Compared
  every layer against `HEAD` — `floodplain` geometry is the **only** thing that changed;
  the other 8 layers are byte-identical in both attributes and WKB. `floodplain` area =
  41,142.89 ha, 1 feature, EPSG:3005, all geometries valid.
- `HEAD`'s artifacts measure 521,028 cells / 48,603.12 ha, confirming the "0.4.1
  as-coded" row of both tables.

**CSV integrity — both parse to the right shape.** `read.csv` on
`flood_scenarios.csv` gives 3 × 11 with default row names (the earlier
column-shift breakage would show as row names and `scenario_id` = `2,4,6`; it does
not), all 11 documented columns present in `fl_scenarios()`'s `@return` order, 0 `NA`,
`ecological_process` intact at 226 / 313 / 354 chars, `citation_keys` unmerged.
`flood_params.csv` gives 6 × 7, one `NA` (`hole_threshold`'s literal `NA` citation key,
pre-existing), descriptions 839 / 450 / 344 / 443 / 352 / 380 chars. The
`@nagel_etal2014LandscaleScale` → `LandscapeScale` typo fix in that file is correct and
the key resolves in `vignettes/references.bib`; no instance of the typo remains outside
`planning/`.

**No residual old-units or old-default assumption anywhere.** Swept `R/`, `tests/`,
`vignettes/` (including `stac-dem.Rmd.orig`), `data-raw/`, `inst/`, `man/`, `README.md`
for `precip = 1` and for the un-converted formula. The only surviving `precip = 1`
occurrences are prose *explaining why it is wrong* (`test-fl_flood_surface.R:138`,
`valley-confinement.Rmd:334`), which is the intended state. Every live call site
(`data-raw/wsg_vignette_data.R:259`, `pars-floodplain.Rmd:232`, four in `stac-dem.Rmd`
/ `.orig`, all `@examples`) passes a real precipitation raster and is unaffected by the
default change. `methodology.md:14` now carries the input-units column, so the one
remaining statement of the raw formula is no longer unit-less — which was the documented
root cause.

**The units guard actually reaches the failure mode.** Restored the pre-fix function
from `git show HEAD:R/fl_flood_surface.R` (exact bytes, not a reconstruction) and patched
**both** `asNamespace("flooded")` and `as.environment("package:flooded")` per
`code-check.md`. Printed a proof value first — 0.984453 where the fixed code gives
0.2740248754 — then ran the file: **FAIL 5 | PASS 9**. It fails on the literals, and the
`precip = NULL` cases error outright on the old `stopifnot(is.numeric(precip))`. The test
is a real guard, not decoration.

**Suite and examples.** `devtools::test()` → `FAIL 0 | WARN 0 | SKIP 0 | PASS 254`. Ran
the `@examples` for all four changed functions (`fl_flood_surface`, `fl_flood_model`,
`fl_valley_confine`, `fl_scenarios`) — all execute clean. `devtools::document()` produces
no working-tree diff, so the four staged `.Rd` files are exactly what roxygen generates.

**`NEWS.md` 0.5.0 claims checked against the evidence.** Nothing overstated that I can
find. "No test in this package pinned an absolute value before now, and `_snaps/` was
empty" — `tests/testthat/_snaps/` does not exist, and no pre-existing test pins an
absolute numeric result. "The as-coded run reproduces the previous artifact exactly
(521,028 cells, 0 difference)" — the 521,028 half is confirmed against `HEAD`'s artifact;
the reproduction itself I did not re-run. The dataset-dependence framing ("not a fixed
ratio", "the error only reaches the boundary where the flood mask is the binding
criterion") is the correct reading and matches what the two datasets measure.

**Not flagged, per the brief:** `field = "channel_width"` (flooded#47), `DESCRIPTION`
still at 0.4.1, and the annotated historical measurements in `methodology.md` and the
0.4.1 `NEWS.md` entry. For the record, one line inside that 0.4.1 entry — "The shipped
vignette artifacts are therefore still current" — is falsified by this release, but it
sits inside a historical entry and I read it as covered by that instruction.
