# Chinese Chess Engine Engineering Standards

These standards govern the Chinese-chess runtime, engine tooling, and behavior tests. Correctness outranks playing strength and speed: optimize only after legality, termination, and repeatability are proven.

## Correctness-first architecture

Keep dependencies one-way:

1. `domain/chess_state.lua` owns board representation, legal-move generation, check/checkmate rules, state transitions, and repetition counts for the played game.
2. Evaluation and search consume State APIs. `domain/chess_ai_core.lua` owns search-line position identity, repetition context, and its apply/unwind lifecycle. Search explores copied positions only through `State.apply_pure`; it does not mutate the live game.
3. `domain/chess_app.lua` is the controller. Only the controller may commit a selected move to the live game, update history/UI, or trigger the next turn.
4. Views render controller state and never decide legality or commit moves.

State legality is a hard boundary. Do not bypass `State.is_legal`, legal-move generation, or the canonical state transition with duplicated piece rules or unchecked board writes.

Good:

```lua
local next_board = State.apply_pure(board, move.r, move.c, move.tr, move.tc)
```

Bad:

```lua
board[move.tr][move.tc] = board[move.r][move.c] -- mutates and skips State legality
```

## Test-first changes

Use strict Red/Green/Refactor for every behavior change:

1. **Red:** add the smallest behavior test and run it; record the expected failure caused by the missing behavior.
2. **Green:** implement only enough production code to pass; rerun the focused test and relevant suite.
3. **Refactor:** improve structure without changing behavior; rerun the same evidence.

Tests must exercise legal positions and observable outcomes. A new search feature needs a tactical/legality case, not a regex assertion against Lua source. Documentation/config-only changes may use a deterministic contract script instead of entering the production test suite.

## Search termination and ownership

- Search must use `State.apply_pure` and return a candidate; it must never commit a game move.
- Every potentially long loop must either yield resumably with deadline/node/leaf checks or be provably finitely bounded to safe work per call.
- Feed the X4 Pro watchdog in hot loops as a separate liveness obligation. Feeding is never a termination condition or proof of bounded work.
- Preserve a legal fallback from the last completed iteration. Never publish a half-computed principal variation.
- Cancellation, timeout, leaf limit, no-legal-move, and normal completion must converge through one cleanup path.

Good:

```lua
if session.watchdog then session.watchdog:feed() end
if clock() >= session.deadline then
  session.stop_reason = "timeout"
  return
end
```

Bad:

```lua
while true do search_next_node() end
```

## Transposition tables and repetition

- Keep the transposition table capacity-bounded; replacement must not let its count or backing storage grow beyond the configured limit.
- A TT hit is valid only when position identity, side to move, depth/bound semantics, and repetition context match.
- Played-game counts in `chess_state.lua` and search-line identity/context in `chess_ai_core.lua` must use byte-identical `board .. "|" .. side` encoding. Add cross-layer compatibility and regression tests before changing either encoder.
- Repetition counts/signatures are part of correctness. Apply and unwind them symmetrically on every searched move; never reuse a score from a different repetition history.
- Add tests for capacity rollover, replacement, repetition draws, and false-hit prevention before changing TT keys or policies.

## Evaluation and benchmarking

Centralize evaluation weights in `domain/chess_evaluation.lua`; do not scatter tuning literals through search. Each weight change must state its hypothesis and include benchmark before/after evidence. Reject gains that reduce legal rate, overall or critical tactical hit rate, deterministic budget compliance, or X4 Pro safety.

The simulator benchmark measures engine logic and relative trends, not real-device speed. Use:

Runtime benchmark records and the human report expose deterministic logical elapsed time plus observed host wall time. Host wall time is operational deadline evidence only, never an engine-speed measurement.

Enforce the Worker wall deadline independently and exactly; the default is 5000ms with no allowed-runtime tolerance. Deterministic JSON excludes host wall aggregates and per-record wall values so identical logical runs serialize identically. Real wall-speed claims require separately identified X4 Pro device evidence.

The default CLI is the authoritative gate: it always runs the complete immutable case catalog with fixed case difficulty/budget profiles, thresholds, motif populations, and the 5000ms wall cap. Filters and overrides require explicit `--explore`; exploratory output is labeled `not-evaluated` and never claims authoritative gate success.

## Lua conventions

