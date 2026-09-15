# Requirements: AshCommanded — Milestone v0.3 Library Rewrite

**Defined:** 2026-09-15
**Core Value:** `core`'s five event-sourced domains run in production on AshCommanded.
**This milestone's contribution:** a rewritten generation layer good enough that the migration
milestone is worth attempting. `core` migration itself is explicitly out of scope here.

**"User" throughout means the developer consuming AshCommanded**, not an end user of their app.

## Method

Every component requirement below is delivered through the same loop, and a component is not
complete until all six steps are done:

1. Propose the DSL surface
2. Write a runnable usage example
3. Build the transformer(s)
4. **Render the generated output and get human approval of its conciseness**
5. Iterate the transformer if the render is unsatisfactory
6. Add persisters/verifiers and a test suite; `mix check` green

## Milestone Requirements

### Foundation

Must land before the first component, because step 4 of the method depends on it.

- [x] **FOUND-01**: `mix ash_commanded.dump <Module>` renders a DSL-using module's generated code as formatted Elixir source
- [x] **FOUND-02**: The renderer defaults to the AST as written by the transformer, before `Module.create/3`
- [x] **FOUND-03**: The renderer can also render post-compile from BEAM `debug_info`, behind a flag
- [ ] **FOUND-04**: Golden renders of generated output are committed and diffed in CI, failing the build on unreviewed change
- [x] **FOUND-05**: A developer can regenerate golden files with a single documented command
- [ ] **FOUND-06**: A check fails the build when any generated function clause exceeds ~10 lines in the rendered output
- [ ] **FOUND-07**: A check fails the build when any `quote` block in the library exceeds 40 lines
- [ ] **FOUND-08**: A check fails the build when values computable at macro-expansion time survive into rendered output as runtime work (the `:erlang.++` class of defect)
- [ ] **FOUND-09**: A check fails the build when transformer code calls `Code.string_to_quoted!`/`eval_string` to build AST from strings
- [ ] **FOUND-10**: A check fails the build when a module name is derived by `Module.split`/`Module.concat` surgery rather than from persisted state
- [ ] **FOUND-11**: Structural duplicate detection runs across generator modules and reports clones Credo's built-in check misses
- [ ] **FOUND-12**: Rule 9 ("no double-handling") is carried as an explicit reviewer checklist item, since no mechanical check exists for it
- [ ] **FOUND-13**: `usage_rules` is a dev dependency and the library publishes generated LLM-facing usage rules
- [ ] **FOUND-14**: `AGENTS.md` documents idiomatic Elixir, DSL conventions, transformer ordering and testing expectations, using `core` as the worked reference
- [ ] **FOUND-15**: `AGENTS.md` includes the Spark API reference so implementers reach for built-in machinery before hand-rolling it
- [ ] **FOUND-16**: CI runs the suite against the current Elixir/OTP release plus the previous two minors
- [ ] **FOUND-17**: `lib/` is reorganised into `resource/` and `domain/` trees, each with its own `transformers/`, `verifiers/` and `info.ex`
- [x] **FOUND-18**: A shared module-creation helper sets explicit `file:`/`line:` metadata so generated-code errors point somewhere useful

### Commands

- [ ] **CMD-01**: A user can declare a command with a name and fields, and get a generated struct with typespecs
- [ ] **CMD-02**: A user can map a command to a named Ash action
- [ ] **CMD-03**: A user can override the generated command module's name
- [ ] **CMD-04**: A user can nominate the identity field used for aggregate routing
- [ ] **CMD-05**: Declaring two commands with the same name fails at compile time
- [ ] **CMD-06**: Declaring a command field that is not a resource attribute fails at compile time, naming the field
- [ ] **CMD-07**: Referencing an action that does not exist on the resource fails at compile time, naming the action
- [ ] **CMD-08**: `AshCommanded.Resource.Info` exposes a resource's declared commands without reading DSL state directly
- [ ] **CMD-09**: The rendered command module is reviewed and approved against the size gates

### Events

