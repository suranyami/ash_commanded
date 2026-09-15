---
phase: 01-build-integrity
plan: 03
subsystem: testing
tags: [ash, spark, commanded, elixir, logger, dead-code-removal]

# Dependency graph
requires:
  - phase: 01-01
    provides: ":commanded hard dependency — the guards this plan deletes were always dead code behind it"
provides:
  - "GenerateProjectorModules and GenerateEventHandlerModules create modules unconditionally (D-06) — no skip_*_module_creation knob, no Code.ensure_loaded?(Commanded) stub branch"
  - "GenerateMainRouterModule creates domain and main routers unconditionally; the accept-everything `dispatch(command), do: {:ok, command}` stub can no longer be generated (D-07)"
  - "GenerateCommandedApplication.transform/1 always attempts application generation; the has_commanded?/0 gate is gone and the surviving body returns the UPDATED dsl_state"
  - "snapshot_adapter.ex no longer references a nonexistent Commanded behaviour (deviation — see below)"
  - "lib/ contains zero IO.puts/IO.inspect calls; snapshot_store.ex logs its rescue via Logger.error, base_middleware.ex's moduledoc example teaches Logger.debug"
affects: ["01-04", "01-06", "01-07"]

actuals:
  tokens: 5115
  tasks: 3
  commits: 4
  plan_head_before: dff5cc25c17b400f3ad04f8fb4e2e0c07de0d9e0

tech-stack:
  added: []
  patterns:
    - "Escaping #{...} inside an @moduledoc heredoc example with \\#{...} — a code-fenced example block living inside a normal \"\"\"...\"\"\" docstring is still subject to the enclosing string's interpolation, so any #{} written for illustration (not for the moduledoc's own use) must be escaped or it evaluates against the surrounding module's (nonexistent) scope at compile time"

key-files:
  modified:
    - "lib/commanded/transformers/generate_projector_modules.ex"
    - "lib/commanded/transformers/generate_event_handler_modules.ex"
    - "lib/commanded/transformers/generate_main_router_module.ex"
    - "lib/commanded/transformers/generate_commanded_application.ex"
    - "lib/commanded/snapshot_adapter.ex"
    - "lib/commanded/snapshot_store.ex"
    - "lib/commanded/middleware/base_middleware.ex"
    - "test/commanded/transformers/projector_generator_test.exs"
    - ".planning/phases/01-build-integrity/deferred-items.md"
    - ".planning/WINDOWS.md"

key-decisions:
  - "snapshot_adapter.ex: removed @behaviour Commanded.Aggregates.Aggregate.Snapshotter entirely (both the conditional wrapper AND the declaration itself) instead of making it unconditional as the plan specified. Verified against deps/commanded (1.4.11) that this module has never existed in Commanded — Commanded's real snapshotting is internal (Commanded.Snapshotting), configured per-aggregate via a plain map, with no pluggable adapter behaviour. Declaring @behaviour on a module that doesn't exist raises a compile warning that fails --warnings-as-errors. The four adapter functions are unchanged; nothing calls them through a behaviour-checked dispatch (confirmed by grep — they're only referenced by module name in a :snapshot_module config key that Commanded's real :snapshotting schema doesn't recognize either, a separate pre-existing gap outside this plan's file list)"
  - "Removed a dead `import unquote(resource_module)` line from GenerateEventHandlerModules's generated AST (not in the plan's action items) — Task 1's unguarding exposed that this import crashes at compile time whenever resource_module is the very module currently compiling (the only test exercising event_handlers in the whole suite never ran with the guard removed until this fix). Nothing in the generated code used an unqualified call from the import; deleting it removes the crash with no loss of function"
  - "Fixed (not deleted) test/commanded/transformers/projector_generator_test.exs's stale `assert String.contains?(ast_string, \"init\")` line — it asserted the presence of the now-deleted stub branch's `def init/1`. Replaced with an assertion on the real, always-generated `use Commanded.Event.Handler` line. The rest of the test (checks for @moduledoc, def handle, perform_action) already asserted real behaviour and was left unchanged"
  - "Left generate_main_router_module.ex's pre-existing `String.to_atom(domain_name)` (line 252) untouched despite the project's Iron Law hook flagging it as an atom-exhaustion risk — the atom derives from a domain module name declared in code at compile time by the developer, not runtime attacker input, and is not a line this plan's action items named or modified. Converting to String.to_existing_atom/1 risks a runtime ArgumentError for any domain whose downcased name atom doesn't already exist elsewhere, which is a real behavior change outside this plan's scope"

