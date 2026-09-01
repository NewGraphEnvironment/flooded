# Review round 4 — staged prose diff, `inst/notes/floodplain_interpretation.md` + `CLAUDE.md` (#52)

Scope: the staged diff read as *fixes* to round 3, plus the mechanism producing rounds 1–3. Every
number recomputed from the committed artifacts, `methodology.md`, `NEWS.md` and the consuming report
code. Nothing taken from `findings.md` or the earlier review files except the finding text being
checked.

Constants: AOI = 5,596.6047 km² = 559,660.47 ha; cell area 932.8312 m²; `sf_use_s2(FALSE)`.

---

## The mechanism

**Every round's finding has been about a number; every round's fix has been correct about the
number and has introduced a new *scope quantifier* over a population the memo has never
enumerated.** The numbers keep passing re-verification. The quantifier attached to them is what
fails, because the widening is written from recall of an adjacent document rather than read off the
memo.

The move is structural, not careless: when a claim is flagged as under-evidenced, this passage
repairs it by **widening the stated evidential base** ("on every run", "from either layer", "across
the figures in this memo", "which run from X to Y") instead of by narrowing the claim. Widening
requires a population; the population is asserted.

| flagged | the fix's new scope phrase | holds? |
|---|---|---|
| pre-diff | "Scenario-to-scenario comparisons are unaffected **on every dataset**" | no — removed at R2 |
| pre-diff | "the unclipped rasters **quoted elsewhere in this memo**" | no — removed at R2 |
| R1#3 "Denominator inside — stable" | "**One measured case**, not a rule" | **yes** — the only fix that *narrowed* |
| R2#2 lineages paired | "the fall is ~15% **on either lineage**" | no — R3#2 |
| R3#2 that | "**from either pre-fix layer** (15.19% clipped, 15.35% raw on this package's own lineage)" | no — **finding 1** |
| R3#4 "superset" | "…**on every run recorded here**" | vacuous where it matters — **finding 4** |
| R3#6 "not scaled" | "…**which run from 48.6% to 90% across the figures in this memo**" | no — **finding 2** |
| R3#1 "12.5→23.9, no dataset" | `CLAUDE.md` "**the corrected gap** is only 4.6%" | no — **finding 3** |

Five of the seven widening fixes broke. The one that held is the one that shrank the claim.

**Why this memo in particular.** Its job is to license or refuse *quoting a published figure*, so
nearly every sentence is a claim about a population of figures. But the figures it records sit on a
ragged four-axis grid — dataset × resolution × lineage × clipped/raw — and no dataset fills it:

```
                          ff02   ff04   ff06   ff07     as-coded  corrected   raw  clipped
bundled 10 m               ✓      ✓      ✓      -          ✓          ✓        ✓      n/a
Parsnip 30 m (flooded)     -      ✓      ✓      ✓        ff04 only    ✓        ✓       ✓
Parsnip 30 m (peace)       -      ✓      -      -        ✓ only       -        ✓       ✓
restoration_wedzin_kwa     -      ✓      -      -          ✓          ✓        ✓      n/a
```

Any sentence of the form "across the figures here" is a statement over that grid's *holes* as much
as its cells. **Write the grid down once, in the memo, and quantify against it** — that terminates
the class, where a fifth round of instances will not. The candidate set is closed and small: every
scope phrase in the passage. I enumerated all 13 below; four fail, nine hold.

Scope phrases that **do** hold, checked: "in every fish-passage report appendix beside the hectares"
(3 of 3 extant — peace `0730:53`, skeena `0720:55`, fraser `0720:53`); "measured the same way" (both
clipped); "exactly as the area does" (15.1889% both); "Both figures are the floodplain clipped to
the watershed group" (`sf::st_intersection(floodplain, aoi)`, peace `0730-appendix-floodplain.Rmd:41`,
`flood-load` chunk — verified in the file); "the same two layers"; "no corrected run of *its* lineage
exists"; "not even predictably in direction"; "A restatement factor measured on one dataset does not
transfer to another"; "One measured case, not a rule."

