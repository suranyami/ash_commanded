---
phase: 01-foundation-rendering-enforcement-and-layout
plan: 05
subsystem: codegen-tooling
tags: [credo, static-analysis, golden-tests, mix-check, quality-gates, roadmap-citations]

# Dependency graph
requires:
  - phase: 01-02
    provides: "AshCommanded.Dump.Golden.measure/1 and AshCommanded.Dump.Lint.check/1, the FOUND-06/FOUND-08 detection logic this plan's fixtures and evidence exercise"
  - phase: 01-03
    provides: "AshCommanded.CredoChecks.NoRuntimeStringToAst/NoModuleNameSurgery, Credo.Check.Refactor.LongQuoteBlocks at max_line_count:40, and the # gsd-disable-until-phase: N citation format this plan applies to the 15 pre-existing disables"
  - phase: 01-04
    provides: "the lib/ash_commanded resource/domain relocation — every file path this plan touches is the relocated path, not the archived lib/commanded one"
provides:
  - "priv/seeded_violations/*.ex (5 fixtures) — one deliberately-invalid, deliberately-uncompiled violation per gate (FOUND-06..10), on no elixirc_paths entry and swept by no .credo.exs included: glob"
  - "test/ash_commanded/seeded_violations_test.exs — permanent regression test proving each gate's real detection logic still fires against its fixture, plus a fixture-set-completeness assertion"
  - "test/ash_commanded/disable_phase_citation_test.exs — walks lib/'s disables and test/golden/'s staged markers through one shared roadmap parser, failing on an absent phase, a Complete phase, or a disable with no structured citation within 3 lines"
  - "the 15 pre-existing # credo:disable-for-this-file lines (8 files) re-pointed onto the current roadmap's phase numbers via # gsd-disable-until-phase: N, replacing free prose that still cited the archived 13-phase roadmap"
  - ".planning/phases/01-foundation-rendering-enforcement-and-layout/01-GATE-EVIDENCE.md — one-time record of all five gates provably failing the real mix check on a real violation, and recovering, with verbatim output"
affects: ["01-06", "Phase 2-7: every disable this plan re-points is deleted, not re-cited, as each owning phase's rewrite lands; the citation test then fails loudly if that phase forgets to remove its own disable"]

# Actuals (#2632)
actuals:
  tokens: 12110
  tasks: 3
  commits: 3
  plan_head_before: 6ea2e71ad7343f2332d22f8fa20724dd3322837f

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Seeded-violation fixtures live under priv/, never lib/ or test/ — the one directory on no elixirc_paths entry (mix.exs) and swept by no .credo.exs included: glob, so a fixture encoding a real violation can be committed permanently without ever compiling or linting"
    - "Both custom-check regression tests build their Credo.SourceFile with a filename starting lib/ — NoRuntimeStringToAst and NoModuleNameSurgery both short-circuit to zero issues on any other prefix, which would otherwise make the regression test pass vacuously"
    - "A citation validator takes existing_phases/statuses as plain data (MapSet/Map) rather than always re-parsing ROADMAP.md, so the same validation code path is exercised by both the real repository walk and synthetic fixtures with an injected roadmap"

key-files:
  created:
    - priv/seeded_violations/oversized_clause.ex
    - priv/seeded_violations/oversized_quote.ex
    - priv/seeded_violations/runtime_reassembly.ex
    - priv/seeded_violations/string_to_ast.ex
    - priv/seeded_violations/module_name_surgery.ex
    - test/ash_commanded/seeded_violations_test.exs
    - test/ash_commanded/disable_phase_citation_test.exs
    - .planning/phases/01-foundation-rendering-enforcement-and-layout/01-GATE-EVIDENCE.md
  modified:
    - lib/ash_commanded/command_action_mapper.ex
    - lib/ash_commanded/error.ex
    - lib/ash_commanded/resource/transformers/generate_aggregate_module.ex
    - lib/ash_commanded/domain/transformers/generate_commanded_application.ex
    - lib/ash_commanded/resource/transformers/generate_domain_router_module.ex
    - lib/ash_commanded/resource/transformers/generate_event_handler_modules.ex
    - lib/ash_commanded/resource/transformers/generate_main_router_module.ex
    - lib/ash_commanded/resource/transformers/generate_projector_modules.ex

