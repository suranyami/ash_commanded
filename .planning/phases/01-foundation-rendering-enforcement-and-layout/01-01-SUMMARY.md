---
phase: 01-foundation-rendering-enforcement-and-layout
plan: 01
subsystem: codegen-tooling
tags: [spark, dsl, codegen, ast, mix-task, golden-tests, ash, commanded]

# Dependency graph
requires: []
provides:
  - "mix ash_commanded.dump <DslModule> [--only <GeneratedModule>], rendering the pre-Module.create/3 AST a transformer wrote"
  - "AST-capture seam on BaseTransformer.create_module/3 (D-06), gated by Application.get_env(:ash_commanded, :capture_ast?, false)"
  - "create_module/4, accepting an explicit [:file, :line] location for future callers (FOUND-18)"
  - "test/ash_commanded/golden_budget_test.exs, a self-consistency gate over every test/golden/**/*.golden file (FOUND-06, D-03)"
  - "The first committed golden: test/golden/parity_widget/AshCommanded.TestSupport.Parity.Commands.CreateWidget.golden"
affects: ["01-02", "01-05", "later phases needing create_module/4 wired into a caller"]

# Actuals (#2632)
actuals:
  tokens: 4981
  tasks: 3
  commits: 6

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pre-Module.create/3 AST capture behind a runtime Application.get_env flag + named public ETS table, scoped to one mix-task invocation"
    - "Golden render files carrying their own ratchet header (# gsd-budget: clause_max=N module_lines=N), self-verified by a plain ExUnit test rather than Credo"
    - "Optional keyword-list location argument (create_module/4) that falls back to Macro.Env.location(env) when empty, preserving all existing callers unchanged"

key-files:
  created:
    - lib/mix/tasks/ash_commanded.dump.ex
    - test/ash_commanded/golden_budget_test.exs
    - test/golden/parity_widget/AshCommanded.TestSupport.Parity.Commands.CreateWidget.golden
  modified:
    - lib/commanded/transformers/base_transformer.ex
    - test/commanded/transformers/base_transformer_test.exs
    - mix.exs

key-decisions:
  - "D-08 (one-way) confirmed at the plan's opening checkpoint: mix ash_commanded.dump ships in the published Hex package as a documented public feature (human replied 'ship', the locked default). Implemented at lib/mix/tasks/ash_commanded.dump.ex, inside mix.exs package/0's files: list, with @moduledoc/@shortdoc written for a library consumer."
  - "The CreateWidget golden's true measured clause_max is 0 (the command struct has @moduledoc/@type/defstruct only, no def/defp at all). The acceptance criterion's literal instruction to demonstrate the ratchet by 'lowering clause_max to 0' is a no-op against this fixture (0<=0 already holds); the gate-bites demonstration was carried out via module_lines instead (a real measured-5-vs-declared-0 failure), and the clause_max<=10 absolute-ceiling check was separately demonstrated by temporarily setting clause_max=11. Both were proven live before being reverted to the correct committed values."
  - "Added :mix to mix.exs's dialyzer plt_add_apps. Without it, Dialyzer had no callback info for Mix.Task/Mix.raise//1/Mix.Task.run//1/Mix.shell//0 and reported the new mix task's use of them as unknown_function — a blocking build-config gap (Rule 3), not something to add to the frozen .dialyzer_ignore.exs seed."
  - "create_module/4 is added as new API surface only; per Task 2's explicit instruction ('this plan does not modify any of them'), none of the nine existing create_module/3 call sites were rewired to pass an explicit location. See Issues Encountered for the resulting gap against this plan's own FOUND-18 must-have truth."

requirements-completed: [FOUND-02, FOUND-18]
# FOUND-01 and FOUND-06 are also declared by 01-02 (both) and 01-05 (FOUND-06) per the phase's
# shared-ID gate (#2388) — they stay Pending until every declaring plan has a SUMMARY.md, even
# though this plan's own truths for them (bare dump invocation; the budget-ceiling gate) are
# fully demonstrated above.

