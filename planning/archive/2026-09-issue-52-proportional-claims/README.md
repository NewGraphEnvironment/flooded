# #52 — the counter-case to "proportional claims stand"

`inst/notes/floodplain_interpretation.md` section 4 closed with *"absolute hectare claims from 0.4.1
need restating; proportional claims stand."* True of the case it cited — land-cover composition
**within** the floodplain, 27.51% -> 27.50% across the 0.5.0 units fix — and false of a ratio whose
denominator sits outside the mapped region. Since this memo is what we consult to decide whether a
published figure can still be quoted, the undistinguished sentence was the whole defect.

The sentence now states the **test** rather than a conclusion — did numerator and denominator move
together — with one worked example of each shape, plus the counter-case: floodplain as a share of
the watershed group (`fp_pct_aoi`), which falls with the hectares. `CLAUDE.md`'s design-decision
entry was updated to match. Docs-only; no version bump, no NEWS entry.

Closed by bd8a717.

## Measurement

Both sides read with `sf::st_area()` over the same 5,596.6 km² (559,660.47 ha) Parsnip AOI, through
the same `st_intersection(floodplain, aoi)` the appendix applies before measuring:

| | raw layer | **clipped — what the report computes** | prints |
|---|---|---|---|
| peace report as committed, pre-fix (520,360 cells) | 48,540.8 ha / 8.6733% | **48,116.2 ha / 8.5974%** | **8.6** |
| corrected, 0.5.0 (441,054 cells) | 41,142.9 ha / 7.3514% | **40,807.9 ha / 7.2915%** | **7.3** |

Confirmed against the rendered `docs/app-floodplain.html` (`48,116`, `8.6 %`) — not a prediction.
The share falls 15.19%, exactly as the area does, because the watershed group does not shrink. The
issue's 8.67% -> 7.35% was the *raw* layer and is not the published number; the correction is what
the memo now carries.

Two further corrections fell out, both of pre-existing text carried through the diff:

- **"Scenario-to-scenario comparisons are unaffected on every dataset"** is contradicted by section
  9's own retention table (57.8 / 48.6 / 53.6%). Only the *ranking* survives: `ff06`–`ff04` widens
  12.5% -> 23.9% while `ff04`–`ff02` narrows 48.63% -> 25.07%. A 0.4.1 report saying "`ff06` maps
  12.5% more than `ff04`" restates to 23.9%.
- **Waterbody areas move.** `fl_valley_confine()` unions waterbodies in independently of
  `flood_factor`, but the published row is `waterbodies ∩ floodplain`, and `terra::rasterize()`
  burns by cell centre — so a waterbody's fringe is in the floodplain only where the VCA mask covers
  it. Lakes -0.3%, wetlands -0.7% on Parsnip.

## The review, and what it cost

Six `/code-check` rounds, **36 findings, 14 of them bugs** — on a four-paragraph prose diff.

| round | findings | the one that mattered |
|---|---|---|
| 1 | 4 (2 bug) | the published figure is the *clipped* layer, not the raw one I measured |
| 2 | 7 (5 bug) | a bullet performed the exact pairing the sentence nine lines below forbade |
| 3 | 6 (1 bug) | a bundled-10 m ratio quoted in a paragraph about the 30 m watershed (4.6% there) |
| 4 | 7 (3 bug) | **named the mechanism** |
| 5 | 5 (2 bug) | the rescale license was unrestricted in what the numerator measures |
| 6 | 7 (1 bug) | "waterbodies do not move at all" — they move |

**The mechanism.** Every round's finding was about a *number*; every round's fix was correct about
the number and then introduced a new **scope quantifier over a population the memo never
enumerates**. Flagged as under-evidenced, the passage kept repairing itself by *widening its stated
evidential base* ("on every run", "from either layer", "across the figures in this memo") instead of
by narrowing the claim. Across rounds 4–6, **every widening broke or was under-justified; every
narrowing held.**

Root cause: the memo's figures sit on a ragged dataset × resolution × lineage × clipped/raw grid
that no dataset fills, so "across the figures here" quantifies over holes as much as cells.

**How it terminated** — by enumeration, not by another instance. Round 6 reproduced 0.4.1 exactly on
current code (the defect was a constant 3.5926× on depth and `flood_depth = bankfull × ff`, so
`flood_factor = 14.3704` returns the settled 521,028 cells) and measured every row of the appendix
rollup on one lineage. Residual, stated exactly: the channel-buffer half of one clause is *vacuous*
against the seven-row enumeration, because the appendix publishes no channel-buffer-derived row.

Two conventions in `CLAUDE.md` were reproduced verbatim by this work and are worth re-reading:
*"Measure the output, not the input you handed in"* (round 1) and *"A defect's magnitude is
dataset-specific — measure it where it lands"* (round 3), whose own worked example is this issue.

## Evidence

`review-round1.md` … `review-round6.md` in this directory — each carries its own recomputed
arithmetic, and rounds 4–6 carry the full quantifier enumerations.
