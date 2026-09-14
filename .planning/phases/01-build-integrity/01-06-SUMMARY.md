---
phase: 01-build-integrity
plan: 06
subsystem: testing
tags: [spark, dsl, commanded, ash, elixir, test-isolation, compile-time-parity]

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
  - "Two real, previously-undiscovered bugs in generate_projection_modules.ex and generate_projector_modules.ex, fixed: no projector had ever been called with a real event before this plan"
affects: ["01-07", "01-08", "phase-2 (FOUND-03/FOUND-04 router-generation and compile-order work)"]

actuals:
  tokens: 11868
  tasks: 3
  commits: 4
  plan_head_before: 9a458fb

tech-stack:
  added: []
  patterns:
    - "Per-test Commanded application isolation via Commanded.Application's own documented `start_link(name: unique_atom)` + `dispatch(cmd, application: name)` — no custom registry needed. The InMemory adapter derives its own event-store process name from the RUNTIME name passed to start_link (Module.concat([application, EventStore])), so uniqueness at start_link automatically isolates the event store too."
    - "`:meck.new/2` links the mock to the calling process. Registering `:meck.unload/1` via ExUnit's `on_exit` races that link — on_exit always runs in a separate process, after the test process (and its linked mock) has already exited, so `:meck.unload/1` can raise `{:not_mocked, module}`. Do `:meck.new` + `:meck.unload` in a `try/after` inside the test body itself instead, so unload runs synchronously in the same process before the test returns."
    - "Same process-link fragility applies to `Commanded.Application.start_link/1`'s returned supervisor pid: `on_exit`'s explicit `stop/1` call can race the automatic linked-process death. Guard with `Process.alive?/1` AND a `try/catch :exit` around the stop call."
    - "Cross-environment (MIX_ENV=dev/test) compile parity is proven with a fixed, explicit expected-module list checked under each environment in turn — never a `_build/dev` vs `_build/test` directory diff, which is swamped by legitimate :test-only fixtures."
    - "`Ash.DataLayer.Ets`'s `private? true` scopes writes to the CALLING PROCESS. A real Commanded dispatch runs the aggregate's `execute/2` inside the aggregate's own registered GenServer process, so an `Ash.get!/2` from the test process afterward cannot see the write. Assert on `dispatch(cmd, returning: :aggregate_state)`'s synchronously-returned aggregate struct instead when proving dispatch worked through a real, private-ETS-backed fixture."

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
    - "test/support/widget.ex"
    - "lib/commanded/transformers/generate_projection_modules.ex"
    - "lib/commanded/transformers/generate_projector_modules.ex"
    - ".planning/phases/01-build-integrity/deferred-items.md"

