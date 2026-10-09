# DRAFT, not posted: issue for jblindsay/whitebox-tools

**Title:** BreachDepressionsLeastCost (fill) and FillDepressions panic intermittently: "Error unwrapping 'output'" (Arc::try_unwrap race)

**Version:** WhiteboxTools v2.4.0 (via the R `whitebox` 2.4.3 package), macOS arm64.

**What happens.** `BreachDepressionsLeastCost --fill` sometimes exits with status 101:

```
thread 'main' panicked at whitebox-tools-app/src/tools/hydro_analysis/breach_depressions_least_cost.rs:657:27:
Error unwrapping 'output'
```

It is intermittent: the same 720 x 720 DEM succeeded on 25 consecutive calls and failed on
others. It happened with `--max_procs=1` as well as the default.

**Likely cause.** In the fill branch (from about line 606), each worker thread holds a clone of
`output2` (`Arc<Array2D>`) and sends its pit list over `tx`. The main thread receives
`num_procs` messages and then calls `Arc::try_unwrap(output2)`. Receiving a message does not
mean the worker has dropped its clone yet, because the thread may still be unwinding after
`tx.send`. So `try_unwrap` can see a strong count above 1 and the `Err(_) => panic!` arm fires.
`fill_depressions.rs:366` has the same pattern. `breach_depressions.rs` does not.

**Possible fix.** Join the worker handles before `try_unwrap`, or drop the clone explicitly
before `tx.send` in each worker.

**Related, separate:** with the default thread count, `BreachDepressionsLeastCost` (fill on
or off) and `FillDepressions` do not give the same output twice on the same input: 36,000 to
60,000 of 518,400 cells differ between two identical runs. `--max_procs=1` is identical every
time. This may be expected for tie-breaking across threads, but it is worth a line in the docs:
it breaks any comparison between runs.

**Workaround we use:** least cost with `fill = FALSE`, then `BreachDepressions` for the pits
that remain, one thread.