coverage:
  - id: D1
    description: "mix ash_commanded.dump renders a DSL module's generated code as formatted Elixir source, from the pre-Module.create/3 AST (FOUND-01/02/05)"
    requirement: FOUND-02
    verification:
      - kind: integration
        ref: "mix ash_commanded.dump AshCommanded.TestSupport.Parity.Widget --only AshCommanded.TestSupport.Parity.Commands.CreateWidget"
        status: pass
      - kind: integration
        ref: "mix ash_commanded.dump NotARealModule.AtAll (non-zero exit, no UndefinedFunctionError)"
        status: pass
    human_judgment: false
  - id: D2
    description: "The AST-capture seam on create_module/3 records module+AST into :ash_commanded_dump_capture only when :capture_ast? is true, and never crashes an ordinary compile when the table is missing (D-06, T-01-BI-02)"
    verification:
      - kind: unit
        ref: "test/commanded/transformers/base_transformer_test.exs#describe create_module/3 (capture tests)"
        status: pass
    human_judgment: false
  - id: D3
    description: "A committed golden carries its own ratchet header, and mix test fails when the committed body no longer satisfies it (FOUND-06, D-03, D-10)"
    requirement: FOUND-06
    verification:
      - kind: unit
        ref: "test/ash_commanded/golden_budget_test.exs (demonstrated live: wrong module_lines -> fail naming path+numbers; clause_max=11 -> ceiling fail; both reverted to pass)"
        status: pass
    human_judgment: false
  - id: D4
    description: "create_module/4 accepts an explicit [:file, :line] location that a compile error in generated AST reports, instead of the transformer's own file (FOUND-18)"
    requirement: FOUND-18
    verification:
      - kind: unit
        ref: "test/commanded/transformers/base_transformer_test.exs#a compile error in the generated AST names the supplied location"
        status: pass
    human_judgment: true
    rationale: "The mechanism is proven directly (a synthetic caller passing create_module/4 an explicit location), but no real transformer is wired to use it yet — Task 2 explicitly excludes touching the nine existing call sites. Whether this satisfies FOUND-18's spirit for this plan, pending a later plan wiring a real caller, needs a human call (see Issues Encountered)."

# Metrics
duration: 45min
completed: 2026-09-15
status: complete
---

# Phase 1 Plan 1: Foundation Renderer Tracer Summary

**`mix ash_commanded.dump` renders a DSL module's pre-`Module.create/3` AST end-to-end, backed by a capture hook on the shared `create_module/3` seam and a self-verifying golden-budget gate that runs on every `mix test`.**

## Performance

- **Duration:** ~45 min (continuation session)
- **Completed:** 2026-09-15T03:58:07Z
- **Tasks:** 2 tasks + 1 checkpoint decision (already resolved on entry)
- **Files modified:** 6

## Accomplishments

- `mix ash_commanded.dump <DslModule> [--only <GeneratedModule>]` forces an in-process recompile of the target's own source with AST capture enabled, then renders every captured module under the target's own namespace prefix (or exactly `--only`) as formatted Elixir source — proven against `AshCommanded.TestSupport.Parity.Widget`, both bare (renders command, event, projection, projector and aggregate) and narrowed to just `Commands.CreateWidget`.
- `BaseTransformer.create_module/3` now captures the pre-`Module.create/3` AST into a named, public ETS table when `Application.get_env(:ash_commanded, :capture_ast?, false)` is true — default `false`, so a normal `mix compile`/`mix test` pays one map lookup and nothing else (D-06). A missing table cannot crash an ordinary compile (T-01-BI-02).
- The first committed golden (`test/golden/parity_widget/AshCommanded.TestSupport.Parity.Commands.CreateWidget.golden`) carries a `# gsd-budget: clause_max=0 module_lines=5` header, and `test/ash_commanded/golden_budget_test.exs` enforces it on every `mix test` run — demonstrated live to bite (a wrong header fails naming the path and both numbers) before being trusted.
- `create_module/4` accepts an explicit `[:file, :line]` location that replaces `Macro.Env.location(env)`, so a compile error in generated code can name the DSL declaration's own file instead of the transformer's (FOUND-18). All nine existing `create_module/3` callers are unaffected.
- Unresolved CLI module arguments (`mix ash_commanded.dump NotARealModule.AtAll`) exit non-zero via `Mix.raise/1` naming the argument, never raising `UndefinedFunctionError` — `Module.safe_concat/1` prevents unbounded atom creation from CLI input (T-01-DOS).