patterns-established: []

requirements-completed: [TEST-01, QUAL-02]

coverage:
  - id: D1
    description: "GenerateProjectorModules and GenerateEventHandlerModules call BaseTransformer.create_module/3 unconditionally — no skip_projector_module_creation / skip_event_handler_module_creation knob and no Code.ensure_loaded?(Commanded) stub branch remain in either file"
    requirement: "TEST-01"
    verification:
      - kind: unit
        ref: "test/commanded/transformers/projector_generator_test.exs, projector_modules_integration_test.exs, projector_transformer_integration_test.exs, event_generator_test.exs (7 tests)"
        status: pass
      - kind: other
        ref: "grep -c 'Mix.env()|skip_projector_module_creation|skip_event_handler_module_creation|Code.ensure_loaded?' across both files -> 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "GenerateMainRouterModule creates domain and main routers unconditionally; the stub branch that generated a def dispatch(command), do: {:ok, command} accept-everything router can no longer be produced — every router carries use Commanded.Commands.Router"
    requirement: "TEST-01"
    verification:
      - kind: unit
        ref: "test/commanded/transformers/main_router_generator_test.exs, domain_router_generator_test.exs, router_module_integration_test.exs, router_transformer_integration_test.exs (5 tests)"
        status: pass
      - kind: other
        ref: "grep -c 'def dispatch(command)' generate_main_router_module.ex -> 0; grep -c 'skip_router_module_creation|Mix.env()' -> 0"
        status: pass
    human_judgment: false
  - id: D3
    description: "GenerateCommandedApplication.transform/1's has_commanded?/0 gate is removed; the surviving body always attempts application generation and its success path returns the UPDATED dsl_state (Transformer.persist'd with :commanded_application_module), not the untouched input the deleted false-branch used to return"
    requirement: "TEST-01"
    verification:
      - kind: other
        ref: "grep -c 'has_commanded?' generate_commanded_application.ex -> 0; manual code read confirms do_transform/1's success path is {:ok, updated_dsl}"
        status: pass
    human_judgment: true
    rationale: "The two tests that would directly exercise this file (commanded_application_generator_test.exs, commanded_application_integration_test.exs) are pre-existing failures explicitly out of this plan's scope (owned by Plan 01-06 per the plan's own triage-authority instruction) — no passing automated test currently proves this behaviour end-to-end, only static code inspection"
  - id: D4
    description: "snapshot_adapter.ex no longer references the nonexistent Commanded.Aggregates.Aggregate.Snapshotter behaviour, conditionally or otherwise — a deviation from the plan's literal expectation, made because the module has never existed in real Commanded (verified against deps/commanded 1.4.11)"
    verification:
      - kind: other
        ref: "mix compile --warnings-as-errors exits 0 with no 'behaviour does not exist' warning"
        status: pass
    human_judgment: true
    rationale: "This is a deviation from an explicit must_haves.artifacts line in the plan (which specified the @behaviour declaration must be present and unconditional). A human should confirm the correction (removing rather than unconditionally declaring) is accepted, since it changes what the plan's own success criteria literally asked for"
  - id: D5
    description: "lib/ contains zero IO.puts/IO.inspect calls; snapshot_store.ex's get_snapshot/2 rescue logs via Logger.error/1 with its :error return value unchanged; base_middleware.ex's @moduledoc example teaches Logger.debug/1 instead of IO.inspect"
    requirement: "QUAL-02"
    verification:
      - kind: unit
        ref: "test/commanded/snapshot_test.exs, test/commanded/middleware/command_middleware_test.exs (11 tests)"
        status: pass
      - kind: other
        ref: "grep -rlE 'IO\\.puts|IO\\.inspect' lib/ -> no output"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-09-14
