---
gsd_state_version: "1.0"
milestone: v0.3
milestone_name: Library Rewrite
current_phase: 01
current_phase_name: Foundation — Rendering, Enforcement and Layout
status: executing
stopped_at: Completed 01-05-PLAN.md
last_updated: "2026-09-16T08:15:45.497Z"
last_activity: 2026-09-16
last_activity_desc: Phase 01 execution resumed (wave continue)
state_head: ff2045884f12395f339669c95da76b37cb3a22a7
progress:
  total_phases: 7
  completed_phases: 0
  total_plans: 6
  completed_plans: 5
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-09-15)

**Core value:** `core`'s five event-sourced domains run in production on AshCommanded.
**Current focus:** Phase 01 — Foundation — Rendering, Enforcement and Layout

## Current Position

Phase: 01 (Foundation — Rendering, Enforcement and Layout) — EXECUTING
Plan: 5 of 6
Status: Ready to execute
Last activity: 2026-09-16 — Phase 01 execution resumed (wave continue)

Progress: [░░░░░░░░░░] 0% (0/7 phases)

**Phase numbering restarted at 1.** The previous 13-phase roadmap was discarded, not completed, and
is archived at `.planning/milestones/archived-20260915-phases/`. Phase 01 "Build Integrity" from
that roadmap *did* complete and its results are recorded in PROJECT.md → Validated and in
`.planning/LEARNINGS.md`; it is not part of this roadmap's numbering.

## Milestone Roadmap

| Phase | Name | Requirements | Status |
| ------- | ------ | -------------- | -------- |
| 1 | Foundation — Rendering, Enforcement and Layout | 18 (FOUND-01..18) | Not started |
| 2 | Commands and Events | 15 (CMD-01..09, EVT-01..06) | Not started |
| 3 | Application and Routers | 12 (APP-01..12) | Not started |
| 4 | Aggregates | 9 (AGG-01..09) | Not started |
| 5 | Projections, Event Handlers and Process Managers | 13 (PROJ-01..07, HDLR-01..06) | Not started |
| 6 | Event Versioning, Snapshots, Middleware and Transactions | 12 (EVOL-01..05, RUN-01..07) | Not started |
| 7 | Documentation, Packaging and the End-to-End Example | 8 (DOCS-01..08) | Not started |

## Performance Metrics

**Velocity:**

- Total plans completed this milestone: 0
- Average duration: —
- Total execution time: 0.0 hours

**By Phase:**

| Phase    | Plans | Total | Avg/Plan |
|----------|-------|-------|----------|
| *(none)* | -     | -     | -        |

**Recent Trend:**

- Last 5 plans: —
- Trend: —

**Per-Plan Metrics (previous milestone, retained for velocity baseline):**

| Plan | Duration | Tasks | Files |
| ------ | ---------- | ------- | ------- |
| Prior Phase 01 P01 | 25min | 3 tasks | 2 files |
| Prior Phase 01 P03 | 25min | 3 tasks | 10 files |
| Prior Phase 01 P04 | 26min | 2 tasks | 8 files |
| Prior Phase 01 P05 | 40min | 3 tasks | 9 files |
| Prior Phase 01 P06 | 2h10min | 3 tasks | 11 files |
| Prior Phase 01 P07 | 55min | 3 tasks | 32 files |
| Phase 01 P01 | 45min | 2 tasks | 6 files |
| Phase 01 P02 | 95min | 3 tasks | 20 files |
| Phase 01 P03 | 110min | 4 tasks | 30 files |
| Phase 01 P04 | 35min | 3 tasks | 112 files |
| Phase 01 P05 | 90min | 3 tasks | 16 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- **Roadmap (2026-09-15): 7 phases, numbering restarted at 1.** Above the `standard` granularity
  band (4-6) because Foundation is a hard precondition, the six-step method is per-component, and
  the user's fixed component order constrains grouping. Three compressions applied against the
  natural ten-category split.
- **Roadmap: commands and events share Phase 2.** Same generated shape (struct + typespecs from a
  field list). Commands land and are approved first — they are the first exercise of the
  render-and-approve loop and the point at which the method itself is judged.
