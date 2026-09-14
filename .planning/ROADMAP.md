# Roadmap: AshCommanded

## Overview

The journey runs in two halves. The first half completes the library: make the build and the test
suite honest enough that a failing test means something, make code generation deterministic, then
add the three capabilities `core` actually depends on and the library does not have today — event
type identity and versioning, aggregate invariants with non-attribute state, and projection
expressiveness — before closing out the remaining Commanded primitives, examples and documentation.
The second half migrates `core`'s five event-sourced domains one at a time, each proven
behaviour-preserving by golden-trace replay of real historical events before cutover, in a fixed
order chosen so the riskiest machinery is exercised first and cheaply confirmed to generalise
second. AshCommanded 1.0 ships to hex.pm only when the last domain lands.

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Build Integrity** - Current toolchain, CI gates, and a test suite that can fail for real reasons
- [ ] **Phase 2: Deterministic Generation and Compile-Time Rejection** - Declared transformer order, enforced Domain/Resource boundary, verifiers that actually reject
- [ ] **Phase 3: Event Identity and Versioning** - Event type strings decoupled from module paths, declarative chained upcasting
- [ ] **Phase 4: Aggregate Expressiveness and Lifecycle** - Preconditions, non-attribute state, multi-event commands, persistent snapshots
- [ ] **Phase 5: Projection Expressiveness** - Read-before-write projections, idempotency under redelivery, projector auto-discovery
- [ ] **Phase 6: Event Handlers, Dispatch and Process Managers** - Subscription and dispatch options in the DSL, process managers as first-class
- [ ] **Phase 7: Examples, Documentation and Agent Rules** - Two runnable example apps, a testing guide, docs that match the code
- [ ] **Phase 8: Migration Tooling** - Golden-trace harness, type-string pre-cutover check, cross-domain dependency graph
- [ ] **Phase 9: Migrate identity** - The riskiest domain first: upcasters and renames on the real event store
- [ ] **Phase 10: Migrate integration** - The cheapest domain second: confirm the pilot generalises
- [ ] **Phase 11: Migrate data** - Projection-heavy domain with idempotency exposure
- [ ] **Phase 12: Migrate schema_definition** - The largest command surface (26 commands)
- [ ] **Phase 13: Migrate workflow and publish 1.0** - Last domain lands and the library ships to hex.pm

## Phase Details

### Phase 1: Build Integrity

**Goal**: Every test in the suite can fail for a real reason, on a current, CI-enforced toolchain.
**Depends on**: Nothing (first phase)
**Requirements**: QUAL-01, QUAL-02, REPO-03, REPO-04, REPO-05, TEST-01, TEST-02, TEST-03, TEST-04, TEST-06
**Success Criteria** (what must be TRUE):

  1. A fresh clone runs `mix deps.get && mix compile --warnings-as-errors` successfully without any consumer-supplied `:commanded` or `:eventstore` dependency, and `grep -rn "Mix.env()\|IO.puts\|IO.inspect" lib/` returns no matches.
  2. Generated aggregate, main-router, event-handler and projector modules are created identically under `MIX_ENV=test` and `MIX_ENV=dev` — a test can construct and call them as real compiled modules.
  3. A test asserting a specific `Spark.Error.DslError` message for an invalid DSL passes, and fails if the corresponding verifier is deleted.
  4. No test in the suite asserts against a hardcoded mock return from `CommandActionMapper`; create, update and destroy assertions read state back through `Ash`.
  5. `mix test` and `mix test <any single file>` agree on every test's outcome; no test's result depends on event-store or aggregate-process state left behind by another test.

**Plans**: 7/8 plans executed across 6 waves

Plans:
**Wave 1**

- [x] 01-01-PLAN.md — Commit the in-flight branch work as a baseline, then declare the toolchain and make `mix setup` work (wave 1)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 01-02-PLAN.md — Tracer: one command end-to-end through a really-compiled aggregate into real Ash state, extended to update and destroy (wave 2)
- [x] 01-03-PLAN.md — Delete the remaining module-creation knobs, all six load-check stubs, and both console-print sites (wave 2)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 01-04-PLAN.md — Remove the last two mapper branches and rewrite the three remaining mapper-calling test files (wave 3)
- [x] 01-05-PLAN.md — Compile-time DSL rejection tests for all nine verifiers, replacing the mocked ones (wave 3)

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 01-06-PLAN.md — Test isolation, cross-environment generated-module parity, and direct calls into every generated module kind (wave 4)