status: complete
---

# Phase 1 Plan 3: Delete the Remaining Guard and Stub Mechanisms Summary

**Deleted the three surviving `skip_*_module_creation` knobs and all six `Code.ensure_loaded?(Commanded)` stub branches across projector, event-handler, router and application generation, and replaced both console-print sites with `Logger` — while discovering the plan's `Commanded.Aggregates.Aggregate.Snapshotter` behaviour has never existed in real Commanded and a dead self-referential `import` that crashed compilation the moment the event-handler guard came off.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-09-14T10:03:00+10:00 (approx.)
- **Completed:** 2026-09-14T10:28:00+10:00
- **Tasks:** 3
- **Files modified:** 7 lib files + 1 test file + deferred-items.md + WINDOWS.md

## Accomplishments

- Deleted `skip_projector_module_creation` and `skip_event_handler_module_creation` `Application.get_env` knobs in `generate_projector_modules.ex` / `generate_event_handler_modules.ex` — `BaseTransformer.create_module/3` now runs unconditionally (D-06)
- Deleted the `Code.ensure_loaded?(Commanded)` stub branches in both files; the surviving branch always carries `use Commanded.Event.Handler` (D-07)
- Deleted `skip_router_module_creation` in `generate_main_router_module.ex` and both its `Code.ensure_loaded?(Commanded)` stub branches (domain router and main router) — the accept-everything `def dispatch(command), do: {:ok, command}` router can no longer be generated
- Deleted `generate_commanded_application.ex`'s `has_commanded?/0` gate; `transform/1`'s surviving body always attempts application generation and its success path returns the **updated** `dsl_state` (confirmed by reading `do_transform/1`, which persists `:commanded_application_module` and returns `{:ok, updated_dsl}`)
- Replaced `snapshot_store.ex`'s `IO.puts` in the `get_snapshot/2` rescue with `Logger.error/1`; the `:error` return value is unchanged; `require Logger` added
- Rewrote `base_middleware.ex`'s `@moduledoc` example to use `Logger.debug/1` instead of `IO.inspect`, matching `logging_middleware.ex`'s established convention
- **Deviation, discovered mid-plan:** `snapshot_adapter.ex`'s `@behaviour Commanded.Aggregates.Aggregate.Snapshotter` — verified against `deps/commanded` (1.4.11) that this module has never existed in Commanded. Making the declaration unconditional (as literally specified) raises a "behaviour does not exist" compile warning and fails `--warnings-as-errors`. Removed the declaration entirely rather than making it unconditional; the four adapter functions are unchanged
- **Deviation, discovered mid-plan:** the generated event-handler AST's `import unquote(resource_module)` crashed at compile time whenever `resource_module` was the module currently being compiled (its own transformer running mid-compilation) — dead-by-construction until Task 1 removed the skip knob. Deleted the unused import
- Logged two further out-of-scope discoveries to `deferred-items.md` and `.planning/WINDOWS.md`: `Ash.run_action/3` (used by the same `execute_action/2`) does not exist in the installed Ash version, and `test/commanded/parameter_transformer_errors_test.exs` fails against a bare-struct `TestResource` because Plan 01-02 removed `CommandActionMapper`'s test-env mock

## Task Commits

1. **Task 1: Unguard projector and event-handler generation** — `e9e129f` (feat)
2. **Task 2: Unguard router generation, application generation and the snapshot behaviour** — `b02661d` (feat), plus a follow-up fix commit `36603b0` (fix) for the dead-import bug Task 1's change exposed
3. **Task 3: Replace both console-print sites with Logger** — `087beb2` (fix)