key-decisions:
  - "The plan's Task 1 assumed `commanded_application_generator_test.exs` had the same dead-by-construction `Code.ensure_loaded?`/`@tag :skip_if_no_commanded` shape as the (quarantined) integration test — it does not. It mocks Spark DSL accessors directly via a fake `%TestDsl{}` struct with hand-rolled `get_entities/2`/`get_persisted/2`. Root-caused the real failure instead: Spark 2.7.2's `Spark.Dsl.Extension.get_entities/2` does not dispatch to a struct's own functions the way that fixture assumed, raising `ArgumentError` before the first test's `:meck.unload` ran and leaving `BaseTransformer` mocked for the next test (the actual source of the `:already_started` cascade). Replaced the fake struct with a real plain-map dsl_state — the shape Spark's own `Transformer`/`Extension` modules operate on — rather than mocking Spark further."
  - "Left `test/commanded/transformers/commanded_application_integration_test.exs.phase2-blocked` quarantined and untouched, on explicit standing instruction (orchestrator context, corroborating the file's own header and `deferred-items.md`'s existing FOUND-03/FOUND-04 entry): restoring it aborts `mix test` at compile time. This means the `grep -rn 'skip_if_no_commanded' test/'` acceptance criterion (written assuming this file would be rewritten) cannot read zero across ALL of `test/` — it reads zero across every file ExUnit can actually collect (`*_test.exs`); the one remaining match is in the `.phase2-blocked` file, deliberately excluded from that glob by its own extension."
  - "Discovered by live probe (not assumed) that `GenerateMainRouterModule`/`GenerateDomainRouterModule` never actually produce a router module for ANY domain under the current Domain/Resource DSL split — both only run while a resource compiles and check whether that resource IS a domain, which is never true; `DomainDsl` doesn't list either transformer itself. This predates and partly explains FOUND-03/FOUND-04's compile-order crash (no router ever existed to crash against, in any configuration, until this phase's D-01 made `:commanded` a hard dependency). Documented at length in `deferred-items.md`; NOT fixed here (structural transformer-wiring change, Phase 2 territory)."
  - "Task 3's router-dispatch tests use `AshCommanded.TestSupport.WidgetRouter` — a hand-written `Commanded.Commands.Router` wired to the DSL's real generated `Commands.CreateWidget`/`WidgetAggregate` modules — instead of 'the generated router' the plan's acceptance criteria describe, because no such module exists to dispatch through (see above). This proves the same underlying TEST-06 claim (real per-test Commanded-application isolation, real dispatch through Commanded) using real generated command/aggregate modules; it does not prove the DSL's own router-generation transformers work, because they currently produce nothing."
  - "Widget's projection uses `:widget_updated`/`action :update` rather than `:widget_created`/`:create`: a `:create`-action projection would be a second, redundant creation path alongside the command-driven one `aggregate_end_to_end_test.exs` already exercises, and `:update` requires an existing record, more thoroughly exercising the projector's `Ash.get` + apply + perform_action chain."
  - "The event handler uses a quoted lambda `action`, not an atom Ash-action reference, to avoid a pre-existing, out-of-scope defect (`generate_event_handler_modules.ex`'s `execute_action/2` calls `Ash.run_action/3`, which doesn't exist — flagged in `deferred-items.md` from Plan 01-03, still unfixed, still out of this plan's scope)."

patterns-established:
  - "Any future test that mocks a module via `:meck` inside an ExUnit test MUST unload it synchronously in the same process (`try/after` in the test body), never via `on_exit` — `on_exit` always runs in a different process after the mock's linked owner has already exited, and `:meck.unload/1` can then raise `{:not_mocked, module}`, leaving the mock loaded for whichever test runs next."
  - "Any future Commanded dispatch test targeting a `private? true` ETS-backed Ash resource must assert on `dispatch(..., returning: :aggregate_state | :execution_result)`'s synchronously-returned value, not a subsequent `Ash.get!/2` — the write happens in the aggregate's own process, invisible to a private ETS table looked up from any other process."

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
    description: "mix test and mix test <file> agree on outcome; the full suite passes on two consecutive runs and under multiple seeds"
    requirement: "TEST-06"
    verification:
      - kind: unit
        ref: "mix test (seeds 0, 1, 4, 42, 4242, 987654) -> 175 tests, 0 failures each run; two consecutive mix test invocations both 175/0"
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

duration: ~2h10min (active, including two live probes: the router-generation architecture and the private-ETS cross-process visibility issue)
completed: 2026-09-14
status: complete
---

# Phase 1 Plan 6: Test Isolation, Cross-Environment Parity, and Direct Generated-Module Calls Summary

**Reduced `test_helper.exs` to a bare `ExUnit.start()`, built a per-test Commanded-application isolation helper, proved generated-module parity between `MIX_ENV=dev` and `MIX_ENV=test` with a dependency-free fixture, and — while making the projector/event-handler/router module kinds actually callable for the first time in this suite's history — found and fixed two real bugs (a DSL-changes-function that was never invoked, and a `with`-clause shape mismatch) that meant no projector had ever successfully processed a real event before this plan.**

## Performance

