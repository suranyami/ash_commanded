# AshCommanded

## What This Is

AshCommanded is an Elixir library that brings CQRS and Event Sourcing to the Ash Framework
declaratively. It is a Spark DSL extension: you describe commands, events, aggregate behaviour
and projections inside an Ash resource, and the library generates the Commanded modules —
command structs, event structs, aggregates, projectors, routers and the Commanded application —
that would otherwise be written by hand, one file at a time.

This project completes a library that was abandoned by its original author with structural pieces
missing, brings it to production quality, and then migrates the `core` application's entire
event-sourced codebase onto it. David is now a maintainer of the upstream repository
(`accountex-org/ash_commanded`) with rights to merge, triage issues and publish to hex.pm, so the
work lands upstream rather than in a private fork.

## Core Value

`core`'s five event-sourced domains run in production on AshCommanded. No lesser proof counts —
a library for removing event-sourcing boilerplate is only credible if it carries a real
event-sourced system.

## Context

**Why this exists.** `core` has accumulated 163 event-sourcing modules totalling ~6,398 LOC across
five domains — roughly 29% of its 22,380-line `lib` tree — and the volume of files, directories and
near-identical modules has become a drag on working in the codebase. Repetition at that scale is the
textbook smell a DSL exists to remove.

**Measured surface of `core`'s event-sourced code (2026-09-11):**

| Kind | Files | LOC | Character |
|------|-------|-----|-----------|
| Commands | 64 | 505 | Plain structs, ~8 LOC each — near-total boilerplate |
| Events | 68 | 548 | Structs, `@derive Jason.Encoder`, some `Commanded.Event.Upcaster` impls |
| Aggregates | 13 | 1,822 | Genuine invariants mixed with dispatch plumbing |
| Projectors | 18 | 3,523 | Mostly real logic; the heaviest category |
| **Total** | **163** | **6,398** | Across `data`, `identity`, `integration`, `schema_definition`, `workflow` |

The win is asymmetric and worth stating plainly: 132 of 163 files (commands + events) are almost
pure boilerplate but only 1,053 lines. The remaining 5,345 lines carry real business logic that a
DSL can frame but not delete. Expect a dramatic reduction in file and module count and a more
modest reduction in total lines — which is the right trade, because file/module sprawl is the
stated pain.

**Structural gaps found during initial investigation:**

1. **Domain vs Resource DSL split.** The Commanded *application* is a per-domain singleton (one
   router, one event store, one supervisor) and cannot coherently be declared on a resource. Work
   is already in flight on branch `fix-application-generation` separating
   `AshCommanded.Commanded.Dsl` (targets `Ash.Resource`) from `AshCommanded.Commanded.DomainDsl`
   (targets `Ash.Domain`).
2. **No event versioning whatsoever.** `core` relies on `Commanded.Event.Upcaster` to evolve events
   across schema changes (e.g. `Core.Identity.Events.OrganisationRegistered` drops removed fields on
   replay). A search for `Upcaster`/`upcast` across ash_commanded returns nothing. For a library
   whose subject is an append-only log, this is a first-class absence.
3. **No vocabulary for aggregate invariants or non-attribute state.** `core`'s aggregates encode
   business rules as pattern-matched guards (`%__MODULE__{id: nil}` → already-created error;
   `status: :suspended` → reject update) and hold state that is not a resource attribute
   (`members: %{}`). `GenerateAggregateModule` generates execute/apply pairs from command→event
   mappings and has no way to express either.
4. **No end-to-end example.** There is no runnable application demonstrating the library across a
   full command → event → projection → read-model cycle.
5. **No documented testing story.** Nothing shows a consumer how to test a system built this way.
6. **Contrived tests.** Coverage looks healthy by file count, but tests largely assert that
   transformers *ran* (module exists, struct has fields) rather than that DSL misuse is *rejected*.
   Unhappy paths are barely exercised — `test/commanded/verifiers/event_handler_tests.exs` only
   checks that the verifier modules load.

**Documentation drift.** `CLAUDE.md` documents verifiers `ValidateCommandActions`,
`ValidateCommandHandlers` and `ValidateCommandNameConflict`. None of the three exist in
`lib/commanded/verifiers/`. Treat existing documentation as aspirational until verified.

**Known debt (from `.planning/codebase/CONCERNS.md`), all in scope:**

- `:commanded` and `:event_store` are not declared in `mix.exs` despite generated code depending on them
- `IO.puts`/`IO.inspect` in production paths (`snapshot_store.ex:111`, `middleware/base_middleware.ex:18,25,31`)
- `GenerateAggregateModule` is 861 lines spanning command execution, event application and snapshots
- `CommandActionMapper` is 640 lines spanning mapping, transformation, validation, transactions and error handling
- `Error` module is 514 lines
- `generate_commanded_application.ex:115` — projector auto-discovery is an unfinished TODO
- Snapshot store is ETS-only: lost on VM restart, unusable across nodes, not production-ready
- Generated command structs carry no validation independent of middleware

## Requirements

### Validated

<!-- Inferred from existing code, 2026-09-11. Working today; must not regress. -->