- **Roadmap: application and routers are one phase (Phase 3).** The confirmed defect spans both and
  the application cannot be demonstrated working without a router. Follows REQUIREMENTS.md's APP
  grouping; supersedes the research document's alternative of grouping routers with event handlers.
- **Roadmap: projections, event handlers and process managers share Phase 5.** HDLR-05 requires the
  three to generate *distinct* shapes — only judgeable with all three rendered side by side.
- **Roadmap: documentation is the last phase, not the first.** Reconciling `CLAUDE.md` before the
  rewrite would be invalidated by the rewrite itself.
- [Prior Phase 01]: D-14's literal `Code.compile_string` + `assert_raise` pattern does not work
  against Spark 2.7.2 (verifier errors from `@after_verify` become warnings, not raises); use
  `Spark.Test.assert_dsl_error/refute_dsl_errors` instead.
- [Prior Phase 01]: `private?: true` ETS makes cross-process Ash record visibility impossible after
  a real Commanded dispatch; router-dispatch tests assert via `dispatch(returning: :aggregate_state)`.
- [Prior Phase 01]: `:meck` removed entirely from the suite after an intermittent `:cover`-server
  race; re-verified over 35 consecutive full-suite runs. Keep the suite mock-free.
- [Prior Phase 01]: Per-file inline Credo disables naming the exact resolving phase, not blanket
  `.credo.exs` disables. **These citations now point at archived phase numbers and must be
  re-pointed as each file is rewritten.**
- [Phase 01]: D-08 (one-way) confirmed: mix ash_commanded.dump ships in the published Hex package as documented public feature
- [Phase 01]: FOUND-18's create_module/4 proven at mechanism level only; no transformer caller wired yet (excluded by Task 2's own scope) — a real end-to-end demonstration needs a future plan
- [Phase 01]: Code.compile_file/1 (used for AST capture) leaves :code.which/1 unable to find a module's real .beam file for the rest of the VM session; capture_entries/2 now purges and force-recompiles affected modules immediately afterward to restore normal compiled state — Discovered when --beam introspection broke for a module already touched by the default AST view in the same test process; invisible in real single-invocation usage but essential for the test suite
- [Phase 01]: Credo strictness folded into plan 01-03 rather than landed standalone — `mix credo -a --strict`
  is RED (exit 6: 34 readability + 72 design issues) while default `mix credo` is exit 0; `mix check` runs
  credo as a blocking step, so landing strictness alone would block plans 01-03..01-06. 01-03 already owns
  `.credo.exs` and `mix.exs` and will calibrate its two new custom checks against strict directly. `coveralls`
  and `precommit.fast` are additive and land with it.
- [Phase 01]: `workflow.build_command` / `workflow.test_command` set in `.planning/config.json` — GSD's
  post-merge gate has no `mix.exs` branch and was skipping silently, so waves could report "verified" with
  nothing having run.
