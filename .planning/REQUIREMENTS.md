# Requirements: AshCommanded

**Defined:** 2026-09-11
**Core Value:** `core`'s five event-sourced domains run in production on AshCommanded.

"User" below means a developer consuming the library, unless stated otherwise.

## v1 Requirements

### Foundation

- [ ] **FOUND-01**: Transformer execution order is declared as an explicit total order, with every transformer declaring `after?/1`, and the dead `AshCommanded.Commanded.Transformers.ExtractCommands` references removed from `collect_parameter_transforms.ex` and `collect_parameter_validations.ex`
- [ ] **FOUND-02**: A test fails if any generated module is produced empty, so a mis-ordered transformer cannot silently generate nothing
- [ ] **FOUND-03**: The `application` section is valid only on an `Ash.Domain` via `AshCommanded.Commanded.DomainDsl`, and `commands`/`events`/`projections`/`event_handlers` only on an `Ash.Resource` via `AshCommanded.Commanded.Dsl`
- [ ] **FOUND-04**: A resource-level transformer that reads its domain's DSL state is rejected or prevented, so the compile deadlock cannot be reintroduced
- [ ] **FOUND-05**: A domain's generated Commanded application supervises every projector across its resources without manual registration

### Test Infrastructure

- [ ] **TEST-01**: No production code branches on `Mix.env()` — module creation and Ash action execution behave identically in test and production
- [ ] **TEST-02**: A developer can write a test asserting that an invalid DSL is rejected at compile time with a specific error message
- [ ] **TEST-03**: The test suite exercises generated aggregate, projector, router and event-handler modules as real compiled modules
- [ ] **TEST-04**: The test suite exercises real Ash create/update/destroy execution rather than mocked return values
- [ ] **TEST-05**: Every verifier has tests covering both a valid DSL that is accepted and an invalid DSL that is rejected
- [ ] **TEST-06**: Event store state is isolated between tests, with no leakage across async tests

### Event Identity and Versioning

- [ ] **TYPE-01**: A developer can declare an explicit event type string independent of the event module's path
- [ ] **TYPE-02**: The library provides a `Commanded.EventStore.TypeProvider` that honours declared event type strings in both directions
- [ ] **TYPE-03**: A stored event whose type resolves to no loaded module degrades to a logged sentinel instead of raising and killing the subscription
- [ ] **TYPE-04**: A developer can declare ordered upcast transforms for an event, compiled into a single `upcast/2` implementation, giving the chaining Commanded does not provide natively
- [ ] **TYPE-05**: Upcasting is verified against a store containing events persisted in an earlier shape, not only against synthetic structs

### Aggregates

- [ ] **AGG-01**: A developer can declare preconditions that reject a command based on aggregate state, returning `{:error, reason}`
- [ ] **AGG-02**: A developer can declare aggregate state fields that are not derived from resource attributes, including maps and collections
- [ ] **AGG-03**: A single command can emit multiple events
- [ ] **AGG-04**: A developer can supply a function or module reference for command handling where declaration is insufficient
- [ ] **AGG-05**: Aggregate lifespan is configurable from the DSL

### Projections

- [ ] **PROJ-01**: Projection changes can be computed from the event, its metadata and the current record
- [ ] **PROJ-02**: Projections are idempotent under at-least-once redelivery
- [ ] **PROJ-03**: A developer can supply a function or module reference for projection logic where declaration is insufficient
- [ ] **PROJ-04**: Projection writes compose transactionally with Ash actions, proven by an integration test rather than assumed

### Event Handlers and Dispatch

- [ ] **HAND-01**: Event handler subscription options (`start_from`, `subscribe_to`, `consistency`) are declarable in the DSL
- [ ] **HAND-02**: Command dispatch options — consistency, timeout, and causation/correlation metadata — pass through from the DSL to Commanded

### Process Managers

- [ ] **SAGA-01**: A developer can declare a process manager, including its routing and state
- [ ] **SAGA-02**: Process manager state is persisted and recovered per Commanded's semantics
- [ ] **SAGA-03**: At least one example and test covers a process manager end to end

### Snapshots

- [ ] **SNAP-01**: Snapshot storage is a documented, pluggable behaviour
- [ ] **SNAP-02**: A persistent Postgres-backed snapshot adapter ships with the library
- [ ] **SNAP-03**: Snapshot configuration (`snapshot_every`, `snapshot_version`) is declarable from the DSL

### Code Quality

- [ ] **QUAL-01**: `:commanded` and `:eventstore` are declared dependencies in `mix.exs`
- [ ] **QUAL-02**: No `IO.puts` or `IO.inspect` in production paths; `Logger` is used throughout
- [ ] **QUAL-03**: `GenerateAggregateModule` (861 lines) is decomposed into a thin transformer plus focused AST builders
- [ ] **QUAL-04**: `CommandActionMapper` (640 lines) is decomposed, with transaction and transformation concerns moved to their existing modules
- [ ] **QUAL-05**: `Error` (514 lines) is reviewed and reduced or justified
- [ ] **QUAL-06**: The three verifiers documented but absent — `ValidateCommandActions`, `ValidateCommandHandlers`, `ValidateCommandNameConflict` — are either implemented or removed from the documentation

