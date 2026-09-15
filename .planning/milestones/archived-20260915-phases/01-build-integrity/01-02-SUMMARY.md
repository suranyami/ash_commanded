---
phase: 01-build-integrity
plan: 02
subsystem: testing
tags: [ash, spark, commanded, ets, elixir, tdd]

# Dependency graph
requires:
  - phase: 01-01
    provides: ":commanded hard dependency, elixirc_paths(:test) -> lib+test/support, mix setup"
provides:
  - "GenerateAggregateModule creates the aggregate module unconditionally (D-06) — no skip_aggregate_module_creation knob, no Mix.env() branch"
  - "CommandActionMapper's execute_create/4, execute_update/5 and execute_destroy/5 run real Ash actions, not mocks (D-08)"
  - "The :by_id -> :read lookup-action fix RESEARCH.md flagged, applied at both call sites"
  - "test/support/test_domain.ex + test/support/widget.ex — the ETS-backed Domain/Widget fixture every action-execution test in this phase builds on"
  - "test/commanded/aggregate_end_to_end_test.exs — the tracer proof: one command through one generated aggregate into real persisted state"
affects: ["01-03", "01-04", "01-06", "01-07"]

actuals:
  tokens: 5413
  tasks: 2
  commits: 3
  plan_head_before: 5a21c0f52b26194af7b0fa5c874f90214ba65c3c

tech-stack:
  added: []
  patterns:
    - "ETS-backed Ash.Resource test fixture (test/support/widget.ex) with an explicit writable :id attribute — uuid_primary_key/1 hides every option but :name and defaults writable?: false, so a resource whose identity is client-supplied (as every Commanded aggregate's is) must declare the primary key attribute explicitly"
    - "Compile-time resource_module resolution in generated aggregate execute/2 — the command module's own namespace only ever encodes the app_prefix, never the resource name, so it must be resolved once at macro-generation time (closed over the command_module + resource_name already in scope) and inlined as a literal, not reconstructed from Module.split at runtime"

key-files:
  created:
    - "test/support/test_domain.ex"
    - "test/support/widget.ex"
    - "test/commanded/aggregate_end_to_end_test.exs"
  modified:
    - "lib/commanded/transformers/generate_aggregate_module.ex"
    - "lib/commanded/command_action_mapper.ex"
    - "test/commanded/command_action_mapper_test.exs"

key-decisions:
  - "Skipped the optional Ash.Changeset.for_create/4 modernisation RESEARCH.md mentioned — changeset construction stays as Changeset.new/1 + for_action/3, since this pass already touches every line in these functions for correctness fixes and the style change was explicitly optional in the plan"
  - "Used an explicit attribute :id, :uuid block instead of uuid_primary_key :id in the Widget fixture, since uuid_primary_key's schema hides every option but :name and hardcodes writable?: false — incompatible with a command-supplied identity"
  - "Resolved the aggregate's resource_module once per command at macro-generation time (inside generate_execute_functions/5) rather than changing build_aggregate_module_ast/7's public arity, to avoid breaking test/commanded/transformers/aggregate_generator_test.exs, which calls that function positionally and is out of this plan's scope"

patterns-established:
  - "Real-Ash-execution test fixtures live in test/support/ as a domain+resource pair with an ets { private? true } data layer — process-scoped, zero setup/teardown, safe under async: true"

requirements-completed: [TEST-01, TEST-03, TEST-04]