- **Duration:** ~2h10min active (includes two substantial investigation phases: reproducing and root-causing the `:meck`/`on_exit` process-link race, and probing why the DSL's own router-generation transformers never fire)
- **Completed:** 2026-09-14
- **Tasks:** 3 (all `type="auto"`, Task 3 `tdd="true"`)
- **Files modified:** 11 (5 created, 6 modified)

## Accomplishments

- **Task 1 — reduced `test_helper.exs` to `ExUnit.start()`** (D-16), removing the Commanded-availability probe, the `:skip_if_no_commanded`/`:skip` exclusion list, and the fixed `seed: 0`. Confirmed via `mix test` header output: no "Excluding tags" line, no seed override — order-dependence can now surface as a failure instead of hiding behind a stable seed forever.
- **Root-caused and fixed all four pre-existing `CommandedApplicationGeneratorTest` failures** — not by patching around them, but by finding the actual bug: the test's `%TestDsl{}` fixture hand-rolled `get_entities/2`/`get_persisted/2` clauses assuming Spark would dispatch to them, but Spark 2.7.2's real `Spark.Dsl.Extension.get_entities/2` does something different for a `%struct{}` value (calls `struct.entities(path)`, a real Spark.Dsl callback `TestDsl` never defined), raising `ArgumentError` before the first test's `:meck.unload` ran. That left `BaseTransformer` mocked for the next test, producing the `:already_started` cascade Plan 01-05 flagged as "yours to fix." Rewrote the fixture as a real plain-map dsl_state (the shape `Spark.Dsl.Transformer`/`Extension` genuinely operate on) and replaced the `setup`/`on_exit` meck cleanup with `try/after` in each test body — `on_exit` runs in a separate process after the mock's linked owner has already exited, which is itself a second, independently-confirmed race (empirically reproduced with a minimal 2-test probe before touching the real file).
- **Built `test/support/commanded_app_case.ex`** (D-15): `AshCommanded.TestSupport.CommandedAppCase`, an `ExUnit.CaseTemplate` that starts a `Commanded.Application` under a name unique to the invoking test (`System.unique_integer([:positive])`, never the file/module) with its own `InMemory` event store, torn down in `on_exit` (guarded against the same process-link race meck has, via `Process.alive?/1` + `try/catch :exit`).
- **Task 2 — built the D-19/SC2 cross-environment parity fixture**: `test/support/parity/parity_domain.ex` + `parity_widget.ex`, a domain-neutral, dependency-free `Ash.Domain`/`Ash.Resource` pair (no data layer — defaults to `Ash.DataLayer.Simple`) carrying one command, one event, and one projection, safe under `mix.exs`'s `elixirc_paths(:dev)`. `scripts/compile_parity.sh` compiles under `MIX_ENV=dev` and `MIX_ENV=test` in turn and asserts a fixed list of 6 expected generated modules loads under each — not a `_build` directory diff. Before this fixture, `_build/dev` contained zero generated modules; this made SC2 checkable for the first time.
- **Task 3 — called the generated projector, event handler, and (substitute) router modules directly**, the two generated-module kinds `aggregate_end_to_end_test.exs` (Plan 01-02) doesn't cover, plus the router: added a minimal `:widget_updated` projection and `:widget_notifier` event handler to `test/support/widget.ex`, then wrote `test/commanded/generated_modules_test.exs` with a direct-call describe block (no Commanded process) and a `CommandedAppCase`-based dispatch block.
- **Found and fixed two real, previously-undiscovered bugs while writing Task 3** — nothing in this suite had ever called a real generated projector's `handle/2` with a real event before this task:
  1. `generate_projection_modules.ex`'s `generate_changes_ast/1` had a dead clause matching literal `{:fn, _, _}` AST (a comment claimed "Spark will store this as a quoted function expression"), but Spark actually evaluates a `changes(fn event -> ... end)` DSL entry into a real compiled function at DSL-processing time. The live fallback clause (`is_function(other)`) just re-embedded that function via `Macro.escape/1` without ever calling it, so `apply/2` handed a raw function to `Ash.Changeset.for_action/3`, which requires a map, crashing with `Protocol.UndefinedError`. Fixed: call the function with `event` (arity 1) or no args (arity 0).
  2. `generate_projector_modules.ex`'s generated `with {:ok, changeset} <- ... .apply(...)` clause expected a two-tuple, but `apply/2` (per its own moduledoc) always returns a bare `%Ash.Changeset{}`. Every projector's `handle/2` crashed with `WithClauseError` the instant a real event flowed through. Fixed: match the bare changeset the way it's actually returned.
- **Found — but did not fix, per this plan's scope and the standing Phase-2 quarantine — that `GenerateMainRouterModule`/`GenerateDomainRouterModule` never produce a router module for any domain under the current Domain/Resource DSL split.** Confirmed by live probe (a real `Ash.Domain` with `DomainDsl` + a resource with commands compiles command/event/aggregate modules correctly, but `Code.ensure_loaded?/1` is `false` for both candidate router names). Root cause: both transformers check whether the currently-compiling module IS a domain, but they're declared only on the resource-level `AshCommanded.Commanded.Dsl` extension, so that check is always false; `DomainDsl` doesn't list either transformer itself. Documented in `deferred-items.md` alongside the existing FOUND-03/FOUND-04 entry it partly explains. Task 3's router-dispatch tests instead use `AshCommanded.TestSupport.WidgetRouter`, a hand-written `Commanded.Commands.Router` wired to the real generated `Commands.CreateWidget`/`WidgetAggregate` modules.
- **Found — and worked around, not fixed — that `Widget`'s `ets do private? true end` makes an Ash write invisible to a subsequent `Ash.get!/2` from a different process**, which is exactly what happens when dispatching through a real `Commanded.Application` (aggregate execution runs in the aggregate's own registered process). Confirmed by probe. Router-dispatch tests assert on `dispatch(..., returning: :aggregate_state)`'s synchronously-returned aggregate struct instead.
- Full suite: 175 tests (was 170), 0 failures, stable across two consecutive runs and six different seeds (0, 1, 4, 42, 4242, 987654).