---

## Findings

### 1. **[bug]** `inst/notes/floodplain_interpretation.md:140-141` — the parenthetical labels a **peace-lineage** number as "on this package's own lineage", and the pair it prints varies on two axes at once, so it cannot demonstrate the claim it licenses

```
... good enough here, because the fall is ~15% from either pre-fix layer
(15.19% clipped, 15.35% raw on this package's own lineage).
```

The prose is now right; the parenthetical is not. There are four possible "falls" and the memo
prints one from each of two different families:

```
A cross-lineage, CLIPPED : 48,116.2027 -> 40,807.8791 = 15.1889 %   <- memo's "15.19% clipped"
B same-lineage,  RAW     : 48,603.1174 -> 41,142.8932 = 15.3493 %   <- memo's "15.35% raw"
C cross-lineage, RAW     : 48,540.8043 -> 41,142.8932 = 15.2406 %   <- not in the memo
D same-lineage,  CLIPPED : does not exist (no clipped 0.4.1 artifact anywhere)
```

Two problems.

- **A is the peace lineage.** 48,116.2027 ha is the peace report's own raster (520,360 cells) after
  the appendix clip; flooded's 0.4.1 artifact is 521,028 cells. If "on this package's own lineage"
  distributes across both figures, it is false of the first. If it attaches only to "15.35% raw",
  nothing says so and the reader has no way to tell — and the *previous sentence* has just spent two
  clauses establishing that these are two different runs, which is precisely the distinction the
  parenthetical then blurs.
- **The pair cannot support "from either pre-fix layer."** A and B differ on lineage *and* on
  clipping simultaneously, so their 0.1604 pp spread is not attributable to lineage. The comparison
  that varies lineage alone is **B vs C — 15.35% and 15.24%, both raw, spread 0.1087 pp** — and C is
  computable from figures already in the memo (48,540.8 is the 520,360-cell layer implied at line
  137–138; 41,142.9 is at line 109).

The memo reaches for A rather than C because D is missing — cell **D of the grid above is empty**,
so there is no clipped pair on one lineage to print. That is the mechanism in miniature: the scope
("either layer") was widened to a grid position that does not exist, and the nearest available
number was substituted without re-labelling.

Fix: `(15.35% on this package's own lineage, 15.24% from the peace raster — both unclipped, so the
comparison isolates the lineage)`. Or drop the parenthetical and keep "~15% from either pre-fix
layer", which is true and is all the conclusion needs.

This is round-3 finding 2's residue, and the third consecutive round in which a lineage claim has
been removed from one clause and reappeared, weaker, in the clause that replaced it.

---

### 2. **[bug]** `inst/notes/floodplain_interpretation.md:131` — "which run from 48.6% to **90%** across the figures in this memo" — 90% is not in this memo, and the figure it comes from is not a retention

```
$ grep -n "90" inst/notes/floodplain_interpretation.md
131:  never with a retention borrowed from another dataset, which run from 48.6% to 90% across the
```

One hit: the sentence itself. Every retention figure the memo actually records:

```
line 108  bundled 10 m  ff04   231.9/476.8       = 48.64 %   ("49% retained")
line 110  Parsnip 30 m  ff04   41,142.9/48,603.1 = 84.65 %   ("84.7% retained")
line 111  wedzin kwa    ff04   14,345.3/17,100.7 = 83.89 %   ("84% retained")
line 273  bundled 10 m  ff02   185.4/320.8       = 57.79 %
line 274  bundled 10 m  ff04                     = 48.64 %
line 275  bundled 10 m  ff06   287.3/536.4       = 53.56 %
line 128  share pair    clipped                  = 84.81 %   (100 − 15.19)
line 141  raw own lineage                        = 84.65 %   (100 − 15.35)
```