coverage:
  - id: D1
    description: "A create_widget command dispatched through the generated WidgetAggregate.execute/2 creates a real row in the ETS-backed Widget resource, readable back through Ash.get!/2"
    requirement: "TEST-04"
    verification:
      - kind: unit
        ref: "test/commanded/aggregate_end_to_end_test.exs#a create_widget command travels through the generated aggregate into real Ash state"
        status: pass
    human_judgment: false
  - id: D2
    description: "WidgetAggregate is a real compiled module under MIX_ENV=test — Code.ensure_loaded?/1 is true and execute/2 is callable, proving the skip_aggregate_module_creation knob is gone"
    requirement: "TEST-03"
    verification:
      - kind: unit
        ref: "test/commanded/aggregate_end_to_end_test.exs#a create_widget command travels through the generated aggregate into real Ash state"
        status: pass
    human_judgment: false
  - id: D3
    description: "execute_update/5 and execute_destroy/5 resolve the target record through the resource's declared :read action (not the undeclared :by_id), and CommandActionMapper carries no Mix.env() branch in the create/update/destroy paths"
    requirement: "TEST-01"
    verification:
      - kind: unit
        ref: "test/commanded/command_action_mapper_test.exs#map_to_action/4 against a real Ash resource (6 tests: not-found update, not-found destroy, create, update, destroy)"
        status: pass
      - kind: other
        ref: "grep -n 'for_read(:read)' lib/commanded/command_action_mapper.ex -> two matches (lines 487, 528)"
        status: pass
    human_judgment: false
  - id: D4
    description: "The mapper test suite is stable under repeated runs and randomized seeds — the ETS fixture leaves no residue between runs"
    requirement: "TEST-01"
    verification:
      - kind: other
        ref: "mix test test/commanded/command_action_mapper_test.exs run twice consecutively, plus --seed 1 and --seed 99999, all exit 0"
        status: pass
    human_judgment: false

duration: 22min
completed: 2026-09-14
status: complete
---

# Phase 1 Plan 2: End-to-End Tracer Through Real Ash Execution Summary

**Removed the `skip_aggregate_module_creation` knob and the create/update/destroy mocks from `CommandActionMapper`, fixed the `:by_id` lookup-action defect RESEARCH.md predicted, and proved the whole path with an ETS-backed `Widget` fixture and two tests that read real persisted state back through `Ash.get`.**

## Performance

- **Duration:** ~22 min
- **Started:** 2026-09-14T08:16:00+10:00 (approx.)
- **Completed:** 2026-09-14T08:36:37+10:00
- **Tasks:** 2 (1 tracer, 1 TDD)
- **Files modified:** 7 (2 created, 2 lib files modified, 1 test file rewritten, 1 test file created, deferred-items.md)

## Accomplishments

- Deleted the `unless Application.get_env(:ash_commanded, :skip_aggregate_module_creation, Mix.env() == :test)` wrapper in `GenerateAggregateModule` — `BaseTransformer.create_module/3` now runs unconditionally (D-06)
- Deleted the `Mix.env() == :test` mock branches around `execute_create/4`, `execute_update/5` and `execute_destroy/5` in `CommandActionMapper` — all three now run the real `Ash.Changeset`/`Ash.create`/`Ash.update`/`Ash.destroy` path (D-08)
- Fixed the `:by_id` defect RESEARCH.md found: both lookup sites in `execute_update/5` and `execute_destroy/5` now call `Ash.Query.for_read(:read)` — the action name `defaults [:read, ...]` actually creates — instead of an action no resource declares
- Found and fixed three further latent defects the mocks had concealed, all surfaced by the tracer's own real assertions (not hypothesized in advance):
  1. The generated aggregate's `execute/2` tried to recover the resource module by splitting the *command* module's own namespace at runtime — but that namespace only ever encodes the app_prefix, never the resource name, so it always resolved to the wrong module and crashed on the very first real `Ash.Changeset.new/1` call
  2. `Ash.read_one/1` returns `{:ok, nil}` for "no match," never a bare `nil` — the dead `nil ->` case clause never fired, and `{:ok, record}` silently matched `{:ok, nil}`, letting `record = nil` flow into `Ash.Changeset.new(nil)`
  3. Both `execute_update/5` and `execute_destroy/5` forwarded the identity field through to `Ash.Changeset.for_action/3` as an action input, but update/destroy actions do not accept it (it only resolved the query lookup) — every real update/destroy call raised `Ash.Error.Invalid.NoSuchInput`
  4. `Ash.destroy/1` returns bare `:ok` by default, not `{:ok, record}` — `execute_action_internal/11`'s `case` only handled `{:ok, _}`/`{:error, _}`, so a real destroy crashed with `CaseClauseError`