- Indent with 2 spaces; use `snake_case` for locals/functions.
- Export modules through `M.*`; keep constants `local` and `UPPER_SNAKE_CASE`.
- Do not create globals. Pass dependencies/state explicitly.
- Avoid allocating tables, closures, concatenated strings, or copied collections per node in hot paths unless profiling and benchmarks justify them.
- Prefer small pure helpers; document non-obvious coordinate, bound, and repetition invariants.

Good: `local TT_LIMIT = 2048` and `function M.step(...)`.
Bad: `ttLimit = 2048` or an implicit global callback.

## JavaScript tooling and tests

- Follow repository ESLint rules and ESM conventions.
- Use `node:test` and `node:assert/strict`.
- Test public behavior, stable reports, legal outcomes, deadlines, cleanup, and exit codes. Do not use source-text regex as a substitute for behavior tests.
- Keep fixtures deterministic and sort serialized collections before comparing output.

Run the repository commands that match the changed surface:

```bash
npm run lint
npm test
npm run build
```

## Observability and failure contracts

Search-session statistics and benchmark reports are different contracts:

- Drive search through `AI.begin` and repeated `AI.step` calls. Observe completion from the returned `done` value and search statistics from returned `stats`; obtain the current best/legal fallback move through the returned `move` or `AI.result`.
- Stable finished-search `stats.stop_reason` values are `book`, `target_depth`, `timeout`, `leaf_limit`, `cancelled`, and `no_legal_move`. `stats.reason` is the compatibility alias. After `AI.cancel`, call `AI.step` again to observe the finished `cancelled` result and use `AI.result` for the retained move; do not depend on internal session fields.
- Finished-search stats carry `completed_depth`, `nodes`, and `elapsed_ms`. Do not infer a stop cause from logs.
- `completed_depth = 0` is valid only when no root layer completed before an
  explicit hard resource stop (`timeout` or configured `leaf_limit`). Such a
  stop retains a legal fallback when one exists and keeps its exact stop
  reason; `leaf_limit` must never be relabeled as `timeout`. A position with no
  legal move instead returns no move with `no_legal_move`.
- Benchmark records/reports are a separate stable schema: records expose move legality/tactical classification, completed depth, nodes, and elapsed logical time; aggregate reports expose rates, node metrics, budget violations, thresholds, and records. They do **not** currently expose `stop_reason`; do not claim or add it without an intentional schema change and tests.
- Keep field names and deterministic ordering stable unless a versioned migration is provided. Logs must be bounded and must not expose secrets.

## Security, dependencies, and provenance

- Add no runtime dependency for engine work without explicit approval; prefer existing platform and standard-library APIs.
- Runtime engine code must not use network access, dynamic execution (`load`, `loadstring`, `eval`, generated code), environment secrets, or undeclared globals.
- Never commit credentials, tokens, private game data, or machine-specific paths.
- Before adding code, data, opening books, fonts, portraits, or other assets, verify redistribution and derivative-work rights.
- Preserve notices in XTApp Studio and provenance in XTApp Studio; unlicensed or unclear-source assets do not ship.

## Pull-request evidence and X4 Pro safety

For behavior or algorithm changes, every engine PR must include:

- Red/Green/Refactor command output and focused/full-suite results.
- Benchmark before/after from the same cases and options; explain regressions.
- Correctness invariants affected, observability/schema changes, and license/asset review.
- X4 Pro risks: CPU slice length, watchdog feeding, memory/TT capacity, allocations, package size, startup latency, and real-device evidence when performance-sensitive.
- A rollback plan that identifies the revertable commit/flag/data artifact and confirms saved games and report consumers remain compatible.

For docs/config-only changes, provide deterministic contract validation instead of behavior TDD. Benchmark before/after is required only when the change affects performance guidance, benchmark gates, budgets, or report semantics.

Do not create or edit a PR template as part of these standards.

## Review severity and merge criteria

- **Must:** legality/state-boundary violation, live-state mutation from search, unbounded work, watchdog risk, TT/repetition unsoundness, nondeterminism, security/provenance breach, missing evidence required for the change class, or a benchmark gate regression. Blocks merge.
- **Should:** maintainability, allocation, observability, test-quality, or benchmark-evidence gap with credible product risk. Resolve before merge unless the PR records an owner-approved follow-up and rationale.
- **Nit:** non-blocking naming, wording, or formatting improvement.

Merge only when all Must findings are resolved, required Should findings are resolved or explicitly accepted, verification appropriate to the change class passes, applicable benchmark gates pass, X4 Pro risk and rollback are documented where relevant, and licenses/assets are accounted for.