**Range: 48.6% to 84.8%.** The 90% comes from `methodology.md:96`, and it is wrong on three counts
for the use made of it:

1. It is not in this memo, which is the scope the sentence names.
2. It is not a retention. That row is `ff07` **corrected** (43,780.8) over `ff04` **as-coded**
   (48,603.1) = 90.08% — a cross-*scenario* ratio. There is no as-coded `ff07` run, so `ff07` has no
   retention.
3. It is the **same** dataset (Parsnip), so it cannot illustrate "a retention borrowed from
   *another* dataset."

The sentence is the one that tells a report author not to rescale a published share with someone
else's ratio, so the width of the quoted range is the whole force of the warning. Fix: "…which run
from 48.6% to 84.8% across the figures in this memo". The narrower range is still a 1.7× spread and
still makes the point.

Worth noting alongside it: skeena (48,344 ha, 6.2%) and fraser (54,306 ha, 13.1%) publish the same
`fp_pct_aoi` from 0.4.1-era layers and have **no measured retention at all**. "Nothing to borrow" is
a stronger and more accurate statement than any range.

---

### 3. **[bug]** `CLAUDE.md:94` — "on the Parsnip WSG at 30 m **the corrected gap** is only 4.6%" names no scenario pair; the nearest referent is `ff04`–`ff02`, which has never been measured at 30 m

```
... on the bundled 10 m tile `ff06`–`ff04` widened 12.5% -> 23.9% while `ff04`–`ff02` narrowed
48.6% -> 25.1%, and on the Parsnip WSG at 30 m the corrected gap is only 4.6% (#52).
```

4.6% is the corrected **`ff06`–`ff04`** gap — `methodology.md:94-95`, 43,015.6/41,142.9 − 1 =
4.5517% (cells 461,129/441,054 − 1 = 4.5516%), which does print `4.6`. But the memo names the pair
(`:148`, "the corrected `ff06`–`ff04` gap") and `CLAUDE.md` does not, so the last-mentioned pair
wins: `ff04`–`ff02`. **There is no `ff02` run on Parsnip at any resolution** (`methodology.md:91-96`
records `ff04` as-coded, and `ff04`/`ff06`/`ff07` corrected), so a reader takes 4.6% for a quantity
that does not exist.

Compounding it: the two preceding clauses are `X -> Y` pairs and 4.6% is a bare single value with no
as-coded counterpart (there is no as-coded Parsnip `ff06`). "only 4.6%" in that position reads as
"the gap *fell to* 4.6%". It did not fall to anything.

Round 3's finding was a figure carried without its **dataset**; the fix supplied the dataset and
dropped the **scenario pair**. Same class, one axis over.

Fix: "…and on the Parsnip WSG at 30 m the corrected `ff06`–`ff04` gap is only 4.6%".

---

### 4. **[fragile]** `inst/notes/floodplain_interpretation.md:145-146` — "on every run recorded here" is vacuously true for the run the paragraph is actually about

```
the *ranking* of scenarios survives — `ff06` maps more ground than `ff04`, which maps more
than `ff02`, on every run recorded here
```

Enumerating every run in the memo and in `methodology.md` that records more than one scenario:

```
section 9, bundled 10 m as-coded    320.8 < 476.8 < 536.4     both halves ✓
section 9, bundled 10 m corrected   185.4 < 231.9 < 287.3     both halves ✓
methodology.md, Parsnip corrected   41,142.9 < 43,015.6 < 43,780.8 (ff04<ff06<ff07)
                                                              ff06>ff04 ✓, ff04>ff02 NOT MEASURED
Parsnip as-coded                    ff04 only
restoration_wedzin_kwa_2024         co_ff04 only
```

So `ff04` > `ff02` is measured on **one dataset**, at 10 m, where the flood mask binds. The
paragraph's subject is the 30 m Parsnip watershed — the run a report author would be restating —
and that run has no `ff02` in it. The quantifier passes only because the runs missing `ff02` cannot
falsify it.

