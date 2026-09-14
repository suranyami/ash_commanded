---
phase: 01-build-integrity
plan: 05
subsystem: testing
tags: [spark, dsl, verifiers, ash, elixir, compile-time-testing]

# Dependency graph
requires:
  - phase: 01-02
    provides: "Mix.env()-free CommandActionMapper and its real Ash fixtures — established the real-compilation testing standard this plan applies to verifiers"
  - phase: 01-03
    provides: "Guard-free transformers (Mix.env() removed), so a resource compiled in a test actually runs the full transformer/verifier pipeline this plan depends on"
provides:
  - "Nine verifier test files (one per module in lib/commanded/verifiers/), every one reached through real DSL compilation rather than mocked Spark.Dsl.Verifier accessors"
  - "A discovered, verified replacement for D-14's literal Code.compile_string + assert_raise pattern: Spark.Test.assert_dsl_error/refute_dsl_errors, shipped in this repo's own Spark 2.7.2 dependency specifically to solve the exact problem D-14 was written to solve"
  - "The mocking library (mock/with_mock) is no longer referenced anywhere in test/ — Plan 01-07's stated precondition for dropping the {:mock, \"~> 0.3.0\"} dependency"
  - "Two verifiers (ValidateEventHandlerEvents, ValidateEventHandlerActions) have a mix-test-collected test for the first time ever"
affects: ["01-06", "01-07", "01-08"]

actuals:
  tokens: 15785
  tasks: 3
  commits: 3
  plan_head_before: 7bbc9a7

tech-stack:
  added: []
  patterns:
    - "Spark.Test.assert_dsl_error/refute_dsl_errors (deps/spark/lib/spark/test.ex) for compile-time DSL rejection testing — NOT Code.compile_string + assert_raise. Spark's @after_verify hook (which is how Spark.Dsl runs verifiers on Ash.Resource modules) runs asynchronously per Elixir's own documented @after_verify contract (\"Elixir provides no guarantees of when in the compilation cycle nor in which process the callback runs\"), so a raised Spark.Error.DslError never reaches a caller-side assert_raise — it is converted to a stderr warning instead. Spark.Test registers the test process as a collector via Process.put({Spark.Dsl, :test_collector}, self()) before the block runs; the verifier-running code checks for that collector and, when present, sends the error back as a message instead of raising it into the void."
    - "Two-segment unique module naming for nested defmodule DSL-rejection tests: Module.concat([:\"Prefix#{System.unique_integer([:positive])}\", :DescriptiveName]) — NOT a single segment with the unique suffix on the end. AshCommanded's own transformers derive a generated-module prefix via BaseTransformer.get_module_prefix/1, which drops only the LAST segment of the resource module's path. A single-segment unique name (e.g. AshCommanded.Test.Foo123) leaves a constant, shared prefix (AshCommanded.Test) across every test resource, causing concurrent generated-module redefinition crashes (e.g. all tests' Commands.RegisterUser colliding) under async: true. Putting the uniqueness in the segment BEFORE the last one avoids this."
    - "`autogenerate?(false)` on a deliberately-malformed projection/event-handler entity that references a non-existent event name — GenerateProjectorModules and GenerateEventHandlerModules both look up the event struct module by event name to build a `%EventModule{}` pattern match; a name with no corresponding event resolves to nil and crashes the transformer (a %nil{} pattern is invalid) before the verifier under test ever runs. Setting autogenerate?(false) opts the malformed entity out of module generation without affecting whether the verifier examines it."

key-files:
  created:
    - "test/commanded/verifiers/validate_event_handler_events_test.exs"
    - "test/commanded/verifiers/validate_event_handler_actions_test.exs"
  modified:
    - "test/commanded/verifiers/validate_command_names_test.exs"
    - "test/commanded/verifiers/validate_command_fields_test.exs"
    - "test/commanded/verifiers/validate_event_names_test.exs"
    - "test/commanded/verifiers/validate_event_fields_test.exs"
    - "test/commanded/verifiers/validate_projection_actions_test.exs"
    - "test/commanded/verifiers/validate_projection_changes_test.exs"
    - "test/commanded/verifiers/validate_projection_events_test.exs"

