---
phase: 01-build-integrity
plan: 01
subsystem: build-tooling
tags: [mix, elixir, commanded, eventstore, ash, spark, credo, dialyxir, excoveralls, usage_rules]

# Dependency graph
requires: []
provides:
  - "mix.exs declares :commanded as a hard runtime dependency (D-01)"
  - "mix.exs declares :eventstore and :commanded_eventstore_adapter as optional: true (D-02)"
  - "elixirc_paths/1 with three clauses (:test -> lib+test/support, :dev -> lib+test/support/parity, _ -> lib) for Plan 02 and Plan 06 to build on"
  - "mix setup alias (local.hex --force, local.rebar --force, deps.get, deps.compile) that works with no rebar3 on PATH"
  - "ExCoveralls test_coverage/preferred_cli_env project config for Plan 07/coverage gates"
  - "dialyzer: [ignore_warnings: .dialyzer_ignore.exs, plt_file: priv/plts/project.plt] project config for Plan 07"
  - "in-flight fix-application-generation lib/ work captured as a standalone baseline commit (b481ae1), ancestor of the toolchain commit (D-27)"
affects: ["01-02", "01-03", "01-06", "01-07", "01-08"]

actuals:
  tokens: 6470
  tasks: 3
  commits: 1
  plan_head_before: b481ae1c48f19d23db8ee87a628c96d5e95070a6

tech-stack:
  added:
    - "commanded ~> 1.4 (resolved 1.4.11) - hard runtime dependency"
    - "eventstore ~> 1.4 (resolved 1.4.8), optional: true"
    - "commanded_eventstore_adapter ~> 1.4 (resolved 1.4.2), optional: true"
    - "credo ~> 1.7 (resolved 1.7.19), only: [:dev, :test], runtime: false"
    - "dialyxir ~> 1.4 (resolved 1.4.8), only: [:dev, :test], runtime: false"
    - "excoveralls ~> 0.18 (resolved 0.18.5), only: [:test]"
    - "usage_rules ~> 1.2 (resolved 1.2.8), only: [:dev]"
    - "spark bumped ~> 2.3 -> ~> 2.6 (resolved 2.7.2, matches Ash's own >= 2.6.0 floor)"
  patterns:
    - "elixirc_paths/1 per-Mix.env() compile parity (D-13/D-19) — dedicated test/support and test/support/parity paths, neither of which exists yet, compiling cleanly today as an empty glob"

key-files:
  created: []
  modified:
    - "mix.exs"
    - "mix.lock"

key-decisions:
  - "Task 1 was satisfied by a pre-existing orchestrator commit (b481ae1), not re-created — both plan `<verify>` commands passed against it as-is"
  - "Task 2 package-legitimacy checkpoint (gate=blocking-human) was approved by the coordinator with hex.pm evidence for all seven packages before any fetch occurred"
  - "ash was left at its already-locked 3.5.8 (unchanged constraint ~> 3.0); only spark's constraint changed (~> 2.3 -> ~> 2.6), which is what drove its resolution to 2.7.2 — no unrelated dependency was force-upgraded"
  - "Found and removed a pre-existing unused mix.lock entry (:inflex, unrelated to this plan's added packages) while verifying mix deps.unlock --check-unused — required to satisfy this plan's own <verify> gate"

patterns-established:
  - "elixirc_paths(Mix.env()) with three clauses, activated by Plan 02 (test/support) and Plan 06 (test/support/parity)"

requirements-completed: [QUAL-01, REPO-03, REPO-04]

