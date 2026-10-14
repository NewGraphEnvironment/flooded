# Plan review 1 (Plan agent, background, delivered 2026-10-14)

Read-only agent; findings transcribed by the parent session. Disposition column added by the parent.

| ID | Finding | Disposition |
|----|---------|-------------|
| B1 | `aoi_pipeline()` reads `pipeline` after it is overwritten by the source->target pin, so a non-pinnable source->target pair (e.g. WGS 84 UTM source) leaves AOI->target unpinned even when that pair (3157 -> 3005) is pinnable; measured 3/30 offsets move | Fix: keep the raw argument; add a 32610-source / 3157-AOI test |
| G1 | supplied-pipeline test uses the exact inverse of the default pin, so it cannot tell "string used" from "string ignored" | Fix: shifted string, compare against an independently built result |
| G2 | a string sf cannot invert, or that meets lat/lon axis order, gives NaN window and "[ext] invalid extent" | Fix: stop with a clear message on a non-finite window |
| G3 | third-CRS AOI + supplied string: AOI transforms use default pins, warp uses the string | Keep design (Option A); document in `@param pipeline` |
| G4 | guard does not cover `third` offsets; does not check the mock reaches flooded's namespace | Fix both |
| G5 | 26910 -> 3005 is a pair no PROJ moves; use 3157 (CSRS) | Fix: switch to 3157, re-search offsets |
| G6 | `pipeline = ""` covered only on the early-return path | Fix: add reproject-path case |
| O1 | roxygen quoted probe figures before probe committed | Already committed together in ff0e53b |
| A1 | guard compares pinned vs mocked rather than unmocked-plain vs mocked-plain | Fix |
| A2 | mock's +1.3 m is not the real (+0.71, -1.05) split | Note in comment; real-PROJ check via terra-backed mock (Acceptance 1) |
| A3 | testthat pin reason wording | No change |
| S1 | `expected_ext()` uses unpinned transform with tolerance 0 | Out of scope; noted in PR |
| S2 | NEWS wording at release | Carried to PR body |
| Acc1 | re-run against fixed code with a real PROJ | Add terra-backed outer mock to `measure_window.R` |
| Acc2 | no change on this machine | Compare 0.7.0 vs branch outputs |
| D1-D4 | docs qualifiers (`@param`, `@details`, research Consequences, CLAUDE.md) | Fix |