### Examples and Documentation

- [ ] **DOCS-01**: A runnable end-to-end example application on Commanded's in-memory adapter, covering command through event, aggregate, projection and read model
- [ ] **DOCS-02**: A runnable end-to-end example application on a Postgres-backed EventStore
- [ ] **DOCS-03**: A testing guide showing how to test commands, aggregate invariants, projections, upcasting and full event flows
- [ ] **DOCS-04**: Generated documentation and cheat sheets cover both the Resource and Domain extensions, and no documented feature is absent from the code

### Repository and Tooling

- [ ] **REPO-01**: `usage_rules` is set up and a `usage-rules.md` is published with the package
- [ ] **REPO-02**: An `AGENTS.md` documents DSL conventions, transformer ordering and testing expectations for coding agents
- [ ] **REPO-03**: Dependencies are current — Ash, Spark (`~> 2.6`, required by Ash), ExDoc — with Credo and Dialyxir added
- [ ] **REPO-04**: `mix.exs` declares `elixir: "~> 1.18"` and CI runs a matrix across Elixir 1.18, 1.19 and 1.20 on their supported OTP releases
- [ ] **REPO-05**: CI runs format check, Credo, compile with warnings as errors, tests, Dialyzer and a docs build

### Migration Tooling

- [ ] **MIG-01**: A golden-trace harness replays real historical events through both the existing and generated implementations and asserts identical resulting state
- [ ] **MIG-02**: A pre-cutover check verifies that every generated event's type string matches what is already persisted for that event
- [ ] **MIG-03**: `core`'s cross-domain event-handler dependency graph is documented, so migration sequencing is chosen rather than assumed

### core Migration

- [ ] **MIG-04**: `identity` runs on AshCommanded, verified by golden trace
- [ ] **MIG-05**: `integration` runs on AshCommanded, verified by golden trace
- [ ] **MIG-06**: `data` runs on AshCommanded, verified by golden trace
- [ ] **MIG-07**: `schema_definition` runs on AshCommanded, verified by golden trace
- [ ] **MIG-08**: `workflow` runs on AshCommanded, verified by golden trace

### Release

- [ ] **REL-01**: AshCommanded 1.0 is published to hex.pm with migration notes from 0.2.0

## v2 Requirements

Deferred. Tracked but not in the current roadmap.

### Distribution

- **DIST-01**: Declarative configuration for distributed registries (Swarm, Horde)
- **DIST-02**: Guidance and tests for multi-node deployment

### Multitenancy

- **TENANT-01**: Ash multitenancy integration for commands and projections

### Storage

- **STORE-01**: Additional snapshot adapters beyond Postgres

## Out of Scope

| Feature | Reason |
|---------|--------|
| Backwards compatibility with the published 0.2.0 DSL | Adoption is negligible; the aggregate and projection redesign cannot be done additively |
| Non-Commanded event-sourcing backends | The library targets Commanded 1.4.x specifically |
| Migrating `core` code that is not event-sourced | Only the CQRS/ES surface is in scope |
| Ash multitenancy support | `core` uses none; building it untested against real usage is speculative. Deferred to v2 |
| Multi-node / distributed registry configuration | `core` has no multi-node requirement; this is supervision-tree configuration, not DSL syntax. Deferred to v2 |
| Maintaining a private fork | David holds upstream maintainer rights, so work lands in `accountex-org/ash_commanded` |
| Reusing `ash-project`'s shared CI workflow | It assumes org-owned secrets and actions unavailable under `accountex-org` |

## Open Questions

Resolved during planning, not now.

| Question | Affects | Decided by |
|----------|---------|-----------|
| Use `commanded_ecto_projections` or hand-roll idempotency in generated AST? | PROJ-02, PROJ-04 | Integration spike before the projection phase |
| Does `core` use snapshots at all today? | SNAP-01..03 scope | Capability audit |
| Aggregate precondition signature — does `(state, command) -> :ok \| {:error, reason}` fit every guard in `core`? | AGG-01 | Sampling `core`'s 13 aggregates during planning |
| Should projector auto-discovery live in the domain transformer or a third later-compiled module? | FOUND-05 | Compile-order integration test |
| How does `core`'s string-vs-atom key divergence (aggregates see string keys, projectors see atom keys after deserialization) affect generated code? | PROJ-01, TYPE-02 | Capability audit — `Core.EventTypeTranslator` documents the workaround |

## Traceability

Populated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| _(all v1 requirements)_ | _pending roadmap_ | Pending |

**Coverage:**
- v1 requirements: 57 total
- Mapped to phases: 0
- Unmapped: 57 ⚠️

---
*Requirements defined: 2026-09-11*
*Last updated: 2026-09-11 after initial definition*
