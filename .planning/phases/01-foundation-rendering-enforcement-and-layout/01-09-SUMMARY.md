---
phase: 01-foundation-rendering-enforcement-and-layout
plan: 09
subsystem: dsl-documentation
tags: [spark-dsl, transformers, documentation, guard-test, windows-ledger, golden-renders]

requires:
  - phase: 01-foundation-rendering-enforcement-and-layout
    provides: "01-08's atom-cast trust boundary correction, preserved inside the re-framed ParameterTransformer example"
provides:
  - "No registered transformer walks a DSL block it cannot receive"
  - "A suite-level assertion that the command entity declares no nested entities"
  - "A two-sided guard that fails when documentation advertises an undeclared nested block"
  - "Measured proof that the deletions changed no generated output"
  - "A Phase 7-owned WINDOWS.md entry for the remaining module-path documentation drift"
affects: [phase-2-commands-and-events, phase-3-application-and-routers, phase-7-documentation-packaging]

actuals:
  tokens: 14046
  tasks: 3
  commits: 3
  plan_head_before: ab6616631638bcb7e871865c526b5bcb60475e73
  plan_head_after: a620d388a8d21b4ac52eb9b1abf6f268b5988990

tech-stack:
  added: []
  patterns:
    - "Two-sided documentation guard: a nested block is legal when the extension declares it, otherwise its declaration count must be zero"
    - "Occurrence-counting scan over an explicitly enumerated file set, excluding the guard's own source and .planning/"

key-files:
  created:
    - test/ash_commanded/documented_dsl_surface_test.exs
  modified:
    - lib/ash_commanded/resource/dsl.ex
    - lib/ash_commanded/resource/transformers/collect_transaction_options.ex
    - lib/ash_commanded/parameter_transformer.ex
    - lib/ash_commanded/parameter_validator.ex
    - README.md
    - documentation/parameter_handling.md
    - documentation/commands.md
    - documentation/transactions.md
    - cheatsheets/AshCommanded.Resource.Dsl.cheatmd
    - cheatsheets/AshCqrs.Commanded.Dsl.cheatmd
    - .planning/WINDOWS.md
  deleted:
    - lib/ash_commanded/resource/transformers/collect_parameter_transforms.ex
    - lib/ash_commanded/resource/transformers/collect_parameter_validations.ex

key-decisions:
  - "Delete the two collectors rather than implement the undeclared DSL: transform_params and validate_params appear nowhere in REQUIREMENTS.md, so a reader for them would invent an interface with no requirement behind it. The documented, tested public functions remain."
  - "Write every documentation remedy in prose, never in declaration form, so the guard cannot read its own remedy as a fresh claim."
  - "Enumerate the guard's scan set explicitly and count occurrences rather than files — the CR-02 failure mode this repository already shipped once."
  - "Defer the module-path namespace sweep to Phase 7's stated goal rather than fabricate a DOCS-0x citation; contrast the deleted transformers, for which no live phase owned the work at all."

patterns-established:
  - "A documentation guard's scan set excludes its own source and .planning/, and asserts every enumerated file was read"
  - "A deferred defect must name a live owner whose requirements or stated goal cover it, or be fixed now"

requirements-completed: [WR-01, IN-01]

coverage:
  - id: D1
    description: "Two unreachable DSL-block collectors deleted, the dead nested-transaction branch removed, and the command entity's empty nested-entity list asserted from the extension"
    requirement: WR-01
    verification:
      - kind: unit
        ref: "test/ash_commanded/documented_dsl_surface_test.exs#the command entity declares no nested entities"
        status: pass
      - kind: integration
        ref: "MIX_ENV=test mix test (277 tests, 0 failures)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Every documented nested transform_params, validate_params and transaction block corrected to prose, with a two-sided guard that fails when documentation advertises an undeclared block"
    requirement: WR-01
    verification:
      - kind: unit
        ref: "test/ash_commanded/documented_dsl_surface_test.exs#no scanned documentation file presents an undeclared nested block as a declaration"
        status: pass
      - kind: unit
        ref: "test/ash_commanded/documented_dsl_surface_test.exs#the occurrence counter counts occurrences, not files"
        status: pass
    human_judgment: false
  - id: D3
    description: "Generated output proven byte-identical after the deletion, and the remaining module-path documentation sweep recorded against Phase 7 with measured counts"
    verification:
      - kind: integration
        ref: "MIX_ENV=test mix test test/ash_commanded/golden_render_test.exs test/ash_commanded/golden_budget_test.exs (29 tests, 0 failures)"
        status: pass
      - kind: other
        ref: "mix check (exit 0; Dialyzer 8 total / 8 skipped / 0 unnecessary)"
        status: pass
    human_judgment: true
    rationale: "Output neutrality is test-proven; whether Phase 7's stated goal adequately owns the module-path sweep is a judgment recorded in WINDOWS.md that no test asserts."