## Task Commits

Each task followed RED → GREEN (no REFACTOR needed — implementations were minimal on first pass):

1. **Task 1 (TRACER) — capture hook:**
   - `22538a4` test(01-01): add failing test for AST-capture hook on create_module/3
   - `ac8f3e0` feat(01-01): capture pre-Module.create/3 AST behind :capture_ast? flag (D-06)
2. **Task 1 (TRACER) — golden budget gate:**
   - `8ca2f6f` test(01-01): add golden budget gate; deliberately-wrong header proves it bites
   - `4895e05` feat(01-01): mix ash_commanded.dump renders pre-Module.create/3 AST (D-05, D-06)
3. **Task 2 — explicit source location:**
   - `aefbe22` test(01-01): add failing tests for create_module/4 explicit location (FOUND-18)
   - `b0d5e44` feat(01-01): create_module/4 accepts an explicit source location (FOUND-18)

**Plan metadata:** committed alongside this SUMMARY.

_Note: Task 1 was a `type="tracer"` task with four layers (capture hook, mix task, golden, budget gate); the tracer feedback gate (re-running Task 1's automated `<verify>` end-to-end) passed before Task 2 began — logged as "⚡ Tracer verified end-to-end — expanding."_

## Files Created/Modified

- `lib/mix/tasks/ash_commanded.dump.ex` - new mix task, renders captured AST as formatted source
- `lib/commanded/transformers/base_transformer.ex` - capture hook on create_module/3; new create_module/4
- `test/ash_commanded/golden_budget_test.exs` - new: per-golden ratchet/ceiling gate, dynamic one-test-per-file
- `test/golden/parity_widget/AshCommanded.TestSupport.Parity.Commands.CreateWidget.golden` - first committed golden
- `test/commanded/transformers/base_transformer_test.exs` - extended `describe "create_module/3"` (6 new tests)
- `mix.exs` - added `:mix` to dialyzer's `plt_add_apps`

## Decisions Made

- **D-08 confirmed (one-way):** the human replied "ship" at the plan's opening checkpoint, confirming the dump task ships in the published package as documented public surface — the checkpoint required no further action beyond implementing at the already-agreed path (`lib/mix/tasks/ash_commanded.dump.ex`).
- **module_lines used as the concrete "gate bites" demonstration** instead of clause_max, since CreateWidget's true clause_max is 0 (no functions at all) — see Deviations.
- **`:mix` added to Dialyzer's PLT apps** (mix.exs) rather than adding to the frozen `.dialyzer_ignore.exs` seed, since the seed file is explicitly documented as a one-time snapshot nobody should extend without a stated reason, and the real fix (give Dialyzer Mix's callback info) is a one-line, permanent config correction.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Dialyzer had no callback info for `Mix.Task`/`Mix.raise`/`Mix.shell`**

- **Found during:** Task 1 (running `mix check` after adding the mix task)
- **Issue:** `mix dialyzer` reported `unknown_function` for `Mix.raise/1`, `Mix.Task.run/1`, `Mix.shell/0`, and `callback_info_missing` for the `Mix.Task` behaviour — the project's PLT never included the `:mix` application.
- **Fix:** Added `plt_add_apps: [:mix]` to `mix.exs`'s `dialyzer:` config and rebuilt the PLT (`mix dialyzer --plt`).
- **Files modified:** `mix.exs`
- **Verification:** `mix dialyzer` passes cleanly; full `mix check` exits 0.
- **Commit:** `4895e05`

**2. [Rule 1 - Bug] `module_lines` measurement was inflated by a trailing-newline artifact**

- **Found during:** Task 1 (writing `golden_budget_test.exs`, first RED/GREEN cycle)
- **Issue:** `String.split(body, "\n", trim: false) |> length()` counted a trailing empty string from the body's final newline, reporting 6 lines for a 5-line rendered module.
- **Fix:** `String.trim_trailing("\n")` before splitting.
- **Files modified:** `test/ash_commanded/golden_budget_test.exs`
- **Verification:** Re-measured the CreateWidget golden at exactly 5 lines, matching the visually-counted body.
- **Commit:** `8ca2f6f`

