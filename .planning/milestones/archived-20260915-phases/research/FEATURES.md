# Feature Research

**Domain:** Declarative CQRS/Event-Sourcing DSL over Commanded 1.4.8, built on Ash/Spark
**Researched:** 2026-09-11
**Confidence:** HIGH for Commanded API surface (verified against hexdocs.pm/commanded 1.4.x and GitHub source); MEDIUM for Ash-integration recommendations (synthesized from `core`'s measured usage, no external prior art of a mature Ash+Commanded DSL to benchmark against)

## Scope Note

This is a *subsequent milestone* on an existing library. "Table stakes" here means: capabilities the DSL must expose for `core`'s five event-sourced domains (163 modules / 6,398 LOC) to migrate onto it, and for the library to be credible as "declarative Commanded." It does not mean "what a brand-new CQRS product needs to launch" — the product already has commands, events, aggregates, projections and routers generated. This document is about what's *missing*.

---

## Commanded Capability-by-Capability Assessment

Each of the nine capabilities named in the research question, verified against Commanded 1.4.x hexdocs, classified, and scoped for complexity.

### 1. `Commanded.Event.Upcaster` — event schema evolution

**Classification: TABLE STAKES.** Confirmed v1 requirement per PROJECT.md; `core` already depends on it and a search for `Upcaster`/`upcast` across ash_commanded today returns nothing. An event-sourced library cannot claim production-readiness without a schema-evolution story — the event log is append-only and permanent; every other capability (aggregates, projections, process managers) reads through it.

**Verified protocol shape** ([Commanded.Event.Upcaster, hexdocs](https://commanded.hexdocs.pm/1.4.8/Commanded.Event.Upcaster.html), [events guide](https://commanded.hexdocs.pm/events.html)):

- It is a plain Elixir protocol: `defprotocol Commanded.Event.Upcaster do def upcast(event, metadata) end`, with a default `for: Any` clause that returns the event unchanged.
- Consumers implement `defimpl Commanded.Event.Upcaster, for: MyApp.Events.SomeEvent do def upcast(%SomeEvent{} = event, _metadata) do ... end end`.
- **It fires on read, not on append.** The docs state upcasting runs "for new events and for historical events" — i.e., every time an event is loaded from the store (aggregate rehydration, event handler dispatch, process manager dispatch), not once at write time. This matters for a DSL: upcasting must be co-located with the *current* event definition, and it must be idempotent/cheap since it runs on every replay, not just once per event.
- `upcast/2`'s second argument is the same metadata map handlers receive: system keys are atoms (`application`, `event_id`, `event_number`, `stream_id`, `stream_version`, `causation_id`, `correlation_id`, `created_at`), user-supplied keys are strings. A DSL wrapping this must expose this metadata to the upcast function, not just the event.
- **Two upcasting patterns are directly supported by the protocol dispatch mechanism itself:** (a) field-level transformation on the *same* struct (add/rename/derive a field, return the same module), and (b) **full event-type replacement** — the events guide explicitly describes replacing a historical event with a different, newer event module entirely (`upcast/2` returns a struct of a *different* type than its input pattern-matched on). Protocol dispatch is keyed on the *input* struct's module, so this is a clean mechanism for "event renamed" migrations.
- **Chaining is NOT built into Commanded.** This is the load-bearing finding for the DSL design: Commanded dispatches the protocol exactly once per stored event, based on the struct module of what's in the store. There is no mechanism that re-dispatches the protocol against the *output* of `upcast/2` to walk `V1 -> V2 -> V3`. If a consumer needs multi-step evolution, today they hand-write a single `upcast/2` clause per legacy struct that fast-forwards straight to the current shape, or they nest calls to intermediate upcast functions manually inside one clause. **A declarative DSL over this must decide the chaining semantics itself** — e.g. let a user declare an ordered list of version transforms per event and compile them into one generated `upcast/2` implementation that folds through the list, OR require one `defimpl` per legacy struct module that upcasts directly to current. The former is more DSL-idiomatic (matches "commands"/"events" list style already in the DSL) and avoids N-legacy-module proliferation; it is also unverified by any upstream precedent, so it is a design decision to make explicitly, not infer from Commanded's docs.
- **Versioned event naming is not conventionalized by Commanded itself.** hexdocs examples upcast a single struct in place; there is no canonical `EventV1`/`EventV2` naming shown in official docs. Community practice (surveyed via general event-sourcing literature, not Commanded-specific — MEDIUM confidence) favors either a suffix (`OrganisationRegisteredV1`) or a version field inside one struct. Given AshCommanded already generates event modules from DSL entities, the natural convention is: the *current* version has the plain name (`Events.OrganisationRegistered`), and superseded shapes get an explicit prior-version marker the DSL generates as distinct modules purely to give `upcast/2` something to pattern-match against — these prior-version modules are never constructed by application code, only deserialized from the store.

**Complexity: MEDIUM-HIGH.** The protocol itself is trivial to implement by hand (this is why some may argue it's not worth a DSL). The DSL value is in (a) the chaining/versioning convention above, which Commanded leaves unsolved, and (b) compile-time verification that an upcast chain actually terminates at the resource's current event shape — a verifier analogous to `ValidateEventFields` but walking version chains.

**Dependency:** Upcasting is meaningless without a stable event-naming/versioning convention; that convention must be decided before (or alongside) the upcaster DSL section, and it constrains `GenerateEventModules` — likely requiring it to track a "supersedes" relationship between event entities.

---

### 2. Aggregate command handling: preconditions, invariants, rejection, multi-event returns

**Classification: TABLE STAKES.** PROJECT.md's structural-gap #3 names this directly: `core`'s aggregates encode real business rules as pattern-matched guards (`%__MODULE__{id: nil}` → already-created error; `status: :suspended` → reject update) and `GenerateAggregateModule` "has no way to express either." This is 1,822 LOC across 13 files where — per PROJECT.md — genuine invariants are "mixed with dispatch plumbing." Without this, the DSL only handles the boilerplate slice of aggregates and cannot absorb the part that actually costs the most to hand-write.

**Verified semantics** ([aggregates guide](https://commanded.hexdocs.pm/aggregates.html)):

- `execute/2` (the aggregate's command-handling function) may return: a single event, a list of events, `:ok`/`nil`/`[]`/`{:ok, []}` for "no-op, valid command but nothing to record," `{:error, reason}` for a rejection, or it may **raise** — Commanded's docs explicitly permit either `{:error, reason}` or a raised exception as valid rejection strategies, leaving the choice to the implementer.
- Multiple *dependent* events from one command (where event 2's shape depends on event 1 having already been "applied") use `Commanded.Aggregate.Multi`, a small builder API that chains event-producing steps and discards all pending events/state changes if any step errors.
- Commanded gives zero structure to *invariants themselves* — that logic is 100% userland Elixir. The DSL's job is not to reimplement business rules declaratively (that is the anti-feature territory, see below) but to give a **place and calling convention** for precondition/invariant functions to plug into generated `execute/2`, so the 861-line `GenerateAggregateModule` doesn't have to special-case every resource.

**What the DSL should add:** a `precondition`/`guard` hook per command (a user-supplied function `(state, command) -> :ok | {:error, reason}` invoked before the generated execute/2 body runs), and first-class support for returning `{:error, reason}` vs. raising — both should be legal outputs of that hook, and the generated wrapper must not swallow either. Whether a command produces one event or many should be driven by whether the command declares one `emits` event or a list; multi-event emission should generate `Commanded.Aggregate.Multi` usage rather than reinventing dependent-event chaining.

**Complexity: MEDIUM.** No new Commanded API to wrap beyond what's already understood (`execute/2`, `Multi`); the work is DSL surface design (where does a guard function live, what's its signature) plus reworking `GenerateAggregateModule`'s command→event mapping to support N events and early rejection instead of assuming exactly one event per command.

**Anti-feature adjacent:** Do NOT attempt to express the *content* of business rules (e.g. "reject if status is X") as DSL syntax/data (a mini rules-DSL). Express only the *shape* — where a hand-written guard function is invoked and what it may return. See Escape Hatches section.

---

### 3. Aggregate state that is not a read-model mirror

**Classification: TABLE STAKES.** Same structural gap (#3) in PROJECT.md: `core` aggregates hold state that is not a resource attribute (`members: %{}`), and the current `GenerateAggregateModule` derives aggregate state purely from resource attributes.

**Verified guidance** ([aggregates guide](https://commanded.hexdocs.pm/aggregates.html)): Commanded's own docs warn against "blindly copying all event data into aggregate state without considering whether that data is actually needed for command handling" — state should hold only what's needed to enforce invariants and provide command context, explicitly *not* mirror the read model. This directly validates PROJECT.md's framing: an aggregate that is forced to be an Ash-resource-attribute mirror is architecturally wrong per Commanded's own idioms, not just inconvenient for `core`.

**What the DSL should add:** an aggregate `state` declaration independent of the resource's attributes — fields with types/defaults that are not projected anywhere, populated by `apply/2` clauses the DSL generates from event definitions plus a user-supplied reducer function for fields that aren't simple "copy this field from the event" (e.g. `members: %{}` accumulating from repeated events). This is squarely inside the DSL's job because it's structural (shape of the state struct + generated apply/2 dispatch), not business logic.

**Complexity: MEDIUM-HIGH.** Requires decoupling `GenerateAggregateModule`'s state struct from the resource attribute list (a real API change, not additive), and a mechanism for per-field or per-event apply functions supplied by the user for anything beyond direct field copy.

**Dependency:** This depends on/interacts with #2 — invariant-checking guards need to read this richer state, so the two should land together.

---

### 4. Aggregate lifecycle: `Lifespan`, snapshotting, identity/prefixes

**Classification: TABLE STAKES for snapshotting and identity; DIFFERENTIATOR for declarative `Lifespan`.**

**Verified API** ([Commanded.Aggregates.AggregateLifespan, hexdocs](https://hexdocs.pm/commanded/Commanded.Aggregates.AggregateLifespan.html); [commands guide](https://commanded.hexdocs.pm/commands.html); [aggregates guide](https://commanded.hexdocs.pm/aggregates.html)):

- **Lifespan**: a behaviour with `after_event/1`, `after_command/1`, `after_error/1`, each returning an inactivity timeout in ms, `:infinity`, `:hibernate`, or `:stop`. Registered per-command via the `lifespan:` option on `dispatch` in the router. Controls whether the aggregate GenServer stays warm, hibernates (reduces memory, incurs wake latency), or is torn down immediately (e.g. after a "close account" event, to free resources instantly rather than idle-timeout out).
- **Snapshotting**: `snapshot_every` (event-count interval; `nil` disables) and `snapshot_version` (bump to invalidate old snapshots after a state-shape change) are configured in `config.exs` under a snapshotting map keyed by aggregate module — **not** a router or aggregate-module option. This is important: a DSL cannot express this purely inside the resource's `commanded do ... end` block without also emitting runtime config, or it must generate a config-time hook (e.g. via `AshCommanded` needing to write/patch `config.exs`, or documenting a required manual config entry the verifier checks exists).
- AshCommanded already has snapshot support today (`SnapshotConfiguration`, `SnapshotStore`, ETS-backed `SnapshotAdapter`), but PROJECT.md flags the store itself as "ETS-only: lost on VM restart, unusable across nodes, not production-ready" — this is a production-viability gap, not a DSL-expressiveness gap. Fixing it means a persistent snapshot adapter (e.g. Postgres-backed), separate from whether `snapshot_every`/`snapshot_version` are declarable.
- **Identity/prefix**: `identify Aggregate, by: :field, prefix: "some-prefix-"` at the router level. The prefix becomes part of the event-store stream name; Commanded's docs are explicit that **the prefix must never change once events exist** — this is exactly the kind of one-way door a verifier should catch (e.g. warn/fail if a resource's declared prefix differs from what's already been generated previously, once there's a mechanism to detect that).

**What the DSL should add:**

- Table stakes: a declarative way to set `snapshot_every`/`snapshot_version` per resource that `GenerateCommandedApplication`/`GenerateAggregateModule` correctly wires into config (closing the "ETS-only" gap requires a real adapter, separately).
- Table stakes: identity/prefix already exists implicitly (resource primary key is the identity today) but prefix support is not confirmed present — verify and add if missing.
- Differentiator: a declarative `lifespan` mini-DSL (e.g. `lifespan after_event(:account_closed), do: :stop`) is a genuine ergonomic win over hand-writing a `Lifespan` module per resource, since the shape (event/command/error → duration or atom) is a clean match for `commanded do` syntax. This is lower priority than snapshotting/invariants because it's a performance/resource-management concern, not a correctness one — `core`'s aggregates work today without custom lifespans (they use Commanded's default).

**Complexity:** Snapshot declarative config — LOW (mostly wiring, verifier work). Lifespan DSL — MEDIUM (new code-generation target, a `Commanded.Aggregate.Lifespan` behaviour module per resource).

---

### 5. Process managers / sagas

**Classification: DIFFERENTIATOR — and the single highest-leverage new capability for this milestone**, contingent on confirming `core` actually needs cross-aggregate orchestration (PROJECT.md's five domains are described in terms of commands/events/aggregates/projectors; process managers are not named in the measured surface, which is a gap to close during requirements, not assume away).

**Verified API** ([Commanded.ProcessManagers.ProcessManager, hexdocs](https://commanded.hexdocs.pm/Commanded.ProcessManagers.ProcessManager.html)):

- `use Commanded.ProcessManagers.ProcessManager, application:, name:, idle_timeout:, event_timeout:, consistency:, router:`.
- `interested?/1` (event → routing decision) returns `{:start, uuid}`, `{:start!, uuid}` (asserts non-existence), `{:continue, uuid}`, `{:continue!, uuid}` (asserts existence), `{:stop, uuid}`, or `false`; can return a list of UUIDs to fan out to multiple instances.
- `handle/2` (state, event → command(s)) returns a command, a list of commands, or `{:error, reason}`.
- `apply/2` (state, event → new state) is optional and mutates the process manager's own persisted state (distinct from any aggregate's state).
- `error/3` supports `{:retry, context}`, `{:retry, delay, context}`, `:skip`, `{:skip, :continue_pending}`, `{:skip, :discard_pending}`, `{:continue, commands, context}`, `{:stop, reason}` — a materially richer error-recovery vocabulary than event handlers get.
- State persists automatically via instance snapshots; instances rehydrate after idle timeout or crash.

**Why this is a differentiator, not table stakes:** the library today (per ARCHITECTURE.md) has commands, events, aggregates, projections/projectors and generic event handlers — no process manager generation exists at all. If `core`'s migration doesn't require cross-aggregate command choreography (its own event handlers may already do "react to event → do side effect," which Commanded's event handler covers), process managers may be entirely out of scope for the migration and should not be built speculatively. **This needs a direct answer during requirements**: does any of `identity`/`data`/`integration`/`schema_definition`/`workflow` orchestrate a multi-step saga today (state machine spanning multiple aggregates, needing to track outstanding steps)? If yes, it's load-bearing and should be table stakes, not a differentiator to defer.

**Complexity: HIGH.** New DSL section (`process_managers do ... end` at domain or cross-resource level — process managers do not map 1:1 to a single Ash resource the way projections do, since they route between potentially many aggregates), a new transformer generating `interested?/1`/`handle/2`/`apply/2`/`error/3`, and a new verifier surface (valid event references across resources, valid command references across resources). This is comparable in size to the aggregate-generation work already done.

---

### 6. Event handlers and subscriptions

**Classification: TABLE STAKES for the subscription-configuration surface (`start_from`, `subscribe_to`, `consistency`); DIFFERENTIATOR for a declarative `error/3`.** The library already generates event handler modules (`GenerateEventHandlerModules`), so this is about closing gaps in an existing feature, not building from zero.

**Verified API** ([Commanded.Event.Handler, hexdocs](https://commanded.hexdocs.pm/Commanded.Event.Handler.html)):

- `use` options: `application`, `name` (subscription identity — **changing it creates a new subscription and replays all events**, a sharp edge a verifier could flag), `start_from` (`:origin` | `:current` | explicit event number; **only takes effect the first time the subscription is created**, not on every boot — another sharp edge worth a compile-time note or runtime warning), `subscribe_to` (restrict to one stream vs. all events), `consistency` (`:eventual` default or `:strong`).
- `handle/2` returns `:ok`, `{:ok, new_state}`, `{:error, :already_seen_event}` (explicit skip-ack), or `{:error, reason}` (triggers `error/3`).
- `error/3` returns `{:retry, context}`, `{:retry, delay, context}`, `:skip`, or `{:stop, reason}`.
- **Consistency semantics**: `:eventual` (default) means command dispatch returns as soon as the event is persisted, without waiting on any handler. `:strong` blocks dispatch until *all* `:strong`-configured handlers (and process managers) have processed the resulting events — Commanded is explicit that this is **not** a transaction guarantee, only an ordering guarantee ("the event handler will have processed all events produced by the command," not "in the same transaction as the command").

**Gap check against current library:** ARCHITECTURE.md's `EventHandlersSection`/`EventHandler` struct is described only as "side-effect handlers" with `events`/`action` — no mention of `start_from`, `subscribe_to`, `consistency`, or `error/3` in the documented DSL surface. If those options aren't already exposed, that's the concrete gap: **table stakes**, because `core`'s handlers, once migrated, need to control replay behavior (`start_from: :current` is essential for anything migrated from a running system — you do not want a newly-generated handler to replay the entire historical event log on first deploy) and need `:strong` consistency wherever a caller expects a side effect to have happened before the HTTP response returns.

**Complexity: LOW-MEDIUM** for exposing `start_from`/`subscribe_to`/`consistency` as DSL options (additive to existing section schema). **MEDIUM** for a declarative `error/3` (same shape argument as aggregate guards — see escape hatches, below; likely a hook function reference rather than DSL-expressed retry logic).

---

### 7. Projections: `Commanded.Projections.Ecto`, idempotency, transactional side effects

**Classification: TABLE STAKES, and the single largest body of logic to absorb** — 3,523 LOC across 18 projectors in `core`, "mostly real logic; the heaviest category" per PROJECT.md. This is the feature area where the DSL's expressiveness ceiling matters most and where over-reaching into an anti-feature is likeliest.

**Verified API** ([commanded_ecto_projections usage guide](https://commanded-ecto-projections.hexdocs.pm/usage.html)):

- `project/2` and `project/3` macros map one event (optionally + metadata) to an `Ecto.Multi`; returning the `multi` argument unchanged is how a clause "skips" projecting for that shape.
- Idempotency is via a `projection_versions` table tracking `projection_name` + `last_seen_event_number`, updated as part of the same `Ecto.Multi` the projection changes are added to — i.e., **the version bump and the data change are the same atomic operation**, which is exactly the "transactional projection" property required for at-least-once event delivery to be safe. AshCommanded's generated projectors must preserve this — if the version bump and the write are ever split across two Ash actions/transactions, replays after a crash mid-projection become unsafe (double-application or gaps).
- `after_update/3` is the sanctioned side-effect hook: it fires after the transaction succeeds, receiving event/metadata/the Ecto.Multi's changes, for out-of-band effects (Phoenix PubSub broadcast, cache invalidation) that must not themselves be part of the DB transaction.
- Error handling mirrors event handlers: `{:retry, context}`, `{:retry, delay, context}`, `:skip`, `{:stop, reason}`.
- One projector module legally handles multiple event types via multiple `project` clauses — this already matches AshCommanded's per-resource projector generation model.

**What "absorb `core`'s projector logic" concretely requires**, given 3,523 LOC is not boilerplate:

- Table stakes: multi-event projectors (already true), conditional projection (skip/no-op based on event or current record state — e.g. "only update if this event is newer than what's stored," a common idempotency-adjacent pattern beyond the generic `projection_versions` table), and updates that read current state before writing (`update` needs the existing record, not just a blind upsert) — today's `Projection` struct is described as "static map or dynamic function" of changes, which may already cover function-of-event but likely not function-of-(event, current-record).
- Table stakes: `after_update`-equivalent hook for side effects (PubSub broadcast is extremely common in Phoenix/Ash apps and is exactly the kind of thing that must NOT be inside the transactional projection write).
- Differentiator: a declarative "only apply if event_number > stored value" idempotency guard as a DSL primitive, since it's a recurring shape across many projectors and can be expressed data-first (unlike arbitrary business logic).
- **Anti-feature: do not attempt to express projector business logic as DSL data beyond "event → changeset/changes."** 3,523 LOC of "mostly real logic" is exactly the signal that projector bodies contain real conditionals, joins to other data, and derived calculations that a changes-map or simple function-of-event cannot capture without the DSL becoming a general-purpose expression language. The correct boundary (argued in detail in Escape Hatches, below) is: the DSL declares *routing* (which event → which resource/action → optional guard/idempotency check) and always accepts a plain Elixir function as the "compute the changes" step. That function is exactly where the real logic already lives today, and moving it out of a hand-rolled projector module into a DSL-declared callback is where the boilerplate savings genuinely are (event pattern matching, action dispatch plumbing, transaction wiring, idempotency bookkeeping) — without trying to also declare *what* the callback computes.

**Complexity: HIGH.** This is the highest-complexity, highest-value single item in the roadmap: it requires reworking `Projection`/`GenerateProjectionModules`/`GenerateProjectorModules` to support read-before-write, `after_update` hooks, and function-of-(event, metadata, current-record) changes, while verifying that the underlying `commanded_ecto_projections` transactional idempotency property is preserved end-to-end through Ash's changeset/action layer (this is a genuine integration risk: Ash actions run their own transactions by default, and marrying that to `Ecto.Multi`-based idempotency bookkeeping needs explicit design, not assumption).

---

### 8. Command dispatch: middleware, consistency, timeouts, causation/correlation

**Classification: TABLE STAKES**, and mostly a verification/completeness task against what the library already claims to have ("Command middleware pipeline (base, logging, validation, processor)" is listed as existing in PROJECT.md's Validated section).

**Verified API** ([commands guide](https://commanded.hexdocs.pm/commands.html)):

- Router-level `dispatch` options: `consistency:` (`:eventual` default, `:strong`, or an explicit list of handler/process-manager modules to wait on), `timeout:` (ms, default 5s), `lifespan:` (see #4), `identity`/`identify ... by:, prefix:`.
- Per-call dispatch options (at the call site, not just router-declared): `timeout:`, `metadata:` (string/number/boolean values only — anything else is coerced to a string on serialization), `causation_id:`, `correlation_id:`, `include_execution_result:` / `include_aggregate_version:` for shaping the return value.
- Middleware modules implement `before_dispatch/1`, `after_dispatch/1`, `after_failure/1` against a `Commanded.Middleware.Pipeline` struct, composed in router-declaration order.
- Causation/correlation propagation is a manual convention, not automatic magic: handlers/process managers extract `event_id`/`correlation_id` from incoming event metadata and pass them explicitly to any command they dispatch in response.

**Gap check:** the library's middleware pipeline already exists; what needs verification (not assumed present) is whether `consistency:`, per-call `causation_id`/`correlation_id` threading, and `include_execution_result`/`include_aggregate_version` are exposed through the generated command API, or whether callers must bypass the DSL and call the raw Commanded router to get them. Given `core` almost certainly needs `:strong` consistency somewhere (any API endpoint that must reflect a just-issued command's side effects before responding) and correlation IDs for tracing across its five domains, these should be **first-class dispatch options**, not something a caller works around.

**Complexity: LOW-MEDIUM.** No new Commanded concepts to model; this is about not silently dropping options between the DSL-generated dispatch call and the underlying router, and exposing per-call overrides (not just router-declared defaults) through whatever `Domain.Router.dispatch/2` wrapper the library generates.

---

### 9. Multi-node / distributed concerns

**Classification: ANTI-FEATURE for this milestone — deliberately not built, with an explicit escape hatch.**

**Verified landscape** ([Deployment guide](https://commanded.hexdocs.pm/deployment.html); [Choosing an event store guide](https://commanded.hexdocs.pm/choosing-an-event-store.html); `commanded_swarm_registry` and `commanded_horde_registry` package docs):

- Commanded supports pluggable process registries via `config :commanded, registry: ...` — options are the built-in `:global` registry (no extra dependency, works but has known scaling/split-brain caveats), or separate packages `commanded_swarm_registry` / `commanded_horde_registry` for cluster-aware distribution, each requiring its own supervision-tree wiring (e.g. Horde needs a `Linker` process joining supervisors across nodes).
- Event store adapters: `commanded_eventstore_adapter` (Postgres-backed `EventStore`, the one `core` uses per PROJECT.md's "Postgres-backed EventStore" example-app requirement), `commanded_extreme_adapter` (EventStoreDB), and an in-memory adapter explicitly documented as **test-use only**.

**Why anti-feature, not just "later":** distribution is a deployment-topology and infrastructure decision (which registry, how nodes discover each other, how the event store is clustered) that lives in application/release config, not in a per-resource DSL. There is no sensible way to "declare in `commanded do ... end`" that a resource's aggregate should run on a distributed registry — that's a single application-wide `config.exs` choice (which registry module) plus supervision-tree wiring, orthogonal to any individual resource. A DSL that tried to expose this per-resource would be modeling infrastructure as domain logic, the exact inversion this project should avoid. PROJECT.md's own scope also doesn't mention a multi-node deployment target for `core`; introducing distributed-registry support now would be building for a requirement nobody has stated.

**What the DSL should do instead:** ensure `GenerateCommandedApplication` doesn't hard-code the default local registry in a way that prevents an application from overriding `config :commanded, registry: ...` itself, and document (in the AGENTS.md/usage-rules work already in the Active requirements) that registry/event-store-adapter choice is a `config.exs` concern outside the DSL's remit. That is the escape hatch: application-level config, not DSL syntax.

---

## What the Ash Side Requires

This is the axis Commanded's own docs cannot answer — it is specific to this library's job of sitting on top of Ash resources, and is where PROJECT.md's structural gaps (#1 Domain/Resource DSL split, #3 invariants/state) actually bite.

**Actions.** Commands should keep mapping to Ash actions (already the model via `CommandActionMapper`), but the action-selection story needs to support actions whose success does *not* imply "create/update the same resource the command lives on" — e.g. an aggregate command that only validates and emits an event, where the *actual* Ash write happens later via a projection on a different resource. Today's model (per ARCHITECTURE.md's "Command → Action mapping" step) assumes the command's resource is also the thing being written; that assumption should be checked against `core`'s five domains rather than treated as given.

**Changesets.** The context-propagation options already present (`include_command?`, `include_aggregate?`, `include_metadata?`) are the right shape — a guard/invariant hook (item #2 above) should receive the same enriched context so hand-written invariant functions can inspect actor/tenant/metadata without re-deriving it.

**Policies.** ARCHITECTURE.md states plainly: "Not handled by AshCommanded; use Ash policy layer or middleware." This is correct and should stay an anti-feature for the DSL — Ash already has a mature, general policy engine; reimplementing authorization semantics inside a CQRS extension would duplicate a solved problem. The DSL's job is only to make sure `context.actor` (and multitenancy context, next) reliably reaches the Ash action a command ultimately calls, so existing Ash policies apply unchanged.

**Multitenancy.** Not mentioned anywhere in ARCHITECTURE.md or the current DSL surface — this is a real gap to verify against `core` before committing scope. If any of `core`'s five domains are multitenant (`identity` plausibly is), the aggregate identity/stream-naming scheme (item #4's `prefix`) needs to incorporate tenant context, and projections need tenant-scoped Ash actions. This should be confirmed during requirements gathering rather than assumed either way — treat as an open question, not a stated requirement.

**Escape hatches — where a hook wins over a declaration.** The recurring pattern across items #2, #3, #6, #7 above is the same shape: **the DSL should declare *structure and routing*, and always accept a plain Elixir function reference for *content*.** Concretely:

| DSL declares (structural) | Escape hatch (a function reference) |
| --- | --- |
| Which command maps to which action/aggregate | The precondition/guard body deciding whether to reject |
| Which fields exist on aggregate state | The reducer for any field that isn't a straight copy from an event |
| Which event maps to which projection/action | The changes-computation body (event, metadata, current record → changeset params) |
| That a handler subscribes with `consistency: :strong` | The retry/skip/stop decision in `error/3` |

This is not a compromise forced by time constraints — it is the correct architectural line for a DSL that must not become "a worse programming language" (the downstream consumer's own framing). Data-shaped configuration (event names, field lists, action references, consistency levels) is exactly what a Spark DSL is good at expressing and verifying at compile time. Business rules, derived-state reducers, and changeset-computation bodies are exactly what Elixir functions are good at expressing, and trying to encode conditionals/derivations as DSL *data* (e.g. a mini expression language for "if status == :suspended, reject") reinvents a worse, unverifiable, undebuggable version of the language the user is already writing the DSL in. `core`'s own numbers make the case quantitatively: aggregates (1,822 LOC) and projectors (3,523 LOC) are "mostly real logic," while commands and events (1,053 LOC combined) are "almost pure boilerplate" — the DSL should aggressively eliminate the latter and *frame, not delete*, the former, exactly as PROJECT.md's Key Decisions table already states.

---

## Feature Landscape Summary

### Table Stakes (library is not credible without these)

| Feature | Why Expected | Complexity | Notes |
| --------- | -------------- | ------------ | ------- |
| `Commanded.Event.Upcaster` DSL section + versioning convention | Confirmed v1 requirement; `core` depends on it today; zero current support | MEDIUM-HIGH | Needs an explicit chaining convention Commanded itself doesn't provide |
| Aggregate preconditions/invariants hook, `{:error, reason}`/raise, multi-event via `Multi` | `core`'s 1,822 LOC of aggregate logic is exactly this | MEDIUM | Hook-based, not rules-DSL |
| Aggregate state independent of resource attributes | `core` aggregates hold non-attribute state (`members: %{}`) today | MEDIUM-HIGH | Requires decoupling state struct from resource attrs |
| Declarative `snapshot_every`/`snapshot_version` | Currently only ETS-backed, not production-viable per PROJECT.md | LOW (config wiring) | Persistent adapter is a separate, also-table-stakes item |
| Event handler `start_from`/`subscribe_to`/`consistency` options | Needed for safe migration (`start_from: :current`) and correctness (`:strong` where required) | LOW-MEDIUM | Verify against current `EventHandlersSection` schema — likely missing |
| Projection read-before-write, `after_update` side-effect hook, function-of-(event, current-record) changes | 3,523 LOC of "mostly real logic" won't fit today's changes-map/function-of-event model | HIGH | Highest-value, highest-risk item in the roadmap |
| Full dispatch option passthrough (`consistency`, `causation_id`/`correlation_id`, `include_execution_result`) | `core` needs strong consistency and traceability across 5 domains | LOW-MEDIUM | Verification task against existing middleware pipeline |
| Domain/Resource DSL split (application vs. resource) | Already identified structural gap, in flight on `fix-application-generation` | (already scoped) | Not new research — confirmed necessary |

### Differentiators (what makes this worth having over hand-written Commanded)

| Feature | Value Proposition | Complexity | Notes |
| --------- | ------------------- | ------------ | ------- |
| Process manager / saga DSL section | Removes an entire class of hand-written GenServer-adjacent code Commanded normally requires by hand | HIGH | Only build if `core`'s domains actually need cross-aggregate orchestration — confirm, don't assume |
| Declarative `Lifespan` (`after_event`/`after_command`/`after_error` → duration/atom) | Clean data-shaped mapping to a 3-callback behaviour; genuine ergonomic win | MEDIUM | Lower priority than correctness-affecting items |
| Declarative idempotency guard ("skip if event_number <= stored") as a projection primitive | Recurring shape across many projectors; reduces repeated hand-rolled guards | MEDIUM | Complements, doesn't replace, `projection_versions` table |
| Compile-time verifier for upcast-chain termination | Catches a class of bug (event evolved but old shape never reconciled) that's invisible until replay | MEDIUM | Natural extension of existing nine verifiers |

### Anti-Features (deliberately not built — escape hatch instead)

| Feature | Why it looks appealing | Why it's wrong here | Alternative |
| --------- | ------------------------ | ---------------------- | ------------- |
| Declarative business-rule/invariant language (conditions as DSL data) | Feels consistent with "everything else is declarative" | Reinvents a worse, unverifiable version of Elixir; `core`'s 1,822 LOC of aggregate logic is real logic, not config | Hook function reference (precondition/guard callback) |
| Declarative projector logic beyond routing + changes-function | Same consistency impulse; 3,523 LOC is the biggest single win if "absorbed" | A changes-computation DSL that tries to express joins/conditionals/derived values becomes a general-purpose language wearing a DSL costume | Function-of-(event, metadata, current-record) callback; DSL only owns event→action routing and idempotency plumbing |
| Ash policy reimplementation inside AshCommanded | Commands/projections touch actors and could plausibly gate on them | Ash already has a mature, general policy engine; duplicating it fragments authorization into two systems | Ensure `context.actor`/tenant reach the underlying Ash action; let Ash policies apply unchanged |
| Multi-node registry/event-store-adapter selection as per-resource DSL syntax | Distribution feels like it belongs "in the framework" | It's an application-wide `config.exs`/supervision-tree decision, not a per-resource one; no stated multi-node requirement exists for `core` | Document as an application-config concern; ensure generated code doesn't hard-code a registry choice that blocks override |
| Multi-step upcast chaining invented as a generic protocol re-dispatch inside Commanded itself | Would "fix" Commanded's own gap generally | Out of scope — this is a fork-of-upstream-behavior risk; the DSL should compile a *single* `upcast/2` implementation per event that internally applies the chain, not alter how Commanded dispatches the protocol | Generate one `upcast/2` clause per legacy event that folds an ordered list of transform steps |

---

## Feature Dependencies

```text
Event versioning convention (naming/supersession)
    └──requires──> Upcaster DSL section (chaining semantics depend on the convention)

Aggregate state independent of resource attributes
    └──requires──> Invariant/precondition hook (guards need to read the richer state)

Domain/Resource DSL split (in flight)
    └──requires──> Everything else (application-level config — snapshotting, registry override,
                     process manager domain wiring — all assume this split is landed first)

Projection read-before-write + after_update hook
    └──requires──> Transactional-idempotency verification against Ash's own transaction handling
                     (Ash actions run their own transactions; must confirm this composes safely
                     with commanded_ecto_projections's projection_versions Ecto.Multi pattern)

Process manager DSL (differentiator)
    └──requires──> Confirmed cross-aggregate orchestration need in core (open question, not assumed)

Declarative Lifespan (differentiator)
    ──enhances──> Snapshotting (both are aggregate lifecycle/performance concerns, independent of each other)

Multi-node registry support (anti-feature)
    ──conflicts──> Per-resource DSL syntax (this is application config, not resource declaration —
                     building it as DSL syntax would be architecturally wrong, not just premature)
```

### Dependency Notes

- **Event versioning convention requires landing before/alongside the Upcaster DSL section**, because the chaining mechanism the DSL invents (ordered transform list vs. one-`defimpl`-per-legacy-struct) is a naming/module-generation decision, not just a runtime behavior — it affects `GenerateEventModules`.
- **Aggregate state independence requires shipping with (not after) the invariant hook**, since PROJECT.md's structural gap #3 names both together and hand-written invariants in `core` already read non-attribute state (`members: %{}}`).
- **The Domain/Resource DSL split is a hard prerequisite for nearly everything else**, because application-level concerns (snapshot config, registry override, process-manager supervision) all need a place to live that isn't a single resource — this is already recognized and in flight, not new here.
- **Projection transactional guarantees are the highest-risk dependency in this list**: `commanded_ecto_projections` documents that changes and idempotency-version bumps share one `Ecto.Multi`, but AshCommanded routes projection changes through Ash actions/changesets, which have their own transaction semantics. This composition has not been verified against Commanded's docs (they don't cover Ash) and must be tested directly, not assumed to just work.
- **Process managers conflict with nothing structurally**, but building them speculatively before confirming `core` needs cross-aggregate sagas would violate the project's own stated bar ("real event-sourced system" as proof) — an unused DSL surface proves nothing.

---

## MVP Definition

### Launch With (this milestone)

Minimum to call the library capability-complete against `core`'s measured needs:

- [ ] Event versioning/upcasting DSL section with an explicit chaining convention — table stakes, confirmed v1 requirement
- [ ] Aggregate precondition/invariant hook + non-attribute state + multi-event (`Multi`) support — table stakes, structural gap #3
- [ ] Event handler `start_from`/`subscribe_to`/`consistency` exposed in DSL — table stakes, needed for safe migration
- [ ] Projection read-before-write + `after_update` side-effect hook + function-of-(event, current-record) changes — table stakes, the highest-LOC absorption target
- [ ] Full dispatch option passthrough (`consistency`, causation/correlation, `include_execution_result`) — table stakes, verification-heavy not build-heavy
- [ ] Persistent snapshot adapter (beyond ETS) — table stakes, already flagged as not-production-ready

### Add After Validation (once `core`'s migration proves the above)

- [ ] Declarative `Lifespan` DSL — differentiator, no correctness dependency
- [ ] Declarative idempotency-guard primitive for projections — differentiator, ergonomic layer over table-stakes projection work
- [ ] Upcast-chain-termination verifier — differentiator, natural but not blocking

### Future Consideration (only if a concrete need surfaces)

- [ ] Process manager / saga DSL section — build only once a `core` domain is confirmed to need cross-aggregate orchestration; do not build speculatively
- [ ] Any multi-node registry ergonomics beyond "don't block override" — explicitly out of scope absent a stated multi-node deployment target

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
| --------- | ------------ | --------------------- | ---------- |
| Event upcasting DSL | HIGH | HIGH | P1 |
| Aggregate invariants + non-attribute state | HIGH | MEDIUM | P1 |
| Projection expressiveness (read-before-write, after_update) | HIGH | HIGH | P1 |
| Event handler subscription options | MEDIUM | LOW | P1 |
| Full dispatch option passthrough | MEDIUM | LOW | P1 |
| Persistent snapshot adapter | MEDIUM | MEDIUM | P1 |
| Declarative Lifespan | LOW-MEDIUM | MEDIUM | P2 |
| Projection idempotency-guard primitive | MEDIUM | MEDIUM | P2 |
| Upcast-chain verifier | LOW-MEDIUM | MEDIUM | P2 |
| Process manager / saga DSL | Unconfirmed (HIGH if needed, else zero) | HIGH | P3 — confirm need first |
| Multi-node registry declarative support | LOW (no stated need) | HIGH | Not planned |

**Priority key:** P1 must ship this milestone (blocks `core` migration or library credibility). P2 should ship if capacity allows, ordered after P1 lands and `core` migration is underway. P3 requires a confirmed need before scoping at all.

---

## Sources

**Primary — Commanded 1.4.x official documentation (HIGH confidence, fetched directly):**

- [Commanded.Event.Upcaster](https://commanded.hexdocs.pm/1.4.8/Commanded.Event.Upcaster.html)
- [Events guide (upcasting, versioning, serialization)](https://commanded.hexdocs.pm/events.html)
- [Commanded.Event.Handler](https://commanded.hexdocs.pm/Commanded.Event.Handler.html)
- [Commanded.ProcessManagers.ProcessManager](https://commanded.hexdocs.pm/Commanded.ProcessManagers.ProcessManager.html)
- [Commands guide (dispatch options, identify, middleware, causation/correlation)](https://commanded.hexdocs.pm/commands.html)
- [Aggregates guide (state design, snapshotting, Multi, error handling)](https://commanded.hexdocs.pm/aggregates.html)
- [Commanded.Aggregates.AggregateLifespan](https://hexdocs.pm/commanded/Commanded.Aggregates.AggregateLifespan.html)
- [Deployment guide](https://commanded.hexdocs.pm/deployment.html)
- [Choosing an event store guide](https://commanded.hexdocs.pm/choosing-an-event-store.html)

**Primary — commanded_ecto_projections official documentation (HIGH confidence):**

- [Commanded.Projections.Ecto usage guide](https://commanded-ecto-projections.hexdocs.pm/usage.html)

**Secondary — package documentation for distributed registries (HIGH confidence, official but ecosystem-adjacent packages):**

- [commanded_swarm_registry](https://github.com/commanded/commanded-swarm-registry)
- [commanded_horde_registry](https://commanded-horde-registry.hexdocs.pm/Commanded.Registration.HordeRegistry.html)

**Project-internal (this repository, HIGH confidence — direct measurement):**

- `/Users/djp/development/forks/ash_commanded/.planning/PROJECT.md`
- `/Users/djp/development/forks/ash_commanded/.planning/codebase/ARCHITECTURE.md`

**Not usable — inaccessible or non-substantive:**

- GitHub issue [commanded/commanded#258](https://github.com/commanded/commanded/issues/258) (upcasting feature request) — fetched, but contained only the original issue text, no implementation discussion; did not change any conclusion above.

**Explicitly unverified / open questions to resolve during requirements, not assumed:**

- Whether any of `core`'s five domains (`identity`, `data`, `integration`, `schema_definition`, `workflow`) require process-manager-style cross-aggregate orchestration.
- Whether any `core` domain is multitenant, and if so, how tenant context should compose with aggregate identity/stream prefixes.
- Whether Ash's own action-level transaction handling composes safely with `commanded_ecto_projections`'s `Ecto.Multi`-based idempotency guarantee, or whether the library needs to bypass `Commanded.Projections.Ecto` and reimplement the idempotency bookkeeping directly against Ash changesets.

---
*Feature research for: AshCommanded (declarative CQRS/ES DSL over Commanded 1.4.8, Ash Framework extension)*
*Researched: 2026-09-11*
