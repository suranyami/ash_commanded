---
phase: 01-build-integrity
plan: 06
subsystem: testing
tags: [spark, dsl, commanded, ash, elixir, test-isolation, compile-time-parity, meck, cover]

# Dependency graph
requires:
  - phase: 01-04
    provides: "CommandActionMapper real-Ash execution and test/support fixtures (Widget, TestDomain) this plan builds on"
  - phase: 01-05
    provides: "170 tests, 4 pre-existing CommandedApplicationGeneratorTest meck failures owned by this plan; established the Spark.Test / real-compilation testing standard"
provides:
  - "test_helper.exs reduced to ExUnit.start() — no exclusions, no fixed seed (D-16)"
  - "AshCommanded.TestSupport.CommandedAppCase — per-test uniquely-named Commanded application + InMemory store, torn down in on_exit (D-15)"
  - "A dev-visible, dependency-free parity fixture (test/support/parity/) and scripts/compile_parity.sh proving generated modules are identical under MIX_ENV=dev and MIX_ENV=test (D-19, SC2)"
  - "Direct-call and per-test-isolated-dispatch tests for the projector, event-handler, and (substitute) router generated module kinds (TEST-03, TEST-06)"
  - "Zero :meck/with_mock usage anywhere in the suite — the last two holdouts (commanded_application_generator_test.exs, aggregate_generator_test.exs) rewritten against real dsl_state / a real hand-defined router, eliminating an intermittent full-suite failure caused by meck's :cover-server bookkeeping"
  - "Three real, previously-undiscovered bugs fixed: two in generate_projection_modules.ex/generate_projector_modules.ex (no projector had ever been called with a real event before this plan), one in generate_commanded_application.ex (child_spec/0 had never been called for real before this plan's meck-removal rewrite)"
affects: ["01-07", "01-08", "phase-2 (FOUND-03/FOUND-04 router-generation and compile-order work)"]

actuals:
  tokens: 25549
  tasks: 3
  commits: 7
  plan_head_before: 9a458fb

tech-stack:
  added: []
  patterns:
    - "Per-test Commanded application isolation via Commanded.Application's own documented `start_link(name: unique_atom)` + `dispatch(cmd, application: name)` — no custom registry needed. The InMemory adapter derives its own event-store process name from the RUNTIME name passed to start_link (Module.concat([application, EventStore])), so uniqueness at start_link automatically isolates the event store too."
    - "`:meck.new/2`'s own defensive bookkeeping is a real, intermittent async-suite hazard, independent of any mock-cleanup bug: it asks Erlang's `:cover` tool to preserve a mocked module's coverage state before replacing it, and `:cover.call/1` STARTS the (off) coverage server on demand if it isn't running. Two concurrent `async: true` tests' `:meck.new/2` calls can race to start that server; the loser gets `{:error, {:already_started, pid}}` against a success-only match inside meck's own `backup_original/4`, crashing that one test. This surfaces ONLY under repeated full-suite runs (not single-file runs, not seed variation — a seed reorders tests, it doesn't change whether two async files' meck calls land in the same VM instant). The only reliable fix is removing `:meck` entirely, not `async: false` or better cleanup."
    - "`:meck.new/2` links the mock to the calling process. Registering `:meck.unload/1` via ExUnit's `on_exit` races that link — on_exit always runs in a separate process, after the test process (and its linked mock) has already exited, so `:meck.unload/1` can raise `{:not_mocked, module}`. Do `:meck.new` + `:meck.unload` in a `try/after` inside the test body itself instead, so unload runs synchronously in the same process before the test returns. (Superseded within this same plan: this pattern was itself later replaced by removing :meck entirely — see the :cover-race pattern above.)"
    - "Same process-link fragility applies to `Commanded.Application.start_link/1`'s returned supervisor pid: `on_exit`'s explicit `stop/1` call can race the automatic linked-process death. Guard with `Process.alive?/1` AND a `try/catch :exit` around the stop call."
    - "Cross-environment (MIX_ENV=dev/test) compile parity is proven with a fixed, explicit expected-module list checked under each environment in turn — never a `_build/dev` vs `_build/test` directory diff, which is swamped by legitimate :test-only fixtures."
    - "`Ash.DataLayer.Ets`'s `private? true` scopes writes to the CALLING PROCESS. A real Commanded dispatch runs the aggregate's `execute/2` inside the aggregate's own registered GenServer process, so an `Ash.get!/2` from the test process afterward cannot see the write. Assert on `dispatch(cmd, returning: :aggregate_state)`'s synchronously-returned aggregate struct instead when proving dispatch worked through a real, private-ETS-backed fixture."
    - "When a generated module's real behavior needs testing but real end-to-end compilation is blocked by a SEPARATE, already-documented defect (here: the router the application module references never gets auto-generated), hand-supply the ONE missing prerequisite (a minimal real module satisfying just the interface the blocked code needs) rather than mocking the transformer under test. This proves the transformer's OWN behavior for real while cleanly isolating it from the other defect — stronger than mocking, and honest about what it does and doesn't prove."

key-files:
  created:
    - "test/support/commanded_app_case.ex"
    - "test/support/parity/parity_domain.ex"
    - "test/support/parity/parity_widget.ex"
    - "scripts/compile_parity.sh"
    - "test/commanded/generated_modules_test.exs"
  modified:
    - "test/test_helper.exs"
    - "test/commanded/transformers/commanded_application_generator_test.exs"
    - "test/commanded/transformers/aggregate_generator_test.exs"
    - "test/support/widget.ex"
    - "lib/commanded/transformers/generate_projection_modules.ex"
    - "lib/commanded/transformers/generate_projector_modules.ex"
    - "lib/commanded/transformers/generate_commanded_application.ex"
    - ".planning/phases/01-build-integrity/deferred-items.md"