## Task Commits

1. **Task 1: Strip the test helper to ExUnit.start() and give dispatch tests their own Commanded application** — `0169ce9` (test)
2. **(interstitial) Record router-generation and private-ETS cross-process findings** — `53768b8` (docs)
3. **Task 2: Cross-environment parity — one dependency-free fixture, one fixed expected-module list** — `13e99c4` (test)
4. **Task 3: Call the generated projector, event-handler and router modules directly** — `88b4e7a` (test)

**Plan metadata:** committed alongside this SUMMARY (see below)

## Files Created/Modified

- `test/test_helper.exs` — reduced from a 17-line availability-probe/exclusion/fixed-seed script to a single `ExUnit.start()` call
- `test/commanded/transformers/commanded_application_generator_test.exs` — rewritten: real plain-map dsl_state fixture (not a fake struct), `try/after` meck cleanup (not `setup`/`on_exit`), two incorrect `"defmodule X do"` string assertions fixed (they checked for text that can never appear in a module *body* AST)
- `test/support/commanded_app_case.ex` (new) — `AshCommanded.TestSupport.CommandedAppCase`, `AshCommanded.TestSupport.WidgetRouter`, `AshCommanded.TestSupport.CommandedApplication`
- `test/support/parity/parity_domain.ex`, `test/support/parity/parity_widget.ex` (new) — dependency-free `Ash.Domain`/`Ash.Resource` pair for cross-environment parity
- `scripts/compile_parity.sh` (new) — cross-environment (`MIX_ENV=dev`/`test`) generated-module parity check
- `test/support/widget.ex` — added a minimal `:widget_updated` projection and `:widget_notifier` event handler
- `test/commanded/generated_modules_test.exs` (new) — direct-call and per-test-isolated-dispatch tests for projector, event handler, and (substitute) router
- `lib/commanded/transformers/generate_projection_modules.ex` — fixed `generate_changes_ast/1`'s function-value clause to actually call the function
- `lib/commanded/transformers/generate_projector_modules.ex` — fixed the generated `with` clause's changeset match shape
- `.planning/phases/01-build-integrity/deferred-items.md` — documented the router-generation and private-ETS cross-process findings for Phase 2