- ✓ Spark DSL extension on `Ash.Resource` exposing `commands`, `events`, `projections`, `event_handlers` — existing
- ✓ Spark DSL extension on `Ash.Domain` exposing `application` — existing (in flight on `fix-application-generation`)
- ✓ Command struct generation with typespecs (`GenerateCommandModules`) — existing
- ✓ Event struct generation with typespecs (`GenerateEventModules`) — existing
- ✓ Projection and projector module generation (`GenerateProjectionModules`, `GenerateProjectorModules`) — existing
- ✓ Aggregate module generation with execute/apply (`GenerateAggregateModule`) — existing
- ✓ Domain and main router generation (`GenerateDomainRouterModule`, `GenerateMainRouterModule`) — existing
- ✓ Commanded application generation with projector supervision (`GenerateCommandedApplication`) — existing
- ✓ Nine compile-time verifiers over command, event, event-handler and projection DSL — existing
- ✓ Command middleware pipeline (base, logging, validation, processor) — existing
- ✓ Parameter transformation and validation layers — existing
- ✓ Transaction coordination via `Ecto.Multi` — existing
- ✓ Snapshot support with pluggable adapter interface (ETS default) — existing

### Active

<!-- Hypotheses until shipped and validated. -->

**Library completion**

- [ ] Land the Domain/Resource DSL split currently in flight on `fix-application-generation`
- [ ] Audit the library against `core`'s real event-sourcing patterns and produce an explicit capability checklist
- [ ] Declarative event versioning — express `Commanded.Event.Upcaster` through the DSL
- [ ] Declarative aggregate invariants and preconditions (reject commands based on aggregate state)
- [ ] Aggregate state that is not derived from resource attributes (collections, maps, derived fields)
- [ ] Projection expressiveness sufficient to absorb `core`'s projector logic, with escape hatches only where genuinely required
- [ ] Implement projector auto-discovery (replace the `generate_commanded_application.ex:115` TODO)
- [ ] Production-viable snapshot store beyond in-memory ETS

**Examples and documentation**

- [ ] End-to-end example application on Commanded's in-memory adapter — fast, CI-friendly, doc-facing
- [ ] End-to-end example application on a Postgres-backed EventStore — proves the real persistence path
- [ ] Documented testing story: how to test commands, aggregates, projections and full event flows
- [ ] Documentation reconciled with reality (remove or implement the three documented-but-absent verifiers)

**Quality**

- [ ] Tests that exercise unhappy paths — DSL misuse rejected at compile time, runtime failures handled
- [ ] Declare `:commanded` and `:event_store` in `mix.exs`
- [ ] Replace `IO.puts`/`IO.inspect` in production paths with `Logger`
- [ ] Decompose `GenerateAggregateModule` (861 lines) and `CommandActionMapper` (640 lines)
- [ ] Review `Error` (514 lines) for composition opportunities

**core migration**

- [ ] Migrate `identity` onto AshCommanded
- [ ] Migrate `data` onto AshCommanded
- [ ] Migrate `integration` onto AshCommanded
- [ ] Migrate `schema_definition` onto AshCommanded
- [ ] Migrate `workflow` onto AshCommanded

**Release**

- [ ] Publish 1.0 to hex.pm once `core` is fully migrated

### Out of Scope

- **Backwards compatibility with the published 0.2.0 DSL** — adoption is negligible and the
  aggregate/projection redesign cannot be done additively. Break freely on 0.x; migration notes
  ship with 1.0.
- **Maintaining a private fork** — David is an upstream maintainer, so work lands in
  `accountex-org/ash_commanded` directly.
- **Non-Commanded event-sourcing backends** — the library targets Commanded 1.4.8 specifically.
- **Migrating `core` code that is not event-sourced** — only the CQRS/ES surface is in scope.

## Constraints

- **Tech stack**: Elixir ~> 1.14 (developed on 1.18.4), Erlang/OTP 27.3 — matches `core`'s runtime
- **Dependencies**: Ash ~> 3.0 (3.5.8), Spark ~> 2.3 (2.3.5), Commanded 1.4.8 — pinned by `core`'s own versions
- **Compatibility**: Must support every pattern `core` uses today, or `core` cannot migrate
- **Licence**: MIT, upstream `accountex-org/ash_commanded` — contributions must suit a public library
- **Genericity**: Examples and tests must be domain-neutral; no Accountex-specific concepts in the published library
- **Versioning**: Break freely on 0.x; 1.0 is cut only after `core` is fully migrated

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Bar for "production ready" is `core` running on it | A boilerplate-removal library is only credible if it carries a real system; any lesser bar is self-assessed | — Pending |
| `core` migration is inside this project's scope | Changed from "library only" during questioning — direct proof beats indirect proof, and the migration is the payoff | — Pending |
| All five `core` domains, not a pilot | Partial migration leaves `core` maintaining two idioms at once, which is worse than either | — Pending |
| Absorb everything viable into the DSL, not just boilerplate | Boilerplate-only wins file count but leaves 5,345 lines of aggregate/projector logic untouched; escape hatches only where genuinely needed | — Pending |
| Declarative event upcasting is a v1 requirement | `core` depends on `Commanded.Event.Upcaster`; an ES library with no schema-evolution story is incomplete | — Pending |
| Fold the in-flight `fix-application-generation` work into Phase 1 | The Domain/Resource split is correct and already underway; restarting wastes it | — Pending |
| Two example adapters (in-memory + Postgres EventStore) | In-memory keeps docs and CI fast; Postgres proves the path `core` actually uses | — Pending |
| All flagged tech debt in scope | "Production ready" is not compatible with `IO.inspect` in dispatch paths or undeclared dependencies | — Pending |
| Break the DSL now, cut 1.0 later | 0.2.0 adoption is negligible; freezing the DSL before `core` migrates would lock in the gaps this project exists to fix | — Pending |
| Upstream rather than fork | David holds maintainer rights on `accountex-org/ash_commanded` including hex publishing | ✓ Good |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-09-11 after initialization*