coverage:
  - id: D1
    description: "In-flight fix-application-generation lib/ work committed verbatim as its own baseline, strictly before any Phase 1 mix.exs edit (D-27)"
    requirement: "REPO-04"
    verification:
      - kind: other
        ref: "git status --porcelain -- lib/ (empty) && git log -1 --format=%H -- lib/commanded/transformers/generate_aggregate_module.ex (b481ae1)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Package-legitimacy checkpoint: all seven new hex.pm dependencies verified against their source repos before any mix deps.get fetch"
    requirement: "QUAL-01"
    verification: []
    human_judgment: true
    rationale: "gate=\"blocking-human\" by design — a supply-chain identity check must be confirmed by a human, not self-approved. Coordinator supplied a hex.pm evidence table for all seven packages (versions, release dates, source repos, owners) and explicitly chose not to pin the two freshest releases (dialyxir 1.4.8, usage_rules 1.2.8)."
  - id: D3
    description: "mix.exs declares commanded/eventstore/commanded_eventstore_adapter/credo/dialyxir/excoveralls/usage_rules, elixir ~> 1.18, elixirc_paths/1, ExCoveralls + Dialyzer project config, and a setup alias; mix setup and mix compile succeed from a clean deps/_build with zero warnings"
    requirement: "REPO-03"
    verification:
      - kind: other
        ref: "rm -rf deps _build && mix setup (exit 0)"
        status: pass
      - kind: other
        ref: "mix compile (exit 0, 0 warnings)"
        status: pass
      - kind: other
        ref: "mix deps.unlock --check-unused (exit 0, clean)"
        status: pass
      - kind: other
        ref: "mix format --check-formatted mix.exs (exit 0)"
        status: pass
    human_judgment: true
    rationale: "The task's own <verify> block includes a <human-check>: confirming mix setup works with no rebar3 pre-installed on PATH, on a genuinely fresh machine — CI's erlef/setup-beam images pre-install rebar3, so CI structurally cannot observe this failure mode. This executor's environment installed rebar3 fresh via mix local.rebar --force during mix setup (no rebar3 archive existed beforehand), which is strong corroborating evidence, but the plan explicitly scopes the definitive check to end-of-phase human verification (workflow.human_verify_mode: end-of-phase)."

duration: 25min
completed: 2026-09-14
status: complete
---

# Phase 1 Plan 1: Build Integrity Toolchain Foundation Summary

**Declared `:commanded` as a hard runtime dependency, bumped `spark` to `~> 2.6`, added the credo/dialyxir/excoveralls/usage_rules static-analysis stack, and made `mix setup` work with no rebar3 pre-installed — unblocking every other Phase 1 plan.**

## Performance

- **Duration:** ~25 min (Task 3 work; Task 1 was pre-existing, Task 2 was a human checkpoint pause)
- **Started:** 2026-09-14T07:50:29+10:00 (Task 1 baseline commit, made by orchestrator before this execution)
- **Completed:** 2026-09-14T08:05:52+10:00 (Task 3 commit)
- **Tasks:** 3 (1 verified as pre-satisfied, 1 checkpoint approved, 1 executed)
- **Files modified:** 2 (`mix.exs`, `mix.lock`)

## Accomplishments

