---
phase: 01-foundation-rendering-enforcement-and-layout
plan: 11
subsystem: ci-gate-and-code-generation
tags: [mix-aliases, github-actions, elixir-1.20, warnings-as-errors, golden-renders, macro-expansion, parity-fixture]

requires:
  - phase: 01-foundation-rendering-enforcement-and-layout
    provides: "01-07's location attribution and parity-fixture wiring, and 01-09's documentation guard and deleted unreachable collectors"
provides:
  - "A gate composed of two direct Mix invocations with the environment chosen by the caller, plus a separate parity script step"
  - "CI invokes mix check, MIX_ENV=test mix coveralls and ./scripts/compile_parity.sh as three separate steps"
  - "The two hand-written Elixir 1.20 warnings removed with no behaviour change"
  - "The four generated-aggregate warnings resolved at macro-expansion time, with a smaller rendered aggregate and no suppression attribute"
  - "The regenerated parity WidgetAggregate golden reviewed and approved by a human"
  - "A recorded deviation for the parity fixture's optional argument in WINDOWS.md"
affects: [01-10-ci-observation, phase-4-aggregates]

actuals:
  tokens: 7308
  tasks: 5
  commits: 3
  plan_head_before: 72cbddf6ac88fe1df5235f11bffe8d1f2c3d6f4c
  plan_head_after: 36584a3aaba959d630aa5822c1b8872a796474dc

tech-stack:
  added: []
  patterns:
    - "Gate composition: one dev alias with only direct Mix steps, and test/parity commands invoked by the caller in their own environment"
    - "Expansion-time decision making: branch on transformer configuration while building AST, never emit a runtime branch on a compile-time literal"
    - "No suppression attributes: fix dead generated code at its source, proven by a rendered golden that shrinks"

key-files:
  modified:
    - mix.exs
    - .github/workflows/ci.yml
    - AGENTS.md
    - README.md
    - .planning/PROJECT.md
    - .planning/ROADMAP.md
    - lib/ash_commanded/middleware/command_middleware_processor.ex
    - lib/ash_commanded/resource/dsl.ex
    - lib/ash_commanded/resource/transformers/generate_aggregate_module.ex
    - test/golden/parity_widget/AshCommanded.TestSupport.Parity.WidgetAggregate.golden
    - test/support/parity/parity_widget.ex
    - .planning/WINDOWS.md

key-decisions:
  - "Remove the cmd shell-out entirely rather than special-case Mix 1.19: the environment switch belongs to the caller, so the :enoent failure class cannot recur on any supported Mix version."
  - "Keep ./scripts/compile_parity.sh as its own CI step: a cross-environment comparison genuinely starts two VMs and is not a basic Mix task."
  - "Resolve the generated-aggregate warnings at macro-expansion time, not with @compile {:nowarn_...}: the rendered module shrank from 267 to 208 lines and clause_max from 131 to 72, with no suppression attribute."
  - "Fix the fourth warning in the parity fixture rather than in GenerateAggregateModule: Ash, not this library, emits input/1 with the literal key in [], so the fixture was the only non-suppression site. A human approved the fixture change at the blocking checkpoint."
  - "Do not mark FOUND-16 complete: the local toolchain is 1.18.4, and only an observed three-leg GitHub Actions run can establish the 1.19.6 and 1.20.4 legs."

patterns-established:
  - "A Mix alias runs in one environment only; anything needing another environment is a caller-side command, never a subprocess inside the alias"
  - "A warning in generated code is evidence of a dead runtime decision; fix it in the transformer so the rendered output gets smaller"
  - "A human-approved generated-output change is recorded as a WINDOWS.md deviation so the approval does not live only in conversation"

requirements-completed: []