key-decisions:
  - "Identified the exact 15 pre-existing disables (8 files) by diffing against c5e71e8^ — the commit immediately before 01-03 started, and therefore the precise state D-01's 'eight files, fifteen disable lines' (grep-verified 2026-09-15) describes — rather than re-pointing all 33 disable lines currently in lib/. The other 18 (AshCommanded.CredoChecks.NoModuleNameSurgery and ExDNA.Credo disables) were introduced BY 01-03 itself and already carry correct current-roadmap citations; re-pointing them again would have been a no-op at best and a citation collision at worst."
  - "Re-ran all five gate-evidence violations fresh in this session rather than reusing 01-03's original deliberate-violation proof, because that proof survives only as commit-message prose (dc370d7), not an archived verbatim transcript. Reusing a paraphrase would have quietly weakened the literal evidence 01-GATE-EVIDENCE.md exists to provide."
  - "The two golden-level scratch violations (FOUND-06, FOUND-08) were placed inside the existing parity_widget/ fixture directory rather than a new one, so AshCommanded.GoldenRenderTest's fixture-target registration also fires on the same stray file — a second, independent failure signal on the identical glob, not double-counting."

requirements-completed: [FOUND-06, FOUND-07, FOUND-08, FOUND-09, FOUND-10]

coverage:
  - id: D1
    description: "Five seeded fixtures under priv/seeded_violations/, one per gate (FOUND-06..10), each proven to still trip its gate's real detection logic by a permanent regression test — and proven invisible to the compiler, Credo, and the published Hex package"
    requirement: FOUND-06
    verification:
      - kind: unit
        ref: "test/ash_commanded/seeded_violations_test.exs (6 tests: one per gate + fixture-set-completeness)"
        status: pass
      - kind: other
        ref: "mix compile --force --warnings-as-errors exit 0; mix credo exit 0; mix hex.build's tarball contains zero priv/ entries (verified via tar tzf)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Credo.Check.Refactor.LongQuoteBlocks (FOUND-07) still fires on a real >40-line quote block, proven directly against the seeded fixture"
    requirement: FOUND-07
    verification:
      - kind: unit
        ref: "test/ash_commanded/seeded_violations_test.exs#FOUND-07 — oversized quote block"
        status: pass
    human_judgment: false
  - id: D3
    description: "AshCommanded.Dump.Lint (FOUND-08) still fires on a real runtime-reassembly violation, proven directly against the seeded fixture"
    requirement: FOUND-08
    verification:
      - kind: unit
        ref: "test/ash_commanded/seeded_violations_test.exs#FOUND-08 — runtime reassembly"
        status: pass
    human_judgment: false
  - id: D4
    description: "AshCommanded.CredoChecks.NoRuntimeStringToAst (FOUND-09) and AshCommanded.CredoChecks.NoModuleNameSurgery (FOUND-10) still fire on real violations, proven directly against the seeded fixtures with a filename under lib/ so the checks' own path guard cannot silently suppress the assertion"
    requirement: FOUND-09
    verification:
      - kind: unit
        ref: "test/ash_commanded/seeded_violations_test.exs#FOUND-09 and #FOUND-10"
        status: pass
    human_judgment: false
  - id: D5
    description: "Every gate disable in lib/ and every staged golden marker in test/golden/ cites a roadmap phase that exists and is not yet Complete; the 15 pre-existing disables that previously cited only the archived 13-phase roadmap (in free prose, with no structured citation at all) are re-pointed onto the current roadmap via the D-02 format"
    requirement: FOUND-10
    verification:
      - kind: unit
        ref: "test/ash_commanded/disable_phase_citation_test.exs (9 tests: 2 real-tree walks, 2 non-vacuity counts, 5 synthetic rule-level assertions with an injected roadmap)"
        status: pass
      - kind: other
        ref: "grep -rc gsd-disable-until-phase lib/ totals 25 citations across the same 15 files that carry disables (grep -rl credo:disable-for-this-file lib/ | wc -l == 15 == grep -rl gsd-disable-until-phase lib/ | wc -l)"
        status: pass
    human_judgment: false
  - id: D6
    description: "The real mix check alias, run five times against five real seeded violations (one per gate) placed where the alias actually sweeps, fails naming the file and the rule each time, and returns to green after each is reverted — the literal half of ROADMAP SC3"
    requirement: FOUND-08
    verification:
      - kind: other
        ref: ".planning/phases/01-foundation-rendering-enforcement-and-layout/01-GATE-EVIDENCE.md — five verbatim failing/green mix check transcripts, git status --porcelain -- test/golden lib priv empty at the end"
        status: pass
    human_judgment: false

# Metrics
duration: ~90min
completed: 2026-09-16
status: complete
---