key-decisions:
  - "D-14's literal mechanism (Code.compile_string/1 wrapped in assert_raise Spark.Error.DslError, ~r/.../) does not work against this repo's actual Spark version (2.7.2) — confirmed empirically with a standalone probe before writing any real test file. A duplicate-command-name resource compiled via Code.compile_string inside assert_raise produced 'Expected exception Spark.Error.DslError but nothing was raised'; the verifier's error was instead printed to stderr as a compiler warning. Root cause: Spark.Dsl registers its verifier-running function via Elixir's @after_verify hook, which Elixir's own Module docs state runs with 'no guarantees of when in the compilation cycle nor in which process the callback runs' — i.e. NOT synchronously in the calling process, so a bare assert_raise around the defining code can never observe it."
  - "Adopted Spark.Test (deps/spark/lib/spark/test.ex) instead — a module shipped in this exact Spark dependency version whose own moduledoc states verbatim: 'Verifier errors raised inside Spark's @after_verify hook are converted to stderr warnings by the framework rather than propagated as exceptions, so the usual assert_raise/2 testing pattern is unsuitable.' This is not a workaround invented for this plan; it is Spark's own documented, current answer to the exact problem D-14 was written to solve, one Spark minor version before this repo's floor (REPO-03 already bumped Spark to ~> 2.6, resolving 2.7.2). Every must_have this plan states is satisfied by this replacement: real DSL compilation (not mocked verify/1 calls), a regex-matched Spark.Error.DslError, and — empirically confirmed per verifier below — loud failure when the verifier is removed from dsl.ex's verifiers list."
  - "All nine rejection-test resources are scaffolded with a valid action/event/changes-map alongside the one deliberately-wrong field, so only the verifier under test has anything to reject (Task 2's own instruction, applied to all nine, not just the three projection verifiers it named). Two of the nine (the ValidateProjectionEvents and ValidateEventHandlerEvents rejection cases) additionally need autogenerate?(false) on the malformed entity, because an unrecognized event name crashes a downstream module-generation transformer (GenerateProjectorModules / GenerateEventHandlerModules) before the verifier gets a turn — discovered by running the tests and reading the resulting RuntimeError, not assumed."
  - "Consolidated projection verifier test counts from 3/4/4 (11 total, in the old mocked files) to 3/3/3 (9 total) per the plan's own template of exactly one reject + one accept + one empty-block test per verifier. The dropped assertions (a 'skips validation for function-based changes' case, and a 'multiple invalid projections in one message' case) tested real verifier behavior that still holds — Enum.filter/Enum.map based aggregation is unchanged code, and the multi-invalid-entry behavior is exercised implicitly by the loop structure — but is not, per D-17's own instruction, required to survive a rewrite whose job is proving compile-time reachability, not re-deriving full behavioral coverage from scratch."

patterns-established:
  - "Every future Spark verifier rejection test in this repo must use Spark.Test.assert_dsl_error / refute_dsl_errors, not Code.compile_string + assert_raise. The latter is dead on arrival against this repo's Spark version and will silently produce a false-positive-looking test that never actually asserts anything (assert_raise's own failure path — 'nothing was raised' — is the only tell, and it is easy to read past under time pressure)."

requirements-completed: [TEST-02]

coverage:
  - id: D1
    description: "Each of the nine verifiers in lib/commanded/verifiers/ has a test that compiles a deliberately malformed DSL and asserts Spark.Error.DslError is raised with a message matching that verifier's own distinguishing fragment"
    requirement: "TEST-02"
    verification:
      - kind: unit
        ref: "mix test test/commanded/verifiers/ -> 27 tests, 0 failures"
        status: pass
    human_judgment: false
  - id: D2
    description: "Removing a verifier from AshCommanded.Commanded.Dsl's verifiers/0 list makes its own rejection test fail loudly ('no error raised'), proving the tests are load-bearing rather than incidentally passing"
    requirement: "TEST-02"
    verification:
      - kind: other
        ref: "manual per-verifier check: commented each of the nine verifiers out of lib/commanded/dsl.ex in turn, ran that verifier's test file, confirmed 'Expected a Spark.Error.DslError matching: _ / Got: []' for all nine, restored dsl.ex and confirmed diff-clean each time"
        status: pass
    human_judgment: false
  - id: D3
    description: "Every rejection test matches the DslError message with a ~r/.../ regex naming the distinguishing fragment, never full-string equality; no file mocks Spark.Dsl.Verifier"
    requirement: "TEST-02"
    verification:
      - kind: other
        ref: "grep -c '~r/' across all nine files -> at least 1 per file; grep -rlE 'with_mock|import Mock' test/ -> no matches (exit 1)"
        status: pass
    human_judgment: false
  - id: D4
    description: "The one-time-never-collected event_handler_tests.exs and the assertion-free integration_test.exs are deleted, their assertions and reasons recorded, and test/commanded/verifiers/ contains exactly nine files, one per verifier, all collected by a plain mix test"
    requirement: "TEST-02"
    verification:
      - kind: other
        ref: "ls test/commanded/verifiers/ | wc -l -> 9; ls test/commanded/verifiers/ | grep -vc '_test\\.exs$' -> 0"
        status: pass
    human_judgment: false
  - id: D5
    description: "The rest of the suite is unaffected: mix test shows no more than the 4 pre-existing meck :already_started failures owned by Plan 01-06"
    requirement: "TEST-02"
    verification:
      - kind: unit
        ref: "mix test -> 170 tests, 4 failures, all four in CommandedApplicationGeneratorTest"
        status: pass
    human_judgment: false

