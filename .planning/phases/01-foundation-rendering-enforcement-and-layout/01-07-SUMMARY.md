---
phase: 01-foundation-rendering-enforcement-and-layout
plan: 07
subsystem: code-generation
tags: [spark, dsl, transformers, found-18, dialyzer, golden-renders]

# Dependency graph
requires:
  - phase: 01-foundation-rendering-enforcement-and-layout
    plan: 01
    provides: BaseTransformer.create_module/4 with an explicit location argument
  - phase: 01-foundation-rendering-enforcement-and-layout
    plan: 04
    provides: post-relocation resource/ and domain/ transformer trees
provides:
  - BaseTransformer.dsl_location/1 and entity_location/2 as the shared location helpers
  - all nine real module-creating call sites attributed to their DSL module
  - a persisted-state attribution sweep over every module the parity fixture generates
  - an AST occurrence guard that fails if a future generator is added unwired
affects: [02, 03, 04, 05, 06]

# Actuals (#2632) — pairs with the plan's estimate on the same chars/4 scale.
actuals:
  tokens: 6286
  tasks: 3
  commits: 3

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Generated modules carry the DSL declaration's own file:line in compile metadata"
    - "AST guards count call occurrences and arities, never files"

key-files:
  created:
    - test/ash_commanded/generated_module_location_test.exs
  modified:
    - lib/ash_commanded/resource/transformers/base_transformer.ex
    - lib/ash_commanded/resource/transformers/generate_command_modules.ex
    - lib/ash_commanded/resource/transformers/generate_event_modules.ex
    - lib/ash_commanded/resource/transformers/generate_projection_modules.ex
    - lib/ash_commanded/resource/transformers/generate_event_handler_modules.ex
    - lib/ash_commanded/resource/transformers/generate_projector_modules.ex
    - lib/ash_commanded/resource/transformers/generate_aggregate_module.ex
    - lib/ash_commanded/resource/transformers/generate_main_router_module.ex
    - lib/ash_commanded/domain/transformers/generate_commanded_application.ex
    - .dialyzer_ignore.exs
    - .planning/WINDOWS.md

key-decisions:
  - "Entity-owned generators use entity_location/2; resource-owned and domain-owned generators use dsl_location/1 because no single declaration owns their module"
  - "The event-handler group is attributed to its first declaration, the only site where the representative is a choice rather than a fact"
  - "Three pre-existing Dialyzer findings were re-anchored, not suppressed: FOUND-18 moved their attribution to the parity fixture while their messages and count stayed identical"

patterns-established:
  - "Location attribution: read Spark.Dsl.Transformer.get_persisted(dsl_state, :file) and Spark.Dsl.Entity.anno/1, never derive a path"
  - "Two-sided structural guards: assert the forbidden count is zero AND the expected count has a floor, so an empty search cannot pass"

requirements-completed: [FOUND-18]

coverage:
  - id: D1
    description: "A generated projection module's own stacktrace frame names the parity fixture's file and the line of its `projection :widget_created do` declaration"
    requirement: FOUND-18
    verification:
      - kind: unit
        ref: "test/ash_commanded/generated_module_location_test.exs#the projection module's own stacktrace frame points at the fixture declaration"
        status: pass
    human_judgment: false
  - id: D2
    description: "Every generated module the parity fixture produces reports the fixture's own source from __info__(:compile), and none reports a path under lib/ash_commanded"
    requirement: FOUND-18
    verification:
      - kind: unit
        ref: "test/ash_commanded/generated_module_location_test.exs#reports the fixture's own source path from __info__(:compile)"
        status: pass
    human_judgment: false
  - id: D3
    description: "No three-argument BaseTransformer.create_module call survives under lib/ outside base_transformer.ex, and at least nine four-argument calls exist"
    requirement: FOUND-18
    verification:
      - kind: unit
        ref: "test/ash_commanded/generated_module_location_test.exs#create_module is called with four arguments at least nine times and never with three"
        status: pass
    human_judgment: false
  - id: D4
    description: "Every committed golden still matches a fresh render byte for byte, proving only attribution moved"
    verification:
      - kind: unit
        ref: "MIX_ENV=test mix test test/ash_commanded/golden_render_test.exs test/ash_commanded/golden_budget_test.exs"
        status: pass
    human_judgment: false
  - id: D5
    description: "WINDOWS.md entry 5 is marked fixed through the ledger tooling"
    verification:
      - kind: other
        ref: "gsd-tools windows fixed 5; open_count 6 -> 5"
        status: pass
    human_judgment: false
  - id: D6
    description: "The two router call sites and the Commanded application call site pass an explicit location"
    requirement: FOUND-18
    verification:
      - kind: unit
        ref: "structural AST guard (D3) covers these sites"
        status: pass
    human_judgment: true
    rationale: "Router generation never fires today (nothing persists :command_resource_mappings; Phase 3 owns that defect) and no fixture declares an application block, so these three sites cannot be exercised behaviourally until Phase 3."