key-decisions:
  - "The plan's Task 1 assumed `commanded_application_generator_test.exs` had the same dead-by-construction `Code.ensure_loaded?`/`@tag :skip_if_no_commanded` shape as the (quarantined) integration test — it does not. It mocks Spark DSL accessors directly via a fake `%TestDsl{}` struct with hand-rolled `get_entities/2`/`get_persisted/2`. Root-caused the real failure instead: Spark 2.7.2's `Spark.Dsl.Extension.get_entities/2` does not dispatch to a struct's own functions the way that fixture assumed, raising `ArgumentError` before the first test's `:meck.unload` ran and leaving `BaseTransformer` mocked for the next test (the actual source of the `:already_started` cascade). Replaced the fake struct with a real plain-map dsl_state — the shape Spark's own `Transformer`/`Extension` modules operate on — rather than mocking Spark further."
  - "Left `test/commanded/transformers/commanded_application_integration_test.exs.phase2-blocked` quarantined and untouched, on explicit standing instruction (orchestrator context, corroborating the file's own header and `deferred-items.md`'s existing FOUND-03/FOUND-04 entry): restoring it aborts `mix test` at compile time. This means the `grep -rn 'skip_if_no_commanded' test/'` acceptance criterion (written assuming this file would be rewritten) cannot read zero across ALL of `test/` — it reads zero across every file ExUnit can actually collect (`*_test.exs`); the one remaining match is in the `.phase2-blocked` file, deliberately excluded from that glob by its own extension."
  - "Discovered by live probe (not assumed) that `GenerateMainRouterModule`/`GenerateDomainRouterModule` never actually produce a router module for ANY domain under the current Domain/Resource DSL split — both only run while a resource compiles and check whether that resource IS a domain, which is never true; `DomainDsl` doesn't list either transformer itself. This predates and partly explains FOUND-03/FOUND-04's compile-order crash (no router ever existed to crash against, in any configuration, until this phase's D-01 made `:commanded` a hard dependency). Corroborated a SECOND time (moving an equivalent fixture to `test/support`, per a coordinator suggestion, produces the identical crash under `MIX_ENV=test` — file placement does not change the outcome). Documented at length in `deferred-items.md`; NOT fixed here (structural transformer-wiring change, Phase 2 territory)."
  - "Task 3's router-dispatch tests use `AshCommanded.TestSupport.WidgetRouter` — a hand-written `Commanded.Commands.Router` wired to the DSL's real generated `Commands.CreateWidget`/`WidgetAggregate` modules — instead of 'the generated router' the plan's acceptance criteria describe, because no such module exists to dispatch through (see above). This proves the same underlying TEST-06 claim (real per-test Commanded-application isolation, real dispatch through Commanded) using real generated command/aggregate modules; it does not prove the DSL's own router-generation transformers work, because they currently produce nothing."
  - "Widget's projection uses `:widget_updated`/`action :update` rather than `:widget_created`/`:create`: a `:create`-action projection would be a second, redundant creation path alongside the command-driven one `aggregate_end_to_end_test.exs` already exercises, and `:update` requires an existing record, more thoroughly exercising the projector's `Ash.get` + apply + perform_action chain."
  - "The event handler uses a quoted lambda `action`, not an atom Ash-action reference, to avoid a pre-existing, out-of-scope defect (`generate_event_handler_modules.ex`'s `execute_action/2` calls `Ash.run_action/3`, which doesn't exist — flagged in `deferred-items.md` from Plan 01-03, still unfixed, still out of this plan's scope)."
  - "CORRECTION, post-SUMMARY (coordinator-directed): the initial version of this SUMMARY claimed full-suite stability based on 2 consecutive runs and 6 seeds. That verification was insufficient — it caught order-dependence (what varying seeds actually tests) but not an async cross-file race in `:meck`'s own `:cover`-server bookkeeping, which needs REPEATED full-suite runs (not reordered ones) to surface, because the race condition is about wall-clock timing between two files' `:meck.new/2` calls, not test order. The coordinator measured 2 failures in 5 full-suite runs; reproduced independently (1 failure in the first 10 runs after partial fix, then 0/55 after removing meck from all files). Fixed by removing `:meck` from BOTH remaining files in this plan (`commanded_application_generator_test.exs` AND `aggregate_generator_test.exs` — a `with_mock`-only grep, which is what indicated 'the last meck holdout', missed the latter's raw `:meck` calls). Re-verified via 35 consecutive full-suite runs, 0 failures."
  - "For `commanded_application_generator_test.exs`'s rewrite specifically: tried compiling a real domain with a real `application` section (the most literal 'stop mocking, compile for real' approach) and confirmed it hits the identical FOUND-03/FOUND-04 router-compile-order crash, regardless of whether the fixture lives inline or under `test/support`. Landed instead on hand-defining a real, empty `Commanded.Commands.Router` at the exact module name `GenerateCommandedApplication`'s `router(...)` call expects, then calling `transform/1` for real with no mocks at all — this supplies the ONE missing prerequisite the (separately broken) router-generation transformer would have supplied, isolating `GenerateCommandedApplication`'s own behavior from that other defect. Every assertion is now against real compiled-module behavior (`app_module.config()`, `function_exported?/3`, `__registered_commands__/0`), not string-matched generated AST."

