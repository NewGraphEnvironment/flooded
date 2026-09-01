# Code review — round 3: the round-2 fixes (flooded#49)

Scope: the five fixes made in response to round 2, plus the new NEWS clause and any
inconsistency those edits introduced. Not a re-audit of the change.

**First: `/tmp/cc_diff3.txt` is stale.** It does not match the index. Two files were revised
after it was written — `vignettes/stac-dem.Rmd` (the caveat now names 53,635 explicitly) and
`planning/active/findings.md` (a new stac-dem reproduction section). This review was done
against `git diff --cached` and the working tree, not that file. Regenerate before the next
round.

Everything below was **recomputed or re-run**, not read.

---

## Findings

### 1. [fragile] `vignettes/pars-floodplain.Rmd:81` — "a loss of 15.4%" is 15.3%, and still disagrees with the other three statements of the same quantity

```
48,603.1 ha before the fix, 41,142.9 ha now, a loss of 15.4%.
```

Measured, both ways:

| basis | loss | retained |
|---|---|---|
| hectares 48,603.1 → 41,142.9 | **15.3492%** | 84.6508% |
| cells 521,028 → 441,054 | **15.3493%** | 84.6507% |

15.3492 rounds to **15.3%**, not 15.4%. This looks like double rounding: round 2's finding
reported "a **15.35%** loss" (15.3492 to 4 s.f.), and the fix rounded *that* up.

The round-2 finding was that this vignette disagreed with every other document stating the
quantity. It still does, by less: `NEWS.md:29` and `inst/notes/methodology.md:94` give
**84.7% retained** (⇒ 15.3% loss), `inst/notes/floodplain_interpretation.md:110` gives 84.7%,
`NEWS.md:32` says "~15%". The vignette is the reader-facing one and is the only document that
now says 15.4.

Fix: `15.3%`.

### 2. [fragile] `inst/notes/floodplain_interpretation.md:188` + `:242-247` — 1.99× is correct only on a basis the memo does not state, and a reader recomputing from the shipped data gets 1.95× back

The change from 1.95 to 1.99 is **not wrong**, but it is not a units correction either, and the
memo does not carry the fact that makes it true.

Verified by direct computation:

| basis | Cesford bankfull | ff04 | ff06 | Bulkley / Cesford ratio |
|---|---|---|---|---|
| both streams at **531 mm** (what the table used) | 0.2099 | 0.8395 | 1.2592 | **1.9892** → 1.99 |
| each stream's **own** `map_upstream` (Cesford 576 mm) | 0.2136 | 0.8543 | 1.2815 | **1.9547** → 1.95 |

`inst/testdata/streams.gpkg` gives the 1,929 ha Cesford segment `map_upstream = 576`, not 531
(531 is the Bulkley's). So the §9 table holds precipitation constant at the Bulkley's value —
which is the *right* basis for the sentence at :188, since that sentence is illustrating the
**area** sensitivity ("drains 57× … gets 1.99× the depth") — but the caption says only
"(corrected, precipitation 531 mm)", which reads as a statement about the data rather than as
a deliberate hold-one-variable choice.

Consequences as it stands:

- A reader recomputing the Cesford row from the shipped test data gets 0.85 / 1.28 and a ratio
  of **1.95** — the number that was just replaced — and concludes the memo is wrong.
- The old 1.95 was **not** an error. Confirmed units-invariant: with each stream's own precip
  the ratio is 1.9547 in *both* unit regimes (as-coded ha/mm and corrected km²/cm). So this
  ratio could never have moved with the fix, in either direction. The NEWS/status framing that
  every figure was "re-measured against the corrected model" does not explain this one changing.
- The two rows also round inconsistently: Bulkley's ff04/ff06 (1.67 / 2.50) come from the
  unrounded depth, Cesford's (0.84 / 1.26) from the rounded 0.21. At 531 mm the unrounded
  Cesford values are 0.8395 / 1.2592, so 0.84 / 1.26 happen to be right — but by coincidence of
  the basis, not by the arithmetic a reader would repeat.

Fix: say it explicitly in the caption — e.g. "both evaluated at 531 mm to isolate the area
effect; Cesford's own MAP is 576 mm" — and add the same half-clause at :188. No number needs to
change.

### 3. [fragile] `NEWS.md:47-50` — an inserted sentence leaves the Parsnip reproduction claim reading as a claim about `stac-dem.Rmd`, which does *not* reproduce

```
  `vignettes/stac-dem.Rmd` is pre-baked and could not be regenerated without the STAC endpoint and
  a 1 m lidar re-run, so it carries an explicit caveat instead: its printed figures are pre-fix. The as-coded run reproduces the previous artifact exactly
  (521,028 cells, 0 difference), which is what establishes the corrected one as a like-for-like
  replacement.
```

Line 48 is **154 characters** where every other line in the file wraps at 87–99 — the tell that
the stac-dem sentence was spliced into the middle of the artifact-regeneration sentence. The
result is that "The as-coded run reproduces the previous artifact exactly" now sits directly
after the stac-dem sentence, and reads as being about stac-dem. It is not: 521,028 is
`pars_valleys.tif`.

That misreading is actively wrong, and this same session established why. Measured today on
stac-dem's own 10 m baseline configuration:

| | cells |
|---|---|
| published in the baked vignette | 54,637 |
| as-coded reproduction, today | **53,635** |
| corrected | **28,727** |

stac-dem's published figure does **not** reproduce — ~1,002 cells of its gap predate this
release, which the vignette's own caveat now says. NEWS's flat "its printed figures are
pre-fix" is the weaker version of that, and the adjacency makes it worse.

Fix: move the stac-dem sentence to the end of the bullet (or its own bullet) so the
reproduction claim stays attached to `pars_valleys.tif`, and re-wrap line 48.

---

## Verified — the five fixes, recomputed

### 1. `stac-dem.Rmd` caveat — **correct, and the number is right for that configuration**

Re-ran the vignette's own 10 m baseline chunk (`field = "upstream_area_ha"`, explicit
`slope.tif`, `slope_threshold = 9`, `max_width = 2000`, `cost_threshold = 2500`,
`flood_factor = 6`, `precip = fl_stream_rasterize(streams, dem, "map_upstream")`, **no**
waterbodies, `channel_buffer` auto) under the working-tree code:

