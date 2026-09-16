---
phase: 01-foundation-rendering-enforcement-and-layout
plan: 04
subsystem: infra
tags: [elixir, spark, ash, dsl, refactor, credo, dialyzer, exdoc]

# Dependency graph
requires:
  - phase: 01-01
    provides: FOUND-18's create_module/4 seam, D-06 AST capture hook in BaseTransformer
  - phase: 01-02
    provides: the mix ash_commanded.dump renderer and the test/golden/parity_widget corpus used as the neutrality-proof instrument
  - phase: 01-03
    provides: the static enforcement gates (Credo custom checks, ex_dna, .credo.exs strict mode) this plan's relocation must not break
provides:
  - "lib/ash_commanded/resource/ and lib/ash_commanded/domain/ sibling trees, each with its own sections/transformers/verifiers (resource) or transformers (domain), replacing the flat lib/commanded/ tree"
  - "AshCommanded.Resource.Dsl / AshCommanded.Domain.Dsl (D-13), with every AshCommanded.Commanded.* submodule renamed from an enumerated list"
  - "AshCommanded.Resource.Info and AshCommanded.Domain.Info, the FOUND-17 .Info convention, via Spark.InfoGenerator with zero hand-written getters"
  - "A golden-diff proof (D-14/FOUND-04) that the big-bang move changed layout and naming only"
  - "mix.exs and .dialyzer_ignore.exs repointed at the new tree; cheatsheets/AshCommanded.Resource.Dsl.cheatmd renamed and its content updated"
affects: [01-05, 01-06, phase-02-commands, phase-03-application-and-routers, phase-04-aggregates]

# Actuals (#2632)
actuals:
  tokens: 43300
  tasks: 3
  commits: 3
  plan_head_before: 3b3bb56

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Resource/Domain tree split under lib/ash_commanded/, mirroring ash_graphql's resource/domain boundary (ARCHITECTURE.md §7), adapted to this DSL's CURRENT extension registration rather than its future aspirational shape"
    - "Spark.InfoGenerator as the single .Info lookup point per tree (rewrite rule 6) — zero hand-written accessors"
    - "Enumerated old-to-new module-name substitution list (ordered longest-match-first to avoid substring collisions) instead of a blind repo-wide rename"

key-files:
  created:
    - lib/ash_commanded/resource/info.ex
    - lib/ash_commanded/domain/info.ex
    - test/ash_commanded/info_test.exs
  modified:
    - lib/ash_commanded/resource/dsl.ex (was lib/commanded/dsl.ex)
    - lib/ash_commanded/domain/dsl.ex (was lib/commanded/domain_dsl.ex)
    - mix.exs
    - .dialyzer_ignore.exs
    - cheatsheets/AshCommanded.Resource.Dsl.cheatmd (was AshCommanded.Commanded.Dsl.cheatmd)
    - test/golden/parity_widget/AshCommanded.TestSupport.Parity.WidgetAggregate.golden
    - "every other file under the old lib/commanded/ and test/commanded/ trees (100 renames)"

key-decisions:
  - "GenerateCommandedApplication is the only transformer physically relocated to domain/transformers/ — it is the sole entry in AshCommanded.Domain.Dsl's own transformers: [...] list, and its transform/1 is a documented no-op on resources (early-returns on empty :resources entities). GenerateDomainRouterModule and GenerateMainRouterModule stay under resource/transformers/, matching their actual current registration in AshCommanded.Resource.Dsl's own transformers list, even though the latter's behaviour is domain-scoped — this is a pure relocation (D-14), not a re-architecture of a pre-existing, separately-quarantined router-wiring defect."
  - "Command/Event/Projection/EventHandler entity target structs, and all cross-cutting runtime modules (Error, CommandActionMapper, Transaction, ParameterTransformer, ParameterValidator, Snapshot*, Middleware/) sit directly under lib/ash_commanded/, per the plan's own three-category rule (sections/transformers/verifiers go to a tree; everything else is cross-cutting) rather than the checkpoint context's non-exhaustive example list."
  - "AshCommanded.Domain.Info currently generates zero accessors (AshCommanded.Domain.Dsl.sections() is [], confirmed at runtime) — an honest reflection of what that extension declares today, not a bug. The test asserting this is written against the extension's own declared-sections list, not a hardcoded 0, so it starts asserting real accessors automatically once Phase 3's APP-11 gives the domain its own section."
  - "cheatsheets/AshCommanded.Resource.Dsl.cheatmd's content was updated via the same text substitution used everywhere else, not via mix spark.cheat_sheets — the currently-vendored spark (2.7.2, Igniter-based) writes cheat sheets to documentation/dsls/DSL-<name>.md, a different, pre-existing, disconnected path from what mix.exs's docs() actually references. Logged as WINDOWS.md entry #6, left unresolved (Phase 7 territory)."
  - "Stray test-module names inside test/ash_commanded/ that duplicated the old \"Commanded.\" segment for no functional reason (e.g. AshCommanded.Commanded.ContextTest, AshCommanded.Commanded.Transformers.AggregateGeneratorTest) were also renamed by dropping the redundant segment, to satisfy the plan's own zero-stray-reference acceptance criterion for test/ — these are arbitrary test-module names, not references to any actual DSL module."