duration: 11min
completed: 2026-10-20
status: complete
plan_head_before: 7c2805c0f1b1519332e54b9b2c076fa806c1c88e
plan_head_after: 4f45a6aa8ae517c40c60c737ba74d05dd02ce4f9
---

# Phase 1 Plan 07: Generated Module Location Attribution Summary

**A developer who hits an error in generated code is now given the DSL declaration's own file and line, with all nine module-creating transformers wired through shared location helpers and a structural guard against the next unwired generator.**

## Performance

- **Duration:** 11min
- **Started:** 2026-10-20T14:23:17+11:00
- **Completed:** 2026-10-20T14:34:40+11:00
- **Tasks:** 3
- **Files modified:** 12

## Accomplishments

- `BaseTransformer.dsl_location/1` and `entity_location/2` turn Spark's persisted `:file` and an entity's own annotation into the explicit location `create_module/4` already accepted but no real caller used.
- All nine real call sites now pass that location: command, event, projection, event handler, projector, aggregate, both router sites and the Commanded application.
- An end-to-end test raises inside the real generated projection module and asserts its stacktrace frame names the fixture's declaration line, derived from the fixture at test time rather than hardcoded; it also asserts the frame does not name the transformer tree.
- A persisted-state sweep asserts all six modules the parity fixture generates report the fixture's source, and an AST guard counts call occurrences and arities so a future generator cannot land unwired.
- Goldens are byte-identical, `mix check` is green, and WINDOWS.md entry 5 is closed.

## Task Commits

Each task was committed atomically:

1. **Task 1: end-to-end attribution for one generator** - `7983186` (feat)
2. **Task 2: expand to the remaining eight call sites and add the guards** - `03f3f73` (feat)
3. **Task 3: prove neutrality, run every gate, close the ledger** - `4f45a6a` (chore)

**Plan metadata:** see the docs commit that follows this summary.

## Files Created/Modified

- `lib/ash_commanded/resource/transformers/base_transformer.ex` - added `dsl_location/1`, `entity_location/2`, and the guarded entity-line reader
- `lib/ash_commanded/resource/transformers/generate_command_modules.ex` - entity-attributed
- `lib/ash_commanded/resource/transformers/generate_event_modules.ex` - entity-attributed
- `lib/ash_commanded/resource/transformers/generate_projection_modules.ex` - entity-attributed (Task 1)
- `lib/ash_commanded/resource/transformers/generate_event_handler_modules.ex` - attributed to the handler group's first declaration
- `lib/ash_commanded/resource/transformers/generate_projector_modules.ex` - resource-file attributed
- `lib/ash_commanded/resource/transformers/generate_aggregate_module.ex` - resource-file attributed
- `lib/ash_commanded/resource/transformers/generate_main_router_module.ex` - both router sites domain-file attributed
- `lib/ash_commanded/domain/transformers/generate_commanded_application.ex` - domain-file attributed
- `test/ash_commanded/generated_module_location_test.exs` - stacktrace proof, persisted-state sweep, AST call-site guard
- `.dialyzer_ignore.exs` - re-anchored three relocated findings
- `.planning/WINDOWS.md` - entry 5 marked fixed

## Decisions Made