**Wave 5** *(blocked on Wave 4 completion)*

- [x] 01-07-PLAN.md — Credo, Dialyzer, cleared warning debt, and a single `mix check` alias (wave 5)

**Wave 6** *(blocked on Wave 5 completion)*

- [ ] 01-08-PLAN.md — CI matrix across the supported Elixir/OTP pairs, plus synced upstream usage rules (wave 6)

**Note**: This phase is the stated blocker for everything downstream. Four transformers
(`generate_aggregate_module.ex:141`, `generate_event_handler_modules.ex:99`,
`generate_main_router_module.ex:128`, `generate_projector_modules.ex:113`) skip real module creation
under `mix test` by default, and `CommandActionMapper` returns hardcoded mocks at five sites. Until
these land, no test written in any later phase can fail for a real reason.

### Phase 2: Deterministic Generation and Compile-Time Rejection

**Goal**: Code generation runs in a declared, total order, the Domain/Resource boundary is enforced rather than conventional, and DSL misuse is rejected at compile time with a specific message.
**Depends on**: Phase 1
**Requirements**: FOUND-01, FOUND-02, FOUND-03, FOUND-04, FOUND-06, FOUND-07, TEST-05, QUAL-06
**Success Criteria** (what must be TRUE):

  1. Every transformer in `lib/commanded/transformers/` declares `after?/1`, the total order is written down in exactly one place, and no `after?/1` clause names a module that does not exist — the dead `ExtractCommands` references in `collect_parameter_transforms.ex` and `collect_parameter_validations.ex` are gone.
  2. A resource declaring commands, events, projections and event handlers compiles to generated modules that each contain every entity declared; a test fails the build if any generated module is produced empty.
  3. Declaring `application` on an `Ash.Resource`, or `commands` on an `Ash.Domain`, raises a `Spark.Error.DslError` naming the correct extension.
  4. `mix compile` from clean succeeds with resources, domain and application all present, and no transformer calls `Ash.Domain.Info` or `Ash.Resource.Info` on any module other than self.
  5. Every verifier in `lib/commanded/verifiers/` has both an accepting test and a rejecting test with an asserted error message; `ValidateCommandActions`, `ValidateCommandHandlers` and `ValidateCommandNameConflict` either exist with such tests or are absent from `CLAUDE.md`.
  6. `AGENTS.md` states the DSL authoring rules, leading with **generated code is thin wiring; logic lives in hand-written runtime modules** — a generated clause carries only the per-entity literals that vary, and anything computable at macro-expansion time is computed there rather than reassembled at runtime. Then section/entity structure, verifier-over-transformer for validation, the `ModuleName.Info` introspection convention, `Transformer.get_persisted/2` over module-name reconstruction, and the escape-hatch types — so a contributor adding a transformer or verifier is told where it goes, which stage it belongs in, and how much of it belongs in the emitted AST at all.
  7. `mix ash_commanded.dump` renders every generated module for a fixture resource to formatted Elixir, committed golden renders exist for that fixture, and CI fails when generated output changes without the golden files being updated in the same change.

**Plans**: TBD

**Note**: FOUND-03 and FOUND-04 must be planned before FOUND-05 (Phase 5). Domain-reads-Resource is
safe; Resource-reads-Domain deadlocks the compiler. Work is already in flight on branch
`fix-application-generation` and should be folded in, not restarted.

### Phase 3: Event Identity and Versioning

**Goal**: An event's stored type string is a declared contract independent of where its module lives, and an event's shape can evolve without breaking replay of what is already persisted.
**Depends on**: Phase 2
**Requirements**: TYPE-01, TYPE-02, TYPE-03, TYPE-04, TYPE-05
**Success Criteria** (what must be TRUE):

  1. An event declared with an explicit type string serializes to exactly that string and deserializes back to the generated module, and still does so after the module is moved to a different namespace.
  2. Reading a stored event whose type string resolves to no loaded module logs a warning and yields a sentinel value — the subscription survives instead of raising `ArgumentError` from `String.to_existing_atom/1`.
  3. An event declaring three ordered upcast transforms compiles to a single `upcast/2` implementation that applies them in declared order; reordering the declarations changes the resulting struct.
  4. Upcasting is asserted against a payload captured from `core`'s existing event store in its pre-change shape, not against a struct the test constructed.
  5. Fields that were atoms or `DateTime`s before serialization are handled correctly after a real JSON round trip, where they arrive as strings.