**Plan metadata:** committed alongside this SUMMARY (see below)

## Files Created/Modified

- `lib/commanded/transformers/generate_projector_modules.ex` — knob and stub branch removed; unused "Common parts regardless of Commanded availability" comment cleaned up
- `lib/commanded/transformers/generate_event_handler_modules.ex` — knob and stub branch removed; dead self-referential `import unquote(resource_module)` removed
- `lib/commanded/transformers/generate_main_router_module.ex` — knob removed; both domain-router and main-router stub branches removed
- `lib/commanded/transformers/generate_commanded_application.ex` — `has_commanded?/0` and its top-level `case` removed; `transform/1` body is now the former true-branch, unconditionally
- `lib/commanded/snapshot_adapter.ex` — `@behaviour Commanded.Aggregates.Aggregate.Snapshotter` removed entirely (see Deviations); moduledoc rewritten to explain why; `@impl true` placeholder comments reworded to match
- `lib/commanded/snapshot_store.ex` — `IO.puts` → `Logger.error/1`; `require Logger` added
- `lib/commanded/middleware/base_middleware.ex` — moduledoc example rewritten to `Logger.debug/1`, with `#{...}` escaped as `\#{...}` inside the enclosing heredoc
- `test/commanded/transformers/projector_generator_test.exs` — stale `"init"` assertion replaced with an assertion on `use Commanded.Event.Handler`
- `.planning/phases/01-build-integrity/deferred-items.md` — two new discoveries logged (see Deviations/Issues)
- `.planning/WINDOWS.md` — two entries appended (deviation: snapshot_adapter.ex behaviour removal; todo: `Ash.run_action/3` in generated event handlers)

## Decisions Made

See `key-decisions` in frontmatter — summarized: (1) removed rather than unconditionally declared the nonexistent Snapshotter behaviour; (2) removed a dead self-referential import discovered as Task 1 fallout; (3) fixed rather than deleted the stale projector AST test; (4) left the pre-existing `String.to_atom` call in `generate_main_router_module.ex` untouched as out of scope.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `snapshot_adapter.ex`'s `@behaviour Commanded.Aggregates.Aggregate.Snapshotter` references a module that has never existed in Commanded**

- **Found during:** Task 2, immediately after removing the `Code.ensure_loaded?` wrapper — `mix compile --warnings-as-errors` failed with "`@behaviour Commanded.Aggregates.Aggregate.Snapshotter` does not exist"
- **Issue:** The plan's must_haves and Task 2's action item both specified making this `@behaviour` declaration unconditional, on the assumption (never verified in RESEARCH.md/CONTEXT.md/PATTERNS.md) that it names a real Commanded module. Confirmed via `grep -rln Snapshotter deps/commanded/lib` and reading `deps/commanded/lib/commanded/snapshotting.ex` and `aggregates/aggregate.ex` that Commanded 1.4.11 has no such behaviour — its real snapshotting integration is internal (`Commanded.Snapshotting` struct, `EventStore.read_snapshot`/`record_snapshot`), configured per-aggregate via a plain map with no pluggable adapter module. The `Code.ensure_loaded?` guard this plan removed was therefore *always* false, in every environment — this `@behaviour` was never actually declared, ever, even in production
- **Fix:** Removed the `@behaviour` declaration entirely (not just the conditional wrapper); rewrote the moduledoc to state plainly that no such Commanded module exists and why the four adapter functions (`snapshot_version/1`, `snapshot_threshold/1`, `take_snapshot/2`, `load_snapshot/2`) don't need `@impl true` — nothing in the codebase dispatches to them via behaviour-checked callback, only by module name (confirmed via `grep -rn SnapshotAdapter lib/`)
- **Files modified:** `lib/commanded/snapshot_adapter.ex`
- **Verification:** `mix compile --force --warnings-as-errors` exits 0
- **Committed in:** `b02661d` (Task 2 commit)
- **Flagged for human review:** this contradicts the plan's literal `must_haves.artifacts` line (`contains: "@behaviour Commanded.Aggregates.Aggregate.Snapshotter"`); see `coverage.D4` above