- [ ] **EVT-01**: A user can declare an event with a name and fields, and get a generated struct with typespecs
- [ ] **EVT-02**: A user can override the generated event module's name
- [ ] **EVT-03**: Declaring two events with the same name fails at compile time
- [ ] **EVT-04**: Declaring an event field that is not a resource attribute fails at compile time, naming the field
- [ ] **EVT-05**: `AshCommanded.Resource.Info` exposes a resource's declared events
- [ ] **EVT-06**: The rendered event module is reviewed and approved against the size gates

### Application and Routers

Planned as one coupled unit: the ordering defect spans both, and neither can be proven working alone.

- [ ] **APP-01**: A user can declare a Commanded application on an `Ash.Domain` and get a generated application module
- [ ] **APP-02**: Router generation fires for every domain that declares commands — the confirmed defect is fixed
- [ ] **APP-03**: A domain-level transformer reads each resource's persisted command state via `Ash.Domain.Info.resources/1`, with no module-name surgery
- [ ] **APP-04**: The generated application compiles without the `__registered_commands__/0 is undefined` failure
- [ ] **APP-05**: A user can dispatch a command through the generated router and observe the aggregate acting on it
- [ ] **APP-06**: A user can configure event store, pubsub, registry and supervision through the DSL
- [ ] **APP-07**: Projectors are discovered and supervised automatically, replacing the unfinished TODO
- [ ] **APP-08**: The quarantined `commanded_application_integration_test.exs.phase2-blocked` is restored, its stale `Code.ensure_loaded?` guard deleted, and it genuinely exercises application generation
- [ ] **APP-09**: `test/` is swept for the same `Code.ensure_loaded?` pattern already removed from `lib/`
- [ ] **APP-10**: A design note records that compile ordering comes from an on-demand compiler block, and that bidirectional resource/domain reads risk deadlock
- [ ] **APP-11**: `AshCommanded.Domain.Info` exposes the domain's application configuration
- [ ] **APP-12**: The rendered application and router modules are reviewed and approved against the size gates

### Aggregates

- [ ] **AGG-01**: `AshCommanded.Aggregate.__using__/1` exists as a hand-written front door, and generated aggregates delegate to it
- [ ] **AGG-02**: Aggregate execution logic lives in a plain runtime module that can be unit-tested without compiling a DSL
- [ ] **AGG-03**: A generated aggregate's `execute/2` and `apply/2` clauses carry only per-entity literals
- [ ] **AGG-04**: A user can express an invariant that rejects a command based on current aggregate state
- [ ] **AGG-05**: A user can declare aggregate state that is not a resource attribute, such as a collection
- [ ] **AGG-06**: A user can express aggregate lifespan (`after_event`, `after_command`, `after_error`)
- [ ] **AGG-07**: A command returning no event, one event, a list of events, or an error is handled per Commanded's contract
- [ ] **AGG-08**: The rendered aggregate for a one-command, one-event resource is under a documented size budget, reviewed and approved
- [ ] **AGG-09**: `AshCommanded.Aggregate.Info` is the single lookup point for per-command configuration

### Projections

- [ ] **PROJ-01**: A user can declare a projection mapping an event to an Ash action with static changes
- [ ] **PROJ-02**: A user can compute changes from the event via a function
- [ ] **PROJ-03**: A projection referencing an unknown event fails at compile time
- [ ] **PROJ-04**: A projection writing an unknown attribute fails at compile time
- [ ] **PROJ-05**: The latent `Ash.run_action(changeset, action)` defect is fixed and covered by a test that would have caught it
- [ ] **PROJ-06**: A user can assert on a projected Ash record after a real dispatch, with the cross-process ETS visibility limitation resolved or documented
- [ ] **PROJ-07**: The rendered projector module is reviewed and approved against the size gates

### Event Handlers and Process Managers

- [ ] **HDLR-01**: A user can declare an event handler that runs a side effect without updating the resource
- [ ] **HDLR-02**: A user can declare a process manager coordinating across aggregates
- [ ] **HDLR-03**: A user can choose `:strong` or `:eventual` consistency per handler
- [ ] **HDLR-04**: Handler errors are surfaced through Commanded's error callbacks rather than swallowed
- [ ] **HDLR-05**: Handlers, projectors and process managers generate distinct shapes rather than one generic base
- [ ] **HDLR-06**: The rendered handler and process-manager modules are reviewed and approved against the size gates

