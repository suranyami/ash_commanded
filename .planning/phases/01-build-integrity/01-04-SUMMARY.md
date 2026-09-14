---
phase: 01-build-integrity
plan: 04
subsystem: testing
tags: [ash, spark, commanded, ets, elixir, context-propagation]

# Dependency graph
requires:
  - phase: 01-02
    provides: "CommandActionMapper's execute_create/4, execute_update/5, execute_destroy/5 running real Ash actions; the ETS-backed test/support/widget.ex + test_domain.ex fixture"
provides:
  - "CommandActionMapper carries zero Mix.env() branches — all five execution paths (create, update, destroy, read, custom) run real Ash unconditionally (D-08, TEST-01 complete)"
  - "A genuine, previously-unreachable context-propagation defect found and fixed: all five execute_* paths now thread :context through for_action/for_read/ActionInput.for_action's own opts instead of a too-late set_context/2 call"
  - "test/commanded/error_handling_test.exs, context_test.exs, parameter_transformer_errors_test.exs rewritten against real Ash outcomes (Widget or a new context-observing fixture), no assertion left reading an echoed parameter map"
  - "test/support/context_widget.ex — a context-observing ETS fixture, and test/support/custom_action_widget.ex + command_action_mapper_read_custom_test.exs — proof that execute_read/execute_custom actually run against real Ash, not assumed correct"
affects: ["01-05", "01-06", "01-07", "01-08"]

actuals:
  tokens: 7611
  tasks: 2
  commits: 3
  plan_head_before: 4088677fa5ecc79e75d765066efabfd2f7a470f7

tech-stack:
  added: []
  patterns:
    - "Context-observing ETS fixture (test/support/context_widget.ex): a resource whose create action's declarative change copies Ash.Changeset.get_context onto a persisted attribute, purpose-built so a test can prove :context landed on the real changeset rather than trusting the mapper's own return value"
    - "Context must be passed via for_action/4's (or for_read/4's, or ActionInput.for_action/4's) own :context opt, never via a set_context/2 call issued after for_action returns — Ash runs declarative changes/validations/preparations DURING changeset construction, so anything set afterward never reaches them"

key-files:
  created:
    - "test/support/context_widget.ex"
    - "test/support/custom_action_widget.ex"
    - "test/commanded/command_action_mapper_read_custom_test.exs"
  modified:
    - "lib/commanded/command_action_mapper.ex"
    - "lib/commanded/error.ex"
    - "test/commanded/error_handling_test.exs"
    - "test/commanded/context_test.exs"
    - "test/commanded/parameter_transformer_errors_test.exs"

key-decisions:
  - "Rule 1 auto-fix, discovered mid-plan: all five execute_* functions set context via set_context/2 AFTER for_action/for_read, which is too late for declarative changes/validations/preparations to observe it (they run during for_action/for_read, not later). Fixed by threading context: context through for_action/for_read/ActionInput.for_action's opts directly on all five paths, not just the two (read, custom) this plan's task list named."
  - "context_test.exs could not be pointed at the shared Widget fixture (Widget's create action has no context-observing change, and adding one would be an unrelated edit to a fixture other plans in this wave also read) — added a new, purpose-built test/support/context_widget.ex fixture instead, following the same real-Ash-resource pattern Widget itself established."
  - "Read/custom path proof (must_haves TEST-01) was not assigned to either task's file list, but the plan's own must_haves explicitly required it and neither path had ever executed before this plan — added test/support/custom_action_widget.ex (a generic-action fixture, needed because Ash.ActionInput.for_action requires a resolvable domain that domain: nil doesn't satisfy) and command_action_mapper_read_custom_test.exs as a Rule 2 auto-add, committed as part of Task 1."
  - "The parameter_transformer_errors_test.exs rewrite does not make ParameterTransformer itself raise or return an error tuple — by design (per its own moduledoc and the four 'safely handles...' tests above it) it never does. Instead, a cast that fails to convert leaves an attribute (:age) in place that Widget's create action does not accept, and the real Ash action is what now rejects the command — proven by an Ash.get read-back finding no record. This is the real-world manifestation the mock's unconditional {:ok, _} previously hid."

patterns-established:
  - "When a test needs to prove :context reached a real Ash action, attach a declarative change that copies context onto a persisted attribute and assert on the read-back record — never assert on CommandActionMapper's own return value, which no longer echoes anything."

requirements-completed: [TEST-01, TEST-04]