The claim is almost certainly true and derivable: `flood_factor` enters solely through
`fl_flood_surface()`, raising the waterline at every stream cell; `terra::interpIDW` weights are
independent of `z`; the three other masks, the channel buffer and the waterbody OR are
`ff`-independent. Round 3 asked for exactly this — *"say 'by construction' and give the one-line
reason, or measure it once and cite the number."* The fix took neither option and widened the scope
instead, which is the mechanism above.

The memo holds itself to the opposite standard at section 7 item 2: *"its magnitude … is uncited and
should not be asserted."*

Fix: "`ff06` maps more ground than `ff04`, which maps more than `ff02` — by construction, since
`flood_factor` only raises the waterline and every other criterion is independent of it; measured
directly on the bundled tile at both stages (section 9)."

---

### 5. **[fragile]** `inst/notes/floodplain_interpretation.md:131` vs `:147` — "48.6%" appears sixteen lines apart in one section meaning two unrelated quantities, both cited to section 9

```
:131  "which run from 48.6% to 90%"        -> ff04 RETENTION, 231.9/476.8      = 48.6367 %
:147  "`ff04`–`ff02` narrows, 48.6% -> 25.1%" -> ff04–ff02 as-coded GAP, 476.8/320.8 − 1 = 48.6284 %
```

A coincidence to four significant figures, in the same section, both pointing at the same table. A
reader chasing either "48.6%" back to section 9 has a 50% chance of landing on the wrong row, and
the two quantities license opposite actions (one is a retention you may rescale a share by, the
other is a gap the memo has just said you may **not** carry forward).

Cheap disambiguation: write the retention bound as "48.6% *retained*" at `:131`, or state the range
in the reciprocal form the bullets already use ("49% to 85% retained"). Finding 2's fix changes this
line anyway.

---

### 6. **[fragile]** `inst/notes/floodplain_interpretation.md:129-131` vs `:317-318` — the memo now gives two answers to "may I rescale?", and the second one points at the first as its justification

```
:129  A share of this shape has to be **re-run**, not held. Rescaling works only with *this*
      group's own retention — the denominator is fixed, so the share falls exactly as the area
      does — never with a retention borrowed from another dataset ...

:317  Figures carried over from 0.4.1 or earlier are over-mapped by a dataset-dependent amount
      — see section 4 — and must be re-run rather than scaled, since the error only reaches the
      boundary where the flood mask binds.
```

`:318` is a blanket prohibition on scaling that cites section 4; section 4 now says scaling works in
a named case. The two are reconcilable — `:318` is about **absolute areas** and `:129` about
**shares** — but nothing in either sentence makes that distinction, and `:318` is in *"Open
verification items"*, the part someone reads when deciding whether a specific published number may
be quoted.

Round 3's finding 6 was that "not scaled" was wrong for the case just worked. That is fixed, and
correct: 8.597392 × (40,807.8791 / 48,116.2027) = 8.597392 × 0.848111 = **7.291542%**, the corrected
share exactly. The relocation is that the prohibition now survives, unqualified, 180 lines later.

Note also that the licensed operation is near-circular: to rescale by "this group's own retention"
you need the corrected area, and with the corrected area you can compute the share directly. Its one
real use is a reader holding corrected hectares but not a corrected share — which is exactly the
situation this memo creates by publishing 40,807.9 ha. Worth saying, since otherwise the sentence
reads as a shortcut past the re-run it sits beside.

Fix: qualify `:318` — "absolute area figures … must be re-run rather than scaled (a *share* may be
rescaled by its own group's retention — section 4)".

---

### 7. **[fragile]** `CLAUDE.md:92` — "Scenario *ranking* survives such a fix" drops the scope the memo attaches to it

