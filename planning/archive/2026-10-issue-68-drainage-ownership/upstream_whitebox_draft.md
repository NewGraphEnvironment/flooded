# DRAFT, not posted: issue for jblindsay/whitebox-tools

Revised after a repro attempt. Post only the determinism issue. The panic is held back because
it did not reproduce in 800 runs, and its input was never identified (details at the end).

---

**Title:** BreachDepressionsLeastCost and FillDepressions give different output on identical runs when multi-threaded

**Version:** WhiteboxTools v2.4.0 (via the R `whitebox` 2.4.3 package), macOS arm64.

**What happens.** Running the same tool twice on the same 648 x 800 DEM with the default thread
count gives different output rasters. Count of cells (of 518,400) that differ between two
consecutive identical runs:

| tool | cells differing |
|---|---|
| `BreachDepressionsLeastCost --dist=50 --fill` | 59,638 |
| `BreachDepressionsLeastCost --dist=50` (no fill) | 49,570 |
| `FillDepressions --fix_flats` | 36,047 |
| `BreachDepressions` | 0 |
| `D8Pointer` (fixed input) | 0 |

With `--max_procs=1`, all five are identical between runs.

**Why it matters.** Any workflow that compares two runs (before/after, with/without a change)
picks up tens of thousands of spurious differences. Ours is a check that adding streams never
removes floodplain, and it failed on fixed flow directions until we pinned one thread.

**Ask.** If the variation is expected tie-breaking across threads, a note in these tools' docs
would help, perhaps with a recommendation to use `--max_procs=1` for reproducible output. If it is
not expected, the repro is: run either tool twice on any DEM with depressions and diff the outputs.

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