- Built the ETS-backed `test/support` fixture (`AshCommanded.TestSupport.Domain` + `AshCommanded.TestSupport.Widget`) with `create_widget`, `update_widget` and `destroy_widget` commands/events, `private? true` (process-scoped, zero-setup `async: true` isolation)
- Wrote `test/commanded/aggregate_end_to_end_test.exs`: one command travels through the real generated `WidgetAggregate.execute/2`, into a real ETS-backed record, read back via `Ash.get!/2`
- Rewrote `test/commanded/command_action_mapper_test.exs` against the real `Widget` fixture (no more `resource_module = __MODULE__`): not-found case first for both update and destroy, then create/update/destroy each read persisted state back through `Ash.get!`/`Ash.get`
- **TDD sequence, RED then GREEN:** `ebb4a4a` added the rewritten tests against the still-mocked/broken mapper and confirmed 4 intentional failures on real assertions (not crashes — the mocked update/destroy unconditionally returned `{:ok, ...}` even for a non-existent id, so the not-found tests failed on the assertion, and the update/destroy-persists tests failed on the `Ash.get!` read-back). `d28e09a` then made all 11 tests pass by deleting the mocks and applying the fixes above — the `:by_id` defect and the three additional latent bugs were each caught by a test failing for a real reason, not discovered by inspection first.
- `execute_create`, `execute_update` and `execute_destroy` now run real Ash actions and are covered by tests that read persisted state back. `execute_read` and `execute_custom` remain on their `Mix.env() == :test` mock branches by design — Plan 01-04's scope, confirmed untouched (lines 578 and 613 of `command_action_mapper.ex`)

## Task Commits

1. **Task 1: End-to-end "create a widget"** — `5d73bea` (feat)
2. **Task 2: Extend the slice to update and destroy** — RED `ebb4a4a` (test), GREEN `d28e09a` (feat). No REFACTOR commit — no cleanup beyond the correctness fixes was identified, and the plan explicitly allowed skipping the optional `for_create/4` modernisation.

**Plan metadata:** committed alongside this SUMMARY (see below)

## Files Created/Modified

- `test/support/test_domain.ex` — `AshCommanded.TestSupport.Domain`, the Ash.Domain owning the Widget fixture
- `test/support/widget.ex` — `AshCommanded.TestSupport.Widget`, ETS-backed resource carrying the Commanded DSL (create_widget/update_widget/destroy_widget commands, matching events)
- `test/commanded/aggregate_end_to_end_test.exs` — the tracer assertion
- `lib/commanded/transformers/generate_aggregate_module.ex` — skip knob removed; `resource_module` resolved once at macro-generation time and inlined as a literal in generated `execute/2` clauses
- `lib/commanded/command_action_mapper.ex` — `execute_create/4`, `execute_update/5`, `execute_destroy/5` mocks removed; `:by_id` → `:read`; dead `nil ->` clause replaced with `{:ok, nil}`; identity field stripped from update/destroy action params; `Ash.destroy/1`'s bare `:ok` normalized to `{:ok, record}`
- `test/commanded/command_action_mapper_test.exs` — rewritten against the real Widget fixture
- `.planning/phases/01-build-integrity/deferred-items.md` — out-of-scope discoveries logged (see below)

## Decisions Made