duration: 10min
completed: 2026-10-20
status: complete
---

# Phase 01 Plan 09: Gap Closure — Unreachable Collectors and False Documentation

**Deleted two transformers that could never receive their block and corrected every documentation site advertising undeclared command sub-blocks, with generated output proven byte-identical.**

## Performance

- **Duration:** 10 min
- **Started:** 2026-10-20T03:42:35Z
- **Completed:** 2026-10-20T03:52:44Z
- **Tasks:** 3
- **Files modified:** 14 (2 deleted, 1 created, 11 modified)

## Accomplishments

- Removed `CollectParameterTransforms` and `CollectParameterValidations`, which walked
  `transform_params`/`validate_params` blocks the `command` entity cannot contain and then
  substituted a hardcoded literal list; removed both from the extension's transformer list.
- Removed `CollectTransactionOptions`' dead nested-transaction-entity branch while keeping the
  three flat default options it genuinely reads and applies.
- Added `documented_dsl_surface_test.exs`: a positive assertion that the `command` entity was
  found and declares `entities: []`, read from the extension rather than copied.
- Corrected all 13 declaration-shaped occurrences across six documentation/cheatsheet files, plus
  the `ParameterValidator` moduledoc, re-framing the machinery as direct calls to
  `ParameterTransformer.transform_params/2` and `ParameterValidator.validate_params/2`.
- Added a two-sided documentation guard that enumerates its file set, counts occurrences rather
  than files, excludes its own source and `.planning/`, and was observed failing against the
  pre-correction files before passing after correction.
- Proved output neutrality: the parity fixture's `create_widget` command reported
  `transforms: []` / `validations: []` both before and after deletion, and every committed
  golden still matches a fresh render (29 tests, 0 failures).

## Task Commits

Each task was committed atomically:

1. **Task 1: delete unreachable collectors and dead transaction branch** - `ea76f34` (fix)
2. **Task 2: correct documentation and add the guard** - `16338b4` (fix)
3. **Task 3: prove output neutral, defer the wider sweep** - `a620d38` (docs)

**Plan metadata:** committed separately as `docs(01-09): complete ... plan`.

## Files Created/Modified

- `test/ash_commanded/documented_dsl_surface_test.exs` - nested-entity assertion plus the
  two-sided documentation guard
- `lib/ash_commanded/resource/dsl.ex` - two transformer entries removed
- `lib/ash_commanded/resource/transformers/collect_transaction_options.ex` - dead nested-entity
  branch and its moduledoc claim removed; flat defaults retained
- `lib/ash_commanded/parameter_transformer.ex` - worked example re-framed as a direct call,
  preserving 01-08's `String.to_existing_atom/1` correction
- `lib/ash_commanded/parameter_validator.ex` - worked example re-framed as a direct call
- `lib/ash_commanded/resource/transformers/collect_parameter_transforms.ex` - deleted
- `lib/ash_commanded/resource/transformers/collect_parameter_validations.ex` - deleted
- `README.md` - parameter and transaction sections corrected
- `documentation/parameter_handling.md` - rewritten around the public functions
- `documentation/commands.md` - nested transaction block replaced with flat options
- `documentation/transactions.md` - nested transaction block replaced with flat options
- `cheatsheets/AshCommanded.Resource.Dsl.cheatmd` - declaration blocks replaced with prose
- `cheatsheets/AshCqrs.Commanded.Dsl.cheatmd` - declaration blocks replaced with prose
- `.planning/WINDOWS.md` - two entries: the Phase 7-owned namespace sweep and the removed DSL surface

## Decisions Made