**Plans**: TBD

**Open question to resolve during planning**: How does `core`'s string-vs-atom key divergence
(aggregates see string keys, projectors see atom keys after deserialization) affect generated code?
`Core.EventTypeTranslator` documents the existing workaround. Affects TYPE-02 here and PROJ-01 in
Phase 5.

**Note**: This phase gates every migration phase. Commanded's default TypeProvider derives the stored
type string from the module name via `Atom.to_string(struct.__struct__)` and reads back with
`String.to_existing_atom/1`. A generated event module at a different path than the hand-written one
it replaces will hard-crash replay of `core`'s historical events.

### Phase 4: Aggregate Expressiveness and Lifecycle

**Goal**: Everything `core`'s 1,822 lines of aggregate code expresses — invariants, non-attribute state, multi-event commands — can be declared in the DSL, and aggregate lifecycle survives a restart.
**Depends on**: Phase 2
**Requirements**: AGG-01, AGG-02, AGG-03, AGG-04, AGG-05, SNAP-01, SNAP-02, SNAP-03, QUAL-03
**Success Criteria** (what must be TRUE):

  1. A command dispatched against an aggregate whose state matches a declared precondition returns `{:error, reason}` and emits no event; a command routed instead to a supplied function or module handler produces the same event as the declared form.
  2. An aggregate holds a map-valued state field that is not a resource attribute, and that field is rebuilt correctly from history after the aggregate process is killed and rehydrated.
  3. A single command emits two events, both persisted to the stream in declared order.
  4. Aggregate lifespan, `snapshot_every` and `snapshot_version` are set from the DSL and honoured, and a snapshot written before a VM restart is still readable after it through the shipped Postgres adapter.
  5. A generated `execute/2` clause is under ~10 lines and delegates to a hand-written runtime module; no `quote` block in `lib/commanded/transformers/` exceeds 40 lines. Measured on generated OUTPUT, not generator length — splitting the generator into builder modules relocates the emission without shrinking it. Baseline at time of writing: `generate_aggregate_module.ex` emits 541 generated lines across 11 `quote` blocks with a 225-line `execute/2` body; every other transformer's largest block is 31 lines and none exceeds 40. The same concerns are currently implemented twice — once inlined in the generated body, once in `command_action_mapper.ex` — and the fix is removing that duplication across the macro boundary.

**Plans**: TBD

**Open questions to resolve during planning**:

- Does the precondition signature `(state, command) -> :ok | {:error, reason}` fit every guard in `core`? Decided by sampling `core`'s 13 aggregates. Affects AGG-01.
- Does `core` use snapshots at all today? Decided by the capability audit. Affects SNAP-01..03 scope.

**Note**: AGG-01..03 gate all migrations — `core`'s aggregate code is exactly invariants plus
non-attribute state, the two things the DSL cannot express today. QUAL-03 belongs here because
adding these capabilities means rewriting `GenerateAggregateModule` regardless; decomposing an
861-line module is part of doing that work, not a separate cleanup.

### Phase 5: Projection Expressiveness

**Goal**: `core`'s 3,523 lines of projector logic can be expressed as declared projections that survive redelivery, and every projector in a domain is supervised without manual registration.
**Depends on**: Phase 4
**Requirements**: PROJ-01, PROJ-02, PROJ-03, PROJ-04, FOUND-05
**Success Criteria** (what must be TRUE):

  1. A projection computes its changes from the event, its metadata and the current record read before the write.
  2. Delivering the same event twice to a generated projector leaves the read-model row byte-identical to a single delivery, for create, update and destroy projections alike.
  3. A projection write that fails rolls back the Ash action it composed with, proven by an integration test against a Postgres event store rather than the in-memory adapter.
  4. A projection can delegate to a supplied function or module and still participate in the same transaction and idempotency guarantees as the declared form.
  5. Adding a resource with a projection to a domain causes its projector to appear in that domain's Commanded application supervision tree with no manual registration, and `mix compile` from clean still succeeds.