coverage:
  - id: D1
    description: "The dev gate is one mix check alias composed of five direct Mix steps, and no alias shells out to a Mix task"
    requirement: FOUND-16
    verification:
      - kind: other
        ref: "grep -nE '\"cmd .*mix' mix.exs (no output); mix check (exit 0)"
        status: pass
    human_judgment: false
  - id: D2
    description: "The test gate is invoked by the caller as MIX_ENV=test mix coveralls and by CI as its own step with MIX_ENV set on the step"
    requirement: FOUND-16
    verification:
      - kind: integration
        ref: "MIX_ENV=test mix coveralls (277 tests, 0 failures, exit 0)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Six Elixir 1.20 compiler warnings eliminated at their source, with no suppression attribute and a smaller rendered aggregate"
    requirement: FOUND-04
    verification:
      - kind: unit
        ref: "test/ash_commanded/golden_render_test.exs and test/ash_commanded/golden_budget_test.exs (pass)"
        status: pass
      - kind: integration
        ref: "mix check (compile --warnings-as-errors, exit 0) and MIX_ENV=test mix coveralls (277 tests, 0 failures)"
        status: pass
    human_judgment: true
    rationale: "The golden was approved by a human at the blocking checkpoint, and the 1.20.4 leg that originally emitted the warnings is not yet observed; the local toolchain is 1.18.4."
  - id: D4
    description: "All three CI matrix legs (1.18.4, 1.19.6, 1.20.4, all OTP 27.3) observed green and recorded as evidence"
    requirement: FOUND-16
    verification: []
    human_judgment: true
    rationale: "Requires an actual GitHub Actions run against a pushed branch; the branch is not pushed, so no run exists yet. This is 01-10 Task 3's observation."

duration: 13h 38m elapsed
completed: 2026-10-20
status: complete
---

# Phase 01 Plan 11: Gap Closure — CI Portability and Warning-Free Generated Code

**Gate rebuilt as two direct Mix invocations, six Elixir 1.20 warnings removed at their source, and the smaller regenerated aggregate golden human-approved — with the three-leg CI observation still owed.**

## Performance

- **Duration:** 13h 38m elapsed, including the Task 4 blocking-human approval pause; active editing time was not separately instrumented.
- **Started:** 2026-10-20T05:14:39Z (Task 1 commit)
- **Completed:** 2026-10-20T18:52:28Z
- **Tasks:** 5 of 5 (Tasks 1-3 autonomous, Task 4 human checkpoint approved, Task 5 verification)
- **Files modified:** 12 (9 project files, 3 planning files)

## Accomplishments

- Removed both `cmd ... mix` alias entries. `mix check` is now five direct dev steps; the test
  half is `MIX_ENV=test mix coveralls`, invoked by the caller. CI runs `mix check`,
  `MIX_ENV=test mix coveralls` and `./scripts/compile_parity.sh` as three separate steps, with
  `MIX_ENV` set on the test step. The Mix 1.19 `:enoent` failure class is structurally gone.
- Removed the two hand-written warnings: the unused `require Logger` in
  `AshCommanded.Resource.Dsl` and the always-true `is_map(command)` conjunct in
  `get_command_middleware/1`, with the fallback behaviour preserved.
- Resolved the four generated-aggregate warnings at macro-expansion time. The transformer now
  emits `metadata: %{}` (or direct field access when the command declares `:metadata`) and only
  the middleware-context assignments a command actually configures, with context keys chosen as
  literals. No `@compile` suppression was added.
- Regenerated and human-approved the parity `WidgetAggregate` golden. The aggregate shrank from
  267 to 208 module lines (`clause_max` 131 to 72); no other golden changed.
- Closed the fourth warning in the parity fixture by declaring one optional argument, so Ash's
  generated `input/1` no longer contains the literal `key in []`.
- Ran the local gate as documented: `mix check` exited 0, and `MIX_ENV=test mix coveralls`
  exited 0 with **277 tests, 0 failures** (77.6% total coverage).
- Deleted the two `documentation/dsls/*.md` files regenerated by `gen.docs`;
  `git status --porcelain -- documentation/dsls` printed nothing at commit time.

## Task Commits

Each autonomous task was committed atomically. Task 4 was a human checkpoint with no commit.

1. **Task 1: replace the shelling-out gate with direct Mix invocations** - `457c768` (fix)
2. **Task 2: remove the two hand-written warnings Elixir 1.20 reports** - `d02abd4` (fix)
3. **Task 3: resolve the four generated-code warnings at macro-expansion time** - `36584a3` (fix)
4. **Task 4: human approval of the changed generated output** - checkpoint only, no commit
5. **Task 5: prove the local gate green and record what CI still has to confirm** - this SUMMARY