```
corrected  ff6  28,727     <- matches the caveat exactly
as-coded   ff6  53,635     <- matches the caveat exactly
published                  54,637
```

So 28,727 is genuinely this vignette's configuration and not a borrowed figure from the §9
bundled-tile table — the two configurations are in fact identical, which is why the §9 as-coded
ff06 is also 53,635. The current caveat text (revised after `cc_diff3.txt` was cut) already
names 53,635 and attributes the residual ~1,000 cells to changes since the last bake. Nothing
to do.

Configuration sensitivity claim in `findings.md` also confirmed: the same tile gives **55,345**
as-coded with `waterbodies` supplied, against 53,635 without.

**The caveat must NOT go in `stac-dem.Rmd.orig`, and leaving it out is right.** `.orig` is the
knitr source and carries **no hardcoded numbers at all** — every figure in it is computed
(checked: all numeric output comes from `cat()`/`kable` on live objects). A re-bake therefore
produces corrected figures, at which point the caveat would be a false warning attached to
correct output. Keeping it only in the generated `.Rmd`, where it disappears on re-bake, is the
correct placement.

### 2. `pars-floodplain.Rmd` — see finding 1. Underlying figures confirmed against the artifacts

Read the regenerated binaries directly rather than trusting the prose:

```
inst/vignette-data/pars_valleys.tif : 441,054 cells @ 30.5423 m -> 41,142.9 ha
inst/vignette-data/pars.gpkg[floodplain] : 1 feature, 41,142.9 ha
```

The vignette computes no areas of its own (no `st_area`/`expanse` anywhere), so 41,142.9 in
prose is the only figure and it matches the shipped artifact. The 6.4% ff04→ff07 span claim
matches `methodology.md:92-95`.

### 3. `README.md` — matches the signatures, and `~2.4x` is now consistent everywhere

- `fl_flood_surface(dem, streams, flood_factor = 6, precip = NULL)`,
  `fl_flood_model(..., precip = NULL, ...)`, `fl_valley_confine(..., precip = NULL, ...)` —
  README's "`upstream_area` (hectares) is required, `precip` … optional and defaults to `NULL`"
  is accurate for all three.
- The 2.35 / 2.4 split round 2 flagged is closed. `~2.4x` now appears in `README.md:50`,
  `R/fl_flood_surface.R:41`, `man/fl_flood_surface.Rd:52`, `vignettes/valley-confinement.Rmd:188`
  and `:332`. Nothing shipped still says 2.35x; the remaining hits are in `planning/`, correctly
  as a record of the measurement history.