**Plans**: TBD

**Open questions to resolve during planning**:

- Use `commanded_ecto_projections` or hand-roll idempotency in the generated AST? Decided by an integration spike before this phase. Affects PROJ-02 and PROJ-04.
- Should projector auto-discovery live in the domain transformer or a third later-compiled module? Decided by a compile-order integration test. Affects FOUND-05.
- `core`'s string-vs-atom key divergence after deserialization (shared with Phase 3). Affects PROJ-01.

**Note**: This is the highest-risk phase. Generated projectors today are bare
`Commanded.Event.Handler` clauses calling `Ash.create`/`update`/`destroy` with no idempotency guard,
and Commanded guarantees at-least-once delivery. FOUND-05 replaces the unfinished TODO at
`generate_commanded_application.ex:115` and must not reintroduce the cross-module compile deadlock
closed in Phase 2.

### Phase 6: Event Handlers, Dispatch and Process Managers

**Goal**: Everything downstream of a persisted event — subscription behaviour, dispatch options and long-running processes — is declarable rather than hand-wired, and the command execution path is decomposed.
**Depends on**: Phase 5
**Requirements**: HAND-01, HAND-02, SAGA-01, SAGA-02, SAGA-03, QUAL-04, QUAL-05
**Success Criteria** (what must be TRUE):

  1. An event handler declaring `start_from`, `subscribe_to` and `consistency` produces a handler configured with exactly those values, and changing the declaration changes observed runtime behaviour, not just generated source.
  2. A command dispatched with declared consistency, timeout and causation/correlation metadata arrives at Commanded carrying those values — asserted on the recorded event metadata, not on the dispatch call site.
  3. A declared process manager routes two related events to a command, persists its state, and recovers that state after its process is killed.
  4. An example and a test drive a process manager end to end, from first triggering event to final dispatched command.
  5. `CommandActionMapper` is under 250 lines with transaction, transformation and error-handling concerns moved to their existing modules, and `Error` is either under 300 lines or carries a comment naming what would break if it were split.

**Plans**: TBD

**Note**: `core` uses no process managers today, so SAGA-01..03 do not gate any migration — they are
1.0 completeness. They sit here because a process manager is a command dispatcher driven by events,
which is the same surface HAND-01 and HAND-02 configure.

### Phase 7: Examples, Documentation and Agent Rules

**Goal**: A developer who has never seen the library can run a full command → event → aggregate → projection → read-model cycle, and knows how to test one.
**Depends on**: Phase 6
**Requirements**: DOCS-01, DOCS-02, DOCS-03, DOCS-04, REPO-01, REPO-02
**Success Criteria** (what must be TRUE):

  1. The in-memory example application dispatches a command and prints the resulting read-model row, running in CI without Postgres.
  2. The Postgres-backed example application runs the same cycle against a real EventStore, including replay of at least one event that requires upcasting.
  3. The testing guide's examples are executed by the test suite — an example that stops compiling fails CI, so the guide cannot drift.
  4. Generated docs and cheat sheets cover both the Resource and the Domain extension, and a test asserts that every DSL option named in the documentation exists in the code.
  5. `usage-rules.md` ships with the package, and `AGENTS.md` states the transformer total order and the testing expectations, so a coding agent adding a transformer is told where it goes.

**Plans**: TBD

**Note**: The Postgres example must exist before the first `core` domain migration is validated — a
migration's correctness claim is only as strong as the adapter it was tested against, and the
in-memory adapter skips the serialization round trip entirely.

### Phase 8: Migration Tooling

**Goal**: A domain migration can be proven behaviour-preserving against real historical events before cutover, using tooling built once and reused five times.
**Depends on**: Phase 7
**Requirements**: MIG-01, MIG-02, MIG-03
**Success Criteria** (what must be TRUE):

  1. The golden-trace harness replays a captured sequence of real `core` events through both the hand-written and the generated implementation and reports a field-level diff of the resulting state.
  2. The harness replays every event twice and still reports equivalence, catching idempotency the hand-written original had by accident but the generated version does not.
  3. A pre-cutover check enumerates every event type string already persisted for a domain and fails if any generated event would serialize to a different string.
  4. `core`'s cross-domain event-handler dependency graph is written down, naming every handler that pattern-matches another domain's event modules.