**2. [Rule 1 - Bug] Generated event handler's `import unquote(resource_module)` crashes at compile time on self-reference**

- **Found during:** Task 2's full-suite verification run (after Task 1 was already committed) — `mix test` produced a compile error in `test/commanded/event_handlers_dsl_test.exs`, the only test in the suite that exercises `event_handlers`
- **Issue:** `import` requires its target module to already be compiled/loaded. The generated handler module's `resource_module` is the resource that declared the `event_handlers`, and that resource's own transformer runs mid-compilation of that very module — so `import unquote(resource_module)` fails with "module ... is not loaded and could not be found" whenever `resource_module` is still compiling. Previously masked entirely because `BaseTransformer.create_module/3` was always skipped under `Mix.env() == :test`, so this code path had never run
- **Fix:** Deleted the `import unquote(resource_module)` line. It was dead weight: every actual reference to the resource in the generated AST is already fully qualified (`Ash.run_action(unquote(resource_module), ...)`), so nothing relied on the import
- **Files modified:** `lib/commanded/transformers/generate_event_handler_modules.ex`
- **Verification:** `mix test test/commanded/event_handlers_dsl_test.exs` — 2 tests, 0 failures (previously a compile error)
- **Committed in:** `36603b0` (separate fix commit, since discovered after Task 2's main commit)

**3. [Rule 1 - Bug] `test/commanded/transformers/projector_generator_test.exs`'s "builds correct module AST" test asserted the now-deleted stub's presence**

- **Found during:** Task 1's own `<verify>` run
- **Issue:** `assert String.contains?(ast_string, "init")` was written to accept either the real `use Commanded.Event.Handler` branch or the stub's `def init(config)` branch. With the stub branch deleted, this line failed even though the rest of the test (checking `@moduledoc`, `def handle`, `perform_action`) still asserted real, correct behaviour
- **Fix:** Replaced the line with `assert String.contains?(ast_string, "Commanded.Event.Handler")` — asserting the real, always-generated behaviour instead of the removed stub's marker
- **Files modified:** `test/commanded/transformers/projector_generator_test.exs`
- **Verification:** `mix test test/commanded/transformers/projector_generator_test.exs` — 7 tests, 0 failures (previously 1 failure)
- **Committed in:** `e9e129f` (Task 1 commit)

---

**Total deviations:** 3 auto-fixed (3 bugs, all Rule 1). One (`snapshot_adapter.ex`) contradicts a literal plan artifact expectation and is flagged for human confirmation via `coverage.D4`'s `human_judgment: true`.
**Impact on plan:** All three were required either to keep `mix compile --warnings-as-errors` passing or to keep the full test suite compiling. None expanded scope beyond files this plan already owned, except the two further latent bugs (below) which were logged, not fixed, per the scope-boundary rule.

## Issues Encountered

Two further latent defects were discovered but NOT fixed — logged to `deferred-items.md` and `.planning/WINDOWS.md` as out of this plan's scope:

- **`Ash.run_action/3`** (used by `generate_event_handler_modules.ex`'s generated `execute_action/2`) does not exist in the installed Ash version (`Ash.run_action/2` takes an `%Ash.ActionInput{}`, not `(resource, action_name, params)`). Exposed by the same Task 1 unguarding, but never actually called at runtime by any current test — `event_handlers_dsl_test.exs` only asserts the DSL parses, never dispatches an event through a generated handler. A correct fix requires branching on the target action's real type (generic/create/update/destroy/read) via `Ash.Resource.Info.action/2`, which is a design question beyond mechanical guard removal.
- **`test/commanded/parameter_transformer_errors_test.exs`** — "handles errors in parameter transformation" fails with `TestResource is not a Spark DSL module`. Root cause: Plan 01-02 deleted `CommandActionMapper.execute_create/4`'s test-env mock (commit `d28e09a`), and this test's inline `TestResource` (a bare `defstruct`) was written assuming the mock. Confirmed pre-existing and unrelated to any file in this plan's list; not caught by Plan 01-02's own verify scope.

Both pre-existing quarantined failures from Plan 01-02 remain, untouched per this plan's explicit instruction not to touch them (owned by Plan 01-06):

- `test/commanded/transformers/commanded_application_generator_test.exs` (4 tests, `:meck` `:already_started`)
- `test/commanded/transformers/commanded_application_integration_test.exs` (compile error)

Full suite excluding the untouched `commanded_application_integration_test.exs` (which halts the runner on a compile error before a summary line): **163 tests, 5 failures** — the 4 quarantined + 1 newly-logged-but-unfixed (`parameter_transformer_errors_test.exs`). No regressions from this plan's changes.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All three remaining module-creation knobs are gone (`generate_projector_modules.ex`, `generate_event_handler_modules.ex`, `generate_main_router_module.ex`) — every guarded transformer this phase set out to fix now reaches `BaseTransformer.create_module/3` unconditionally
- All six `Code.ensure_loaded?(Commanded)` stub branches are gone; the accept-everything router stub cannot be generated
- `lib/` contains zero `IO.puts`/`IO.inspect` calls
- Plan 01-04 (execute_read/execute_custom real execution) inherits two logged items: the `Ash.run_action/3` defect in `generate_event_handler_modules.ex`, and the `parameter_transformer_errors_test.exs` failure from Plan 01-02
- Plan 01-06 still owns `commanded_application_generator_test.exs` / `commanded_application_integration_test.exs` — untouched here as instructed
- Plan 01-07 (Credo/Dialyzer seeding) should note `snapshot_adapter.ex` no longer declares any `@behaviour` — Dialyzer will not check it against a Commanded contract, since no such contract exists; this changes the phase's own anticipated "D-22 adds Dialyzer findings" note for this specific file
- `mix compile --warnings-as-errors` — 0 warnings, 0 errors
- `mix format --check-formatted` passes for all seven files this plan owns

---
*Phase: 01-build-integrity*
*Completed: 2026-09-14*

## Self-Check: PASSED

- FOUND: `lib/commanded/transformers/generate_projector_modules.ex`
- FOUND: `lib/commanded/transformers/generate_event_handler_modules.ex`
- FOUND: `lib/commanded/transformers/generate_main_router_module.ex`
- FOUND: `lib/commanded/transformers/generate_commanded_application.ex`
- FOUND: `lib/commanded/snapshot_adapter.ex`
- FOUND: `lib/commanded/snapshot_store.ex`
- FOUND: `lib/commanded/middleware/base_middleware.ex`
- FOUND: `test/commanded/transformers/projector_generator_test.exs`
- FOUND: `.planning/phases/01-build-integrity/deferred-items.md`
- FOUND: `.planning/WINDOWS.md`
- FOUND: commit `e9e129f` (Task 1)
- FOUND: commit `b02661d` (Task 2)
- FOUND: commit `36603b0` (Task 2 fix)
- FOUND: commit `087beb2` (Task 3)
- PASS: `mix compile --force --warnings-as-errors` exits 0
- PASS: `mix format --check-formatted` on all seven owned lib files
- PASS: no `Mix.env()`, `skip_*_module_creation`, or `Code.ensure_loaded?(Commanded` remains across the seven owned files
- PASS: no `IO.puts`/`IO.inspect` remains under `lib/`
- PASS: full suite (excluding the untouched, pre-existing compile-error file) — 163 tests, 5 failures, all pre-existing/logged, no regressions