patterns-established:
  - "`:meck` must not be used at all in an `async: true` test suite of this size — its own `:cover`-server-startup bookkeeping is a real, intermittent, VM-wide race between any two concurrently-running files that call `:meck.new/2`, independent of how carefully each individual file manages its own mock lifecycle. `try/after`-based cleanup (this plan's own earlier pattern, superseded within the same plan) reduces but does not eliminate the risk; only removing `:meck` does."
  - "Any future Commanded dispatch test targeting a `private? true` ETS-backed Ash resource must assert on `dispatch(..., returning: :aggregate_state | :execution_result)`'s synchronously-returned value, not a subsequent `Ash.get!/2` — the write happens in the aggregate's own process, invisible to a private ETS table looked up from any other process."
  - "When a transformer's generated code references a module produced by a DIFFERENT (and currently broken) transformer, test the first transformer by hand-supplying a real, minimal stand-in for that dependency, rather than mocking the transformer under test. This is real compilation, not a mock, and it correctly isolates 'does transformer X work' from 'does transformer Y (which X depends on) work' when the two are genuinely separate defects."

requirements-completed: [TEST-03, TEST-06]

coverage:
  - id: D1
    description: "test_helper.exs reduced to a bare ExUnit.start() — no tag exclusions, no fixed seed"
    requirement: "TEST-06"
    verification:
      - kind: unit
        ref: "test/test_helper.exs (1 line); mix test full-suite header shows no 'Excluding tags' line and no seed override"
        status: pass
    human_judgment: false
  - id: D2
    description: "Each dispatching test starts its own uniquely-named Commanded application with its own InMemory store, torn down in on_exit; two tests reusing the same aggregate identity do not collide"
    requirement: "TEST-06"
    verification:
      - kind: unit
        ref: "test/commanded/generated_modules_test.exs#dispatching a command against a per-test application produces a real aggregate; #a second test reusing the same identity, under its own per-test application, does not collide"
        status: pass
    human_judgment: false
  - id: D3
    description: "mix test and mix test <file> agree on outcome; the full suite passes reliably across repeated runs (SC5) — not just across reordered (seeded) runs"
    requirement: "TEST-06"
    verification:
      - kind: unit
        ref: "mix test run 35 times consecutively (post meck-removal) -> 176 tests, 0 failures every time; both rewritten single files (commanded_application_generator_test.exs, aggregate_generator_test.exs) individually agree with the full-suite outcome across seeds 0/1/2/3/987654"
        status: pass
    human_judgment: false
  - id: D4
    description: "Cross-environment (MIX_ENV=dev / MIX_ENV=test) generated-module parity is provable via a dependency-free fixture and a fixed expected-module-list check"
    requirement: "TEST-03"
    verification:
      - kind: other
        ref: "./scripts/compile_parity.sh -> PASSED, all 6 expected modules loaded under both MIX_ENV=dev and MIX_ENV=test"
        status: pass
    human_judgment: false
  - id: D5
    description: "Generated projector and event-handler modules are called directly, as real compiled modules, with behavioural assertions (not load-only checks)"
    requirement: "TEST-03"
    verification:
      - kind: unit
        ref: "test/commanded/generated_modules_test.exs#handle/2 writes a real Ash record...; #handle/2 runs its declared side effect..."
        status: pass
    human_judgment: false
  - id: D6
    description: "The generated router kind is exercised with a behavioural, dispatch-level test — substituted with a hand-written router against the DSL's real generated command/aggregate modules, since the DSL's own router-generation transformers currently produce no router module under the Domain/Resource split (documented finding, not fixed in this plan)"
    requirement: "TEST-03"
    verification:
      - kind: unit
        ref: "test/commanded/generated_modules_test.exs#the router implements the Commanded router behaviour and is not a pass-through stub"
        status: pass
    human_judgment: true
    rationale: "This test proves a hand-written substitute router works, not that AshCommanded.Commanded.Dsl's own GenerateMainRouterModule/GenerateDomainRouterModule produce a working router — they currently produce none, for any domain, under the present architecture (see deferred-items.md, 'From Plan 01-06'). A human/Phase-2 reviewer should confirm this substitution is an acceptable interim proof of TEST-06/TEST-03 rather than a completed TEST-03 router deliverable."
  - id: D7
    description: "GenerateCommandedApplication.transform/1's own behavior (module naming, prefix handling, config assembly, supervisor inclusion) is proven against a real compiled application module, with zero mocking"
    requirement: "TEST-03"
    verification:
      - kind: unit
        ref: "test/commanded/transformers/commanded_application_generator_test.exs (7 tests, real app_module.config()/function_exported?/3/__registered_commands__/0 assertions, no :meck)"
        status: pass
    human_judgment: false

duration: ~3h20min (active, including three live probes: the meck/on_exit process-link race, the router-generation architecture including a second corroborating test/support probe, and reproducing the intermittent :cover-server race across 35+ full-suite runs)
completed: 2026-09-14
status: complete
---

# Phase 1 Plan 6: Test Isolation, Cross-Environment Parity, and Direct Generated-Module Calls Summary

**Reduced `test_helper.exs` to a bare `ExUnit.start()`, built a per-test Commanded-application isolation helper, proved generated-module parity between `MIX_ENV=dev` and `MIX_ENV=test` with a dependency-free fixture, made the projector/event-handler/router module kinds actually callable for the first time in this suite's history (finding and fixing three real bugs along the way), and — after the coordinator caught an intermittent full-suite failure my own initial verification missed — removed the suite's last two `:meck` users entirely, eliminating a `:cover`-server startup race that only surfaces under repeated full-suite runs, never under single-file runs or seed variation.**

## Performance