**Plans**: TBD

**Note**: This phase gates Phases 9-13. Golden traces must include historical events that predate the
most recent schema version, or the upcaster's older branches are never exercised.

### Phase 9: Migrate identity

**Goal**: `core`'s `identity` domain runs on AshCommanded, with its existing upcasters and Organization→Organisation renames expressed through the DSL.
**Depends on**: Phase 8
**Requirements**: MIG-04
**Success Criteria** (what must be TRUE):

  1. Golden-trace replay of `identity`'s real event history through the generated aggregates and projectors is field-identical to the hand-written implementation, including events that predate the current schema.
  2. No hand-written `Commanded.Event.Upcaster` implementation remains in `identity` — every upcast is a DSL-declared transform, and the pre-cutover type-string check passes for every `identity` event type.
  3. Every handler in another domain that references an `identity` event module is updated in the same change, and `core`'s full test suite passes against a Postgres event store.
  4. `identity`'s command and event module count drops measurably while every aggregate business rule remains expressed in the aggregate — no rule is dropped, and none is moved into a projection.

**Plans**: TBD

**Note**: `identity` goes first deliberately: it already contains the upcasters and the renames, so it
exercises the riskiest machinery on the first attempt rather than the fifth.

### Phase 10: Migrate integration

**Goal**: The `identity` pilot is shown to generalise on the cheapest possible domain — one aggregate, one command, one event — before larger domains are committed to.
**Depends on**: Phase 9
**Requirements**: MIG-05
**Success Criteria** (what must be TRUE):

  1. Golden-trace replay of `integration`'s event history is field-identical to the hand-written implementation, under single and double delivery.
  2. The migration requires no library changes; any capability gap found is fixed in AshCommanded and re-verified, never worked around inside `core`.
  3. The pre-cutover type-string check passes and every cross-domain consumer of `integration` events is updated in the same change.

**Plans**: TBD

### Phase 11: Migrate data

**Goal**: `core`'s `data` domain runs on AshCommanded, with its projector logic surviving redelivery.
**Depends on**: Phase 10
**Requirements**: MIG-06
**Success Criteria** (what must be TRUE):

  1. Golden-trace replay of `data`'s event history, including double delivery of every event, is field-identical to the hand-written implementation.
  2. Every `data` projector that computed a delta (increment, append) is expressed as an absolute set or guarded by an explicit idempotency key — replaying an event does not double-apply it.
  3. The pre-cutover type-string check passes, every cross-domain consumer is updated in the same change, and `core`'s full test suite passes against a Postgres event store.

**Plans**: TBD

### Phase 12: Migrate schema_definition

**Goal**: `core`'s largest command surface runs on AshCommanded with no hand-written command or event structs left.
**Depends on**: Phase 11
**Requirements**: MIG-07
**Success Criteria** (what must be TRUE):

  1. All 26 of `schema_definition`'s commands are declared in the DSL, and golden-trace replay of the domain's event history is field-identical to the hand-written implementation.
  2. No hand-written Commanded command, event or aggregate module remains in `schema_definition`.
  3. The pre-cutover type-string check passes for every `schema_definition` event type, every cross-domain consumer is updated in the same change, and `core`'s full test suite passes against a Postgres event store.

**Plans**: TBD

### Phase 13: Migrate workflow and publish 1.0

**Goal**: The last `core` domain lands on AshCommanded and the library ships to hex.pm with its migration notes.
**Depends on**: Phase 12
**Requirements**: MIG-08, REL-01
**Success Criteria** (what must be TRUE):

  1. Golden-trace replay of `workflow`'s event history is field-identical to the hand-written implementation, and the pre-cutover type-string check passes.
  2. No hand-written Commanded aggregate, command or event module remains anywhere in `core`'s five event-sourced domains, and `core` runs in production on AshCommanded.
  3. AshCommanded 1.0 is installable from hex.pm, and a fresh project following the published README reaches a working command → event → projection cycle.
  4. Migration notes from 0.2.0 name every breaking DSL change made over the course of this project.

