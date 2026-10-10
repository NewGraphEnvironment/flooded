# DRAFT, not posted: issue for jblindsay/whitebox-tools

Revised after a repro attempt. Post only the determinism issue, with the reprex. The panic is
held back because it did not reproduce in 800 runs, and its input was never identified (details
at the end).

---

**Title:** BreachDepressionsLeastCost and FillDepressions are not deterministic when multi-threaded on DEMs with tied elevations

**Version:** WhiteboxTools v2.4.0 (via the R `whitebox` 2.4.3 package), macOS arm64.

**What happens.** On a DEM whose elevations contain ties, such as an integer-valued DEM, running the
same tool twice with the default thread count gives different outputs. With `--max_procs=1` the
output is identical every time. On a DEM with continuous elevations (no ties), both settings are
identical.

**Reprex** (R, needs only `whitebox` and `terra`): a synthetic 800 x 800 tilted surface with
noise, rounded to whole metres. It is `upstream_whitebox_reprex.R` beside this draft and is pasted
below when posting. Cells (of 640,000) that differ between two consecutive identical runs:

| tool | default threads | `--max_procs=1` |
|---|---|---|
| `BreachDepressionsLeastCost --dist=50 --fill` | 77,352 | 0 |
| `BreachDepressionsLeastCost --dist=50` | 58,060 | 0 |
| `FillDepressions --fix_flats` | 95,467 | 0 |
| `BreachDepressions` | 0 | 0 |

The same surface without the rounding gives 0 for every tool at both settings, so the variation
is in tie-breaking. A real integer DEM (648 x 800, 409 distinct elevations) gave 36,047–59,638
differing cells.

**Why it matters.** Integer DEMs are common (SRTM, many national products). Any workflow that
compares two runs picks up tens of thousands of spurious differences. Ours checks that adding
streams never removes floodplain, and it failed on fixed inputs until we pinned one thread.

**Ask.** Make tie-breaking independent of thread scheduling. Failing that, note in these tools'
docs that multi-threaded output is not reproducible on tied elevations and that `--max_procs=1` is.

---

## Held back: the panic (not for posting as is)

During development, `BreachDepressionsLeastCost --fill` panicked twice, with exit 101:

```
thread 'main' panicked at whitebox-tools-app/src/tools/hydro_analysis/breach_depressions_least_cost.rs:657:27:
Error unwrapping 'output'
```

- Both happened inside test runs while the machine was heavily loaded: once with a second R
  process running alongside, once minutes before the session died from memory pressure.
- The crashing call reported 1,847 unsolved pits. That input was not identified: the bundled DEM
  reports 1,865 and the NA-block test fixture 1,503.
- The thread count at the second crash was probably 1, set through `R_WHITEBOX_MAX_PROCS`, but the
  log line with the arguments was not kept.
- **Repro attempt, 2026-10-09 (the fill branch ran on every call):**
  - the bundled DEM, 200 calls at `--max_procs=1` and 200 at default threads: **0 panics**;
  - four concurrent loops, 200 calls at each setting: **0 panics**.
- **Plausible cause, from reading the v2.4.0 source, unconfirmed.** Workers hold `Arc` clones of
  `output2` and send over `tx`. The main thread calls `Arc::try_unwrap(output2)` after receiving
  `num_procs` messages, which does not guarantee every worker has dropped its clone.
  `fill_depressions.rs:366` has the same pattern.
- Worth posting only with an input that reproduces it.

**What flooded does:** least cost with `fill = FALSE`, then `BreachDepressions` for the pits that
remain, one thread. That route never takes the branch in question.