The memo says "on every run recorded here", which is itself too broad (finding 4) but at least
signals that this is an observation over recorded runs. `CLAUDE.md` states it as an unconditional
property of the fix. This file is read standalone as a convention, and it is the file whose own
rules say *"A defect's magnitude is dataset-specific — measure it where it lands"* and *"An
inventory is only complete relative to a boundary — name the boundary."*

Fix: "Scenario *ranking* survives such a fix — by construction, since `flood_factor` only raises the
waterline". One clause, and it is the stronger warrant anyway.

---

## Recomputed and clean

```
peace pre-fix   520,360 cells  raw 48,540.8043 ha  clipped 48,116.2027 ha  8.5974 % -> "8.6"
flooded 0.4.1   521,028 cells  raw 48,603.1174 ha
flooded corr.   441,054 cells  raw 41,142.8932 ha  clipped 40,807.8791 ha  7.2915 % -> "7.3"
668 cells x 932.8312 m2 = 62.3131 ha = 48,603.1174 - 48,540.8043            direction correct
raw shares      8.6733 % -> "8.7"   and   7.3514 % -> "7.4"    both digits move          ✓
area fall == share fall  15.1889 %  (fixed denominator)                                  ✓
wedzin kwa fall 16.1128 %, retained 83.8872 % -> "84%"                                   ✓

section 9 gaps, ha (cells agree to 0.02 pp):
  ff06-ff04   as-coded +12.5000 %  corrected +23.8896 %  -> "12.5 -> 23.9"   WIDENS       ✓
  ff04-ff02   as-coded +48.6284 %  corrected +25.0809 %  -> "48.6 -> 25.1"   NARROWS      ✓
  ff06-ff02   as-coded +67.2070 %  corrected +54.9622 %  (not shown)         NARROWS
Parsnip 30 m corrected ff06-ff04  +4.5517 %  -> "4.6"                                     ✓
```

- **Fix 1 landed in the memo.** `:146-149` names both datasets, both resolutions, gives 23.9% and
  4.6% as like-for-like *corrected* gaps, and states the transferability conclusion. Correct and
  unambiguous. Only the `CLAUDE.md` half regressed (finding 3).
- **Fix 3 landed and is not an over-claim.** "not even predictably in direction" is supported
  directly rather than by induction: the same fix widened one gap and narrowed another *within the
  same table*. Both directions observed, n irrelevant. The unshown third gap also narrows, which
  does not change the claim.
- **Fix 5 landed and did not relocate.** `CLAUDE.md:88-91` splits the attribution ("a published
  8.6%" / "a corrected 7.3%") and the following clause reinforces it ("the raw layer's 8.67% is not
  the published number"). Nothing elsewhere in `CLAUDE.md` re-implies a published corrected figure.
- **No verbatim relocation of any earlier removal.** `git grep` over `inst/ NEWS.md CLAUDE.md R/
  vignettes/` for "drier", "farther from the channel", "comparisons are unaffected", "proportional
  claims stand", "superset", "either lineage", "not scaled", "as published" — **zero hits** for all
  eight. Section 9's "strict subset" is a different, measured claim (corrected vs as-coded at one
  scenario) and is untouched.
- **The clip pointer is exact.** `sf::st_intersection(floodplain, aoi)` at peace
  `0730-appendix-floodplain.Rmd:41`, inside `{r flood-load}` (chunk opens `:14`); `{r flood-rollup}`
  opens `:50` and computes `fp_pct_aoi <- 100 * fp_area_ha / (aoi_area_km2 * 100)` at `:53`. Read
  from the file this round, not carried from round 3.
- **"in every fish-passage report appendix"** — three appendices exist (peace 2025, skeena 2025,
  fraser 2025); all three define and print `fp_pct_aoi` directly beneath "Floodplain area (ha)".
  Neither 2023/2024 nor the template repo has a floodplain appendix, so the quantifier is over a
  complete population.