**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10 → 11 → 12 → 13

| Phase | Plans Complete | Status | Completed |
| ------- | ---------------- | -------- | ----------- |
| 1. Build Integrity | 7/8 | In Progress|  |
| 2. Deterministic Generation and Compile-Time Rejection | 0/TBD | Not started | - |
| 3. Event Identity and Versioning | 0/TBD | Not started | - |
| 4. Aggregate Expressiveness and Lifecycle | 0/TBD | Not started | - |
| 5. Projection Expressiveness | 0/TBD | Not started | - |
| 6. Event Handlers, Dispatch and Process Managers | 0/TBD | Not started | - |
| 7. Examples, Documentation and Agent Rules | 0/TBD | Not started | - |
| 8. Migration Tooling | 0/TBD | Not started | - |
| 9. Migrate identity | 0/TBD | Not started | - |
| 10. Migrate integration | 0/TBD | Not started | - |
| 11. Migrate data | 0/TBD | Not started | - |
| 12. Migrate schema_definition | 0/TBD | Not started | - |
| 13. Migrate workflow and publish 1.0 | 0/TBD | Not started | - |

## Requirement Coverage

All 59 v1 requirements map to exactly one phase.

| Phase | Requirements | Count |
| ------- | -------------- | ------- |
| 1 | QUAL-01, QUAL-02, REPO-03, REPO-04, REPO-05, TEST-01, TEST-02, TEST-03, TEST-04, TEST-06 | 10 |
| 2 | FOUND-01, FOUND-02, FOUND-03, FOUND-04, FOUND-06, FOUND-07, TEST-05, QUAL-06 | 8 |
| 3 | TYPE-01, TYPE-02, TYPE-03, TYPE-04, TYPE-05 | 5 |
| 4 | AGG-01, AGG-02, AGG-03, AGG-04, AGG-05, SNAP-01, SNAP-02, SNAP-03, QUAL-03 | 9 |
| 5 | PROJ-01, PROJ-02, PROJ-03, PROJ-04, FOUND-05 | 5 |
| 6 | HAND-01, HAND-02, SAGA-01, SAGA-02, SAGA-03, QUAL-04, QUAL-05 | 7 |
| 7 | DOCS-01, DOCS-02, DOCS-03, DOCS-04, REPO-01, REPO-02 | 6 |
| 8 | MIG-01, MIG-02, MIG-03 | 3 |
| 9 | MIG-04 | 1 |
| 10 | MIG-05 | 1 |
| 11 | MIG-06 | 1 |
| 12 | MIG-07 | 1 |
| 13 | MIG-08, REL-01 | 2 |
| **Total** | | **59** |

## Ordering Constraints

These are verified findings, not preferences. A roadmap that violates them cannot execute.

1. **Phase 1 is a hard blocker.** Four transformers skip real module creation under `mix test` by
   default and `CommandActionMapper` returns hardcoded mocks at five sites. Until that is fixed, no
   test written in any later phase can fail for a real reason.
2. **Phase 3 gates Phases 9-13.** Commanded binds the stored event type string to the Elixir module
   name. A generated event module at a different path than the one it replaces hard-crashes replay
   of `core`'s historical events.
3. **FOUND-03 and FOUND-04 (Phase 2) precede FOUND-05 (Phase 5).** Calling `Ash.Domain.Info.resources/1`
   from a transformer while the target is mid-compile deadlocks the compiler.
4. **Phase 4 gates Phases 9-13.** `core`'s aggregate code is exactly invariants plus non-attribute
   state — the two things the DSL cannot express today.
5. **Phase 8 precedes Phases 9-13.** Migration tooling is built once and reused five times.
6. **Migration order is fixed:** identity → integration → data → schema_definition → workflow.
   `identity` first because it already contains the upcasters and the Organization→Organisation
   renames, exercising the riskiest machinery. `integration` second because it is trivial (1
   aggregate, 1 command, 1 event), cheaply confirming the pilot generalises before committing to
   `schema_definition`'s 26 commands.

---

Roadmap created: 2026-09-11