---

**Total deviations:** 2 auto-fixed (1 blocking build-config gap, 1 measurement bug). **Impact:** both necessary for correctness of the new gate/tooling; no scope creep.

## Known Stubs

None. Both the mix task and the capture hook are fully wired and exercised end-to-end against the real parity fixture.

## Issues Encountered

**FOUND-18's must-have truth is proven at the mechanism level, not yet end-to-end through a real transformer.** The plan's frontmatter states as a truth: _"A deliberate error inside generated code reports a file and line that name the DSL declaration's own source file rather than the transformer's."_ Task 2 explicitly scopes out wiring any of the nine `create_module/3` call sites to pass the new `create_module/4` location argument ("`create_module/3` must keep working unchanged for all nine existing callers; this plan does not modify any of them"). The mechanism itself is fully proven by a direct unit test (a synthetic caller passing `create_module/4` an explicit location, with a deliberate compile error correctly naming that location) — but because no real transformer calls `create_module/4` yet, an actual error inside real generated code (e.g. from `generate_command_modules.ex`) still reports the transformer's own file today, not the fixture's. This is a genuine gap between the plan's stated must-have truth and its own task-level constraint, not something resolvable without either violating the explicit "do not modify" instruction or leaving the truth unproven end-to-end. Flagging for the phase verifier / a future plan (likely wherever the D-13 namespace rename and per-component rewrite touches `generate_command_modules.ex` first) to wire `Transformer.get_persisted(dsl_state, :file)` through to `create_module/4` for at least one caller.

**Task 2's `<human-check>` verify item** ("introduce a deliberate syntax error into the parity fixture's `commanded do` block... confirm the reported file and line... names the fixture rather than a transformer") **will not pass as literally written today**, for the same reason above — no caller passes the fixture's file yet. Per `workflow.human_verify_mode: end-of-phase`, this is harvested into the phase's UAT rather than executed now; flagging here so the human reviewing UAT.md understands why it will fail and that this is expected given the plan's own scope, not a regression.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The renderer, capture hook, and golden-budget gate are proven on one real generated module — plan 02 (FOUND-03/04/05/06/08) can now build `--beam`, `--write`, and golden-diff behavior on top of a working foundation.
- `create_module/4` is ready for a future plan to wire into real transformers (starting with `generate_command_modules.ex`, which already holds `resource_module` and could pass `Transformer.get_persisted(dsl_state, :file)`).
- FOUND-01 and FOUND-06 stay `Pending` in REQUIREMENTS.md per the shared-ID gate — plans 01-02 and 01-05 also declare them and haven't run yet.
- No blockers for 01-02/01-03 proceeding; the FOUND-18 end-to-end gap above should be revisited when a transformer caller is first touched.

---
_Phase: 01-foundation-rendering-enforcement-and-layout_
_Completed: 2026-09-15_

## Self-Check: PASSED

- All 5 key files confirmed present on disk (`lib/commanded/transformers/base_transformer.ex`, `lib/mix/tasks/ash_commanded.dump.ex`, `test/commanded/transformers/base_transformer_test.exs`, `test/ash_commanded/golden_budget_test.exs`, `test/golden/parity_widget/AshCommanded.TestSupport.Parity.Commands.CreateWidget.golden`)
- All 6 task commits confirmed present in git log (`22538a4`, `ac8f3e0`, `8ca2f6f`, `4895e05`, `aefbe22`, `b0d5e44`)
- Plan-level `<verification>` re-run: `mix check` exits 0; `MIX_ENV=test mix test` reports 183 tests, 0 failures (baseline 176+); `mix ash_commanded.dump AshCommanded.TestSupport.Parity.Widget` prints formatted Elixir source; `./scripts/compile_parity.sh` exits 0
- All task-level `<acceptance_criteria>` re-verified passing (capture_ast? grep, Application.compile_env absence, Module.safe_concat presence, golden header regex, budget test pass count, describe-block uniqueness)