- Verified the in-flight `fix-application-generation` `lib/` work was already committed verbatim as a standalone baseline (`b481ae1`), ancestor of this plan's toolchain commit — satisfying D-27's sequencing requirement without re-creating any commit
- Human-approved package-legitimacy checkpoint for all seven new hex.pm dependencies (`commanded`, `eventstore`, `commanded_eventstore_adapter`, `credo`, `dialyxir`, `excoveralls`, `usage_rules`) before any fetch occurred
- Declared `:commanded` as a hard runtime dependency, `:eventstore`/`:commanded_eventstore_adapter` as `optional: true`, and the four dev/test tooling packages, per D-01/D-02/D-03/D-04/D-05
- Raised `elixir:` to `~> 1.18` (REPO-04) and bumped `spark` from `~> 2.3` to `~> 2.6` (Ash's own `mix.exs` requires `>= 2.6.0`)
- Added `elixirc_paths/1` (three clauses) so Plan 02's `test/support` and Plan 06's `test/support/parity` will compile under the right `Mix.env()` once created
- Added ExCoveralls (`test_coverage`, `preferred_cli_env`) and Dialyzer (`ignore_warnings`, `plt_file`) project config for Plan 07
- Added a `setup` alias (`local.hex --force`, `local.rebar --force`, `deps.get`, `deps.compile`) — verified from a `rm -rf deps _build` clean state, `mix setup` and `mix compile` both succeed with zero warnings in `ash_commanded`'s own code
- Found and removed a pre-existing unused `mix.lock` entry (`:inflex`, unrelated to this plan's additions) to satisfy `mix deps.unlock --check-unused`

## Task Commits

1. **Task 1: Commit the in-flight fix-application-generation work as-is** — `b481ae1` (pre-existing, made by the orchestrator before this plan's execution began; verified via both `<verify>` commands, not re-created)
2. **Task 2: Verify the legitimacy of the seven packages before any of them is fetched** — checkpoint, no commit (human approval recorded in this SUMMARY's coverage block)
3. **Task 3: Declare the toolchain in mix.exs and make `mix setup` work** — `f37681f` (feat)

**Plan metadata:** committed alongside this SUMMARY (see below)

## Files Created/Modified

- `mix.exs` — added `commanded`/`eventstore`/`commanded_eventstore_adapter`/`credo`/`dialyxir`/`excoveralls`/`usage_rules` deps, bumped `spark` to `~> 2.6`, raised `elixir:` to `~> 1.18`, added `elixirc_paths/1`, `test_coverage`/`preferred_cli_env`, `dialyzer:` project config, and a `setup` alias
- `mix.lock` — resolved versions for all seven new packages and their transitive closure; removed a pre-existing unused `:inflex` entry

## Decisions Made

- Task 1's commit was not re-created — the orchestrator's `b481ae1` already satisfied both of the task's `<verify>` commands, so re-committing would have been redundant and risked disturbing D-27's "no rebase, no edits" constraint
- `ash` was left at its already-resolved `3.5.8` — its declared constraint (`~> 3.0`) did not change in this plan, so `mix deps.get` had no reason to move it; only `spark`'s constraint change drove a re-resolution
- Chose not to pin `dialyxir` or `usage_rules` to their previous patch despite being very recent releases (9 and 7 days old respectively at commit time) — the coordinator reviewed the hex.pm evidence and explicitly opted to take current versions per D-05 ("permissive bounds, current lock")

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed a pre-existing unused `mix.lock` entry (`:inflex`)**

- **Found during:** Task 3, while running the plan's own `<verify>` gate `mix deps.unlock --check-unused`
- **Issue:** `mix.lock` (as committed prior to this plan) already carried an `:inflex` entry that no declared or transitive dependency requires. This predates this plan's changes but caused this plan's own required verification gate to fail (exit 1, "Unused dependencies in mix.lock file: :inflex").
- **Fix:** Ran `mix deps.unlock --unused`, which removed the single unused `:inflex` entry from `mix.lock`.
- **Files modified:** `mix.lock` (part of the same commit as the toolchain declaration, since `mix.lock` is this task's own file)
- **Verification:** Re-ran `mix deps.unlock --check-unused` — exit 0, clean. Re-ran `mix compile` and `mix setup` from a clean `deps/_build` afterward — both still succeed with zero warnings.
- **Committed in:** `f37681f` (Task 3 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Necessary to satisfy this plan's own `<verify>` gate; no scope creep — the fix was scoped entirely to `mix.lock`, which this task already owns.

## Issues Encountered

- Immediately after `mix local.hex --force`, the very first `mix setup` invocation failed with `Could not start Hex ... (bad_return, {:EXIT, {:undef, ...}})`. A second `mix local.hex --force` (without `--force` re-run causing any visible difference in output) resolved it, and every subsequent `mix setup`/`mix hex.info` call succeeded. Treated as a transient local Hex-archive activation glitch in this environment, not a defect in the plan's `setup` alias — the alias itself (`local.hex --force`, `local.rebar --force`, `deps.get`, `deps.compile`) is exactly what the plan specifies, and it now succeeds repeatably from a clean `deps/_build`.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `mix setup` and `mix compile` both succeed from a clean `deps/_build` with zero warnings in `ash_commanded`'s own code (transitive `ash`/`reactor` deprecation warnings about `__spark_metadata__` come from those dependencies' own compiled sources under the bumped `spark` version, not from anything in this repo — out of scope for this plan, tracked as dependency-internal noise, not a regression this plan introduced)
- `elixirc_paths/1` exists with the exact three clauses Plan 02 (`test/support`) and Plan 06 (`test/support/parity`) depend on — both directories are still absent and will be created by those plans
- No `check` alias exists yet — Plan 07 owns it
- `.dialyzer_ignore.exs` does not exist yet — Plan 07 seeds it; `dialyxir` tolerates its absence in the meantime
- The end-of-phase human-verify step (per `workflow.human_verify_mode: end-of-phase`) still owes one manual check this plan could not perform in-session: cloning to a genuinely separate machine with no rebar3 ever installed and confirming `mix setup && mix compile` succeed with no interactive prompt
- Ready for Plan 02

---
*Phase: 01-build-integrity*
*Completed: 2026-09-14*