- Skipped the optional `Ash.Changeset.for_create/4` modernisation — kept `Changeset.new/1` + `for_action/3` unchanged, since this pass already touches every line here for correctness fixes and the plan explicitly allowed skipping it
- Used an explicit `attribute :id, :uuid do ... end` block instead of `uuid_primary_key :id` in the Widget fixture — `uuid_primary_key`'s schema hides every option but `:name` and hardcodes `writable?: false`, which cannot accept the command-supplied id every Commanded aggregate identity requires
- Resolved `resource_module` once per command inside the private `generate_execute_functions/5` (adding a `resource_name` parameter to that private function) rather than changing the public, directly-tested `build_aggregate_module_ast/7`'s arity — preserves compatibility with `test/commanded/transformers/aggregate_generator_test.exs`, which is out of this plan's scope and calls that function positionally

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Aggregate's generated `execute/2` resolved the wrong resource module**

- **Found during:** Task 1, first tracer test run
- **Issue:** The generated `execute/2` tried to recover `resource_module` at runtime via `command.__struct__ |> Module.split() |> Enum.drop(-2) |> Module.concat()`. The command module's namespace only ever encodes the app_prefix (one level above the resource), never the resource name — so for any resource this always resolved to the wrong module, and the first real `Ash.Changeset.new/1` call crashed with `UndefinedFunctionError`
- **Fix:** Resolve `resource_module` once at macro-generation time (in `generate_execute_functions/5`, now taking `resource_name` as a new parameter) and inline it as a compile-time literal via `unquote(resource_module)` in both generated `execute/2` clauses (matching-event and no-matching-event)
- **Files modified:** `lib/commanded/transformers/generate_aggregate_module.ex`
- **Verification:** `test/commanded/aggregate_end_to_end_test.exs` passes; `test/commanded/transformers/aggregate_generator_test.exs` (out of scope, untouched) still passes — confirmed the arity change to the private helper didn't affect the public, directly-tested function
- **Committed in:** `5d73bea` (Task 1 commit)

**2. [Rule 1 - Bug] Widget fixture's create action rejected the command-supplied id**

- **Found during:** Task 1, second tracer test run
- **Issue:** `uuid_primary_key :id` defaults `writable?: false` and its schema hides every option but `:name`, so `create: [:id, :name]` still raised `Cannot accept [:id] because they are not writable`
- **Fix:** Replaced `uuid_primary_key :id` with an explicit `attribute :id, :uuid do primary_key? true; allow_nil? false; writable? true; public? true; default &Ash.UUID.generate/0 end` block
- **Files modified:** `test/support/widget.ex`
- **Verification:** `mix test test/commanded/aggregate_end_to_end_test.exs` passes
- **Committed in:** `5d73bea` (Task 1 commit)

**3. [Rule 1 - Bug] Dead `nil ->` clause never matched Ash.read_one's actual not-found return shape**

- **Found during:** Task 2, RED phase (test intentionally failed for a different reason than expected)
- **Issue:** `Ash.read_one/1` returns `{:ok, nil}` for "no record found," never a bare `nil`. The `case` in `execute_update/5`/`execute_destroy/5` had a `nil ->` clause that could never fire, because `{:ok, record}` already matches `{:ok, nil}` (binding `record = nil`), which then flowed into `Ash.Changeset.new(nil)`
- **Fix:** Reordered the `case` to match `{:ok, nil}` before `{:ok, record}`, returning the not-found error directly
- **Files modified:** `lib/commanded/command_action_mapper.ex`
- **Verification:** "update against a non-existent id" / "destroy against a non-existent id" tests pass, asserting `{:error, _}` with no `NoSuchAction` in the error
- **Committed in:** `d28e09a` (Task 2 GREEN commit)

**4. [Rule 1 - Bug] Update/destroy forwarded the identity field as an action input**

- **Found during:** Task 2, GREEN phase iteration
- **Issue:** Both real branches passed the full `params` map (including the identity field) to `Ash.Changeset.for_action/3`. Update/destroy actions don't declare the identity field as an accepted input (it only resolved the query lookup above), so every real call raised `Ash.Error.Invalid.NoSuchInput`
- **Fix:** `Map.delete(params, identity_field)` before building the changeset, in both `execute_update/5` and `execute_destroy/5`
- **Files modified:** `lib/commanded/command_action_mapper.ex`
- **Verification:** "update persists the new name" / "destroy removes the record" tests pass
- **Committed in:** `d28e09a` (Task 2 GREEN commit)