- **Duration:** ~3h20min active (three substantial investigation phases: reproducing and root-causing the `:meck`/`on_exit` process-link race; probing why the DSL's own router-generation transformers never fire, including a second corroborating probe with the fixture moved to `test/support`; and reproducing + eliminating the intermittent `:cover`-server race across 35+ full-suite runs)
- **Completed:** 2026-09-14
- **Tasks:** 3 planned (all `type="auto"`, Task 3 `tdd="true"`) + 1 coordinator-directed follow-up task (removing the last `:meck` usage in the suite to satisfy SC5)
- **Files modified:** 14 (5 created, 9 modified)

## Accomplishments

- **Task 1 — reduced `test_helper.exs` to `ExUnit.start()`** (D-16), removing the Commanded-availability probe, the `:skip_if_no_commanded`/`:skip` exclusion list, and the fixed `seed: 0`. Confirmed via `mix test` header output: no "Excluding tags" line, no seed override — order-dependence can now surface as a failure instead of hiding behind a stable seed forever.
- **Root-caused and fixed all four pre-existing `CommandedApplicationGeneratorTest` failures** — not by patching around them, but by finding the actual bug: the test's `%TestDsl{}` fixture hand-rolled `get_entities/2`/`get_persisted/2` clauses assuming Spark would dispatch to them, but Spark 2.7.2's real `Spark.Dsl.Extension.get_entities/2` does something different for a `%struct{}` value (calls `struct.entities(path)`, a real Spark.Dsl callback `TestDsl` never defined), raising `ArgumentError` before the first test's `:meck.unload` ran. That left `BaseTransformer` mocked for the next test, producing the `:already_started` cascade Plan 01-05 flagged as "yours to fix." Initially rewrote the fixture as a real plain-map dsl_state with `try/after` meck cleanup — later superseded in the same plan (see below) by removing meck from this file entirely.
- **Built `test/support/commanded_app_case.ex`** (D-15): `AshCommanded.TestSupport.CommandedAppCase`, an `ExUnit.CaseTemplate` that starts a `Commanded.Application` under a name unique to the invoking test (`System.unique_integer([:positive])`, never the file/module) with its own `InMemory` event store, torn down in `on_exit` (guarded against a process-link race, via `Process.alive?/1` + `try/catch :exit`).
- **Task 2 — built the D-19/SC2 cross-environment parity fixture**: `test/support/parity/parity_domain.ex` + `parity_widget.ex`, a domain-neutral, dependency-free `Ash.Domain`/`Ash.Resource` pair (no data layer — defaults to `Ash.DataLayer.Simple`) carrying one command, one event, and one projection, safe under `mix.exs`'s `elixirc_paths(:dev)`. `scripts/compile_parity.sh` compiles under `MIX_ENV=dev` and `MIX_ENV=test` in turn and asserts a fixed list of 6 expected generated modules loads under each — not a `_build` directory diff. Before this fixture, `_build/dev` contained zero generated modules; this made SC2 checkable for the first time.
- **Task 3 — called the generated projector, event handler, and (substitute) router modules directly**, the two generated-module kinds `aggregate_end_to_end_test.exs` (Plan 01-02) doesn't cover, plus the router: added a minimal `:widget_updated` projection and `:widget_notifier` event handler to `test/support/widget.ex`, then wrote `test/commanded/generated_modules_test.exs` with a direct-call describe block (no Commanded process) and a `CommandedAppCase`-based dispatch block.
- **Found and fixed two real, previously-undiscovered bugs while writing Task 3** — nothing in this suite had ever called a real generated projector's `handle/2` with a real event before this task:
  1. `generate_projection_modules.ex`'s `generate_changes_ast/1` had a dead clause matching literal `{:fn, _, _}` AST (a comment claimed "Spark will store this as a quoted function expression"), but Spark actually evaluates a `changes(fn event -> ... end)` DSL entry into a real compiled function at DSL-processing time. The live fallback clause (`is_function(other)`) just re-embedded that function via `Macro.escape/1` without ever calling it, so `apply/2` handed a raw function to `Ash.Changeset.for_action/3`, which requires a map, crashing with `Protocol.UndefinedError`. Fixed: call the function with `event` (arity 1) or no args (arity 0).
  2. `generate_projector_modules.ex`'s generated `with {:ok, changeset} <- ... .apply(...)` clause expected a two-tuple, but `apply/2` (per its own moduledoc) always returns a bare `%Ash.Changeset{}`. Every projector's `handle/2` crashed with `WithClauseError` the instant a real event flowed through. Fixed: match the bare changeset the way it's actually returned.
- **Found — but did not fix, per this plan's scope and the standing Phase-2 quarantine — that `GenerateMainRouterModule`/`GenerateDomainRouterModule` never produce a router module for any domain under the current Domain/Resource DSL split.** Confirmed by live probe (a real `Ash.Domain` with `DomainDsl` + a resource with commands compiles command/event/aggregate modules correctly, but `Code.ensure_loaded?/1` is `false` for both candidate router names), and CORROBORATED A SECOND TIME later in this plan (see below). Documented in `deferred-items.md` alongside the existing FOUND-03/FOUND-04 entry it partly explains. Task 3's router-dispatch tests instead use `AshCommanded.TestSupport.WidgetRouter`, a hand-written `Commanded.Commands.Router` wired to the real generated `Commands.CreateWidget`/`WidgetAggregate` modules.
- **Found — and worked around, not fixed — that `Widget`'s `ets do private? true end` makes an Ash write invisible to a subsequent `Ash.get!/2` from a different process**, which is exactly what happens when dispatching through a real `Commanded.Application` (aggregate execution runs in the aggregate's own registered process). Confirmed by probe. Router-dispatch tests assert on `dispatch(..., returning: :aggregate_state)`'s synchronously-returned aggregate struct instead.
- **Initially reported the plan complete with 175 tests, 0 failures, verified across 2 consecutive full-suite runs and 6 seeds.** This verification was insufficient — the coordinator ran the full suite 5 times and measured 2 failures, always the same test (`commanded_application_generator_test.exs`'s "uses prefix for module name" test), with `** (MatchError) no match ... {:error, {:already_started, pid}}` from `:cover.call/1` inside meck's `backup_original/4`. **Root cause: `:meck.new/2` asks Erlang's `:cover` tool to preserve a mocked module's coverage state before replacing it, and `:cover.call/1` starts the (off) coverage server on demand if it isn't already running.** Since the file is `async: true`, two concurrent `:meck.new/2` calls (this file racing itself across its own tests, or racing another async file's `:meck.new/2`) could both try to start `:cover` at the same instant; the loser got an error the calling code only matches on success. **This needs repeated full-suite runs to surface, not seed variation** — a seed only reorders which tests run when, it doesn't change whether two async files' `:meck.new/2` calls land in the same VM instant.
- **Fixed by removing `:meck` from the suite entirely** (a coordinator-approved follow-up task, since the standard `try/after` cleanup pattern reduces but cannot eliminate this specific race — it's not a cleanup-ordering bug, it's `:meck.new/2` itself racing another `:meck.new/2`):
  - **`commanded_application_generator_test.exs`** rewritten again: tried compiling a REAL domain with a real `application` section against a fixture moved to `test/support` (testing the coordinator's hypothesis that dependency-ordered compilation might resolve the router the domain needs) — confirmed this does NOT work; it hits the identical FOUND-03/FOUND-04 crash under `MIX_ENV=test` regardless of file placement, corroborating (not merely repeating) the earlier finding. Landed instead on hand-defining a real, empty `Commanded.Commands.Router` at exactly the module name `GenerateCommandedApplication`'s generated code expects, then calling `transform/1` for real with zero mocking — every assertion is now against the real compiled module's actual behavior (`app_module.config()`, `function_exported?/3`, `__registered_commands__/0`).
  - Calling the real `child_spec/0` for the first time (never previously exercised — the old test only string-matched generated AST) surfaced a THIRD real bug: `generate_commanded_application.ex`'s `include_supervisor?: true` branch called `Supervisor.child_spec({Supervisor, opts}, ...)`, which requires its first argument to itself implement `child_spec/1` — bare `Supervisor` doesn't, so this raised `ArgumentError` the instant it was actually called. Fixed to build the child-spec map directly.
  - **`aggregate_generator_test.exs`**, a file the "last meck holdout" claim (based on a `with_mock`-only grep) missed, ALSO used raw `:meck` (two tests, mocking `AshCommanded.Commanded.Dsl.application/1`) with the identical `async: true` + `:cover`-race exposure. Rewrote both to use a real plain-map dsl_state instead (same pattern as the other file), adding an explicit `otp_app` key the mock never needed (`Dsl.application/1` uses `:otp_app` as its own "is this configured" sentinel).
  - `grep -rn ':meck\.\|with_mock' test/` now returns no matches anywhere in the suite.
- Full suite: 176 tests (was 170 at plan start), 0 failures, verified across **35 consecutive full-suite runs** (not seed variations) after the meck-removal fix — the correct stress test for this class of race, per the coordinator's explicit correction.

## Task Commits

1. **Task 1: Strip the test helper to ExUnit.start() and give dispatch tests their own Commanded application** — `0169ce9` (test)
2. **(interstitial) Record router-generation and private-ETS cross-process findings** — `53768b8` (docs)
3. **Task 2: Cross-environment parity — one dependency-free fixture, one fixed expected-module list** — `13e99c4` (test)
4. **Task 3: Call the generated projector, event-handler and router modules directly** — `88b4e7a` (test)
5. **(plan metadata, initially committed as complete)** — `975fc8e` (docs) — see correction below
6. **Coordinator-directed follow-up: remove the last `:meck` usage in the suite (SC5 fix)** — `73ef80a` (fix)
7. **(docs) Corroborate router-generation finding, record meck-removal and child_spec fix** — `1c8634e` (docs)

**Plan metadata (this correction):** committed alongside this SUMMARY update (see below)

## Files Created/Modified

- `test/test_helper.exs` — reduced from a 17-line availability-probe/exclusion/fixed-seed script to a single `ExUnit.start()` call
- `test/commanded/transformers/commanded_application_generator_test.exs` — rewritten TWICE: first to a real plain-map dsl_state fixture with `try/after` meck cleanup (Task 1), then again to remove `:meck` entirely — a hand-defined real router + zero mocking, asserting on real compiled-module behavior (coordinator-directed follow-up)
- `test/commanded/transformers/aggregate_generator_test.exs` — its two `:meck`-using tests rewritten to a real plain-map dsl_state (coordinator-directed follow-up; this file was not touched by the original three tasks)
- `test/support/commanded_app_case.ex` (new) — `AshCommanded.TestSupport.CommandedAppCase`, `AshCommanded.TestSupport.WidgetRouter`, `AshCommanded.TestSupport.CommandedApplication`
- `test/support/parity/parity_domain.ex`, `test/support/parity/parity_widget.ex` (new) — dependency-free `Ash.Domain`/`Ash.Resource` pair for cross-environment parity
- `scripts/compile_parity.sh` (new) — cross-environment (`MIX_ENV=dev`/`test`) generated-module parity check
- `test/support/widget.ex` — added a minimal `:widget_updated` projection and `:widget_notifier` event handler
- `test/commanded/generated_modules_test.exs` (new) — direct-call and per-test-isolated-dispatch tests for projector, event handler, and (substitute) router
- `lib/commanded/transformers/generate_projection_modules.ex` — fixed `generate_changes_ast/1`'s function-value clause to actually call the function
- `lib/commanded/transformers/generate_projector_modules.ex` — fixed the generated `with` clause's changeset match shape
- `lib/commanded/transformers/generate_commanded_application.ex` — fixed the generated `include_supervisor?: true` `child_spec/0`'s `Supervisor.child_spec/2` misuse (coordinator-directed follow-up)
- `.planning/phases/01-build-integrity/deferred-items.md` — documented the router-generation and private-ETS cross-process findings, corroborated the router finding a second time, and recorded the meck-removal/child_spec fixes

## Decisions Made

See `key-decisions` in frontmatter. Summarized: (1) the plan's assumption that `commanded_application_generator_test.exs` shared the quarantined integration test's dead-by-construction shape was wrong — root-caused and fixed the REAL bug instead; (2) the quarantined integration test stays quarantined, per standing instruction; (3) discovered AND corroborated (test/support placement doesn't change the outcome) that the DSL's router-generation transformers never produce a router under the current architecture — Task 3's router tests use a hand-written substitute; (4) `private? true` ETS makes cross-process record visibility impossible after a real Commanded dispatch — worked around, not fixed; (5) the widget projection targets `:widget_updated`/`:update`, not `:widget_created`/`:create`; (6) the event handler uses a quoted lambda action to sidestep a separate, already-known `Ash.run_action/3` defect; (7) **corrected the plan's initial stability claim and removed `:meck` from the suite entirely**, after the coordinator's measurement showed my 2-run/6-seed verification missed a real, intermittent `:cover`-server race that only repeated full-suite runs can surface; (8) landed on hand-supplying a real router (not mocking `create_module/3`, not pure-function testing) as the strongest honest alternative once real domain compilation was confirmed (twice) to hit the separately-documented router-generation defect.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `commanded_application_generator_test.exs`'s dsl fixture was fundamentally incompatible with the installed Spark version, not merely mocked incorrectly**

- **Found during:** Task 1, first attempt to run the pre-existing failing tests
- **Issue:** The plan assumed this file shared the integration test's dead-by-construction shape. It does not — it mocked Spark DSL accessors via a fake `%TestDsl{}` struct whose hand-rolled `get_entities/2` doesn't match how Spark 2.7.2's real `Spark.Dsl.Extension.get_entities/2` dispatches for a `%struct{}` value, so the very first test raised `ArgumentError` before `:meck.unload` ran, leaving `BaseTransformer` mocked and causing every subsequent test's `:meck.new` to fail with `{:already_started, pid}`.
- **Fix (Task 1):** Replaced the fake struct with a genuine plain-map dsl_state. **Fix (later, superseded further):** the whole file was subsequently rewritten again to remove `:meck` entirely — see deviation #8.
- **Files modified:** `test/commanded/transformers/commanded_application_generator_test.exs`
- **Committed in:** `0169ce9`, later superseded by `73ef80a`

**2. [Rule 1 - Bug] `:meck.unload` via `on_exit` races the mock's own process link**

- **Found during:** Task 1, immediately after fixing deviation #1
- **Issue:** `:meck.new/2` links the mock's GenServer to the calling process; `on_exit` runs in a separate process afterward, so `:meck.unload/1` there can raise `{:not_mocked, module}`.
- **Fix:** Moved `:meck.new`/`:meck.expect`/`:meck.unload` into each test body, wrapped in `try/after`. **This fix was itself later superseded** — see deviation #8: `try/after` avoids the on_exit race but not the separate `:cover`-server race, which required removing `:meck` entirely.
- **Files modified:** `test/commanded/transformers/commanded_application_generator_test.exs`
- **Committed in:** `0169ce9`, later superseded by `73ef80a`

**3. [Rule 1 - Bug, found in generated code] Two incorrect string assertions in the same test file**

- **Found during:** Task 1, after fixing deviations #1 and #2
- **Issue:** `assert code_string =~ "defmodule TestDomain.Application do"` checked for text that can never appear in a module *body* AST (the `defmodule` wrapping happens inside `Module.create/3`).
- **Fix:** Removed the incorrect substring checks; kept assertions on the actual module-identity argument and real generated-code substrings.
- **Files modified:** `test/commanded/transformers/commanded_application_generator_test.exs`
- **Committed in:** `0169ce9`

**4. [Rule 1 - Bug in generated code] `generate_changes_ast/1`'s function-value clause never invoked the function**

- **Found during:** Task 3, first run of the new projector direct-call test
- **Issue:** A `changes(fn event -> %{...} end)` DSL entry is evaluated by Spark into a real compiled function at DSL-processing time (not the literal `{:fn, _, _}` AST a stale comment assumed). The live fallback clause re-embedded that function via `Macro.escape/1` without calling it, so `apply/2` handed a raw function to `Ash.Changeset.for_action/3`, crashing with `Protocol.UndefinedError`.
- **Fix:** Call the function with `event` (arity 1) or no args (arity 0).
- **Files modified:** `lib/commanded/transformers/generate_projection_modules.ex`
- **Verification:** `test/commanded/generated_modules_test.exs`'s projector test, plus full suite
- **Committed in:** `88b4e7a`

**5. [Rule 1 - Bug in generated code] Generated projector `with` clause expected `apply/2` to return `{:ok, changeset}`; it returns a bare changeset**

- **Found during:** Task 3, same test run, immediately after fixing deviation #4
- **Issue:** `apply/2` (per its own moduledoc) always returns a bare `%Ash.Changeset{}`, but the projector's generated `with {:ok, changeset} <- ...` expected a two-tuple. Every projector's `handle/2` crashed with `WithClauseError` the instant a real event reached it.
- **Fix:** Bind the changeset as a bare value in both `with` clauses (create and update/destroy branches).
- **Files modified:** `lib/commanded/transformers/generate_projector_modules.ex`
- **Committed in:** `88b4e7a`

**6. [Rule 1 - Bug, correcting this SUMMARY's own initial claim] Full-suite stability was NOT actually verified by 2 runs / 6 seeds**

- **Found during:** Coordinator review, after this plan was initially reported complete
- **Issue:** The initial SUMMARY claimed "stable across two consecutive runs and six seeds." The coordinator measured 2 failures in 5 full-suite runs — an intermittent race that seed variation cannot surface (seeds reorder tests; they don't change whether two async files' `:meck.new/2` calls land in the same VM instant).
- **Fix:** Corrected the claim in this SUMMARY; see deviation #7/#8 for the underlying bug and fix; re-verified via 35 consecutive full-suite runs.
- **Committed in:** this correction (docs)

**7. [Rule 1 - Bug] `:meck.new/2`'s own `:cover`-server bookkeeping races across concurrent async files**

- **Found during:** Coordinator's 5x full-suite run, reproduced independently
- **Issue:** `:meck.new/2` asks Erlang's `:cover` tool to back up a mocked module's coverage state; `:cover.call/1` starts the (off) cover server on demand. Two concurrent `async: true` files' `:meck.new/2` calls could both try to start it; the loser hit `{:error, {:already_started, pid}}` against a success-only match inside meck's own code — a bug in meck's interaction with an unused feature (coverage is not enabled in this project), not in this repo's test code.
- **Fix:** Removed `:meck` from the suite entirely (the only reliable fix — `try/after` cleanup, `on_exit` guards, and `async: false` were all explicitly rejected as workarounds, per the coordinator's direction). See deviation #8 for the two files affected.
- **Verification:** 35 consecutive full-suite runs, 0 failures (was ~40% intermittent failure rate before this fix)
- **Committed in:** `73ef80a`

**8. [Rule 1 - Bug in generated code, found via the meck-removal rewrite] `child_spec/0`'s `Supervisor.child_spec/2` call was never valid**

- **Found during:** Rewriting `commanded_application_generator_test.exs` to call the real generated application module (rather than mocking `create_module/3`) and, for the first time, actually invoking its `child_spec/0`
- **Issue:** `generate_commanded_application.ex`'s `include_supervisor?: true` branch called `Supervisor.child_spec({Supervisor, opts}, id: ...)`, which requires the first element to itself implement `child_spec/1` — bare `Supervisor` doesn't (it's not a `use Supervisor`-based child module) — raising `ArgumentError` the instant this function was actually called. Never previously observed: the old (mocked) test only string-matched the generated AST.
- **Fix:** Build the child-spec map directly (`%{id: ..., start: {Supervisor, :start_link, [[], opts]}, type: :supervisor}`) instead of routing through `Supervisor.child_spec/2`.
- **Files modified:** `lib/commanded/transformers/generate_commanded_application.ex`
- **Verification:** `test/commanded/transformers/commanded_application_generator_test.exs`'s supervisor test now calls `app_module.child_spec()` for real and asserts its shape
- **Committed in:** `73ef80a`

**9. [Rule 1 - Bug, found while removing the other meck file] `aggregate_generator_test.exs` was ALSO a `:meck` user, missed by the "last holdout" grep**

- **Found during:** Coordinator-directed follow-up, searching for all remaining `:meck`/`with_mock` usage after fixing deviation #7's primary file
- **Issue:** The claim that `commanded_application_generator_test.exs` was "the last meck holdout" was based on a `grep -rl "with_mock"` (which IS empty), but `aggregate_generator_test.exs`'s two snapshot-config tests used raw `:meck.new/:meck.expect/:meck.unload` directly (mocking `AshCommanded.Commanded.Dsl.application/1`), carrying the identical `async: true` + `:cover`-race exposure.
- **Fix:** Replaced both tests' mocked `dsl_state = %{}` + meck override with a real plain-map dsl_state carrying the application config under `[:commanded, :application] => %{opts: app_config}` — the same path `AshCommanded.Commanded.Dsl.application/1` itself reads. Required adding an explicit `otp_app` key the old mock never needed, since `Dsl.application/1` uses `:otp_app` as its own "is this section configured" sentinel and would otherwise return `nil` regardless of the other keys present.
- **Files modified:** `test/commanded/transformers/aggregate_generator_test.exs`
- **Verification:** `mix test test/commanded/transformers/aggregate_generator_test.exs` — 6 tests, 0 failures; `grep -rn ':meck\.\|with_mock' test/` — no matches anywhere in the suite
- **Committed in:** `73ef80a`

### Documented Findings (not fixed — out of scope, recorded for Phase 2)

**10. Router generation never fires, for any domain, under the current Domain/Resource DSL split.**

- **Found during:** Task 1 (building `CommandedAppCase`) and Task 3 (attempting the plan's originally-specified router-dispatch test); **corroborated a second time** during the coordinator-directed follow-up, by moving an equivalent fixture to `test/support` (per the coordinator's own suggestion) and confirming the identical crash under `MIX_ENV=test` — ruling out compile ordering/file placement as the cause.
- **Why not fixed:** Root cause is a structural transformer-wiring gap (`GenerateMainRouterModule`/`GenerateDomainRouterModule` are declared only on the resource-level DSL extension and check a condition that can never be true from there; `DomainDsl` doesn't list either transformer). Same class of defect as FOUND-03/FOUND-04, already assigned to Phase 2. Fixing it requires a domain-level transformer that reads persisted state back from each already-compiled resource — an architectural change, out of this plan's scope.
- **Impact:** Task 3's router-dispatch tests, and the rewritten `commanded_application_generator_test.exs`, both use hand-defined real routers instead of the DSL's own (nonexistent) generated router. See `coverage` entries D6/D7 and `deferred-items.md`, "From Plan 01-06."

**11. `private? true` ETS makes cross-process Ash-record visibility impossible after a real Commanded dispatch**

- **Found during:** Task 3, first attempt at a router-dispatch test asserting via `Ash.get!/2`
- **Why not fixed:** Changing `Widget`'s `private?` setting would affect every other test sharing this fixture; out of this plan's scope.
- **Impact:** Router-dispatch tests assert on `dispatch(..., returning: :aggregate_state)` instead of `Ash.get!/2`. See `deferred-items.md`, "From Plan 01-06."

---

**Total deviations:** 9 auto-fixed (3 test-construction bugs in Task 1's file, 2 real generated-code bugs found in Task 3, 1 self-correction of this plan's own stability claim, 1 async-suite-wide `:meck`/`:cover` race fixed by removing `:meck` entirely across 2 files, 1 additional generated-code bug found via that removal) + 2 documented findings (router generation, private-ETS cross-process visibility), neither fixed, both recorded for Phase 2.
**Impact on plan:** The projector fixes (deviations #4, #5) mean `AshCommanded.Commanded.Dsl`'s projector generation genuinely works end-to-end for the first time. The meck-removal work (deviations #6, #7, #9) fixes a real SC5 violation the plan's own initial verification missed, and along the way fixes a third real generated-code bug (deviation #8, the supervisor `child_spec/0`). The two documented findings (#10, #11) do not block this plan's own success criteria but materially inform Phase 2's FOUND-03/FOUND-04 scope, now corroborated twice.

## Known Stubs

None. All documented findings above are pre-existing library defects discovered during this plan's work, not stubs introduced by it — the tests exercising them use real, working substitutes rather than stubbed-out assertions.

## Issues Encountered

**SC5 violation caught by the coordinator, not by this plan's own initial verification.** The plan was first reported complete with a stability claim (2 consecutive runs, 6 seeds) that did not actually establish SC5 — it caught order-dependence but not an async cross-file race that only repeated full-suite runs surface. Resolved per the coordinator's explicit, approved follow-up task: removed `:meck` from the suite entirely (2 files affected, one not originally in this plan's scope), re-verified via 35 consecutive full-suite runs, and corrected this SUMMARY's claims accordingly. No other blockers; no auth gates.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `mix test` → 176 tests, 0 failures, verified across **35 consecutive full-suite runs** (the correct verification method for this class of race — repeated runs, not seed variation)
- `mix test test/commanded/generated_modules_test.exs`, `mix test test/commanded/transformers/commanded_application_generator_test.exs`, and `mix test test/commanded/transformers/aggregate_generator_test.exs` → each individually agrees with the full-suite outcome across seeds 0/1/2/3/987654
- `./scripts/compile_parity.sh` → PASSED, all 6 expected modules loaded under both `MIX_ENV=dev` and `MIX_ENV=test`
- `MIX_ENV=dev mix compile` and `MIX_ENV=test mix compile` → both exit 0
- `mix format --check-formatted` → clean
- `grep -rn ':meck\.|with_mock' test/` → no matches anywhere in the suite (only prose mentions in comments explaining what these files no longer do)
- `grep -rn 'skip_if_no_commanded' test/ --include='*.exs'` → no matches (the one remaining match, in the quarantined `.phase2-blocked` file, is a deliberate, documented exception — not collected by `mix test`)
- **Three real library bugs fixed** (deviations #4, #5, #8) that mean generated projectors and the supervisor-enabled application module now genuinely work when called — worth flagging to Plan 01-07/01-08 in case any warnings-as-errors or Dialyzer pass surfaces related dead-code warnings now that these code paths are reachable and exercised.
- **Two findings handed to Phase 2** (deferred-items.md, "From Plan 01-06", now corroborated twice for the router-generation finding): router generation never fires under the current Domain/Resource split, and `private? true` ETS makes cross-process record visibility impossible after a real Commanded dispatch.
- **Methodology note for future plans in this phase:** verifying "no intermittent failures" requires repeated full-suite runs (10+), not seed variation. Seeds test order-dependence; they do not test whether two async files' calls to some shared, VM-wide resource (a mock, a named process, an external tool like `:cover`) can race each other.

---
*Phase: 01-build-integrity*
*Completed: 2026-09-14*

## Self-Check: PASSED

- FOUND: `test/support/commanded_app_case.ex`
- FOUND: `test/support/parity/parity_domain.ex`
- FOUND: `test/support/parity/parity_widget.ex`
- FOUND: `scripts/compile_parity.sh` (executable)
- FOUND: `test/commanded/generated_modules_test.exs`
- FOUND: commit `0169ce9` (Task 1)
- FOUND: commit `53768b8` (interstitial docs)
- FOUND: commit `13e99c4` (Task 2)
- FOUND: commit `88b4e7a` (Task 3)
- FOUND: commit `975fc8e` (initial plan-complete metadata)
- FOUND: commit `73ef80a` (SC5 fix: remove last :meck usage)
- FOUND: commit `1c8634e` (docs: corroborate findings)
- CONFIRMED: `test/commanded/transformers/commanded_application_integration_test.exs.phase2-blocked` still quarantined (untouched)
- CONFIRMED: `mix test` → 176 tests, 0 failures (35 consecutive runs)
- CONFIRMED: `./scripts/compile_parity.sh` → PASSED
- CONFIRMED: `mix format --check-formatted` → clean
- CONFIRMED: `grep -rn ':meck\.|with_mock' test/` → no matches