- Delete rather than implement the undeclared DSL. `transform_params` and `validate_params` appear
  nowhere in `REQUIREMENTS.md`, and inventing an entity shape nobody declared is a feature
  decision with no requirement behind it.
- Keep `CollectTransactionOptions`. Its flat options are genuinely declared and applied; only the
  nested-entity branch was dead.
- Write every remedy in prose. A remedy written as a declaration would be read by the guard as a
  fresh claim — the same self-exemption failure CR-02 recorded.
- Defer the module-path sweep to Phase 7's stated goal, not to a fabricated `DOCS-0x` citation.
  No requirement names module-path drift; the deleted collectors were refused a citation for the
  same reason, so the distinction is recorded rather than blurred.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Corrected four additional documentation sites beyond the three named**

- **Found during:** Task 2 (documentation correction)
- **Issue:** The plan named three documentation sites, but the repository shipped six files that
  presented `transform_params`, `validate_params` or `transaction` as nested command blocks:
  `documentation/commands.md`, `documentation/transactions.md` and
  `cheatsheets/AshCqrs.Commanded.Dsl.cheatmd` carried further declarations, and
  `lib/ash_commanded/parameter_validator.ex`'s moduledoc had the same false surface. Leaving
  them would have failed the acceptance criterion that no documentation site tells a consumer to
  write rejected DSL.
- **Fix:** Corrected each additional site in prose, naming the blocks without reproducing them
  as declarations, and kept the true statement that the flat transaction options are honoured.
- **Files modified:** `documentation/commands.md`, `documentation/transactions.md`,
  `cheatsheets/AshCqrs.Commanded.Dsl.cheatmd`, `lib/ash_commanded/parameter_validator.ex`
- **Verification:** The guard reported 13 declaration occurrences across six files before
  correction and zero after; full suite 277 tests, 0 failures.
- **Committed in:** `16338b4`

**2. [Rule 1 - Bug] Flattened the guard's violation collector to satisfy Credo's nesting depth**

- **Found during:** Task 3 (`mix check`)
- **Issue:** `mix credo` reported one refactoring opportunity: `documentation_violations/2` nested
  three levels deep against a configured maximum of two, which blocked the alias.
- **Fix:** Extracted `violations_for_name/2` and replaced the `if` with `Enum.reject/2`, leaving
  the behaviour unchanged.
- **Files modified:** `test/ash_commanded/documented_dsl_surface_test.exs`
- **Verification:** `mix credo` found no issues; `mix check` exited 0; the guard still passes.
- **Committed in:** `a620d38`

---

**Total deviations:** 2 auto-fixed (1 missing critical, 1 bug)
**Impact on plan:** Both were necessary for the plan's own acceptance criteria. The first makes
the "no documentation site" criterion true repository-wide rather than only at the three named
files; the second restores the project's blocking quality gate.

## Issues Encountered

- The first two attempts to commit Task 2 failed with
  `error: 1Password: failed to fill whole buffer` from the configured `op-ssh-sign` program. A
  stale signing helper was cleared and the same commit then succeeded. No hooks were bypassed and
  no git configuration was changed.

## Known Stubs

None. This plan removes implementation-shaped stubs rather than adding any.

## User Setup Required

None - no external service configuration required.

## Threat Flags

None. No new network endpoint, auth path, file-access pattern or trust boundary was introduced;
the atom trust boundary from 01-08 is preserved in the re-framed documentation.

## Next Phase Readiness

- Phase 1 is at 9/10 plans; `01-10-PLAN.md` remains.
- The extension's transformer list no longer contains code that contradicts its own name, and the
  suite now records why the nested command blocks cannot exist.
- The remaining module-path documentation drift is measured and owned by Phase 7 in
  `.planning/WINDOWS.md`; `mix check` regenerates two untracked files under
  `documentation/dsls/`, which were deleted rather than committed.

---

*Phase: 01-foundation-rendering-enforcement-and-layout*
*Completed: 2026-10-20*

## Self-Check: PASSED

- `test/ash_commanded/documented_dsl_surface_test.exs` exists.
- `collect_parameter_transforms.ex` and `collect_parameter_validations.ex` are absent.
- Commits `ea76f34`, `16338b4` and `a620d38` are ancestors of HEAD.
- `git status --porcelain -- documentation/dsls` prints nothing.