**5. [Rule 1 - Bug] `Ash.destroy/1`'s bare `:ok` return crashed `execute_action_internal/11`**

- **Found during:** Task 2, GREEN phase iteration
- **Issue:** `Ash.destroy/1` returns bare `:ok` by default (not `{:ok, record}` unless `return_destroyed?: true` is passed). `execute_action_internal/11`'s `case action_result do {:ok, _} = success -> ...; {:error, error} -> ... end` had no clause for `:ok`, so a real destroy raised `CaseClauseError`
- **Fix:** Normalized `execute_destroy/5`'s own `case Ash.destroy(changeset) do :ok -> {:ok, record}; {:ok, destroyed} -> {:ok, destroyed}; {:error, error} -> {:error, error} end`, reusing the already-resolved `record`
- **Files modified:** `lib/commanded/command_action_mapper.ex`
- **Verification:** "destroy removes the record, so Ash.get afterwards returns a not-found error" test passes
- **Committed in:** `d28e09a` (Task 2 GREEN commit)

---

**Total deviations:** 5 auto-fixed (5 bugs, all Rule 1)
**Impact on plan:** All five were required for the tracer's own stated goal — proving the path genuinely works end-to-end. None expanded scope beyond the two files this plan already owned (`generate_aggregate_module.ex`, `command_action_mapper.ex`) plus the fixture/test files this plan creates.

## Issues Encountered

None beyond the deviations above, which were expected in kind (the plan explicitly anticipated the `:by_id` defect) if not in exact number — the tracer surfaced three additional latent defects beyond the one RESEARCH.md predicted, which is precisely what a tracer plan is for.

Three pre-existing test failures, unrelated to this plan's files, were found while running the full suite and logged to `deferred-items.md` rather than fixed (out of scope — different transformer files, owned by Plan 01-03):

- `test/commanded/transformers/commanded_application_generator_test.exs` (4 tests, `:meck` `:already_started` errors)
- `test/commanded/transformers/projector_generator_test.exs` (1 test, stale AST assertion)
- `test/commanded/transformers/commanded_application_integration_test.exs` (compile error)
- `lib/commanded/transformers/generate_projector_modules.ex` also fails `mix format --check-formatted` (pre-existing, not modified by this plan)

All four were confirmed pre-existing via `git diff --stat` (none of the implicated files appear in this plan's diff) and surfaced now because Plan 01-01 made `:commanded` a hard dependency, flipping `Code.ensure_loaded?(Commanded.Application)` from false to true and making dead-by-construction code paths run for the first time.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `GenerateAggregateModule` has zero `Mix.env()`/skip-knob references; `CommandActionMapper` has exactly two remaining (`execute_read/4` at line 578, `execute_custom/4` at line 613) — both Plan 01-04's scope, confirmed untouched
- The ETS-backed `test/support/widget.ex` fixture is ready for Plan 01-06 (parity fixture work) and Plan 01-04 (read/custom real execution) to build on directly
- `mix test test/commanded/aggregate_end_to_end_test.exs test/commanded/command_action_mapper_test.exs` — 11 tests, 0 failures, stable across two consecutive runs and `--seed 1`/`--seed 99999`
- `mix compile` — 0 warnings
- Ready for Plan 01-03 (the other three guarded transformers) and Plan 01-04 (execute_read/execute_custom), which can now run in parallel per the plan's own wave structure

---
*Phase: 01-build-integrity*
*Completed: 2026-09-14*

## Self-Check: PASSED

- FOUND: `test/support/test_domain.ex`
- FOUND: `test/support/widget.ex`
- FOUND: `test/commanded/aggregate_end_to_end_test.exs`
- FOUND: commit `5d73bea` (Task 1)
- FOUND: commit `ebb4a4a` (Task 2 RED)
- FOUND: commit `d28e09a` (Task 2 GREEN)