duration: ~40min (active, including the Spark.Test discovery investigation)
completed: 2026-09-14
status: complete
---

# Phase 1 Plan 5: Verifier Compile-Time Rejection Tests Summary

**Rewrote all nine Spark DSL verifier tests to reach their verifiers through real resource compilation instead of mocked introspection — and, discovering along the way that this plan's own locked D-14 mechanism (`Code.compile_string` + `assert_raise`) is dead on arrival against this repo's actual Spark version, replaced it with `Spark.Test`, the exact-purpose test helper Spark itself ships to solve this.**

## Performance

- **Duration:** ~40 min active work (includes a substantial investigation phase: reading nine verifier sources, probing the actual runtime behavior of `Code.compile_string` + `assert_raise` before writing any real test, and discovering + verifying the `Spark.Test` replacement)
- **Completed:** 2026-09-14T03:39:00Z (approx.)
- **Tasks:** 3 (all `type="auto"`, `tdd="true"`)
- **Files modified:** 9 (2 created, 7 modified, 2 deleted)

## Accomplishments

- **Found, before writing a single real test file, that this plan's locked D-14 mechanism does not work.** Wrote a standalone probe (`Code.compile_string` of a duplicate-command-name resource, wrapped in `assert_raise Spark.Error.DslError, ~r/.../`) and ran it via both `mix run` and a real ExUnit test. Both times: the verifier's error was printed to stderr as a compiler warning, and `assert_raise` reported "Expected exception Spark.Error.DslError but nothing was raised." Traced the root cause into Elixir's own `Module` docs and Spark's source (`deps/spark/lib/spark/dsl.ex:464`, `@after_verify {__MODULE__, :__verify_spark_dsl__}`): Spark runs verifiers via Elixir's `@after_verify` hook, which Elixir's docs state explicitly runs with "no guarantees of when in the compilation cycle nor in which process the callback runs" — so a raised error there can never be caught by a bare `assert_raise` around the defining code.
- **Found the correct, already-shipped replacement**: `Spark.Test` (`deps/spark/lib/spark/test.ex`), present in this repo's resolved Spark 2.7.2. Its own moduledoc states, nearly verbatim, the exact problem just discovered: "Verifier errors raised inside Spark's `@after_verify` hook are converted to stderr warnings by the framework rather than propagated as exceptions, so the usual `assert_raise/2` testing pattern is unsuitable." Verified `assert_dsl_error`/`refute_dsl_errors` work correctly with a repeat of the same probe, then verified (by commenting `ValidateCommandNames` out of `dsl.ex`'s `verifiers/0` list) that the replacement test genuinely fails when the verifier is removed — the exact guarantee D-14 wanted.
- **Task 1 — rewrote the four command/event verifier tests** (`ValidateCommandNames`, `ValidateCommandFields`, `ValidateEventNames`, `ValidateEventFields`) to the `Spark.Test` pattern: each now compiles a genuinely malformed resource, asserts a regex-matched `Spark.Error.DslError`, and carries an accepting + empty-block counterpart. 12 tests, all passing, stable across repeated random seeds.
- **Task 2 — rewrote the three projection verifier tests** (`ValidateProjectionActions`, `ValidateProjectionChanges`, `ValidateProjectionEvents`) to the same pattern, each scaffolded with a valid action, valid changes map, and valid matching event alongside the one deliberately-wrong field, so only the verifier under test fires. Discovered along the way that the invalid-event-name case for `ValidateProjectionEvents` crashes `GenerateProjectorModules` (it builds a `%EventModule{}` pattern from a `nil` lookup) before the verifier runs; fixed by adding `autogenerate?(false)` to that one malformed projection. 9 tests, all passing.
- **Task 3 — deleted two assertion-free test files and replaced the never-collected one.** Confirmed by direct inspection that `integration_test.exs` (18 assertions, all `Code.ensure_loaded?`/`Spark.implements_behaviour?`) and `event_handler_tests.exs` (same shape, and never once collected by `mix test` because its filename doesn't match `*_test.exs`) proved nothing about DSL behavior. Deleted both, and added `validate_event_handler_events_test.exs` and `validate_event_handler_actions_test.exs` — the first-ever collected tests for those two verifiers — following the same pattern (the events-verifier rejection case needed the same `autogenerate?(false)` fix as Task 2's projection-events case, for the identical reason: `GenerateEventHandlerModules` has the same nil-event-module crash).
- **Confirmed every one of the nine verifiers fails loudly when removed**, not just the three Task 2 explicitly required: commented each out of `lib/commanded/dsl.ex`'s `verifiers/0` list in turn, ran that verifier's test file, confirmed "Expected a Spark.Error.DslError matching: `_` / Got: `[]`" for all nine, restored the file and diffed clean each time. (One near-miss during this check: `ValidateEventHandlerActions` is the last entry in the list with no trailing comma, so a naive `sed 's/X,/#X,/'` silently no-op'd on the first attempt — redone with a comma-agnostic pattern and reconfirmed.)
- **Confirmed the mocking library is gone from `test/` entirely**: `grep -rlE 'with_mock|import Mock' test/` returns nothing, satisfying Plan 01-07's stated precondition for dropping `{:mock, "~> 0.3.0"}`.
- Full suite: 170 tests, 4 failures — the same pre-existing `CommandedApplicationGeneratorTest` meck `:already_started` family owned by Plan 01-06. No new failures.

## Task Commits

1. **Task 1: Rewrite the four command and event verifier tests as compile-time rejections** — `8161126` (test)
2. **Task 2: Rewrite the three projection verifier tests to the same shape** — `989465a` (test)
3. **Task 3: Delete the assertion-free integration test and give the two event-handler verifiers real, collectable tests** — `cd02d63` (test)

**Plan metadata:** committed alongside this SUMMARY (see below)

## Files Created/Modified

- `test/commanded/verifiers/validate_command_names_test.exs` — rewritten: real compilation via `Spark.Test`, replacing `with_mock`/`import Mock` against `Spark.Dsl.Verifier`
- `test/commanded/verifiers/validate_command_fields_test.exs` — same rewrite
- `test/commanded/verifiers/validate_event_names_test.exs` — same rewrite
- `test/commanded/verifiers/validate_event_fields_test.exs` — same rewrite
- `test/commanded/verifiers/validate_projection_actions_test.exs` — same rewrite, with valid-scaffolding-around-the-one-defect pattern
- `test/commanded/verifiers/validate_projection_changes_test.exs` — same rewrite
- `test/commanded/verifiers/validate_projection_events_test.exs` — same rewrite; malformed case uses `autogenerate?(false)` to avoid a transformer crash unrelated to the verifier under test
- `test/commanded/verifiers/validate_event_handler_events_test.exs` (new) — first-ever collected test for `ValidateEventHandlerEvents`
- `test/commanded/verifiers/validate_event_handler_actions_test.exs` (new) — first-ever collected test for `ValidateEventHandlerActions`
- `test/commanded/verifiers/integration_test.exs` (deleted) — see Deviations
- `test/commanded/verifiers/event_handler_tests.exs` (deleted) — see Deviations

## Decisions Made

See `key-decisions` in frontmatter. Summarized: (1) D-14's literal `Code.compile_string` + `assert_raise` mechanism does not work against this repo's Spark 2.7.2 — verified empirically, root-caused to Elixir's `@after_verify` async contract, and replaced with `Spark.Test`, which is Spark's own shipped answer to this exact problem; (2) unique module naming must place the uniqueness in the second-to-last path segment, not the last, because `BaseTransformer.get_module_prefix/1` drops only the last segment; (3) two malformed test resources (the event-reference rejection cases for `ValidateProjectionEvents` and `ValidateEventHandlerEvents`) need `autogenerate?(false)` to avoid an unrelated transformer crash; (4) projection verifier test counts were consolidated from 11 to 9 (one reject/accept/empty triplet per verifier), dropping two assertions whose underlying behavior is unchanged code, not lost coverage.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug in the plan's own locked mechanism] `Code.compile_string` + `assert_raise Spark.Error.DslError` does not work against this repo's Spark version**

- **Found during:** Task 1, before writing any real test file (a standalone probe was run first specifically because the plan's own text anticipated needing to record "what actually surfaced")
- **Issue:** D-14 (CONTEXT.md, RESEARCH.md, PATTERNS.md) specifies wrapping `Code.compile_string/1` in `assert_raise Spark.Error.DslError, ~r/.../`. Empirically, against this repo's resolved Spark 2.7.2, this raises nothing catchable — the verifier's `Spark.Error.DslError` is converted into a stderr compiler warning by Elixir's `@after_verify` mechanism, which Spark uses to run DSL verifiers, and which Elixir's own `Module` documentation states runs with "no guarantees of when in the compilation cycle nor in which process the callback runs." `assert_raise` around the compiling code observed "nothing was raised" in every trial.
- **Fix:** Used `Spark.Test` (`deps/spark/lib/spark/test.ex`), shipped in this exact Spark version specifically to solve this problem (its moduledoc says so almost verbatim). `assert_dsl_error`/`refute_dsl_errors` register the test process as Spark's verifier-error collector before the malformed module is defined, and return the collected `%Spark.Error.DslError{}` for direct regex assertion — achieving every one of this plan's stated `must_haves` (real compilation, regex-matched error, fails loudly if the verifier is removed) through the mechanism this Spark version actually supports.
- **Files modified:** all nine files under `test/commanded/verifiers/`
- **Verification:** Each of the nine verifiers, in turn, commented out of `lib/commanded/dsl.ex`'s `verifiers/0` list, its own test run, confirmed to fail with "no error raised," then `dsl.ex` restored and diffed clean. Probe reproduced independently via both `mix run` and a throwaway ExUnit test before any real file was touched.
- **Committed in:** `8161126` (Task 1), `989465a` (Task 2), `cd02d63` (Task 3) — the same mechanism is used throughout, so this deviation applies to all three commits

**2. [Rule 1 - Bug] Malformed module naming caused generated-module collisions under `async: true`**

- **Found during:** Task 1, first `mix test` run of the rewritten command-fields/event-fields files
- **Issue:** `Module.concat([:"Elixir.AshCommanded.Test.InvalidCommandField#{unique}"])` (a single-segment unique suffix on a multi-part path) still leaves a constant prefix (`AshCommanded.Test`) once `BaseTransformer.get_module_prefix/1` drops the last segment, so every test resource's generated `Commands.RegisterUser` module collided under `async: true`, crashing `GenerateCommandModules`/`GenerateEventModules` with "cannot compile module ... (errors have been logged)."
- **Fix:** Moved the uniqueness to the second-to-last segment: `Module.concat([:"AshCommandedTest#{unique}", :DescriptiveName])`, matching the exact two-segment shape in `.planning/research/PITFALLS.md`'s own worked example (which this plan's Task 1 `<read_first>` pointed at) — a detail that example's rationale ("Elixir's module namespace is global per-VM") already implied but did not spell out with respect to this repo's own module-prefix-dropping transformers.
- **Files modified:** all four Task 1 files, then applied identically to the Task 2 and Task 3 files as they were written
- **Verification:** `mix test` on the four files, repeated with three random seeds, 0 failures
- **Committed in:** `8161126`

**3. [Rule 1 - Bug] Invalid event-name rejection cases crashed a downstream transformer instead of reaching the verifier**

- **Found during:** Task 2 (`ValidateProjectionEvents`) and Task 3 (`ValidateEventHandlerEvents`)
- **Issue:** `GenerateProjectorModules` and `GenerateEventHandlerModules` both look up an event's struct module by name (from a `Transformer.persist`-ed map) to build a `%EventModule{}` pattern in generated code. A deliberately non-existent event name resolves to `nil`, so the generated code tries to pattern-match on `%nil{}`, which crashes the transformer with `RuntimeError: Exception in transformer ... cannot compile module ...` — before `@after_verify` (and this plan's verifier under test) ever runs.
- **Fix:** Added `autogenerate?(false)` to the one malformed projection/handler in each affected test, using the DSL's own existing opt-out for module generation. Confirmed `GenerateProjectionModules` (unaffected by `autogenerate?`, since it doesn't filter on it) has no equivalent crash risk.
- **Files modified:** `test/commanded/verifiers/validate_projection_events_test.exs`, `test/commanded/verifiers/validate_event_handler_events_test.exs`
- **Verification:** Both files pass; the per-verifier "comment out of `dsl.ex`" check confirmed the tests genuinely depend on the verifier, not on the `autogenerate?(false)` scaffolding
- **Committed in:** `989465a` (Task 2), `cd02d63` (Task 3)