- **Entity-owned generators use `entity_location/2`; resource- and domain-owned generators use `dsl_location/1`.** The aggregate, projector and router modules are built from whole DSL blocks, so attributing them to one arbitrary member declaration would be a guess dressed as precision; the file is correct and line 1 is honest.
- **The event-handler group is attributed to its first declaration.** The module is generated from a group of handlers, so no single declaration owns it; the first is the one a developer opens first.
- **Three Dialyzer ignore entries were re-anchored to the parity fixture rather than removed or widened.** FOUND-18 moved where those pre-existing findings are reported; their messages and count did not change.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Dialyzer findings relocated out of the committed ignore list**

- **Found during:** Task 3 (prove neutrality and run every gate)
- **Issue:** The first `mix check` after wiring failed Dialyzer with `Total errors: 8, Skipped: 4, Unnecessary Skips: 3`, surfacing four warnings attributed to `test/support/parity/parity_widget.ex`. FOUND-18 changed generated modules' compile metadata from the transformer's file to the DSL declaration's file, so the three pre-existing aggregate findings moved with it and their old `generate_aggregate_module.ex` entries no longer matched. The findings themselves, their messages and the total count were unchanged.
- **Fix:** Regenerated the strict ignore-file view with `mix dialyzer --format ignore_file_strict`, then re-anchored the three entries from `lib/ash_commanded/resource/transformers/generate_aggregate_module.ex` to `test/support/parity/parity_widget.ex`, keeping their exact messages. No entry was added or removed, and the header records the reason.
- **Files modified:** `.dialyzer_ignore.exs`
- **Verification:** `mix dialyzer` reports `Total errors: 8, Skipped: 8, Unnecessary Skips: 0`; `mix check` exits 0.
- **Committed in:** `4f45a6a` (Task 3 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** The fix preserves the ratchet rather than loosening it - same findings, same messages, same count, corrected attribution. No scope creep.

## Issues Encountered

- **Credo nesting failure in the new test helper.** The first structural-guard implementation nested four anonymous-function levels and tripped Credo's `Nesting` check. It was split into named `create_module_arities_in_file/1`, `create_module_arities_in_ast/1` and `collect_create_module_arity/4` helpers before commit; `mix credo` then reported zero issues.
- **Transient commit failure.** The first Task 3 `git commit` failed with `error: 1Password: failed to fill whole buffer` while writing the commit object. The retry succeeded without changing content; no hooks were bypassed.

## Attribution Coverage - Stated Limits

Six of the nine call sites are proven behaviourally against the real parity fixture: the command, event, projection, event handler, projector and aggregate modules are all generated and their `__info__(:compile)` source is asserted against the fixture. The projection module additionally proves a real stacktrace frame names the fixture's declaration line.

Three call sites - the two routers in `generate_main_router_module.ex` and the Commanded application in `generate_commanded_application.ex` - are wired and covered by the structural guard but cannot be exercised until Phase 3. Router generation only proceeds when `:command_resource_mappings` is non-empty, and nothing currently persists that key (the confirmed router-generation defect ROADMAP Phase 3 owns); no fixture in this repository declares an `application` block. This is recorded rather than glossed: an unqualified "FOUND-18 closed" would repeat the failure this gap-closure plan exists to correct.

## Next Phase Readiness

- FOUND-18's stated outcome is demonstrable in the running library for every module the current fixtures generate.
- Phase 3 should extend behavioural coverage to the three domain-owned sites when it makes router and application generation fire.
- WINDOWS.md now has five open entries; entry 5 is closed. Entry 6 (regenerated `documentation/dsls` files) remains Phase 7's.

---

*Phase: 01-foundation-rendering-enforcement-and-layout*
*Completed: 2026-10-20*

## Self-Check: PASSED

- FOUND: `lib/ash_commanded/resource/transformers/base_transformer.ex`
- FOUND: `test/ash_commanded/generated_module_location_test.exs`
- FOUND: `.planning/phases/01-foundation-rendering-enforcement-and-layout/01-07-SUMMARY.md`
- FOUND commit: `7983186`
- FOUND commit: `03f3f73`
- FOUND commit: `4f45a6a`