requirements-completed: [FOUND-04, FOUND-17]

coverage:
  - id: D1
    description: "lib/ reorganised into sibling resource/ and domain/ trees under lib/ash_commanded/, each with transformers/ (both) and verifiers/ + sections/ (resource); AshCommanded.Resource.Dsl / AshCommanded.Domain.Dsl replace AshCommanded.Commanded.Dsl / AshCommanded.Commanded.DomainDsl"
    requirement: "FOUND-17"
    verification:
      - kind: unit
        ref: "shell: test -d lib/ash_commanded/resource/transformers && test -d lib/ash_commanded/resource/verifiers && test -d lib/ash_commanded/domain/transformers — trees-present"
        status: pass
      - kind: unit
        ref: "shell: grep -rlE 'AshCommanded[.]Commanded[.]' lib/ test/ --include='*.ex' --include='*.exs' | grep -v golden — 0 matches"
        status: pass
    human_judgment: false
  - id: D2
    description: "AshCommanded.Resource.Info and AshCommanded.Domain.Info exist as the FOUND-17 .Info convention, generated entirely by Spark.InfoGenerator (zero hand-written getters)"
    requirement: "FOUND-17"
    verification:
      - kind: unit
        ref: "test/ash_commanded/info_test.exs — 5 tests"
        status: pass
      - kind: unit
        ref: "shell: grep -rv '^#' lib/ash_commanded/{resource,domain}/info.ex | grep -c 'def ' — 0 for both"
        status: pass
    human_judgment: false
  - id: D3
    description: "Re-rendering every committed golden after the move produces either no diff, or a diff whose every changed line is a DSL module-name literal — the strongest available proof the move changed layout and naming only (D-14, FOUND-04)"
    requirement: "FOUND-04"
    verification:
      - kind: unit
        ref: "mix ash_commanded.dump AshCommanded.TestSupport.Parity.Widget --write, then git diff test/golden/ — 5/6 goldens byte-identical, 1/6 changed on 6 lines, every one a module-name literal"
        status: pass
      - kind: unit
        ref: "test/ash_commanded/golden_render_test.exs — 6 tests"
        status: pass
    human_judgment: false
  - id: D4
    description: "mix check is green after the move: the Dialyzer ignore paths, documentation groups and cheat-sheet filename all moved with the code"
    requirement: "FOUND-04"
    verification:
      - kind: unit
        ref: "shell: mix check — exit 0 (format, compile --warnings-as-errors, credo, coveralls, compile_parity.sh, dialyzer, gen.docs)"
        status: pass
      - kind: unit
        ref: "doc/dist/sidebar_items-*.js parsed directly — DSL/Transformers/Verifiers groups populated with the renamed modules"
        status: pass
    human_judgment: false

duration: ~35min
completed: 2026-09-16
status: complete
---

# Phase 1 Plan 04: Lib/Test Relocation to resource/domain Trees, .Info Modules, Golden-Diff Neutrality Proof Summary