# Phase 1 Plan 5: Seeded Violations, Phase Citations and Gate Evidence Summary

**Five permanent seeded-violation fixtures proving each of Phase 1's five gates still fires, the 15 pre-existing Credo disables re-pointed from the archived roadmap onto the current one with a citation test that expires a suppression when its phase completes, and a one-time verbatim record of the real `mix check` failing and recovering on all five.**

## Performance

- **Duration:** ~90 min
- **Completed:** 2026-09-16T08:11:53Z
- **Tasks:** 3
- **Files modified/created:** 16 (8 new, 8 modified)

## Accomplishments

- `priv/seeded_violations/{oversized_clause,oversized_quote,runtime_reassembly,string_to_ast,module_name_surgery}.ex` — five fixtures, one real violation each, living on no `elixirc_paths` entry and swept by no `.credo.exs` `included:` glob. Confirmed invisible to every tool that matters: `mix compile --force --warnings-as-errors` exits 0, `mix credo` exits 0, and `mix hex.build`'s published tarball contains zero `priv/` entries (verified directly with `tar tzf`, not inferred from `package_files/0`'s source).
- `test/ash_commanded/seeded_violations_test.exs` calls each gate's real detection logic directly against its fixture — `AshCommanded.Dump.Golden.measure/1`, `Credo.Check.Refactor.LongQuoteBlocks` at `max_line_count: 40`, `AshCommanded.Dump.Lint.check/1`, and both custom Credo checks via `Credo.Test.Case` — and asserts the fixture set is exactly these five files, so a sixth gate added without a fixture fails here rather than leaving an invisible gap.
- Caught and fixed a real, live instance of the exact trap the plan warned about: `module_name_surgery.ex`'s own top-of-file comment, written to document that the fixture carries no exemption marker, initially spelled the marker's literal text out inside that explanation — which caused `AshCommanded.CredoChecks.Exemption`'s plain substring search to self-exempt the fixture, making the FOUND-10 regression test pass vacuously. Reworded to describe the marker without reproducing it, with an explicit warning against reintroducing it.
- Diffed the current 33 `# credo:disable-for-this-file` lines in `lib/` against `c5e71e8^` (the commit immediately before 01-03 started) to isolate the exact 15 pre-existing lines across 8 files D-01 describes, distinct from the 18 `NoModuleNameSurgery`/`ExDNA.Credo` disables 01-03 introduced (and already cited correctly). Added a `# gsd-disable-until-phase: N` citation to all 15, mapped to the phase that actually rewrites each file via `ROADMAP.md`'s Phase Details rather than a mechanical renumber: `command_action_mapper.ex` → Phase 2, `error.ex` → Phase 6, `generate_aggregate_module.ex` → Phase 4, `generate_commanded_application.ex`/`generate_domain_router_module.ex`/`generate_main_router_module.ex` → Phase 3, `generate_event_handler_modules.ex`/`generate_projector_modules.ex` → Phase 5.
- `test/ash_commanded/disable_phase_citation_test.exs` walks `lib/`'s disables and `test/golden/`'s staged markers through one shared roadmap parser and validator: a citation naming a phase absent from `ROADMAP.md`, a citation naming a phase already `Complete`, and a disable with no structured citation within 3 lines all fail, each naming the offending file. Four rule-level assertions run against synthetic fixtures with an injected roadmap map (so a broken rule fails immediately, without waiting for a real `Complete` phase to exist); two real-tree assertions confirm zero violations against the actual repository; two non-vacuity assertions require each walk to find at least one citation to validate.
- `.planning/phases/01-foundation-rendering-enforcement-and-layout/01-GATE-EVIDENCE.md` records, for each of the five gates, a real violation introduced into a location the real `mix check` alias sweeps (`lib/ash_commanded/` for the three source-level gates, `test/golden/parity_widget/` for the two golden-level gates), the verbatim failing output naming the file and the rule, the verbatim green output after revert, and the Elixir version the run was performed on. All five were re-run fresh in this session (see Decisions Made) rather than reusing 01-03's commit-message-only proof.
- `mix check` exits 0; `MIX_ENV=test mix test` reports 249 tests, 0 failures (up from the 229-test count 01-03-SUMMARY.md recorded — this plan's own two new test files add 6 + 9 = 15; the remaining growth comes from 01-04's `info_test.exs` and golden-corpus additions, landed between 01-03 and this plan and not separately re-counted here).

## Task Commits