**4. [Rule 3 - Blocking, self-caught] A `sed` pattern silently no-op'd on the last verifier in `dsl.ex`'s list**

- **Found during:** the per-verifier "delete and observe failure" manual check, second pass
- **Issue:** The check script's `sed 's/X,/#X,/'` pattern required a trailing comma; `ValidateEventHandlerActions` is the last entry in `verifiers/0`'s list and has none, so the substitution matched nothing, `dsl.ex` was silently unchanged, and the first run of this check showed the test passing with the verifier still fully active — which would have been reported as "confirmed" without the verifier ever actually being removed.
- **Fix:** Caught by inspecting `grep -n "ValidateEventHandlerActions" lib/commanded/dsl.ex` after the "removal" and noticing the line was unchanged (no `#`). Rewrote the pattern to match the line without requiring a trailing comma, reran, and got the correct "no error raised" failure.
- **Files modified:** none (verification tooling only; `lib/commanded/dsl.ex` was never actually left modified)
- **Verification:** `diff` against a saved pre-check copy of `dsl.ex` confirmed no residual change after every check in this plan, including the corrected one
- **Committed in:** n/a (not a code change — documented here because it is exactly the kind of self-check failure the plan's transparency requirement exists to surface)

---

**Total deviations:** 4 (1 plan-mechanism bug, 2 test-construction bugs, 1 self-caught verification-tooling bug). None expanded scope beyond the nine files this plan's `files_modified` already named.
**Impact on plan:** The core deviation (Rule 1, #1) is the most consequential: it replaces this plan's stated D-14 mechanism with an equivalent, verified, Spark-native one, because the literal mechanism cannot work against this repo's dependency versions. Every one of the plan's `must_haves` is still satisfied — the substitution changes *how* the guarantee is achieved, not *whether* it is achieved, and is documented at length (including a reproducible probe) precisely because it deviates from a decision previously locked in CONTEXT.md.

## Issues Encountered

None beyond the deviations above (all self-resolved within this plan's scope; no external blockers, no auth gates).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `mix test test/commanded/verifiers/` → 27 tests, 0 failures, exactly nine files, every one collected by a plain `mix test`
- `grep -rlE 'with_mock|import Mock' test/` → no matches — Plan 01-07 can drop `{:mock, "~> 0.3.0"}` from `mix.exs`
- `mix test` (full suite) → 170 tests, 4 failures, all four in `CommandedApplicationGeneratorTest`'s meck `:already_started` family, still owned by Plan 01-06, unaffected by this plan
- `mix format --check-formatted` on all nine files → clean
- **A repo-wide pattern for future Spark verifier work is now established and should be followed, not rediscovered:** use `Spark.Test`, never `Code.compile_string` + `assert_raise`, for any future compile-time DSL rejection test in this codebase (or, per `01-PATTERNS.md`'s own external-reference framing, in any Spark-based project on this Spark version). Worth surfacing to whichever later phase (Phase 2 per QUAL-06's documentation-reconciliation item, or a dedicated ADR) records locked testing patterns, since D-14 as currently written in `CONTEXT.md`/`RESEARCH.md`/`PATTERNS.md` is now stale and could mislead a future planner who does not re-verify it.

---
*Phase: 01-build-integrity*
*Completed: 2026-09-14*

## Self-Check: PASSED

- FOUND: `test/commanded/verifiers/validate_event_handler_events_test.exs`
- FOUND: `test/commanded/verifiers/validate_event_handler_actions_test.exs`
- FOUND: commit `8161126` (Task 1)
- FOUND: commit `989465a` (Task 2)
- FOUND: commit `cd02d63` (Task 3)
- CONFIRMED: `test/commanded/verifiers/integration_test.exs` no longer exists
- CONFIRMED: `test/commanded/verifiers/event_handler_tests.exs` no longer exists
- CONFIRMED: `ls test/commanded/verifiers/ | wc -l` → 9
- CONFIRMED: `mix test test/commanded/verifiers/` → 27 tests, 0 failures
- CONFIRMED: `mix test` (full suite) → 170 tests, 4 failures (pre-existing, unrelated)