coverage:
  - id: D1
    description: "CommandActionMapper.execute_read/4 and execute_custom/4 run real Ash unconditionally, with zero Mix.env() branches remaining anywhere in the module"
    requirement: "TEST-01"
    verification:
      - kind: other
        ref: "grep -c 'Mix.env()' lib/commanded/command_action_mapper.ex -> 0"
        status: pass
      - kind: unit
        ref: "test/commanded/command_action_mapper_read_custom_test.exs#execute_read/4 against a real Ash resource, #execute_custom/4 against a real Ash resource"
        status: pass
    human_judgment: false
  - id: D2
    description: "A genuine context-propagation defect (context set too late to reach declarative changes/validations/preparations) is fixed across all five execute_* paths"
    requirement: "TEST-04"
    verification:
      - kind: unit
        ref: "test/commanded/context_test.exs#context propagation context is built correctly in command execution, #context propagation context with prefix is built correctly"
        status: pass
    human_judgment: false
  - id: D3
    description: "error_handling_test.exs, context_test.exs and parameter_transformer_errors_test.exs assert real Ash outcomes reached through a real fixture, never an echoed parameter map"
    requirement: "TEST-04"
    verification:
      - kind: unit
        ref: "mix test test/commanded/error_handling_test.exs test/commanded/context_test.exs test/commanded/parameter_transformer_errors_test.exs -> 26 tests, 0 failures"
        status: pass
      - kind: other
        ref: "mix test ... --seed 4242 -> 0 failures (order-independent)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Plan 01-02's tests and the rest of test/commanded/ are unaffected by this plan's changes; only the pre-existing, differently-owned meck failures remain"
    requirement: "TEST-01"
    verification:
      - kind: unit
        ref: "mix test test/commanded/command_action_mapper_test.exs test/commanded/aggregate_end_to_end_test.exs test/commanded/command_action_mapper_read_custom_test.exs -> 14 tests, 0 failures"
        status: pass
      - kind: other
        ref: "mix test -> 167 tests, 4 failures, all four in CommandedApplicationGeneratorTest (meck :already_started family, owned by plan 01-06)"
        status: pass
    human_judgment: false

duration: 26min (active) — see Performance note on the signing-agent pause
completed: 2026-09-14
status: complete
---

# Phase 1 Plan 4: CommandActionMapper's Last Two Branches, and a Context Bug the Mocks Hid Summary

**Removed the last two `Mix.env() == :test` branches from `CommandActionMapper` (read, custom), proved both against real Ash fixtures for the first time ever, and — while rewriting `context_test.exs` to assert on a real persisted outcome instead of an echoed return value — found and fixed a genuine defect: all five execution paths set `:context` on the changeset/query *after* `for_action`/`for_read` had already run the action's declarative changes, so context could never actually reach them.**

## Performance

- **Duration:** ~26 min of active work (Task 1 commit 11:56, Task 2 RED/GREEN commits 13:17). The gap between those two windows was a 1Password SSH-agent signing outage — the interactive approval prompt timed out while the user was away from the keyboard — during which the executor correctly stopped rather than bypass signing, and resumed once the user returned and approved. No work was lost; the working tree sat exactly as left.
- **Started:** 2026-09-14T11:54:00+10:00 (approx., first verification run)
- **Completed:** 2026-09-14T13:17:34+10:00
- **Tasks:** 2 (1 auto, 1 TDD)
- **Files modified:** 8 (3 created, 5 modified)

## Accomplishments

- Deleted the `Mix.env() == :test` branches around `execute_read/4` and `execute_custom/4` — all five `CommandActionMapper` execution paths (create, update, destroy, read, custom) now run real Ash unconditionally. `grep -c 'Mix.env()' lib/commanded/command_action_mapper.ex` returns 0.
- Fixed the same dead `{:ok, nil}`-ordering defect Plan 01-02 found in `execute_update`/`execute_destroy`, now also present (and fixed) in `execute_read/4`: `Ash.read_one/1` returns `{:ok, nil}` for "no match," never a bare `nil`, so the not-found clause must be matched before the general `{:ok, record}` clause.
- Cleared the misleading "Mock implementation for tests" comment on `from_commanded_error/1` — it is, and always was, the library's only implementation.
- **Proved the read and custom paths actually work, rather than assuming so.** Neither had ever executed before this plan (the mocks always intercepted them). Added `test/support/custom_action_widget.ex` (a generic-action ETS fixture with its own domain — `Ash.ActionInput.for_action/3` needs a resolvable domain, unlike `Ash.Changeset.for_action/3`, so `domain: nil` isn't sufficient) and `test/commanded/command_action_mapper_read_custom_test.exs`, which exercises `execute_read/4` (real persisted record, not-found case) and `execute_custom/4` (dispatch through `Ash.run_action/1` to a resource's declared generic action). This wasn't in either task's file list — it was required by the plan's own `must_haves` and by the explicit instruction not to declare these paths correct on inspection alone, so it was added as a Rule 2 auto-fix.
- Rewrote `error_handling_test.exs`'s "Command action mapper error handling" tests against the real `Widget` fixture (kept the pure `Error`-construction/formatting tests unchanged — they never depended on the mapper) and added a new test proving a genuine `Ash.Error.Invalid` (an unparseable `:id`) normalizes correctly through `from_ash_error/1` — a path the create mock previously made impossible to reach. 14 → 15 tests.
- Rewrote `parameter_transformer_errors_test.exs`'s mapper-calling test against `Widget`, adding the negative assertion the mock made impossible: a cast that fails to convert leaves `:age` — an attribute Widget's create action does not accept — in the params, so the real Ash action rejects the command; confirmed via `Ash.get` finding no record. 6 → 6 tests (rewritten in place).
- **Found and fixed a genuine, previously-unreachable defect while rewriting `context_test.exs`** (see "The context bug" below). 5 → 5 tests (rewritten in place).