## Decisions Made

See `key-decisions` in frontmatter. Summarized: (1) the plan's assumption that `commanded_application_generator_test.exs` shared the quarantined integration test's dead-by-construction shape was wrong — root-caused and fixed the REAL bug instead (a broken test-fixture dsl_state, not a dead conditional); (2) the quarantined integration test stays quarantined, per standing instruction, so the "zero `skip_if_no_commanded` anywhere in `test/`" criterion is satisfied for every file ExUnit can collect, with the one remaining match documented as the known, sanctioned exception; (3) discovered and documented (not fixed) that the DSL's router-generation transformers never produce a router under the current architecture — Task 3's router tests use a hand-written substitute; (4) `private? true` ETS makes cross-process record visibility impossible after a real Commanded dispatch — worked around via `returning: :aggregate_state`, not fixed; (5) the widget projection targets `:widget_updated`/`:update`, not `:widget_created`/`:create`, to avoid redundant creation paths and more thoroughly exercise the projector; (6) the event handler uses a quoted lambda action to sidestep a separate, already-known, out-of-scope `Ash.run_action/3` defect.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `commanded_application_generator_test.exs`'s dsl fixture was fundamentally incompatible with the installed Spark version, not merely mocked incorrectly**

- **Found during:** Task 1, first attempt to run the pre-existing failing tests
- **Issue:** The plan assumed (per RESEARCH.md's own flagged low-confidence note, "not read in full this session, apply the same disposition after inspection") that this file shared the integration test's `Code.ensure_loaded?`/`@tag :skip_if_no_commanded` dead-by-construction shape. It does not — it mocks Spark DSL accessors via a fake `%TestDsl{}` struct. That struct's hand-rolled `get_entities/2` doesn't match how Spark 2.7.2's real `Spark.Dsl.Extension.get_entities/2` dispatches for a `%struct{}` value (it calls `struct.entities(path)`, which `TestDsl` never defined), so the very first test raised `ArgumentError` before `:meck.unload` ran, leaving `BaseTransformer` mocked and causing every subsequent test's `:meck.new` to fail with `{:already_started, pid}`.
- **Fix:** Replaced the fake struct with a genuine plain-map dsl_state (the shape `Spark.Dsl.Transformer`/`Extension` actually read/write — confirmed by reading `deps/spark/lib/spark/dsl/transformer.ex` directly), eliminating the need to fake Spark's own accessors at all.
- **Files modified:** `test/commanded/transformers/commanded_application_generator_test.exs`
- **Verification:** `mix test` on this file, 6 tests / 0 failures, stable across 5 consecutive seeds
- **Committed in:** `0169ce9`

**2. [Rule 1 - Bug] `:meck.unload` via `on_exit` races the mock's own process link**

- **Found during:** Task 1, immediately after fixing deviation #1 (the four tests still failed with a NEW error, `{:not_mocked, module}`)
- **Issue:** `:meck.new/2` links the mock's GenServer to the calling process. `on_exit` callbacks always run in a separate process, after the test process (and anything linked to it) has already exited — so by the time `on_exit`'s `:meck.unload/1` ran, the mock was frequently already gone. Reproduced independently with a minimal 2-test probe file before touching the real test.
- **Fix:** Moved `:meck.new`/`:meck.expect`/`:meck.unload` into each test body directly, wrapped in `try/after`, so unload runs synchronously in the same process before the test function returns.
- **Files modified:** `test/commanded/transformers/commanded_application_generator_test.exs`
- **Verification:** Same as above; also reproduced the SAME class of race independently for `Commanded.Application.start_link/1`'s supervisor pid inside `CommandedAppCase`'s `on_exit`, and guarded it the same way (`Process.alive?/1` + `try/catch :exit`)
- **Committed in:** `0169ce9`

**3. [Rule 1 - Bug, found in generated code] Two incorrect string assertions in the same test file**

- **Found during:** Task 1, after fixing deviations #1 and #2 (two tests still failed on content assertions)
- **Issue:** `assert code_string =~ "defmodule TestDomain.Application do"` checked for text that can never appear: `code` is the AST passed to `BaseTransformer.create_module/3`, which is the module *body*, not a `defmodule ... do ... end` wrapper (that wrapping happens inside `Module.create/3`, which this test mocks). These assertions never ran successfully before — the cascade masked them entirely.
- **Fix:** Removed the incorrect substring checks; kept (and, for one test, added) assertions on the actual module-identity argument (`assert module == TestDomain.Application`) and on real generated-code substrings (`"use Commanded.Application"`, `"router(TestDomain.Router)"`, etc.)
- **Files modified:** `test/commanded/transformers/commanded_application_generator_test.exs`
- **Committed in:** `0169ce9`

**4. [Rule 1 - Bug in generated code] `generate_changes_ast/1`'s function-value clause never invoked the function**

- **Found during:** Task 3, first run of the new projector direct-call test
- **Issue:** A `changes(fn event -> %{...} end)` DSL entry is evaluated by Spark into a real compiled function before this transformer runs (not the literal `{:fn, _, _}` AST a stale code comment assumed). The live fallback clause (`is_function(other)`) re-embedded that function value via `Macro.escape/1` without calling it, so the generated `apply/2` assigned a raw function to `changes` and passed it to `Ash.Changeset.for_action/3`, crashing with `Protocol.UndefinedError` ("protocol Enumerable not implemented for type Function"). No prior test had ever invoked a real projector's `apply/2` with a real event — the one existing test on this DSL surface (`projections_dsl_test.exs`) only asserted `is_function(email_proj.changes, 1)`, never called it.
- **Fix:** Changed the fallback clauses to actually call the function — with `event` when arity 1, with no arguments when arity 0.
- **Files modified:** `lib/commanded/transformers/generate_projection_modules.ex`
- **Verification:** `test/commanded/generated_modules_test.exs`'s projector test, plus full suite (175 tests, 0 failures, including the pre-existing `projections_dsl_test.exs` unaffected)
- **Committed in:** `88b4e7a`

**5. [Rule 1 - Bug in generated code] Generated projector `with` clause expected `apply/2` to return `{:ok, changeset}`; it returns a bare changeset**

- **Found during:** Task 3, same test run, immediately after fixing deviation #4
- **Issue:** `generate_projector_modules.ex`'s generated `handle/2` used `with {:ok, changeset} <- unquote(projection_module).apply(...)`, but `apply/2` (per its own moduledoc, "An Ash changeset ready to be applied") always returns a bare `%Ash.Changeset{}`. Every projector's `handle/2`, for every projection kind (create and update/destroy), crashed with `WithClauseError` the instant a real event reached it — again, never previously observed because nothing had ever called a real projector's `handle/2` before this task.
- **Fix:** Changed both `with` clauses (create branch and update/destroy branch) to bind the changeset as a bare value rather than pattern-matching `{:ok, changeset}`.
- **Files modified:** `lib/commanded/transformers/generate_projector_modules.ex`
- **Verification:** Same as deviation #4
- **Committed in:** `88b4e7a`

### Documented Findings (not fixed — out of scope, recorded for Phase 2)

**6. Router generation never fires, for any domain, under the current Domain/Resource DSL split.**

- **Found during:** Task 1 (building `CommandedAppCase`) and Task 3 (attempting the plan's originally-specified router-dispatch test)
- **Why not fixed:** Root cause is a structural transformer-wiring gap (`GenerateMainRouterModule`/`GenerateDomainRouterModule` are declared only on the resource-level DSL extension and check a condition — "is the compiling module a domain?" — that can never be true from there; `DomainDsl` doesn't list either transformer). This is the same class of defect as FOUND-03/FOUND-04, already assigned to Phase 2. Fixing it requires a domain-level transformer that reads persisted state back from each already-compiled resource — an architectural change, not a mechanical fix, and out of this plan's scope.
- **Impact:** Task 3's router-dispatch tests use a hand-written substitute router (`AshCommanded.TestSupport.WidgetRouter`) against the DSL's real generated command/aggregate modules. See `coverage` entry D6 (`human_judgment: true`) and `deferred-items.md`, "From Plan 01-06."

**7. `private? true` ETS makes cross-process Ash-record visibility impossible after a real Commanded dispatch**

- **Found during:** Task 3, first attempt at a router-dispatch test asserting via `Ash.get!/2`
- **Why not fixed:** Changing `Widget`'s `private?` setting would affect every other test sharing this fixture; out of this plan's scope, and possibly not a "fix" in the usual sense (it may be inherent to the isolation `private?: true` provides).
- **Impact:** Router-dispatch tests assert on `dispatch(..., returning: :aggregate_state)` instead of `Ash.get!/2`. See `deferred-items.md`, "From Plan 01-06."

---

**Total deviations:** 5 auto-fixed (3 test-construction bugs in Task 1's pre-existing file, 2 real generated-code bugs found and fixed in Task 3) + 2 documented findings (router generation, private-ETS cross-process visibility), neither fixed, both recorded for Phase 2.
**Impact on plan:** The two Task 3 code fixes (deviations #4 and #5) are consequential beyond this plan — they mean `AshCommanded.Commanded.Dsl`'s projector generation genuinely works end-to-end for the first time, for both `changes(fn event -> ... end)`-style and static-map projections. Deviations #1–#3 fully resolve Plan 01-05's flagged "yours to fix" failures with no residual count. The two documented findings do not block this plan's own success criteria (both were substituted around, honestly, with the substitution's limits stated in the coverage table) but materially inform Phase 2's FOUND-03/FOUND-04 scope.

## Known Stubs

None. Both documented findings above (router generation, private-ETS visibility) are pre-existing library defects discovered during this plan's work, not stubs introduced by it — the tests exercising them use real, working substitutes rather than stubbed-out assertions.

## Issues Encountered

None beyond the deviations above (all self-resolved within this plan's scope; no external blockers, no auth gates).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `mix test` → 175 tests, 0 failures, stable across two consecutive runs and seeds 0/1/4/42/4242/987654
- `mix test test/commanded/generated_modules_test.exs` and `mix test test/commanded/transformers/commanded_application_generator_test.exs` → agree with the full-suite outcome
- `./scripts/compile_parity.sh` → PASSED, all 6 expected modules loaded under both `MIX_ENV=dev` and `MIX_ENV=test`
- `MIX_ENV=dev mix compile` and `MIX_ENV=test mix compile` → both exit 0
- `mix format --check-formatted` → clean
- `grep -rn 'skip_if_no_commanded' test/ --include='*.exs'` → no matches (the one remaining match, in the quarantined `.phase2-blocked` file, is a deliberate, documented exception — not collected by `mix test`)
- **Two real library bugs fixed** (deviations #4, #5) that mean generated projectors now genuinely work when called — worth flagging to Plan 01-07/01-08 in case any warnings-as-errors or Dialyzer pass surfaces related dead-code warnings now that these code paths are reachable and exercised.
- **Two findings handed to Phase 2** (deferred-items.md, "From Plan 01-06"): router generation never fires under the current Domain/Resource split (extends FOUND-03/FOUND-04's scope with a concrete root cause), and `private? true` ETS makes cross-process record visibility impossible after a real Commanded dispatch (relevant to any future plan proving end-to-end dispatch against `Widget` or a similar private-ETS fixture).

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
- CONFIRMED: `test/commanded/transformers/commanded_application_integration_test.exs.phase2-blocked` still quarantined (untouched)
- CONFIRMED: `mix test` → 175 tests, 0 failures (two consecutive runs)
- CONFIRMED: `./scripts/compile_parity.sh` → PASSED
- CONFIRMED: `mix format --check-formatted` → clean