**Plan metadata:** the docs commit that carries this SUMMARY, STATE.md, ROADMAP.md and WINDOWS.md.

## Locally Proven vs Still Owed to CI

This distinction is the point of Task 5. The local toolchain is Elixir 1.18.4 / OTP 27.3.

| Fact | Status | Evidence |
| --- | --- | --- |
| No alias shells out to a Mix task | Proven locally | `grep -nE '"cmd .*mix' mix.exs` printed nothing |
| `mix check` exits 0 | Proven locally | exit 0; format, compile --warnings-as-errors, credo (71 checks, 125 files, no issues), dialyzer (4 total / 4 skipped / 1 unnecessary, passed), gen.docs |
| `MIX_ENV=test mix coveralls` exits 0 | Proven locally | 277 tests, 0 failures, 77.6% total coverage |
| No project compiler warnings on 1.18.4 | Proven locally | `compile --warnings-as-errors` inside `mix check`, exit 0 |
| No compiler warnings on 1.19.6 and 1.20.4 | **Not yet observed** | Requires the GitHub Actions matrix run; the branch is unpushed |
| The first-run `:enoent` failure is gone on 1.19.6 | **Not yet observed** | Same run; structural removal is proven, runtime observation is not |
| The 1.20 warning sites are gone on 1.20.4 | **Not yet observed** | Local compiler is 1.18.4 and cannot emit the 1.20 diagnostic |

**FOUND-16 is deliberately not marked complete.** Per the plan, only 01-10 Task 3 may complete it,
after a human observes and records the three-leg run in `01-CI-EVIDENCE.md`.

## Files Created/Modified

- `mix.exs` - `check` and `precommit.fast` contain only direct Mix steps; no `cmd` entry.
- `.github/workflows/ci.yml` - Three separate gate steps; `MIX_ENV` set on the coveralls step.
- `AGENTS.md` - Documents the two-command gate and the separate parity step, and why the test
  invocation is separate.
- `README.md` - Same two-command verification claim.
- `.planning/PROJECT.md` / `.planning/ROADMAP.md` - Gate descriptions kept consistent with `mix.exs`.
- `lib/ash_commanded/resource/dsl.ex` - Unused `require Logger` removed.
- `lib/ash_commanded/middleware/command_middleware_processor.ex` - Redundant `is_map/1` conjunct removed.
- `lib/ash_commanded/resource/transformers/generate_aggregate_module.ex` - Expansion-time metadata
  and context-assignment construction.
- `test/golden/parity_widget/AshCommanded.TestSupport.Parity.WidgetAggregate.golden` - Regenerated
  and human-approved.
- `test/support/parity/parity_widget.ex` - One optional `:source` argument on `create`.
- `.planning/WINDOWS.md` - Deviation 10 recorded.

## Decisions Made

- Remove the shell-out rather than pin or special-case a Mix version. The environment switch is a
  caller concern, so the failure class disappears on every supported version.
- Keep `./scripts/compile_parity.sh` out of the alias. It starts two VMs and is not a basic Mix task.
- Fix generated code at expansion time. The rendered module is 59 lines smaller and gains no
  suppression attribute, which is the observable difference between fixing and silencing.
- Fix the Ash-generated `key in []` in the fixture, not in this library's transformer. The warning
  is not emitted by `GenerateAggregateModule`; the plan's attribution was wrong, and a fixture
  change is the only non-suppression remedy.
- Leave FOUND-16 unmarked until the observed run, even though every local check is green.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical] Corrected the attributed site of the fourth warning**

- **Found during:** Task 3 (resolve generated-code warnings at macro-expansion time)
- **Issue:** The plan attributed the `key in [] || ...` warning to `GenerateAggregateModule` and
  instructed a transformer fix. The expression is generated by Ash itself in the resource's
  `input/1`; no transformer in this library produces it.
