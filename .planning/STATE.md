---
gsd_state_version: "1.0"
milestone: v0.3
milestone_name: Library Rewrite
current_phase: 01
current_phase_name: Foundation — Rendering, Enforcement and Layout
status: executing
stopped_at: Completed 01-01-PLAN.md
last_updated: "2026-09-15T04:03:36.457Z"
last_activity: 2026-09-15
last_activity_desc: Phase 01 execution started
state_head: 937548f5ea36135a024acfadbd3f662b357366f3
progress:
  total_phases: 7
  completed_phases: 0
  total_plans: 6
  completed_plans: 1
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-09-15)

**Core value:** `core`'s five event-sourced domains run in production on AshCommanded.
**Current focus:** Phase 01 — Foundation — Rendering, Enforcement and Layout

## Current Position

Phase: 01 (Foundation — Rendering, Enforcement and Layout) — EXECUTING
Plan: 2 of 6
Status: Ready to execute
Last activity: 2026-09-15 — Phase 01 execution started

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

### Pending Todos

- Re-point the 15 inline Credo disables: each cites a phase number from the archived 13-phase
  roadmap. Update the citation as each file is rewritten under the new numbering.

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

## Deferred Items

Items acknowledged and deferred at milestone close, most recent first:

| Category | Item | Status | Deferred At | Milestone |
| ---------- | ------ | -------- | ------------- | ----------- |
| Migration | MIG-01..05 — migrate `identity`, `data`, `integration`, `schema_definition`, `workflow` | Deferred | 2026-09-15 | v0.3 → next |
| Release | REL-01 — publish 1.0 to hex.pm | Deferred | 2026-09-15 | v0.3 → next |
| Example | EX-01 — end-to-end example on Postgres EventStore | Deferred | 2026-09-15 | v0.3 → next |

## Session Continuity

Last session: 2026-09-15T04:03:36.444Z
Stopped at: Completed 01-01-PLAN.md
Next: `/gsd-plan-phase 1`
Resume file: None