### Event Versioning

- [ ] **EVOL-01**: A user can declare how a historical event shape maps to the current one
- [ ] **EVOL-02**: Each historical event struct's generated `upcast/2` returns the **current** struct directly, never a single version hop
- [ ] **EVOL-03**: Intermediate transformations declared across several versions are composed at generation time into one clause per historical struct
- [ ] **EVOL-04**: A replay test proves an event written at the oldest declared version is correctly upcast to current
- [ ] **EVOL-05**: The rendered upcaster implementation is reviewed and approved against the size gates

### Snapshots, Middleware and Transactions

- [ ] **RUN-01**: Snapshot support targets `Commanded.Snapshotting`, generating configuration rather than a pluggable adapter behaviour
- [ ] **RUN-02**: A user can declare `snapshot_every` and `snapshot_version` per aggregate
- [ ] **RUN-03**: The fictional `Commanded.Aggregates.Aggregate.Snapshotter` behaviour is gone from the codebase
- [ ] **RUN-04**: Middleware modules are verified against Commanded's real middleware contract, by an explicit verifier rather than a schema type
- [ ] **RUN-05**: A user can attach middleware to command dispatch and observe it running in declaration order
- [ ] **RUN-06**: Transaction coordination is covered by a test that exercises a real rollback
- [ ] **RUN-07**: `IO.puts`/`IO.inspect` are gone from production paths, replaced by `Logger`

### Documentation and Packaging

- [ ] **DOCS-01**: `CLAUDE.md` contains no claim that is not true of the code, including the three documented-but-absent verifiers
- [ ] **DOCS-02**: `CLAUDE.md` and `AGENTS.md` are consistent with each other rather than divergent
- [ ] **DOCS-03**: Declared dependency versions in documentation match `mix.exs` and `mix.lock`
- [ ] **DOCS-04**: `spark.cheat_sheets` covers the domain extension as well as the resource extension
- [ ] **DOCS-05**: The published package includes `documentation/` and `cheatsheets/`
- [ ] **DOCS-06**: A documented testing story shows how to test commands, aggregates, projections and full event flows
- [ ] **DOCS-07**: An end-to-end example runs on Commanded's in-memory adapter, fast enough for CI and docs
- [ ] **DOCS-08**: Dependencies are bumped to current versions, including the stale `sourceror` pin

## Deferred to the Next Milestone

Tracked, not in this roadmap.

- **MIG-01..05**: Migrate `identity`, `data`, `integration`, `schema_definition`, `workflow` onto AshCommanded
- **REL-01**: Publish 1.0 to hex.pm once `core` is fully migrated
- **EX-01**: End-to-end example on a Postgres-backed EventStore — proves the path `core` actually uses, but belongs with the migration it serves

## Out of Scope

| Feature | Reason |
|---------|--------|
| Backwards compatibility with the published 0.2.0 DSL | Adoption is negligible and the aggregate/projection redesign cannot be done additively. Break freely on 0.x |
| Non-Commanded event-sourcing backends | The library targets Commanded 1.4.x specifically |
| Maintaining a private fork | Work lands upstream in `accountex-org/ash_commanded` |
| A pluggable snapshot adapter interface | Commanded has no such extension point; the previous one was fiction behind a permanently-false guard |
| A version-chain upcasting DSL | Commanded upcasts exactly once per event, never chained. A chain would compile, pass naive tests, and silently under-upcast real history |
| Migrating `core` code that is not event-sourced | Only the CQRS/ES surface is in scope for the project at all |

## Traceability

Mapped by the roadmap created 2026-09-15. Every milestone requirement maps to exactly
one phase. Phase numbering restarted at 1; the archived 13-phase roadmap does not apply.