- Minor, non-blocking: `valley-confinement.Rmd:88-90` gives the Bulkley worked case as
  "~1.1 m vs ~2.5 m", which is 2.27 as printed and 2.354 exact — the mainstem value, against the
  "~2.4x" (2.366, all stream cells) two lines up. Both correct, one is a stream and one is a
  mean. Verified: NULL 1.0644 m, precip 2.5049 m at `flood_factor = 6`.

### 4. Roxygen "2.366 averaged over stream cells" — correct, and `man/` is in sync

Measured on the bundled data at `flood_factor = 1`, over the 42 stream cells:

```
mean depth, precip = NULL : 0.1336 m
mean depth, precip = pr   : 0.3160 m
ratio of means            : 2.3661   <- the quoted 2.366
mean of per-cell ratios   : 2.3683
```

Both readings round to 2.37 / ~2.4, so the phrase is not load-bearing on which average is meant.
`man/fl_flood_surface.Rd:52` carries the identical sentence, and `devtools::document()` produced
**no** working-tree diff — `man/` is regenerated and staged consistently.

### 5. `floodplain_interpretation.md` 1.95 → 1.99 — arithmetically consistent with §9, see finding 2

- 1.99 reproduces exactly on the §9 basis: 0.41749 / 0.20988 = **1.9892**.
- **The ratio is units-invariant, confirmed in both directions** — with each stream's own
  precipitation it is 1.9547 whether computed in (ha, mm) or (km², cm/yr); with both at 531 mm
  it is 1.9893 in either regime. Any common rescaling of A and P cancels in a ratio of two power
  laws. So the fix could not have moved this number, and the change is a change of basis.
- Adjacent numbers in §7 check out: `2^0.16996 = 1.1250` → x1.13, `10^0.16996 = 1.4796` → x1.48,
  `2^0.215485 = 1.1611` → x1.16.
- §9 worked depths reproduce on the 531 mm basis (Bulkley 0.4175 / 1.6699 / 2.5049; width 5.710 m,
  matching the roxygen's "5.7 m").

### NEWS 0.4.1 supersession clause — **accurate**

`NEWS.md:45-46` claims it supersedes "the 0.4.1 note below saying those artifacts were still
current — that was true of the #41 cost-distance fix and is not true of this one."

`NEWS.md:81-82` (0.4.1) says verbatim: *"`fl_valley_confine()` returns the same 53,635 cells on
the bundled tile and the same 521,028 cells on the Parsnip Watershed Group, with zero cells
differing in either direction. The shipped vignette artifacts are therefore still current."*

The characterisation is exact — including the qualification that it was true *of #41*, which the
0.4.1 entry's own measured table supports. No overclaim.

### Suite and docs

```
devtools::test()      FAIL 0 | WARN 0 | SKIP 0 | PASS 254      (rc 0, 0 in-band error markers)
devtools::document()  rc 0, no warnings, no working-tree diff afterwards
```

Gated on both the exit status and a grep for `Execution halted|^Error` in the captured log, not
on the summary line alone.

### Cross-document sweep for new inconsistencies

Checked every shipped statement of a quantity these five edits touched:

| quantity | where | agrees? |
|---|---|---|
| retained 57.8 / 48.6 / 53.6 % | NEWS §, memo §9 | yes (57.79 / 48.64 / 53.56) |
| Parsnip 84.7% retained | NEWS, methodology, memo §4 | yes (84.65) |
| Parsnip loss | NEWS "~15%", vignette "15.4%" | **no — finding 1** |
| 28,727 / 287.3 ha | memo §9, methodology attribution caveat, stac-dem caveat | yes, one configuration, verified |
| ff multiples 7.19 / 14.37 / 21.56 | NEWS, memo §4, methodology, `fl_scenarios` roxygen + Rd | yes |
| `~2.4x` precip sensitivity | README, roxygen, Rd, vignette ×2 | yes |
| ff04→ff07 span 6.4%, ff07 at 90% | NEWS, methodology, pars vignette | yes (6.412 / 90.08) |
| wedzin kwa 84% retained | memo §4 | 83.89 → yes (not independently re-run; inputs are in another repo) |
| 1.99× Bulkley/Cesford | memo §7 vs §9 | consistent with §9 — **finding 2** on basis |

One residual worth a line, not a finding: `inst/notes/floodplain_interpretation.md:174` still
states `W_b = 0.196 × A^0.280 × P^0.355` with no units, which is the exact shape NEWS blames for
letting the defect survive. Section 4 covers the units three screens above, and
`inst/research/vca_parameter_rationale.md:28` states them correctly on the line after the
formula, so nothing is actually ambiguous — but a "(A in km², P in cm/yr)" there costs nothing.