- [Phase 01]: Staged goldens (D-01 marker) are exempt from the runtime-reassembly lint as well as the absolute clause ceiling — The confirmed live :erlang.++ defect (LEARNINGS.md #1) lives in exactly the same not-yet-rewritten aggregate generator that already exceeds the line ceiling; without the exemption mix check could never be green until Phase 4's rewrite
- [Phase 01]: 01-03: FOUND-10/FOUND-18 namespace-derivation collision resolved by one permanent, named, counted exemption marker (# ash_commanded:namespace-derivation) rather than a rewrite or phase-cited suppression
- [Phase 01]: 01-03: Credo.Check.Design.AliasUsage moved to disabled: (not fixed at 72 call sites) when strict mode was turned on — a real strictness reduction, tracked in WINDOWS.md
- [Phase 01]: 01-03: ex_dna's plugin registration alone does not run the check in a project with a non-empty checks: enabled: list — Credo.ConfigFile.merge_checks/2 discards the plugin's extra: contribution; both plugins: and an explicit checks: enabled: entry are required
- [Phase 01]: 01-03: Credo.Check.Design.DuplicatedCode stays disabled (it already was); ex_dna/ExDNA.Credo is a pure addition, not a swap
- [Phase 01]: D-13/D-14 executed as one behaviour-neutral big-bang move: lib/commanded -> lib/ash_commanded resource/domain trees, proven neutral by golden-diff (5/6 byte-identical, 1/6 changed on module-name literals only)
- [Phase 01]: Domain-tree transformer membership follows current extension registration (only GenerateCommandedApplication), not a semantic re-derivation; AshCommanded.Domain.Info currently exposes zero accessors since AshCommanded.Domain.Dsl.sections() is genuinely []
- [Phase 01]: 01-05: identified the exact 15 pre-existing Credo disables (8 files) by diffing against c5e71e8^ (the commit before 01-03 started), re-pointing only those onto the current roadmap's phase numbers rather than every disable currently in lib/
- [Phase 01]: 01-05: re-ran all five gate-evidence violations fresh rather than reusing 01-03's commit-message-only deliberate-violation proof, since no verbatim transcript from that run was archived
- [Phase 01]: 01-05: seeded-violation fixtures live under priv/seeded_violations/ (on no elixirc_paths entry, swept by no .credo.exs included: glob) so they encode real violations permanently without ever compiling, linting, or reaching the published Hex package

### Pending Todos

None currently — the 15 inline Credo disables were re-pointed onto the current roadmap's phase
numbers in 01-05, enforced going forward by `test/ash_commanded/disable_phase_citation_test.exs`.

### Blockers/Concerns

- **Phase 1 gates everything.** No Elixir tool measures macro-emitted code. Until
  `mix ash_commanded.dump` and the golden-render harness exist, step 4 of the per-component method
  ("render and get human approval") cannot happen, and FOUND-06/07/08 have nothing to enforce.
- **Deadlock, not missing state, is the compile-order risk.** Domain transformers reading resource
  persisted state is settled and safe (Phase 3). But ordering comes from an on-demand compiler
  block in `persisted!/3`, so any future design where a *resource* transformer reads back from its
  *domain* can hang the parallel compiler rather than error. Check explicitly before introducing
  any bidirectional read.
- **Chained upcasting is a trap.** `Commanded.Event.Upcaster.upcast/2` is called exactly once per
  stored event, never re-dispatched on its own result. A per-version-hop chain compiles, passes
  naive tests, and silently under-upcasts real history — recoverable only by re-deriving read
  models from the event store. Phase 6, EVOL-02/03.
- **Two latent defects carried in, neither with a compile signal.**
  `generate_projector_modules.ex:359` calls `Ash.run_action(changeset, action)` — arity 2 exists so
  it compiles clean but matches no clause (Phase 5, PROJ-05). And the quarantined
  `commanded_application_integration_test.exs.phase2-blocked` still carries a stale
  `Code.ensure_loaded?` guard; `lib/` was swept for that pattern, `test/` was not (Phase 3,
  APP-08/09).
- **Documentation drift.** `CLAUDE.md` documents three verifiers that do not exist and three stale
  dependency versions. Treat every factual claim in it as unverified until Phase 7 closes it.
- **In-flight branch.** `fix-application-generation` carries the Domain/Resource split. The split
  itself is correct and compiles; router generation never fires under it. Phase 3 owns the fix.
  Revert `workflow.use_worktrees: false` once the branch merges.
- FOUND-18's create_module/4 (explicit file:/line: metadata) is wired into none of the nine real create_module/3 call sites — plan 01-01's must-have is not demonstrable end to end until 01-04 wires those sites or a gap-closure plan does (see 01-03-SUMMARY.md Findings)

## Deferred Items

Items acknowledged and deferred at milestone close, most recent first:

| Category | Item | Status | Deferred At | Milestone |
| ---------- | ------ | -------- | ------------- | ----------- |
| Migration | MIG-01..05 — migrate `identity`, `data`, `integration`, `schema_definition`, `workflow` | Deferred | 2026-09-15 | v0.3 → next |
| Release | REL-01 — publish 1.0 to hex.pm | Deferred | 2026-09-15 | v0.3 → next |
| Example | EX-01 — end-to-end example on Postgres EventStore | Deferred | 2026-09-15 | v0.3 → next |

## Session Continuity

Last session: 2026-09-16T08:15:45.483Z
Stopped at: Completed 01-05-PLAN.md
Next: `/gsd-execute-phase 1`
Resume file: None