- **Fix:** Gave the parity fixture's `create` action one real optional argument
  (`argument :source, :string, allow_nil?: true`), which keeps the generated membership test
  dynamic. No suppression attribute was added. The change is a deviation from the plan's file
  list because it edits the fixture instead of the generator.
- **Files modified:** `test/support/parity/parity_widget.ex`
- **Verification:** `mix check` (which compiles the fixture on the dev path) exits 0; the golden
  diff contains no suppression. A human approved the fixture change at the Task 4 blocking
  checkpoint.
- **Committed in:** `36584a3` (Task 3 commit)
- **Ledger:** recorded as `.planning/WINDOWS.md` entry 10.

**2. [Rule 2 - Missing critical] Kept the project's stated gate consistent with the code**

- **Found during:** Task 1 (replace the shelling-out gate)
- **Issue:** `PROJECT.md` and `ROADMAP.md` both described the old single-alias gate including
  `test` and `scripts/compile_parity.sh`. Leaving those statements in place would have made the
  project's own standing constraints false.
- **Fix:** Updated both descriptions to the two-command composition. The commit also normalizes
  two markdown tables and adds blank lines after headings in those files, per this workspace's
  markdown conventions.
- **Files modified:** `.planning/PROJECT.md`, `.planning/ROADMAP.md`
- **Verification:** Both files now describe the same composition as `mix.exs` and `ci.yml`.
- **Committed in:** `457c768` (Task 1 commit)

**3. [Rule 3 - Blocking] Repaired the WINDOWS ledger's rendered table before appending**

- **Found during:** Task 5 (record the approved deviation)
- **Issue:** `gsd_run windows append` refused to write because the rendered table no longer
  matched its fenced JSON source of truth (pre-existing formatting drift in the separator row),
  blocking the recorded deviation.
- **Fix:** Regenerated the table from the frozen JSON with the tool's own `renderTable`, verified
  byte-identical by `extractTableRegion`, then appended entry 10. No ledger entry changed.
- **Files modified:** `.planning/WINDOWS.md`
- **Verification:** The append returned `ok: true`; `total_count` moved from 9 to 10.
- **Committed in:** the plan metadata commit

---

**Total deviations:** 3 (2 missing-critical, 1 blocking)
**Impact on plan:** All three were necessary for correctness or to finish the task. The fixture
change is the only source edit outside the plan's stated file list, and it was explicitly
human-approved.

## Issues Encountered

- `mix check` passes, but its output contains non-fatal warnings that are not compiler warnings:
  Credo's own module-loading emits "redefining module" notices for the three custom checks, and
  `gen.docs` reports ex_doc reference warnings (`Commanded.Snapshotting` is hidden; two
  `Spark.Dsl.Transformer.t()` references are undefined). None is emitted by
  `mix compile --warnings-as-errors`, and none fails the gate. They are pre-existing and outside
  this plan's scope; recorded here rather than silently ignored.
- `gen.docs` recreates `documentation/dsls/DSL-AshCommanded.{Domain,Resource}.md` on every run.
  They are deliberately not committed, matching the existing pattern where only the two legacy
  `DSL-*.md` files are tracked.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The local gate is green and honestly bounded. All that remains for FOUND-16 is the observed
  three-leg CI run.
- **Blocking handoff:** 01-10 Task 3 must push `fix-application-generation`, watch the matrix run,
  and append the per-leg evidence to `01-CI-EVIDENCE.md` before marking FOUND-16 complete.
- **Not claimed:** this plan does not establish that 1.19.6 or 1.20.4 are green. The 1.20 warnings
  were removed at their source, but the diagnostic itself was never observed locally.

---

*Phase: 01-foundation-rendering-enforcement-and-layout*
*Completed: 2026-10-20*

## Self-Check: PASSED

- SUMMARY.md exists at the expected path.
- Task commits `457c768`, `d02abd4` and `36584a3` are ancestors of HEAD.
- The plan metadata commit is HEAD; it carries this SUMMARY, STATE.md, ROADMAP.md and WINDOWS.md.
- Every file named in this SUMMARY exists in the working tree.
- `mix check` and `MIX_ENV=test mix coveralls` both exited 0 during Task 5.