1. **Task 1 — five seeded fixtures and the meta-test (ROADMAP SC3, FOUND-06..10):** `4f99f98`
2. **Task 2 — re-point the 15 pre-existing disables and add the phase-citation test (D-01, D-02):** `d1348f7`
3. **Task 3 — one-time gate-evidence record (ROADMAP SC3, literal half):** `e0be2d0`

**Plan metadata:** committed alongside this SUMMARY.

## Files Created/Modified

- `priv/seeded_violations/*.ex` (5 files) — one real violation each, one per gate, invisible to compile/lint/publish
- `test/ash_commanded/seeded_violations_test.exs` — permanent regression proof each gate's detection logic fires
- `test/ash_commanded/disable_phase_citation_test.exs` — permanent proof every disable/staged-marker citation is live and incomplete
- `lib/ash_commanded/command_action_mapper.ex`, `error.ex` — added `# gsd-disable-until-phase:` citations (Phase 2, Phase 6)
- `lib/ash_commanded/resource/transformers/generate_aggregate_module.ex`, `generate_domain_router_module.ex`, `generate_event_handler_modules.ex`, `generate_main_router_module.ex`, `generate_projector_modules.ex`, `lib/ash_commanded/domain/transformers/generate_commanded_application.ex` — added citations for the pre-existing disable groups (Phase 3/4/5)
- `.planning/phases/01-foundation-rendering-enforcement-and-layout/01-GATE-EVIDENCE.md` — the one-time literal evidence record

## Decisions Made

See `key-decisions` in frontmatter. Summarized:

1. Identified the precise 15 pre-existing disables by diffing against `c5e71e8^`, rather than re-pointing every disable currently in `lib/` — the 18 disables 01-03 itself introduced already carry correct citations and re-pointing them again would have been redundant at best.
2. Re-ran all five gate-evidence violations fresh rather than reusing 01-03's paraphrased commit-message proof, since no verbatim transcript from that run was archived.
3. Placed the two golden-level scratch violations inside the existing `parity_widget/` fixture directory so `AshCommanded.GoldenRenderTest`'s registration guard also fires — a deliberate second signal on the same glob, documented in the evidence doc rather than treated as noise.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `module_name_surgery.ex` fixture's own documentation comment self-exempted the fixture**

- **Found during:** Task 1, first `mix test test/ash_commanded/seeded_violations_test.exs` run (5/6 passed, FOUND-10 failed with "There should be one issue, got none")
- **Issue:** The fixture's top comment, written to explain that it deliberately carries no `AshCommanded.CredoChecks.Exemption` marker, spelled the marker's literal text (`ash_commanded:namespace-derivation`) out inside that explanation. `Exemption.exempted?/2`'s plain `String.contains?/2` substring search matched that prose exactly as if it were the real marker, silently exempting the whole fixture and making the regression test pass vacuously (no issue found, because the check itself thought the function was exempt) — the exact class of trap the plan called out for the filename guard, just showing up one layer deeper.
- **Fix:** Reworded the comment to describe the marker without reproducing its literal text, and added an explicit inline warning against reintroducing it.
- **Files modified:** `priv/seeded_violations/module_name_surgery.ex`
- **Verification:** `MIX_ENV=test mix test test/ash_commanded/seeded_violations_test.exs` — 6/6 pass.
- **Committed in:** `4f99f98` (Task 1 commit)

**2. [Rule 1 - Bug] Two Credo readability findings in the new citation test, fixed before commit**

- **Found during:** Task 2, first `mix credo` run after writing `disable_phase_citation_test.exs`
- **Issue:** `Refactor.MapJoin` (an `Enum.map/2 |> Enum.join/2` that should be `Enum.map_join/3`) and `Refactor.Nesting` (a helper one level past the configured max depth of 2).
- **Fix:** Switched to `Enum.map_join/3`; extracted `group_violation/5`, `find_citation_phase/2`, `citation_phase_at/3`, and `missing_citation_violation/2` as named functions, each one level shallower.
- **Files modified:** `test/ash_commanded/disable_phase_citation_test.exs`
- **Verification:** `mix credo` exit 0, 0 issues.
- **Committed in:** `d1348f7` (Task 2 commit)

**3. [Rule 3 - Blocking] Two golden-level scratch fixtures needed a `do ... end` block, not a `do:` one-liner**