| Requirement | Phase | Status |
|-------------|-------|--------|
| FOUND-01 | Phase 1 — Foundation — Rendering, Enforcement and Layout | Complete |
| FOUND-02 | Phase 1 — Foundation — Rendering, Enforcement and Layout | Complete |
| FOUND-03 | Phase 1 — Foundation — Rendering, Enforcement and Layout | Complete |
| FOUND-04 | Phase 1 — Foundation — Rendering, Enforcement and Layout | Pending |
| FOUND-05 | Phase 1 — Foundation — Rendering, Enforcement and Layout | Complete |
| FOUND-06 | Phase 1 — Foundation — Rendering, Enforcement and Layout | Pending |
| FOUND-07 | Phase 1 — Foundation — Rendering, Enforcement and Layout | Pending |
| FOUND-08 | Phase 1 — Foundation — Rendering, Enforcement and Layout | Pending |
| FOUND-09 | Phase 1 — Foundation — Rendering, Enforcement and Layout | Pending |
| FOUND-10 | Phase 1 — Foundation — Rendering, Enforcement and Layout | Pending |
| FOUND-11 | Phase 1 — Foundation — Rendering, Enforcement and Layout | Pending |
| FOUND-12 | Phase 1 — Foundation — Rendering, Enforcement and Layout | Pending |
| FOUND-13 | Phase 1 — Foundation — Rendering, Enforcement and Layout | Pending |
| FOUND-14 | Phase 1 — Foundation — Rendering, Enforcement and Layout | Pending |
| FOUND-15 | Phase 1 — Foundation — Rendering, Enforcement and Layout | Pending |
| FOUND-16 | Phase 1 — Foundation — Rendering, Enforcement and Layout | Pending |
| FOUND-17 | Phase 1 — Foundation — Rendering, Enforcement and Layout | Pending |
| FOUND-18 | Phase 1 — Foundation — Rendering, Enforcement and Layout | Complete |
| CMD-01 | Phase 2 — Commands and Events | Pending |
| CMD-02 | Phase 2 — Commands and Events | Pending |
| CMD-03 | Phase 2 — Commands and Events | Pending |
| CMD-04 | Phase 2 — Commands and Events | Pending |
| CMD-05 | Phase 2 — Commands and Events | Pending |
| CMD-06 | Phase 2 — Commands and Events | Pending |
| CMD-07 | Phase 2 — Commands and Events | Pending |
| CMD-08 | Phase 2 — Commands and Events | Pending |
| CMD-09 | Phase 2 — Commands and Events | Pending |
| EVT-01 | Phase 2 — Commands and Events | Pending |
| EVT-02 | Phase 2 — Commands and Events | Pending |
| EVT-03 | Phase 2 — Commands and Events | Pending |
| EVT-04 | Phase 2 — Commands and Events | Pending |
| EVT-05 | Phase 2 — Commands and Events | Pending |
| EVT-06 | Phase 2 — Commands and Events | Pending |
| APP-01 | Phase 3 — Application and Routers | Pending |
| APP-02 | Phase 3 — Application and Routers | Pending |
| APP-03 | Phase 3 — Application and Routers | Pending |
| APP-04 | Phase 3 — Application and Routers | Pending |
| APP-05 | Phase 3 — Application and Routers | Pending |
| APP-06 | Phase 3 — Application and Routers | Pending |
| APP-07 | Phase 3 — Application and Routers | Pending |
| APP-08 | Phase 3 — Application and Routers | Pending |
| APP-09 | Phase 3 — Application and Routers | Pending |
| APP-10 | Phase 3 — Application and Routers | Pending |
| APP-11 | Phase 3 — Application and Routers | Pending |
| APP-12 | Phase 3 — Application and Routers | Pending |
| AGG-01 | Phase 4 — Aggregates | Pending |
| AGG-02 | Phase 4 — Aggregates | Pending |
| AGG-03 | Phase 4 — Aggregates | Pending |
| AGG-04 | Phase 4 — Aggregates | Pending |
| AGG-05 | Phase 4 — Aggregates | Pending |
| AGG-06 | Phase 4 — Aggregates | Pending |
| AGG-07 | Phase 4 — Aggregates | Pending |
| AGG-08 | Phase 4 — Aggregates | Pending |
| AGG-09 | Phase 4 — Aggregates | Pending |
| PROJ-01 | Phase 5 — Projections, Event Handlers and Process Managers | Pending |
| PROJ-02 | Phase 5 — Projections, Event Handlers and Process Managers | Pending |
| PROJ-03 | Phase 5 — Projections, Event Handlers and Process Managers | Pending |
| PROJ-04 | Phase 5 — Projections, Event Handlers and Process Managers | Pending |
| PROJ-05 | Phase 5 — Projections, Event Handlers and Process Managers | Pending |
| PROJ-06 | Phase 5 — Projections, Event Handlers and Process Managers | Pending |
| PROJ-07 | Phase 5 — Projections, Event Handlers and Process Managers | Pending |
| HDLR-01 | Phase 5 — Projections, Event Handlers and Process Managers | Pending |
| HDLR-02 | Phase 5 — Projections, Event Handlers and Process Managers | Pending |
| HDLR-03 | Phase 5 — Projections, Event Handlers and Process Managers | Pending |
| HDLR-04 | Phase 5 — Projections, Event Handlers and Process Managers | Pending |
| HDLR-05 | Phase 5 — Projections, Event Handlers and Process Managers | Pending |
| HDLR-06 | Phase 5 — Projections, Event Handlers and Process Managers | Pending |
| EVOL-01 | Phase 6 — Event Versioning, Snapshots, Middleware and Transactions | Pending |
| EVOL-02 | Phase 6 — Event Versioning, Snapshots, Middleware and Transactions | Pending |
| EVOL-03 | Phase 6 — Event Versioning, Snapshots, Middleware and Transactions | Pending |
| EVOL-04 | Phase 6 — Event Versioning, Snapshots, Middleware and Transactions | Pending |
| EVOL-05 | Phase 6 — Event Versioning, Snapshots, Middleware and Transactions | Pending |
| RUN-01 | Phase 6 — Event Versioning, Snapshots, Middleware and Transactions | Pending |
| RUN-02 | Phase 6 — Event Versioning, Snapshots, Middleware and Transactions | Pending |
| RUN-03 | Phase 6 — Event Versioning, Snapshots, Middleware and Transactions | Pending |
| RUN-04 | Phase 6 — Event Versioning, Snapshots, Middleware and Transactions | Pending |
| RUN-05 | Phase 6 — Event Versioning, Snapshots, Middleware and Transactions | Pending |
| RUN-06 | Phase 6 — Event Versioning, Snapshots, Middleware and Transactions | Pending |
| RUN-07 | Phase 6 — Event Versioning, Snapshots, Middleware and Transactions | Pending |
| DOCS-01 | Phase 7 — Documentation, Packaging and the End-to-End Example | Pending |
| DOCS-02 | Phase 7 — Documentation, Packaging and the End-to-End Example | Pending |
| DOCS-03 | Phase 7 — Documentation, Packaging and the End-to-End Example | Pending |
| DOCS-04 | Phase 7 — Documentation, Packaging and the End-to-End Example | Pending |
| DOCS-05 | Phase 7 — Documentation, Packaging and the End-to-End Example | Pending |
| DOCS-06 | Phase 7 — Documentation, Packaging and the End-to-End Example | Pending |
| DOCS-07 | Phase 7 — Documentation, Packaging and the End-to-End Example | Pending |
| DOCS-08 | Phase 7 — Documentation, Packaging and the End-to-End Example | Pending |

**Coverage:**

- Milestone requirements: 87 total
- Mapped to phases: 87
- Unmapped: 0
- Orphaned (no phase): 0
- Duplicated (more than one phase): 0

**Per-phase totals:**

| Phase | Name | Requirements |
|-------|------|--------------|
| 1 | Foundation — Rendering, Enforcement and Layout | 18 |
| 2 | Commands and Events | 15 |
| 3 | Application and Routers | 12 |
| 4 | Aggregates | 9 |
| 5 | Projections, Event Handlers and Process Managers | 13 |
| 6 | Event Versioning, Snapshots, Middleware and Transactions | 12 |
| 7 | Documentation, Packaging and the End-to-End Example | 8 |
| — | **Total** | **87** |

---
*Requirements defined: 2026-09-15*