**Big-bang relocation of `lib/commanded/` (49 files) into sibling `lib/ash_commanded/resource/` and `lib/ash_commanded/domain/` trees with every `AshCommanded.Commanded.*` module renamed to `AshCommanded.Resource.*`/`AshCommanded.Domain.*`/`AshCommanded.*`, proven behaviour-neutral by re-rendering the golden corpus (5/6 byte-identical, 1/6 changed on exactly six module-name-literal lines).**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-09-16T07:10:00Z (approx.)
- **Completed:** 2026-09-16T07:39:37Z
- **Tasks:** 3 (Task 1, 2, 3 — the plan's opening `checkpoint:decision` was resolved by the human before this agent was spawned)
- **Files modified:** 112 (git diff --stat across all three task commits)

## Accomplishments

- Every file under `lib/commanded/` relocated to `lib/ash_commanded/`, split into `resource/{sections,transformers,verifiers}/`, `domain/transformers/`, and cross-cutting top-level modules + `middleware/`, using `git mv` so the diff reads as renames.
- Every `AshCommanded.Commanded.*` module renamed to its `AshCommanded.Resource.*`, `AshCommanded.Domain.*`, or bare `AshCommanded.*` equivalent (D-13), from an enumerated old-to-new list applied in longest-match-first order to avoid substring collisions (e.g. `CommandActionMapper` before `Command`, `SnapshotStore` before `Snapshot`).
- `test/commanded/` moved to `test/ash_commanded/` in lockstep, including fixing alias ordering the rename shifted and dropping the redundant "Commanded." segment from arbitrary test-module names.
- `AshCommanded.Resource.Info` and `AshCommanded.Domain.Info` created via `Spark.InfoGenerator` — the FOUND-17 `.Info` convention, zero hand-written accessors.
- `mix.exs`'s cheat-sheet alias, documentation groups, and cheat-sheet filename repointed; `.dialyzer_ignore.exs`'s four path-keyed entries repointed — all four D-14 silent-breakage classes fixed in the same wave as the move.
- Golden-diff neutrality proof run: re-rendered the parity fixture, diffed against the pre-move goldens. 5 of 6 unchanged; the 6th (`WidgetAggregate.golden`) changed on exactly 6 lines, every one a renamed DSL module-name literal in an `alias`/call site — recorded here as the move's own evidence per D-14/FOUND-04.
- `mix check` green end to end: format, `compile --warnings-as-errors`, credo (strict, all custom checks + ex_dna), `coveralls`, `compile_parity.sh` (both `MIX_ENV=dev` and `MIX_ENV=test`), `dialyzer`, `gen.docs`.

## Task Commits

Each task was committed atomically:

1. **Task 1: relocate and rename `lib/`, with the test tree in lockstep** - `e57c82e` (feat)
2. **Task 2: the four breakages that produce no compile error** - `e64bc07` (fix)
3. **Task 3: the two `.Info` modules, and the golden-diff proof the move was neutral** - `b3a5525` (feat)

**Plan metadata:** (this commit, see below)

## Files Created/Modified

- `lib/ash_commanded/resource/dsl.ex` — `AshCommanded.Resource.Dsl` (was `lib/commanded/dsl.ex`)
- `lib/ash_commanded/domain/dsl.ex` — `AshCommanded.Domain.Dsl` (was `lib/commanded/domain_dsl.ex`)
- `lib/ash_commanded/resource/{sections,transformers,verifiers}/*` — 26 relocated files
- `lib/ash_commanded/domain/transformers/generate_commanded_application.ex` — the one domain-tree transformer
- `lib/ash_commanded/{command,event,event_handler,projection,error,command_action_mapper,transaction,parameter_transformer,parameter_validator,snapshot,snapshot_adapter,snapshot_configuration,snapshot_store}.ex` + `lib/ash_commanded/middleware/*` — 18 cross-cutting modules
- `lib/ash_commanded/resource/info.ex`, `lib/ash_commanded/domain/info.ex` — new, FOUND-17's `.Info` modules
- `test/ash_commanded/**` — 55 relocated test files (was `test/commanded/**`)
- `test/ash_commanded/info_test.exs` — new, 5 tests for the two `.Info` modules
- `test/support/{widget,commanded_app_case}.ex`, `test/support/parity/{parity_widget,parity_domain}.ex` — extension references and moduledoc prose updated
- `lib/mix/tasks/ash_commanded.dump.ex` — updated `BaseTransformer` reference (file itself does not move)
- `mix.exs`, `.dialyzer_ignore.exs` — repointed at the new tree
- `cheatsheets/AshCommanded.Resource.Dsl.cheatmd` — renamed (was `AshCommanded.Commanded.Dsl.cheatmd`), content updated
- `test/golden/parity_widget/AshCommanded.TestSupport.Parity.WidgetAggregate.golden` — regenerated via `mix ash_commanded.dump --write`

## Decisions Made

See `key-decisions` in frontmatter. Summarized:

1. Domain-tree membership for transformers follows *current extension registration* (only `GenerateCommandedApplication`, the sole entry in `AshCommanded.Domain.Dsl`'s own list), not a semantic re-derivation of which transformer *should* be domain-scoped — `GenerateDomainRouterModule`/`GenerateMainRouterModule` stay in `resource/transformers/` because that is where `AshCommanded.Resource.Dsl` currently registers them, matching D-14's "pure relocation, no behaviour change" mandate.
2. Entity target structs (`Command`, `Event`, `Projection`, `EventHandler`) are cross-cutting (top-level `lib/ash_commanded/`), following the plan's own three-category rule literally (sections/transformers/verifiers go to a tree; everything else is cross-cutting) rather than inventing a fourth category.
3. `AshCommanded.Domain.Info` is a correct-but-currently-empty `.Info` module (zero accessors) because `AshCommanded.Domain.Dsl.sections()` really is `[]` — verified at runtime, not assumed.
4. The cheat-sheet file's content was hand-substituted rather than tool-regenerated, because the vendored spark's `spark.cheat_sheets` task now writes to a different path (`documentation/dsls/DSL-<name>.md`) that mix.exs's `docs()` doesn't reference — a pre-existing drift, logged to `WINDOWS.md` (#6) rather than fixed here.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Reordered a shifted alias in `commanded_application_generator_test.exs`**

- **Found during:** Task 1 (post-move `mix credo` run)
- **Issue:** `AshCommanded.Resource.Transformers.BaseTransformer`'s alphabetical sort position shifted relative to `AshCommanded.Domain.Transformers.GenerateCommandedApplication` once both were renamed, tripping `Credo.Check.Readability.AliasOrder`.
- **Fix:** Reordered the two `alias` lines.
- **Files modified:** `test/ash_commanded/transformers/commanded_application_generator_test.exs`
- **Verification:** `mix credo` — 0 issues.
- **Committed in:** `e57c82e` (Task 1 commit)

**2. [Rule 3 - Blocking] Updated `lib/mix/tasks/ash_commanded.dump.ex`'s `BaseTransformer` reference**

- **Found during:** Task 1
- **Issue:** This file does not itself move (per the plan), but its two references to `AshCommanded.Commanded.Transformers.BaseTransformer` would have been undefined-module compile failures once Task 1 renamed and relocated `BaseTransformer`.
- **Fix:** Updated both references to `AshCommanded.Resource.Transformers.BaseTransformer`.
- **Files modified:** `lib/mix/tasks/ash_commanded.dump.ex`
- **Verification:** `mix compile --warnings-as-errors` clean; `test/ash_commanded/dump_task_test.exs` passes.
- **Committed in:** `e57c82e` (Task 1 commit)

**3. [Rule 3 - Blocking] Dropped the redundant "Commanded." segment from arbitrary test-module names**

- **Found during:** Task 1
- **Issue:** ~20 test files under `test/commanded/` named their own `defmodule` with a `AshCommanded.Commanded.*` prefix that did not correspond to any actual renamed library module (e.g. `AshCommanded.Commanded.ContextTest`) — just a historical naming habit mirroring the old directory. Left alone, these would have violated Task 1's own acceptance criterion (`grep -rlE 'AshCommanded[.]Commanded[.]' lib/ test/` must be 0) even though nothing about them was functionally broken.
- **Fix:** Mechanically replaced `AshCommanded.Commanded.` with `AshCommanded.` in these test-module names only (a second, narrower pass after the main enumerated-module-list substitution).
- **Files modified:** 20 files under `test/ash_commanded/`.
- **Verification:** `MIX_ENV=test mix test` — same pass/fail counts before and after (test module names are not part of any public contract).
- **Committed in:** `e57c82e` (Task 1 commit)

**4. [Rule 1 - Bug] Restored two accidentally-deleted, pre-existing tracked files**

- **Found during:** Task 2, while investigating the cheat-sheet regeneration path
- **Issue:** Ran `mix spark.cheat_sheets` expecting it to write to `cheatsheets/`; it silently wrote to a different, pre-existing, unrelated directory (`documentation/dsls/`) instead. A subsequent `rm -rf documentation/dsls` (intended to clean up the stray output) accidentally deleted two pre-existing, unrelated, tracked files (`DSL-AshCommanded.Commanded.md`, `DSL-AshCqrs.Commanded.md`) that predate this plan.
- **Fix:** `git checkout -- documentation/dsls/` immediately restored them before anything was staged or committed.
- **Files modified:** none (restored to their pre-existing committed state).
- **Verification:** `git status --short documentation/` — clean, confirmed no diff.
- **Committed in:** n/a (never left the working tree in a bad state; nothing to commit)

---

**Total deviations:** 4 auto-fixed (1 bug/readability, 2 blocking/compile-safety, 1 bug/accidental-deletion-caught-before-commit)
**Impact on plan:** All four were necessary to keep the move compiling, credo-clean, and non-destructive. No scope creep — none touch component DSL logic, none wire `create_module/4` into any call site (FOUND-18 remains explicitly incomplete, per the scope boundary), and none restructure the domain/resource architectural confusion Phase 2/3 already own.

## Issues Encountered

- **Task 1's own `<verify>`/`<acceptance_criteria>` briefly conflicted with Task 3's design.** Immediately after Task 1's move (before Task 3 ran), `MIX_ENV=test mix test` reported 229 tests with exactly 1 failure — `golden_render_test.exs`, because the aggregate's generated code now aliases the renamed `AshCommanded.Error`/`Snapshot`/`SnapshotStore`/`CommandActionMapper`/`Middleware.CommandMiddlewareProcessor`, while the golden committed before the move still showed the old names. This is not a defect: it is the intended, plan-designed neutrality-proof artifact that Task 3 explicitly exists to resolve via `mix ash_commanded.dump --write`. Documented rather than worked around; resolved cleanly once Task 3 ran.
- **`grep -rl 'commanded do' test/support/` returns 2 files, not the "4 or more" Task 1's acceptance criteria expected.** `test/support/context_widget.ex` and `test/support/custom_action_widget.ex` are plain `Ash.Resource` fixtures for unrelated concerns (context propagation, custom actions) and have never had a `commanded do` block, before or after this plan. The actual D-15 concern — the keyword survives the rename — is fully satisfied by the 2 files that do use the extension (`widget.ex`, `parity/parity_widget.ex`); the specific count expectation in the plan text appears to be an estimate that didn't match the real fixture set. No fixture was added or removed to make the number 4; that would have been fabricating test data to satisfy a grep.
- **The vendored spark (2.7.2) no longer generates cheat sheets at the path `mix.exs`'s `docs()` references** (see Decision 4 / Deviation Auto-fix 4 above). Logged to `WINDOWS.md` as entry #6, left open — reconciling the doc-generation pipeline is a bigger call than this plan's declared scope and is Phase 7 (documentation) territory.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `lib/` and `test/` now match FOUND-17's required shape exactly: sibling `resource/`/`domain/` trees, each with its own `transformers/`/`verifiers/`/`info.ex` (verifiers only exist on the resource tree today, since there are none registered on the domain extension — consistent with current behaviour).
- Plan 01-05 can proceed to re-point the 15 pre-existing `# gsd-disable-until-phase: N` citations at their new file paths — none of those citations were touched by this plan (deliberately, per the plan's own scope boundary), so they still cite their original phase numbers but now live at the moved paths.
- Phase 2 (Commands) and Phase 3 (Application and Routers) can build directly on `AshCommanded.Resource.Info`/`AshCommanded.Domain.Info` by extending their `sections:` lists rather than creating new modules or reshuffling directories.
- `WINDOWS.md` entry #6 (cheat-sheet generation path drift) and entry #5 (FOUND-18's `create_module/4` unwired, unchanged by this plan per its explicit scope boundary) remain open — both are pre-existing or explicitly-deferred, not regressions introduced here.

## Self-Check: PASSED

- `lib/ash_commanded/resource/dsl.ex` — FOUND
- `lib/ash_commanded/domain/dsl.ex` — FOUND
- `lib/ash_commanded/resource/info.ex` — FOUND
- `lib/ash_commanded/domain/info.ex` — FOUND
- `test/ash_commanded/info_test.exs` — FOUND
- `cheatsheets/AshCommanded.Resource.Dsl.cheatmd` — FOUND
- commit `e57c82e` — FOUND
- commit `e64bc07` — FOUND
- commit `b3a5525` — FOUND

---
*Phase: 01-foundation-rendering-enforcement-and-layout*
*Completed: 2026-09-16*
