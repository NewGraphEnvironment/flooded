# Plan review — #76 (Plan agent, 2026-10-14)

Read-only agent; findings returned as reply text and recorded here by the parent session.

| # | Category | Finding | Verified | Action |
|---|---|---|---|---|
| 1 | Blocker | `if (grepl("^INT", datatype(r_clip)))` errors on a multi-layer source (length > 1 condition) | yes: `datatype(c(r, r))` is length 2 | `any(grepl(...))` |
| 2 | Gap | Same-CRS, `res` differs path (`res = 30`, `buffer = 2000`) hits it too: max 4294967296, 0 NA | yes | test added; the cast precedes both project paths |
| 3 | Gap | buffer-100 vs buffer-2000 equal-cells test needs an AOI mask, not an N-cell edge rule | n/a | test replaced by a Float32-stored reference (red on main, independent of the cast) |
| 4 | Gap | INT4S is fine only for nodata -2^31; nodata 2^31-1 gives 2147483648 | yes | trigger restated as "integer NoData not exact in Float32" in research, draft, CLAUDE.md |
| 5 | Acceptance | equal-cells test cannot go red on main | n/a | superseded by 3: all new tests compare against the Float32 reference |
| 6 | Acceptance | restore the user's `todisk`, not FALSE | already so | `on.exit()` (withr is not in Suggests) |
| 7 | Assumption | `* 1` leaves good cells unchanged (INT2U, INT4S, INT2S) | reviewer's probe | covered by the reference tests |
| 8 | Assumption | in-memory crop's `datatype()` is `""`, so the cast is skipped there (fine) | reviewer's probe | comment in code |
| 9 | Assumption | on disk the copy is FLT4S: integers above 2^24 lose precision | arithmetic | noted in comment; 2^24 mm is 16.8 km, beyond any elevation |
| 10 | Ordering | mutation check depends on test 3 | n/a | moot after 3 |
| 11 | Scope | no change | — | — |