## The context bug — the most valuable thing this plan found

All five `CommandActionMapper.execute_*` functions built a changeset or query, called `Ash.Changeset.for_action/3` (or `Ash.Query.for_read/2`, or `Ash.ActionInput.for_action/3`), and only **then** called `Ash.Changeset.set_context/2` (or `Ash.Query.set_context/2`, or `Ash.ActionInput.set_context/2`) with the caller-supplied `:context` option.

That ordering is wrong. Ash runs an action's declarative changes, validations and preparations **during** `for_action`/`for_read` (changeset/query construction) — not later, at `Ash.create`/`Ash.update`/`Ash.destroy`/`Ash.run_action` time. Confirmed directly against `deps/ash/lib/ash/changeset/changeset.ex`'s `do_for_action/4`: it calls `Ash.Actions.Helpers.set_context_and_get_opts/3` (which merges `opts[:context]` into the changeset) and *then* `run_action_changes/6` (which actually runs the changes) — both inside `for_action`, before it ever returns to the caller. The same `set_context_and_get_opts` pattern is used by `Ash.Query.for_read/4` and `Ash.ActionInput.for_action/4`. Context set via a separate `set_context/2` call issued after `for_action`/`for_read` returns therefore arrives strictly too late — every declarative change or preparation attached to the action has already finished running with whatever context existed before the caller's custom keys were merged in (in practice, just Ash's own `%{private: ...}` defaults).

**Why nothing caught this before:** the bug was **unreachable** while the `Mix.env() == :test` mocks were in place. The mocked `execute_create`/`execute_update`/`execute_destroy` never touched a real changeset at all — they echoed `opts[:context]` straight back in their return value, so any test asserting on that return value would see exactly what it passed in, regardless of whether a real Ash action (or anything attached to one) ever received it. The previous `context_test.exs` asserted on a **hand-built dictionary and, where it touched the mapper at all, a `MockCommandActionMapper.map_to_action/4` that was defined but never actually called** — it was vacuous in exactly the way this whole phase exists to find and fix (D-17).

The rewrite in this plan replaced that with a real assertion: a new `test/support/context_widget.ex` fixture attaches a declarative `change` to its create action that copies `Ash.Changeset.get_context(changeset)` onto a persisted `:context_probe` attribute, and the test reads that attribute back via `Ash.get!/2` after the real action runs. This is the only kind of assertion that can distinguish "the mapper's opts contained the right context" from "the real Ash action actually saw it" — and it is precisely what caught the bug: the first run showed `context_probe` containing only Ash's default `%{private: ...}`, missing every custom key (`:aggregate`, `:metadata`, `:app_version`, the prefixed `:"test.aggregate"`) the test had passed in.