- **Found during:** Task 3, capturing the FOUND-08 evidence
- **Issue:** A first draft of `AshCommanded.Evidence.RuntimeReassembly.golden` wrote `def execute(state), do: ...` (single-line form). `AshCommanded.Dump.Golden.measure_clause_spans/1` reads clause span off the `:def` node's `meta[:end]` key, which one-line `do:` clauses never carry, raising `KeyError` instead of the clean "measured clause span N exceeds declared clause_max M" assertion message the evidence document quotes.
- **Fix:** Rewrote the fixture using a standard multi-line `do ... end` block, matching what real generated code looks like anyway.
- **Files modified:** none committed (this fixture was a transient scratch file, reverted before the final `mix check`; the corrected form is what `01-GATE-EVIDENCE.md` quotes)
- **Verification:** re-ran `mix check`, got the clean assertion failure quoted in the evidence document.

---

**Total deviations:** 3 auto-fixed (2 bugs, 1 blocking). **Impact:** all three were necessary to make the regression tests and evidence genuinely prove what they claim; none change the plan's delivered scope.

## Known Stubs

None.

## Issues Encountered / Findings for Phase Verification

**Two of the five gate-evidence runs produced a second, independent `mix check` failure alongside the primary one.** Dropping a scratch golden into `test/golden/parity_widget/` to seed the FOUND-06 and FOUND-08 violations also tripped `AshCommanded.GoldenRenderTest` (FOUND-04's own render-parity gate), which raised `no captured module matched <name> under AshCommanded.TestSupport.Parity.Widget` for the same file — both tests walk the identical `test/golden/**/*.golden` glob, so a stray golden trips both gates independently. This is documented explicitly in `01-GATE-EVIDENCE.md` as belt-and-suspenders, not double-counting, but a phase verifier should read that section rather than assume a single clean failure per gate.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- ROADMAP SC3 is now answered in both readings: `test/ash_commanded/seeded_violations_test.exs` is the permanent regression half (runs on every `mix test`), and `01-GATE-EVIDENCE.md` is the one-time literal half (a human-readable record of five real failures and recoveries).
- D-02 is now enforced by a test rather than assumed by convention: every disable and every staged golden in the repository cites a live, incomplete roadmap phase, and a future suppression that outlives its phase becomes a build failure the moment that phase is marked `Complete` in `ROADMAP.md`'s Progress table.
- The 15 disables inherited from the archived 13-phase roadmap are fully repaired; `STATE.md`'s "Pending Todos" entry for this is resolved.
- `FOUND-06`, `FOUND-07`, `FOUND-08`, `FOUND-09`, and `FOUND-10` are all demonstrably met: permanent detection-logic proof plus (for the five ROADMAP SC3 gates specifically) a one-time literal `mix check` proof.
- Phase 2 onward inherits a working pattern for expiring its own suppressions: when Phase 2 (Commands and Events) lands, it should *delete* the `# gsd-disable-until-phase: 2` citations on `command_action_mapper.ex`, `generate_command_modules.ex`, and `generate_event_modules.ex` rather than re-cite them — `disable_phase_citation_test.exs` will fail loudly if Phase 2 is later marked `Complete` while any of those citations still exist.
- `mix check` is green; `MIX_ENV=test mix test` reports 249 tests, 0 failures (176+ baseline maintained with a comfortable margin).
- FOUND-18 (create_module/4 wiring) remains explicitly NOT touched by this plan, per the scope boundary — still tracked open in `WINDOWS.md` entry 5, unchanged.

---
*Phase: 01-foundation-rendering-enforcement-and-layout*
*Completed: 2026-09-16*

## Self-Check: PASSED

- All 8 created files confirmed present on disk (`priv/seeded_violations/*.ex` ×5,
  `test/ash_commanded/seeded_violations_test.exs`,
  `test/ash_commanded/disable_phase_citation_test.exs`,
  `.planning/phases/01-foundation-rendering-enforcement-and-layout/01-GATE-EVIDENCE.md`).
- All 3 task commits confirmed present in git log (`4f99f98`, `d1348f7`, `e0be2d0`).
- Plan-level `<verification>` re-run fresh in this closeout session: `mix check` exit 0;
  `git status --porcelain -- test/golden lib priv` empty; `mix compile --force
  --warnings-as-errors` exit 0 with the fixtures present; `mix credo` exit 0 with the
  fixtures present; `MIX_ENV=test mix test` 249 tests, 0 failures; `grep -rc
  gsd-disable-until-phase lib/` totals 25; every one of the 15 distinct files carrying
  `credo:disable-for-this-file` also carries `gsd-disable-until-phase` (both greps report
  15 distinct files).