**RED → GREEN, TDD:** `c737a41` (test) added the rewritten `context_test.exs` (and the two other files, and the new fixture) against the still-broken mapper; the two "context is built..." tests failed for exactly this reason (`context_probe` missing the custom keys). `5456c87` (fix) threaded `context: context` through `for_action`/`for_read`/`ActionInput.for_action`'s own opts on all five execution paths — not just the two (`execute_read`, `execute_custom`) this plan's task list originally named, since the defect was identical in `execute_create`, `execute_update` and `execute_destroy` (Plan 01-02's territory, but the same file and the same production correctness issue). Both new tests then passed, and the full `test/commanded/` suite (167 tests) showed no new failures — only the four pre-existing, differently-owned meck failures remained.

**Impact:** any consumer relying on `:context` (e.g. actor/tenant propagation, or a declarative change/validation/preparation reading `changeset.context`) to reach a real Ash action through `CommandActionMapper` was silently getting none of it, on every one of the five action types, since whenever this code was first written. This was invisible until the fixture and assertion existed to observe it.

## The Ash.run_action/3 arity problem — still open, not touched by this plan

Plan 01-03's `deferred-items.md` flagged that `lib/commanded/transformers/generate_event_handler_modules.ex:223` generates code calling `Ash.run_action(resource_module, action_name, params)` — a 3-arity call that does not exist (the real function is `Ash.run_action/1`, taking an `%Ash.ActionInput{}`). This plan's `execute_custom/4` in `command_action_mapper.ex` uses the **correct** `Ash.run_action(action_input)` (1-arity) call — confirmed unchanged in behaviour by this plan (only the `for_action` opts changed, per the context fix above) and confirmed via `mix test` producing no warning for it, unlike the generated-code call site.

`generate_event_handler_modules.ex` was not touched by this plan (`git diff --stat` against this plan's starting commit shows zero changes to that file). The 3-arity bug remains exactly as Plan 01-03 logged it: dead-by-construction (no test in the suite dispatches an event through a generated handler at runtime, so the warning is compile-time only), requiring a real design decision (branching on the target action's type via `Ash.Resource.Info.action/2` to dispatch correctly) rather than a mechanical fix — out of scope for this plan, exactly as Plan 01-03 anticipated when it wrote "mirrors how Plan 01-04 owns `execute_read`/`execute_custom`." It is still logged in `deferred-items.md` and still needs an owner.

## Task Commits

1. **Task 1: Remove the last two mapper branches and the misleading error comment** — `1ed421c` (feat). Includes the Rule 2 auto-add of `test/support/custom_action_widget.ex` and `test/commanded/command_action_mapper_read_custom_test.exs`, proving `execute_read`/`execute_custom` against real Ash.
2. **Task 2: Rewrite the three remaining mapper-calling test files** — RED `c737a41` (test), GREEN `5456c87` (fix). No REFACTOR commit — no cleanup beyond the context-timing fix was identified.

**Plan metadata:** committed alongside this SUMMARY (see below)

## Files Created/Modified

- `lib/commanded/command_action_mapper.ex` — Task 1: deleted `Mix.env()` branches around `execute_read/4`/`execute_custom/4`, fixed the dead `nil ->` clause in `execute_read/4`. Task 2 GREEN: threaded `context: context` through `for_action`/`for_read`/`ActionInput.for_action`'s opts on all five execution paths.
- `lib/commanded/error.ex` — removed the stale "Mock implementation for tests" comment on `from_commanded_error/1`; behaviour unchanged.
- `test/support/custom_action_widget.ex` (new) — ETS resource with a generic action and its own domain, used to prove `execute_custom/4` runs against real Ash.
- `test/commanded/command_action_mapper_read_custom_test.exs` (new) — proves `execute_read/4` and `execute_custom/4` against real Ash fixtures.
- `test/support/context_widget.ex` (new) — ETS resource whose create action's declarative change copies real changeset context onto a persisted attribute; the fixture that caught the context bug.
- `test/commanded/error_handling_test.exs` — mapper-calling tests pointed at `Widget`; added a real-Ash-error normalization test.
- `test/commanded/context_test.exs` — the two "context is built..." tests rewritten to assert on a real persisted outcome via `ContextWidget` instead of a hand-built dictionary or an uncalled mock.
- `test/commanded/parameter_transformer_errors_test.exs` — mapper-calling test pointed at `Widget`; added the not-written assertion via `Ash.get`.

## Decisions Made

See `key-decisions` in frontmatter — summarized: (1) the context-timing fix was applied to all five paths, not just the two this task's file list named, because the defect and the file were the same; (2) `context_test.exs` needed a new fixture (`ContextWidget`) rather than `Widget` itself, since proving context propagation requires a declarative change Widget doesn't have and other plans in this wave read that file; (3) the read/custom proof (`custom_action_widget.ex` + its test) was added as a Rule 2 auto-fix beyond either task's declared file list, driven by the plan's own `must_haves`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `execute_create`/`execute_update`/`execute_destroy`/`execute_read`/`execute_custom` set context too late for declarative changes to observe it**

- **Found during:** Task 2, RED phase (the rewritten `context_test.exs` failed for exactly this reason)
- **Issue:** All five functions called `set_context/2` (or the `Query`/`ActionInput` equivalent) *after* `for_action`/`for_read`/`ActionInput.for_action`, but Ash runs declarative changes/validations/preparations *during* that call, not after
- **Fix:** Pass `context: context` as an opt directly to `for_action`/`for_read`/`ActionInput.for_action` on all five paths
- **Files modified:** `lib/commanded/command_action_mapper.ex`
- **Verification:** `test/commanded/context_test.exs`'s two context tests pass; full `test/commanded/` suite shows no new failures (167 tests, same 4 pre-existing meck failures)
- **Committed in:** `5456c87` (GREEN commit)

**2. [Rule 1 - Bug] `execute_read/4`'s dead `nil ->` clause never matched `Ash.read_one`'s actual not-found return shape**

- **Found during:** Task 1, while deleting the environment branch (same class of defect Plan 01-02 already fixed in `execute_update`/`execute_destroy`)
- **Issue:** `Ash.read_one/1` returns `{:ok, nil}` for "no record found," never a bare `nil` — the `nil ->` clause could never fire, and `{:ok, record}` matched first, binding `record = nil`
- **Fix:** Reordered the `case` to match `{:ok, nil}` before `{:ok, record}`
- **Files modified:** `lib/commanded/command_action_mapper.ex`
- **Verification:** `test/commanded/command_action_mapper_read_custom_test.exs`'s not-found test passes
- **Committed in:** `1ed421c` (Task 1 commit)

**3. [Rule 2 - Missing critical coverage] `execute_read/4` and `execute_custom/4` had never actually executed and were not covered by any test in either task's assigned scope**

- **Found during:** Task 1, after deleting the environment branches
- **Issue:** The plan's own `must_haves` required proof these paths run against real Ash, but neither task's file list included a test proving it
- **Fix:** Added `test/support/custom_action_widget.ex` (a generic-action fixture with its own domain, since `Ash.ActionInput.for_action` needs a resolvable domain that `domain: nil` doesn't satisfy) and `test/commanded/command_action_mapper_read_custom_test.exs`
- **Files modified:** new files, listed above
- **Verification:** 3 tests, 0 failures
- **Committed in:** `1ed421c` (Task 1 commit)

---

**Total deviations:** 3 auto-fixed (2 Rule 1 bugs, 1 Rule 2 missing coverage)
**Impact on plan:** All three were required for the plan's own stated goal (proving the previously-mocked paths genuinely work, and that context genuinely reaches a real Ash action). None expanded scope beyond `command_action_mapper.ex` (already in Task 1's file list) plus new fixture/test files the plan's `must_haves` and `context_test.exs`'s own action text explicitly anticipated needing.

## Issues Encountered

**1Password SSH-agent signing outage (not a deviation, an external interruption):** mid-plan, `git commit` began failing with `error: 1Password: failed to fill whole buffer` on every attempt (5 retries, plus direct reproduction against the `op-ssh-sign` binary independent of git). Per instructions, the executor stopped and reported it as a blocker rather than bypass signing with `--no-gpg-sign`. The coordinator confirmed the cause was the user being away from the keyboard when 1Password's interactive approval prompt fired, not an agent malfunction. Signing recovered once the user returned; both pending commits (RED and GREEN) then succeeded on the first attempt with no changes to their content. No work was lost — the working tree sat exactly as left, staged/unstaged as it had been prepared.

No other issues encountered.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `grep -rn "Mix.env()" lib/` returns 0 — the `Mix.env()` half of SC1 is fully satisfied across the whole `lib/` tree, not just this file
- `grep -rn "IO.puts\|IO.inspect" lib/` returns 0 (confirmed still clean, unrelated to this plan)
- `mix test` — 167 tests, 4 failures, all four in `CommandedApplicationGeneratorTest`'s meck `:already_started` family, owned by Plan 01-06
- `mix compile` — 0 warnings from this plan's changes (the pre-existing `Ash.run_action/3` warning from `generate_event_handler_modules.ex` remains, unowned, logged in `deferred-items.md`)
- `CommandActionMapper` is now fully unguarded and its context-handling defect fixed — safe foundation for Plan 01-06 (parity fixture work) and any later plan needing reliable actor/tenant/context propagation through the mapper
- Plan 01-05 was explicitly NOT started per coordinator instruction

---
*Phase: 01-build-integrity*
*Completed: 2026-09-14*

## Self-Check: PASSED

- FOUND: `test/support/custom_action_widget.ex`
- FOUND: `test/support/context_widget.ex`
- FOUND: `test/commanded/command_action_mapper_read_custom_test.exs`
- FOUND: commit `1ed421c` (Task 1)
- FOUND: commit `c737a41` (Task 2 RED)
- FOUND: commit `5456c87` (Task 2 GREEN)
