# Pitfalls Research

**Domain:** Commanded (CQRS/ES) integration + Spark/Elixir macro-based code generation
**Researched:** 2026-09-15
**Confidence:** HIGH for all Commanded API claims (verified against `deps/commanded` 1.4.11 source,
file:line cited) and for the Elixir Code Smells citations (fetched from the upstream catalogue).
MEDIUM for claims about how AshCommanded's *own* generators should be restructured, since that is
design guidance rather than a verifiable fact.

---

## Part A — Commanded 1.4.x reality

### Pitfall 1: Writing an aggregate `__using__` macro that doesn't need to exist

**What goes wrong:** A generator (or a hand-written base module) tries to give aggregates a
`use Commanded.Aggregates.Aggregate` front door — behaviour callbacks, `@before_compile` hooks,
injected helpers — mirroring what `Commanded.Event.Handler`, `Commanded.Commands.Router` and
`Commanded.Application` provide. Commanded has no such macro for aggregates, so all of that
machinery ends up hand-rolled into the DSL's generated `quote` block instead of a runtime module.

**Why it happens:** Every other Commanded consumer (`Commanded.Application`, `Commanded.Commands.Router`,
`Commanded.Event.Handler`) *does* supply a `__using__/1`, so it is a reasonable but false analogy to
assume aggregates work the same way.

**Verified against source:** `deps/commanded/lib/commanded/aggregates/aggregate.ex:120-132`. The
`Commanded.Aggregates.Aggregate` module (the internal `GenServer` that manages one aggregate
instance) declares:

```elixir
@callback execute(aggregate :: state(), command :: struct()) ::
            return_event() | no_return_event() | {:error, term()}
@callback apply(aggregate :: state(), event :: struct()) :: state()
@optional_callbacks execute: 2
```

But this behaviour belongs to the **`GenServer` process module**, not to the domain aggregate struct
you write (`BankAccount`, `WidgetAggregate`, etc.). Nothing calls `@behaviour Commanded.Aggregates.Aggregate`
on the domain module, and nothing requires it to. Commanded dispatches with plain
`Kernel.apply(handler, function, [aggregate_state, command])` (`aggregate.ex:509`) and
`aggregate_module.apply(aggregate_state, data)` (`aggregate_state_builder.ex:112`,
`aggregate.ex:455,553`) — ordinary dynamic function calls against whatever atom is configured.
**A domain aggregate module is exactly two public functions with no macro, no `use`, no required
`@behaviour`.** (You *may* add `@behaviour Commanded.Aggregates.Aggregate` yourself purely to get
Dialyzer/compiler checking of `execute/2`/`apply/2` — that is legitimate and costs nothing, but it is
optional and orthogonal to a `use` macro.)

This is the single fact that explains why `generate_aggregate_module.ex` in the current codebase grew
to 225 lines in one `quote` block while every other generator stayed under 31: Commanded gave those
other generators a `__using__` to delegate to, and gave the aggregate generator nothing, so the
missing machinery (middleware application, param mapping, snapshot wiring, transaction coordination)
was written directly into the emitted AST.

**How to avoid:** Answer the design question PROJECT.md poses ("what is
`AshCommanded.Aggregate.__using__/1`?") by building it as a **library-authored** convenience macro —
not a Commanded one — whose `__using__/1` injects the smallest possible surface: registration of
`execute/2`/`apply/2` clause dispatch tables built from compile-time literals, with everything else
(param mapping, validation, transaction coordination) as calls into hand-written, unit-testable
runtime modules (`AshCommanded.CommandActionMapper`, etc.), matching Rewrite Rule 1 in PROJECT.md.
The generated `execute/2` clause per command should be a single delegating call, not inlined logic.

**Warning signs:** A generated clause body longer than ~10 lines; a `quote` block whose largest
clause is measured in the tens of lines rather than single digits (the audit table in LEARNINGS.md
§1 is the reusable measurement method — rerun it after each component lands).

**Phase to address:** Aggregates component (milestone v0.3, per PROJECT.md Active list).

---

### Pitfall 2: Generating a router/application pair that never actually wires up

**What goes wrong:** `router(SomeRouter)` is called inside an application (or composite router)
module, but the referenced router module has not finished compiling by the time the calling module's
`router/1` macro expands — `SomeRouter.__registered_commands__/0 is undefined` at compile time.

**Verified against source:**

- `deps/commanded/lib/commanded/commands/composite_router.ex:75-87` — the `router/1` macro's entire
  body is:

  ```elixir
  defmacro router(router_module) do
    quote location: :keep do
      for command <- unquote(router_module).__registered_commands__() do
        ...
      end
    end
  end
  ```

  This is a direct, **macro-expansion-time** call to `router_module.__registered_commands__()`. It is
  not deferred to runtime — it runs while the *calling* module (the application, or a composite
  router) is being compiled. That means `router_module` must already be a **compiled, loaded**
  module at that instant, with `__registered_commands__/0` defined.
- `deps/commanded/lib/commanded/commands/router.ex:497-502` — `__registered_commands__/0` on an
  individual router is itself injected by that router's own `@before_compile`, which only runs when
  the router module finishes compiling.
- `deps/commanded/lib/application.ex:172-184` — `use Commanded.Application` immediately does
  `use Commanded.Commands.CompositeRouter, application: __MODULE__, ...` as part of its own
  expansion, so an application module *is* a composite router, and any `router(...)` calls the user
  writes after `use Commanded.Application` hit exactly the code path above.

**This is the mechanical root cause of the confirmed, corroborated-twice defect in PROJECT.md/LEARNINGS.md**
("Router generation never fires" / "Commanded application generation raises
`__registered_commands__/0 is undefined`"): `GenerateCommandedApplication` is a **domain** transformer,
`GenerateMainRouterModule`/`GenerateDomainRouterModule` are **resource** transformers. Ash gives no
guarantee that a domain's transformers run only after every one of its resources has fully compiled —
`resources do resource X end` records a reference, it does not force `X`'s compilation to finish
before the domain module's own transformers execute `Module.create/3` for the application. The
established fact in PROJECT.md is correct, and this is the exact mechanism, confirmed against 1.4.11
source rather than inferred.

**How to avoid:** Whatever the rewritten `Application` component looks like, it must guarantee the
router module used inside `router(...)` is a genuinely separate, already-compiled artifact **before**
the application module's `Module.create/3` runs — not something produced by a sibling transformer in
the same compilation pass. Two viable shapes, in order of preference:

1. Generate the router module and the application module in the **same transformer**, in the correct
   sequence, from within one `Module.create/3` sequence where the router's `Module.create/3` call is
   awaited (its return is `{:module, module, _, _}`, and the module is genuinely loaded) strictly
   before the application module's `Module.create/3` is invoked. `Module.create/3` compiles and loads
   synchronously, so ordering two sequential calls within one transformer function body is safe;
   ordering across two independent transformers running against two independent DSL-using modules
   (domain vs. resource) is not.
2. Have the domain transformer walk `Ash.Domain.Info.resources/1` and read each resource's own
   *persisted DSL state* directly via `Spark.Dsl.Extension.get_persisted/2` (as PROJECT.md's Active
   list already specifies for the router/event-handler/process-manager component) to build the full
   command list itself, and generate one router module and the application module together, rather
   than trusting a cross-module runtime call to `__registered_commands__/0` that depends on
   compile-order.

**Warning signs:** `UndefinedFunctionError` naming `__registered_commands__/0`; any integration test
quarantined with a `.phase2-blocked` extension guarding a `Code.ensure_loaded?` fiction (as
`commanded_application_integration_test.exs.phase2-blocked` currently is) — that pattern is itself the
warning sign, not just the bug.

**Phase to address:** Application component (must precede or land jointly with Routers/event
handlers/process managers, since the ordering problem is shared).

---

### Pitfall 3: Reintroducing a pluggable snapshot adapter behaviour

**What goes wrong:** Building (or preserving) an adapter behaviour — `@behaviour
Commanded.Aggregates.Aggregate.Snapshotter` or similar — so that snapshot storage can be swapped like
an `Ecto.Adapter`.

**Verified against source:** `deps/commanded/lib/commanded/snapshotting.ex` is the entire
snapshotting implementation, `@moduledoc false` (internal, not a public extension point). It is a
plain struct:

```elixir
defstruct [:application, :source_uuid, :snapshot_every, :snapshot_module_version, snapshot_version: 0]
```

built from a **keyword list** the aggregate `GenServer` reads out of its own config at start-up
(`aggregate.ex:158-165`):

```elixir
snapshotting = Keyword.get(config, :snapshotting, %{})
snapshot_options = Map.get(snapshotting, aggregate_module, [])
...
snapshotting: Snapshotting.new(application, aggregate_uuid, snapshot_options)
```

That `snapshotting` map is documented on `Commanded.Aggregates.Aggregate`'s own `@moduledoc`
(`aggregate.ex:81-92`) as **application configuration**, keyed by aggregate module:

```elixir
config :my_app, MyApp.Application,
  snapshotting: %{
    MyApp.ExampleAggregate => [snapshot_every: 10, snapshot_version: 1]
  }
```

There is no adapter behaviour anywhere in the dependency tree. Persistence of the snapshot itself
goes through the configured **event store adapter's** `record_snapshot`/`read_snapshot` (part of the
`Commanded.EventStore` adapter contract every application already configures), not a
snapshot-specific adapter. `snapshot_every` (an integer, or `nil`/absent to disable) and
`snapshot_version` (bumping it invalidates old snapshots — `snapshotting.ex:83-93` compares
`metadata["snapshot_module_version"]` against the configured value and returns
`{:error, :outdated_snapshot}` on mismatch, which the caller treats as "no usable snapshot") are the
entire public surface.

**This fully confirms the established fact**: `Commanded.Aggregates.Aggregate.Snapshotter` has never
existed, in any version. The library's own `snapshot_adapter.ex` compiled cleanly only because its
`@behaviour` declaration sat behind a permanently-false `Code.ensure_loaded?` guard — the compiler
never checked those four callback functions against anything real.

**How to avoid:** The Snapshots component should generate/expose, per aggregate, a **declarative
config fragment** — `snapshot_every`/`snapshot_version` — that gets merged into the `:snapshotting`
key of the generated `Commanded.Application`'s config (or into `config/config.exs` for the consuming
app), not a new adapter behaviour. If storage backend flexibility is genuinely wanted, that
flexibility already exists one level up: swap the *event store adapter* the whole application uses
(e.g. the Postgres `EventStore` adapter vs. `InMemory`), since snapshot storage is a facet of the
event store adapter, not a separate pluggable concern.

**Warning signs:** Any `@behaviour` reference to a module name containing `Snapshotter` that does not
resolve via `mix deps.tree` or `Commanded` hexdocs; any `Code.ensure_loaded?` guard wrapping a
`@behaviour` declaration (this exact shape hid the defect for the library's entire prior life —
grep for it as a matter of course, in both `lib/` and `test/`).

**Phase to address:** Snapshots component (PROJECT.md Active list: "Snapshots re-targeted at
`Commanded.Snapshotting`... production-viable storage beyond in-memory ETS").

---

### Pitfall 4: A declarative upcasting DSL that assumes chained upcasts compose automatically

**What goes wrong:** Designing event versioning so that each version bump gets its own
`Commanded.Event.Upcaster` implementation (V1→V2, V2→V3, ...) and assuming Commanded will walk the
chain until it reaches the "current" struct. It will not. Only **one** `upcast/2` call is made per
stored event, ever, no matter how old that event is.

**Verified against source:**

- The protocol (`deps/commanded/lib/commanded/event/upcaster.ex:52-53`) is a single dispatch:
  `@spec upcast(event :: struct(), metadata :: map()) :: struct()`, dispatching on the concrete
  struct type of the stored event (`for: AnEvent`). There is no version integer anywhere in the
  protocol — "version" *is* "which struct module the event currently is."
- `deps/commanded/lib/commanded/event/upcast.ex:15-21` — the only place `Upcaster.upcast/2` is
  invoked:

  ```elixir
  def upcast_event(%RecordedEvent{} = event, opts) do
    %RecordedEvent{data: data} = event
    enriched_metadata = RecordedEvent.enrich_metadata(event, opts)
    %RecordedEvent{event | data: Upcaster.upcast(data, enriched_metadata)}
  end
  ```

  One call. The result is used as-is; there is no loop, no re-dispatch, no check of whether the
  *result* also implements `Upcaster` and needs a further pass.
- Confirmed at every call site that feeds events to a consumer: `EventStore.stream_forward/4`
  (`deps/commanded/lib/commanded/event_store.ex:83`, feeding aggregate rebuild via
  `aggregate_state_builder.ex`), `Aggregate.handle_info({:events, ...})`
  (`aggregate.ex:389`, live event subscription), `ProcessRouter`
  (`process_managers/process_router.ex:193`), and `Commanded.Event.Handler`
  (`event/handler.ex:1076,1642`, both the per-event and partition-key paths). All five call sites use
  `upcast_event`/`upcast_event_stream` — none loop or recurse.

**Consequence for a DSL:** if an event has gone V1 → V2 → V3 and a consumer only understands V3, a
naive "one upcaster per version transition" implementation will upcast a stored V1 event straight to
V2 and stop there — the aggregate/handler then receives a V2 struct it does not know how to `apply/2`,
typically a `FunctionClauseError` inside `handle_event`/`handle_info`, surfacing as the aggregate or
handler **crashing on replay of old data**, which is the worst possible time to discover it (replay
is exactly when historical low-version events are read).

**How to avoid:** A declarative upcasting DSL needs to express, and generate, **one `upcast/2` clause
per starting version that produces the current (latest) struct directly** — composing the
intermediate transformations itself at the point of generation (or at runtime inside one function
body), not by relying on protocol dispatch to chain. Concretely: if the DSL lets an author declare
"V1 → V2: rename field X to Y" and "V2 → V3: add field Z with default", the generated
`Upcaster.upcast/2` implementation `for: V1Event` must apply *both* transformations in sequence and
return a `V3Event` struct, and the `for: V2Event` implementation must apply the second transformation
and also return `V3Event`. Each historical struct type gets exactly one upcast clause, and every
clause's return type is the same — the current struct. This is squarely a "compose at generation
time" problem (Rewrite Rule 2), not a runtime one.

**Warning signs:** Replay of a real event store (not a freshly seeded test) crashing inside
`apply/2`/`handle/2` with a struct pattern-match failure on an event type nobody expected to see
anymore; an `Upcaster` implementation whose `upcast/2` returns a struct that is *itself* covered by
another `Upcaster` implementation (a chain that was never actually composed).

**Phase to address:** Declarative event versioning component (PROJECT.md Active list).

---

### Pitfall 5: Confusing aggregate lifespan configuration for aggregate-owned behaviour

**What goes wrong:** Assuming an aggregate module itself controls its own process lifetime (e.g. by
looking for a callback on the aggregate struct's module). Lifespan is configured on the **router**,
per command registration, via a separate `Commanded.Aggregates.AggregateLifespan` behaviour module —
not on the aggregate.

**Verified against source:** `deps/commanded/lib/commanded/aggregates/aggregate_lifespan.ex:1-93` and
`aggregate.ex:465-492` (`aggregate_lifespan_timeout/2`, called from `handle_call({:execute_command,
...})` after every dispatch). Supported return values from `after_event/1`, `after_command/1`,
`after_error/1`: a non-negative integer (inactivity timeout, ms), `:infinity`, `:hibernate`, `:stop`,
or `{:stop, reason}`. The router (`router.ex:225,251-260`) wires a default via
`Commanded.Aggregates.DefaultLifespan` (`aggregate.ex` calls `apply(lifespan, function_name, args)`
dynamically per dispatch), or `Application.compile_env(otp_app, [app_module, :aggregate_lifespan],
DefaultLifespan)` if `default_dispatch_opts` doesn't override it, or per-command via `lifespan:` on
`dispatch`. The default (`default_lifespan.ex`) stops the process only `{:stop, error}` on an
`is_exception?` error, otherwise runs forever.

**Rejecting a command based on aggregate state** is unrelated to lifespan: it is done by pattern
matching in `execute/2` and returning `{:error, reason}` directly (`aggregate.ex:509-511` treats any
`{:error, _}` return from the handler as a terminal reply, no event applied, no persistence). This is
the same mechanism `core`'s current aggregates use (`%__MODULE__{id: nil}` → already-created error;
`status: :suspended` → reject). A DSL invariant/guard vocabulary should compile to ordinary
pattern-matched `execute/2` clauses (or guards) returning `{:error, reason}`, not to anything
lifespan-related.

**How to avoid:** Keep the two concerns separate in the DSL surface: an `AggregateLifespan`-shaped
declaration (if the library offers one) is a router/dispatch-time concept keyed by command or event
type; invariants that reject a command are ordinary `execute/2` guard clauses returning
`{:error, reason}`.

**Phase to address:** Aggregates component (invariants), Routers component (lifespan wiring, if
exposed declaratively at all — it is a small feature and may not be worth DSL surface).

---

### Pitfall 6: Treating event handlers, process managers, and projectors as the same thing

**What goes wrong:** Generating one shape of module for all three, or picking the wrong Commanded
base for what a projector actually needs.

**Verified distinctions (source):**

| | `Commanded.Event.Handler` | `Commanded.ProcessManagers.ProcessManager` |
| --- | --- | --- |
| Purpose | Stateless (or transient-state) reaction to *every* matching event | Coordinates a **sequence** of events across possibly multiple aggregates, dispatching follow-up commands |
| Required callbacks | `handle/2` (or `handle_batch/1`), both optional (`event/handler.ex:687-693`) | `interested?/1,2`, `handle/2,3`, `apply/2`, `after_command/2,3`, `error/3` |
| State | GenServer-held, in `:state` config key, lost on restart unless snapshotted separately | Own struct, event-sourced via `apply/2` and Commanded's per-process-manager-instance state (snapshotted internally, see `process_manager_instance.ex`) |
| Consistency | `:eventual` (default) or `:strong`, configured on the handler itself (`event/handler.ex:318-353`) | Same options, at the process-manager level |
| Concurrency | `:concurrency` option — multiple worker processes, requires `partition_by/2` for ordering guarantees, mutually exclusive with `batch_size` (`event/handler.ex:835-838`) | N/A in the same sense — process manager instances are inherently partitioned by their own correlation key from `interested?/2` |
| Batching | `batch_size`/`batch_timeout` — see below | Not offered |

A **projector** (in AshCommanded's vocabulary — a module that turns an event into an Ash
create/update/destroy) is architecturally just an `Commanded.Event.Handler` whose `handle/2` calls
into an Ash action; it needs no `interested?/1,2` and should never dispatch commands. Do not build it
on `Commanded.ProcessManagers.ProcessManager` — that pulls in `apply/2` state-sourcing and
`after_command` machinery the projector will never use, for no benefit.

**The `batch_size` trap specifically:** `event/handler.ex:369-402` documents that `batch_size`
primarily controls the **event-store subscription's in-flight buffer**, not an accumulation
mechanism — during live/steady-state operation, `handle_batch/1` is called with **one event at a
time** regardless of `batch_size`, unless `batch_timeout` is *also* set (which adds real
handler-level buffering). A generator or docs that imply "set `batch_size: 50` to get 50-event
batches in production" is wrong; that only happens during catch-up replay/backpressure, or when
`batch_timeout` is configured alongside it.

**How to avoid:** Keep three distinct generated shapes: thin `Event.Handler`-based projectors (one
`handle/2` clause per declared event → one Ash action call, matching Rewrite Rule 1), genuine
`Event.Handler`-based side-effect handlers (for `event_handlers` DSL entries that are not
projections), and `ProcessManagers.ProcessManager`-based sagas only where the DSL author actually
declares cross-aggregate coordination (`interested?/1,2` + commands). Don't build one generic base
and configure it three ways.

**Phase to address:** Projections component (projector shape); Routers/event handlers/process
managers component (the other two).

---

### Pitfall 7: Assuming `Commanded.Middleware` names/shapes match the project's own middleware modules

**What goes wrong:** `core`'s and AshCommanded's `CLAUDE.md` reference `CommandMiddleware`,
`ValidationMiddleware`, `LoggingMiddleware` as if they were Commanded's own names. Commanded's actual
behaviour (`deps/commanded/lib/commanded/middleware/middleware.ex:46-48`) requires exactly three
callbacks — `before_dispatch/1`, `after_dispatch/1`, `after_failure/1` — each taking and returning a
`%Commanded.Middleware.Pipeline{}`, with `Commanded.Middleware.Pipeline.assign/3` and `halt/1` as the
only sanctioned mutation helpers. Any hand-written or generated middleware module must match that
three-callback shape exactly (all three are required, not optional — there is no `@optional_callbacks`
on `Commanded.Middleware`).

**How to avoid:** Verify AshCommanded's own middleware modules (`lib/commanded/middleware/*.ex`)
actually implement `@behaviour Commanded.Middleware` with all three callbacks before assuming
`CLAUDE.md`'s naming is accurate — treat it as unverified per the existing "Documentation drift"
finding, and confirm by compiling with `--warnings-as-errors` (a missing callback in a `@behaviour`
implementation is a compile warning, not silent).

**Phase to address:** Middleware and transaction coordination component.

---

### Pitfall 8: Per-test uniquely-named applications hiding real multi-application bugs

**What goes wrong:** `Commanded.Application.start_link(name: unique_atom)` (documented at
`deps/commanded/lib/application.ex:111-142`) gives free test isolation — each named instance gets its
own event store namespace under the `InMemory` adapter — but this pattern can mask bugs that only
appear when multiple *different* Commanded applications (not just multiple names of the same one)
coexist in one VM, e.g. two domains each with their own `Commanded.Application`, both registering
event handlers under the same handler module name (handler names must be globally unique per
`event/handler.ex:134-141` — "you must use a unique name for each event handler and process manager
you start" — this is a **cross-application** constraint if handler registration is
application-scoped incorrectly).

**How to avoid:** At least one integration test should start two independently-named
`Commanded.Application`s simultaneously (mirroring `core`'s eventual five-domain reality) rather than
only ever testing one application per test process. This is exactly the situation the deferred `core`
migration will hit and the current test suite (per-test single unique application) does not exercise.

**Phase to address:** Application component; carried into the (deferred) `core` migration milestone
as an acceptance requirement.

---

### Pitfall 9: Not using `Commanded.Assertions.EventAssertions` for event-sourced test assertions

**What goes wrong:** Writing tests that assert on side effects by polling/sleeping, or by directly
inspecting internal aggregate `GenServer` state, instead of using Commanded's own subscription-based
assertion helpers.

**Verified:** `deps/commanded/lib/commanded/assertions/event_assertions.ex` exists and exposes
`wait_for_event/2,3`, `assert_receive_event/3,4`, `refute_receive_event/4`, `assert_correlated/5`, and
`with_subscription/2,3` — all subscription-driven (they attach an event store subscription and block
until a matching event arrives or a timeout elapses), which is the correct way to assert on
`:eventual`-consistency side effects without sleeping. AshCommanded's own generated test suites and
any documentation/usage-rules for consumers should point at this module rather than reinventing
polling helpers.

**Phase to address:** Foundation (usage_rules/AGENTS.md should document this); exercised concretely
by every component's own test suite.

---

## Part B — Macro and code-generation pitfalls

### Pitfall 10: Runtime AST reassembly where a compile-time literal was possible

**What goes wrong:** Emitting code that *builds a data structure at runtime* out of pieces that were
all fully known when the transformer ran, instead of computing the final literal once and `unquote`ing
it.

**Confirmed, concrete instance already found in this codebase** (LEARNINGS.md §1): rendering the
generated aggregate for a single-command, single-event fixture produced, inside `execute/2`:

```elixir
:erlang.++([],
  :erlang.++([],
    :erlang.++([transforms: [], validations: []],
      :erlang.++([], :erlang.++([], :erlang.++([], []))))))
```

— six list concatenations executed **on every command dispatch**, five of them on empty lists, to
build a value (`[transforms: [], validations: []]`) that was fully known at macro-expansion time. The
generator built this by concatenating several separately-computed `*_arg` variables at runtime inside
the emitted function body, rather than computing the merged keyword list once in the transformer and
`unquote`ing the literal.

**Why it happens:** It is easy, when a generator accumulates optional pieces (transforms here,
validations there, defaults elsewhere) across several helper functions, to keep each piece as its own
quoted fragment and concatenate them inside the `quote` block for "flexibility" — but the transformer
already has every piece as plain Elixir data *before* any `quote` runs. Concatenate the plain lists in
the transformer, then `unquote` one final literal.

**How to avoid:** As a mechanical check: **anything a transformer computes from `dsl_state` before it
opens a `quote` block should appear as a single `unquote(...)` of a value, never as expressions that
still perform list/map operations inside the quoted body.** If you find `++`, `Map.merge`,
`Keyword.merge`, or similar inside a `quote` block operating on values that were already fully known
outside it, that is the smell.

**Warning signs:** Rendering generated output (via `mix ash_commanded.dump` once it exists, or the
`scripts/render_generated.exs` prototype) and seeing `:erlang.++/2`, `Enum.concat/1`, or similar in the
compiled AST for a value that never varies per dispatch. **This is invisible from reading the
generator** — the generator's source (`generate_execute_functions/5` in the current codebase) does
not look like the problem; only the rendered output does. This is the direct justification for
Rewrite Rule 7 (golden renders in CI) and the reason this project measures the *output*, not the
generator.

**Phase to address:** Every component, enforced by the golden-render CI check (Foundation).

---

### Pitfall 11: Reconstructing a module name instead of holding the atom the caller already has

**What goes wrong:** Deriving a module name by splitting another module's name into parts and
re-concatenating them (`Module.split/1` + string surgery + `Module.concat/1`), instead of reading it
once via `Transformer.get_persisted(dsl_state, :module)` and passing that atom through.

**Confirmed, concrete instance already found in this codebase:** `generate_aggregate_module.ex:235`
reconstructs the resource module's name this way, while line 97 of the *same file* already holds the
correct value from `get_persisted/2`. Two independent code paths compute the same thing two different
ways in one generator.

**Why this specific pattern is doubly dangerous, beyond duplication:** `Module.concat/1` built from
runtime string operations is **invisible to the Elixir compiler's compile-time dependency tracker**.
The compiler records a compile-time dependency edge when it sees a literal module reference (an alias,
a direct `Aliased.function()` call, a `@behaviour Module` attribute) it can resolve at compile time —
that edge is what makes `mix compile` correctly recompile module A when module B (which A's quoted
code references) changes. A name assembled via `Module.concat(List.first(parts) ++ [...])` at runtime
produces the *same atom* but with **no corresponding compile-time edge**, so a later change to the
referenced module can silently fail to trigger recompilation of the generated module that depends on
it — a stale-BEAM bug that only surfaces as "I changed X and nothing happened until I ran
`mix clean`."

**How to avoid:** Rewrite Rule 4 — derive every module reference from `Transformer.get_persisted/2` (or
an equivalent single source of truth already resolved once), and pass it as a plain function argument
to whatever helper needs it. Never reconstruct a module atom from string/list operations on another
module's name, even when it "should" produce the identical atom.

**Phase to address:** Cross-cutting; specifically re-verify during the Aggregates component rewrite
(this is where the instance was found) and add a Credo check that flags `Module.concat` calls fed
by `Module.split` results within transformer code (Foundation's "custom Credo checks" item).

---

### Pitfall 12: Assembling DSL configuration as strings and reparsing them into AST

**What goes wrong:** Building up a piece of generated code as an interpolated string (e.g.
`"defp foo(x), do: #{expr}"`) and feeding it through `Code.string_to_quoted!/1` (or `Code.eval_string/1`)
instead of constructing the AST directly with `quote`/`unquote`.

**Why it is a real trap, not just a style complaint:**

- It defeats every static-analysis tool that operates on AST (Credo checks, Dialyzer's ability to see
  through the code, this project's own golden-render diffing) — the tool sees a string literal, not
  the shape of the code that string will become.
- Interpolating a value into source text loses type information: an atom, a string, and an
  already-quoted AST fragment all interpolate to visually similar text, and a caller can silently pass
  the wrong one (e.g. a runtime string where a compile-time atom was needed) with no compiler feedback
  until `Code.string_to_quoted!/1` raises — at compile time, with a stack trace pointing into the
  *generator*, not the user's DSL declaration, which is a much worse debugging experience.
- It reintroduces exactly the injection-shaped risk `String.to_atom/1` on untrusted input has, in a
  more diffuse form: whatever text ends up inside the interpolation becomes code, unescaped.

**How to avoid:** Build every generated fragment as quoted AST from the start —
`quote do: unquote(value)` composition, never string formatting. If a generator currently produces
strings and reparses them, this is close to certainly true evidence for Rewrite Rule 10 ("never lists
of tuples and maps assembled into strings and reparsed into AST") and should be treated as a hard
blocker on that component's approval, not a style note.

**Phase to address:** Cross-cutting; call out explicitly in code review for every component.

---

### Pitfall 13: Re-walking nested AST for a value the transformer already has in hand

**What goes wrong:** A helper function receives a `dsl_state` (or a chunk of already-parsed AST) and
walks it again — pattern-matching through nested tuples/lists — to extract a value the *caller*
already computed one call frame up and could simply pass as an argument.

**Why it happens:** Transformer pipelines often pass `dsl_state` around as the universal context
object, and it's easy to reach back into it "just in case" rather than threading the specific value
needed. Each re-walk is its own opportunity to get the traversal subtly wrong (as with Pitfall 11),
and it makes helper functions harder to test in isolation (they need a full `dsl_state` fixture
instead of the two or three plain values they actually use).

**How to avoid:** Rewrite Rule 9 ("no double-handling") — an extra function parameter is always
cheaper than a traversal. When writing a new helper, check whether the value it's about to derive by
walking `dsl_state` (or AST) is already sitting in a variable one frame up, and pass it down instead.

**Phase to address:** Cross-cutting; specifically watch for this in the Aggregates and Projections
components, which are the two that read the most cross-entity information (commands ↔ events ↔
projections all reference each other by name).

---

### Pitfall 14: Hygiene mistakes in emitted code — `var!`, `Macro.escape/1`, `bind_quoted`

**`var!/1,2`:** Elixir macro hygiene means a variable introduced inside `quote` does **not** leak into
the caller's scope by default, and a variable in the caller's scope is not visible inside the quoted
block either — this is almost always what you want in a DSL, because it means two independently
authored `commanded do ... end` blocks can't accidentally collide on a variable name. `var!(x)`
deliberately breaks hygiene to make `x` refer to the *caller's* lexical `x`. It is occasionally
required (e.g. a macro that must read/write a variable the call site is expected to have already
bound), but for a DSL that generates whole modules from data (this project's use case), there should
be close to **zero** legitimate uses of `var!` — if one shows up, it is very likely standing in for
"I wanted to pass a value in" and an `unquote` (or a plain function argument) was the correct tool.

**`Macro.escape/1`:** Needed whenever a **runtime Elixir term** (a struct, a keyword list containing
structs, a `Regex`, a `MapSet`, a PID) must be embedded as a *literal value* inside quoted code —
`Macro.escape/1` converts the term into the AST that would produce it, so `unquote(Macro.escape(value))`
reconstructs the exact value at runtime. It is **harmful** to call it on something that is *already*
AST (a `quote do ... end` result) — escaping already-quoted code turns the code into inert data (a
tuple describing the AST) rather than leaving it as code to be `unquote`d, which is the single most
common cause of "my macro emits `{:foo, [], []}` literally instead of running `foo()`." Rule of thumb:
`Macro.escape/1` is for **data**, never for **code you built with `quote`**.

**`bind_quoted`:** Evaluates each keyword's value **once**, at the macro call site, before injecting it
— this avoids both re-evaluating an expression multiple times if it appears more than once in the
template, and (more importantly for a DSL) accidentally capturing the *caller's* variables by
reference in a way that changes if the caller later reassigns them. Prefer `bind_quoted` over raw
`unquote` inside `quote do ... end, bind_quoted: [...]` whenever the values being injected are plain
data (atoms, strings, numbers, keyword lists) computed once; reserve unquoted `quote do ... end`
(without `bind_quoted`) for cases genuinely requiring access to the caller's unevaluated AST or
requiring the caller's own lexical scope.

**Phase to address:** Cross-cutting; a specific audit item for whichever component currently uses
`var!` (search the existing generators before starting each component's rewrite).

---

### Pitfall 15: Spurious warnings and useless stacktraces from generated code

**What goes wrong:** Generated modules produce compiler warnings the DSL author cannot fix (because
they don't own the generator), or a runtime exception's stacktrace points at line 1 of a module with
no useful file/line correlation to the user's actual DSL declaration.

**Verified prior art in Commanded itself:** `deps/commanded/lib/commanded/commands/router.ex:498`
wraps its entire `__before_compile__` output in `quote generated: true do ... end` specifically
because the injected `dispatch/2` clauses and `do_dispatch/2` private functions are guaranteed correct
by construction and would otherwise trigger warnings (e.g. unreachable-clause or unused-variable
warnings the compiler can't tell are intentional in generated code). `Commanded.Commands.CompositeRouter`
does the same at `composite_router.ex:90`. **This is the correct tool for a DSL that owns its own
generated `quote` blocks**, and should be applied to every `quote` block AshCommanded's own
transformers emit that is not expected to ever warn "for real."

**`:line`/`:file` metadata:** `quote location: :keep do ... end` (used by Commanded's own `identify/2`
and `router/1` macros, e.g. `router.ex:320`, `composite_router.ex:76`) preserves the *macro's own*
source location in the generated code's debug info, which is usually more useful than the call site
for a library macro. For a code-*generation* transformer (as opposed to a small user-facing macro),
the more useful choice is often to set `line:`/`file:` on the quoted AST to point at whatever the DSL
author actually wrote (e.g. the line of the `command :foo do ... end` block in the resource file), so
a runtime error inside generated code shows the user their own DSL declaration rather than an
anonymous line inside `lib/ash_commanded/transformers/generate_command_modules.ex`.

**`@compile` attributes:** Avoid reaching for `@compile {:no_warn_undefined, ...}` or similar
suppression attributes as a first response to a warning in generated code — they suppress the
warning category *everywhere in the module*, not just for the generated clause, which can hide a
genuine mistake made later by hand in the same module. Prefer `generated: true` on the specific
`quote` block, which is precise.

**Phase to address:** Foundation (this is exactly what the renderer and golden-render CI check should
surface — a warning that appears in `mix compile --warnings-as-errors` for `test/support/parity/` but
not for hand-written code is the detection mechanism already built in Phase 01).

---

### Pitfall 16: `Module.create/3` losing the caller's environment

**What goes wrong:** Calling `Module.create/3` with a bare `quote do ... end` (or a hand-built
`__ENV__`) and then being surprised that `alias`es, `import`s, or `require`s the DSL author's resource
file has in scope are not available inside the generated module, or that compile errors inside the
generated code report a nonsensical file/line.

**Why it happens:** `defmodule` implicitly carries the surrounding file's `__ENV__` (its aliases,
requires, and — crucially — its `file`/`line` for error reporting) into the module body it defines.
`Module.create/3` takes an explicit `Macro.Env` (its third argument) or an empty one if omitted, and
does **not** inherit anything from wherever in the transformer it happens to be called — a
transformer running inside Spark's compilation pipeline has its own `__ENV__`, which is *not* the
DSL-using resource module's environment, and is not automatically threaded through.

**How to avoid:** Two consequences worth being deliberate about:

1. Because the generated module gets no aliases for free, **fully qualify every module reference in
   generated code** (`AshCommanded.Foo` not `Foo`) rather than relying on an `alias` the transformer
   happened to have in its own file — that alias does not travel with the AST.
2. Pass `Macro.Env.location(env)` (or an explicit `file:`/`line:` keyword list as `Module.create/3`'s
   third argument, which accepts either a `Macro.Env` or such a keyword list) pointing at the
   DSL-using module's own source file, so compile errors and stacktraces inside generated code report
   a location a human can act on, rather than the transformer's own file or `nofile`.

**Phase to address:** Foundation is the right place to establish this convention once (a shared
`AshCommanded.CodeGen` helper wrapping `Module.create/3` with sane defaults), before any component
generator is rewritten against it.

---

### Pitfall 17: Compile-time dependency cascades from quoted references

**What goes wrong:** Every module reference inside a `quote` block that the compiler can resolve at
compile time (an `alias`, a direct call the compiler recognizes, a `@behaviour`) creates a tracked
compile-time dependency edge from the generated module to the referenced one. This is *correct and
necessary* when the reference is real (e.g. a generated projector genuinely must be recompiled if the
Ash resource action it calls changes shape) — the problem is **unintentional** edges that make
unrelated DSL entities recompile the world whenever one of them changes.

**Concretely, in a Spark-based DSL like this one:** if a resource's aggregate module's generated code
directly references sibling generated modules (its own Event structs, its own Command structs) that
is an inherent, correct dependency — those modules genuinely change together. The trap is broader
transitive coupling: e.g. a shared helper macro that `alias`es or `use`s a large module (pulling in
*that* module's own dependency graph) purely for convenience, causing every DSL-using resource in the
whole application to recompile whenever the large module changes, even though most resources never
touch the functionality that was actually modified.

**How to avoid:** Prefer fully-qualified calls to `alias`-then-call inside generated code (an
unaliased `Some.Deep.Module.function()` is exactly as fast at runtime and creates the identical
necessary dependency edge, without also creating a *second* edge to whatever `alias` resolution
touched); avoid `use`-ing any module inside generated code purely for a helper function when
`import`/qualified-call would do (this is also the Elixir Code Smells catalogue's "'Use' instead of
'Import'" smell — see Pitfall 19); and when in doubt, `Macro.expand/2` an alias down to its literal
resolved atom at macro-expansion time and emit the atom directly rather than emitting an alias
directive into the generated code — this also sidesteps any ambiguity about which alias table the
generated module would otherwise need at its own compile time.

**Phase to address:** Cross-cutting; worth an explicit check during the Foundation CI-matrix work
(watch `mix compile` timings/recompilation counts before and after touching one DSL entity, to catch
an over-broad dependency edge early).

---

### Pitfall 18: "Large code generation by macros" (Elixir Code Smells catalogue)

**What goes wrong:** A macro (or, equivalently, a Spark transformer's `quote` block) expands to a
large amount of code, and that expansion happens once per DSL entity — a resource with 12 commands
means 12 near-identical expansions of whatever the command-generation macro contains, multiplying
compiled code volume and compile time.

**Catalogue description (lucasvegi/Elixir-Code-Smells):** "When a macro provides a large code
generation, it impacts how the compiler or the runtime works." The catalogue's own example is a router
macro invoked hundreds of times, each invocation re-expanding the same validation/storage logic inline.
**Fix per the catalogue:** delegate bulk operations to a helper function the macro merely calls
(the catalogue's own example names this pattern `__define__/3`), rather than expanding the full logic
inline at every call site.

**Direct match to this project:** this is the exact same finding as Pitfall 1/PROJECT.md's aggregate
generator audit, restated as a named, citable code smell rather than a project-local observation. The
fix is identical: Rewrite Rule 1 (generated code is thin wiring over hand-written runtime modules) is
this catalogue's prescribed fix, applied library-wide rather than to one generator.

**Phase to address:** Cross-cutting; the generator audit table in LEARNINGS.md §1 is effectively this
smell's detector — rerun it after each component to confirm the fix held.

---

### Pitfall 19: "'Use' instead of 'import'" and the `AshCommanded.Aggregate.__using__/1` design question

**What goes wrong:** A `use SomeModule` directive injects code, attributes, and (transitively) that
module's own dependencies into the caller with no visible list of what arrived — the catalogue's
example is a client module unknowingly inheriting a name collision from a dependency its `use`d
library itself imported.

**Catalogue description:** "Using `import` or `alias` instead maintains lexical scope and only
facilitates that a module use functions of another" more transparently than `use`, which "injects code
broadly and propagates dependencies opaquely."

**Direct relevance:** the milestone's central open design question — "what is
`AshCommanded.Aggregate.__using__/1`?" — is precisely the situation this smell warns about. Every
`use` in this library (`use Commanded.Application`, `use Commanded.Commands.Router`, `use
Commanded.Event.Handler`, and whatever `use AshCommanded.Aggregate` ends up being) is legitimate and
necessary — the DSL genuinely needs `@before_compile` hooks and behaviour registration a plain
`import` cannot provide — but the smell's fix still applies at the margins: any *helper* function that
does not need `@before_compile`/attribute-registration machinery (e.g. a pure validation function, a
pure param-mapping function) should be reached via `import` or a qualified call, not folded into the
`use` macro's injected surface just because it's convenient to have it "already there." Keep the
`use`-injected surface to the minimum that genuinely requires compile-time registration, and document
that surface explicitly (this is also what Foundation's AGENTS.md/usage_rules work should capture).

**Phase to address:** Aggregates component, at the point the `__using__/1` design question is answered
— treat "what is in the `use` surface vs. what should just be an importable function" as an explicit
design decision to record, not an accretion.

---

### Pitfall 20: "Compile-time global configuration" leaking into generated code

**What goes wrong:** Generated code reads `Application.get_env/2` or `Application.compile_env/3`
directly inside a `quote` block, baking a config-time decision into the compiled artifact in a way
that silently goes stale if config changes without a recompile, or that makes the generated code's
behaviour depend on *when* it was compiled relative to config loading.

**Verified prior art (this is a real pattern in Commanded, not hypothetical):**
`deps/commanded/lib/commanded/commands/router.ex:251-260` does exactly this for the default
`aggregate_lifespan`:

```elixir
lifespan:
  if unquote(app_module) do
    Application.compile_env(unquote(otp_app), [unquote(app_module), :aggregate_lifespan], DefaultLifespan)
  else
    DefaultLifespan
  end,
```

This is Commanded's own considered choice (`compile_env`, not `get_env`, specifically records a
compile-time dependency so `mix compile` recompiles the router if that config key changes — Elixir's
`Config.Reader`/`compile_env` machinery exists precisely to make this safe rather than silently stale).
**The smell is using `Application.get_env/2` (no compile-time tracking) for something that varies by
config inside generated code**, not `compile_env` per se — `compile_env` is the safe, tracked version
of the same idea, and is the mechanism to reach for if a DSL genuinely needs application-config-driven
behaviour baked into generated code (e.g. a default consistency level, a default event store choice).

**How to avoid:** If generated code needs to depend on application config, use `Application.compile_env/3`
(never bare `get_env/2`) so the compiler tracks the dependency and force-recompiles on config
changes; better still, prefer DSL-declared values (resolved once, at transformer time, from
`dsl_state`) over reading config at all, reserving `compile_env` for genuinely environment-level
choices (which event store adapter, which OTP app) that a DSL entity should not need to declare
per-resource.

**Phase to address:** Application component (this is exactly where `otp_app`/event-store/adapter
config choices live).

---

### Pitfall 21: Dynamic atom creation from anything other than the DSL author's own compile-time literals

**What goes wrong:** Turning a runtime string into an atom — `String.to_atom/1` on a value that
originates from event data, a database read, or any external input — which is an unbounded-atom-table
denial-of-service vector (atoms are never garbage collected) and is explicitly called out as a code
smell in the catalogue ("Dynamic atom creation").

**Why this specific library is at elevated (but bounded) risk:** a DSL that generates modules named
after user-declared command/event names, and a router/composite-router mechanism that builds
`Module.concat/1` names from DSL-declared atoms, does a *lot* of legitimate atom/module-name
construction — but every one of those inputs (command names, event names, resource module names) is a
**compile-time literal the DSL author wrote in their own source file**, not runtime data. That is safe:
the atom table only grows once per distinct DSL declaration, at compile time, bounded by the size of
the codebase. The danger threshold is any place where a **runtime value** — an event's `type` string
read back from the event store during upcasting/routing, an actor-supplied string, an HTTP
param — is converted to an atom to use in a `case`/pattern match or module lookup. Nothing in the
verified Commanded surface above does this (event dispatch is always via the already-atom struct
module, e.g. `Kernel.apply(aggregate_module, :apply, [state, data])` where `data` is already a struct,
never a bare string looked up by name) — but a hand-authored declarative upcasting DSL or a dynamic
router extension is exactly the kind of new surface where this mistake could be introduced for the
first time.

**How to avoid:** Audit any new runtime lookup this rewrite introduces (particularly in the upcasting
and routing components, which are new DSL surface) for `String.to_atom/1`/`Module.concat/1` fed by
anything other than a compile-time-known, DSL-author-written literal. Use `String.to_existing_atom/1`
(which raises rather than growing the atom table) wherever a runtime string must be compared against a
known, closed set of atoms.

**Phase to address:** Declarative event versioning component; Routers component (both introduce new
runtime dispatch surfaces).

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
| ---------- | -------------------- | ----------------- | ------------------ |
| `Code.ensure_loaded?` guard around a `@behaviour`/dependency that "might not be present" | Compiles even without the optional dependency declared | Compiler never checks the guarded code against anything real; false confidence (this hid the Snapshotter fiction and a whole quarantined integration test) | Never, for a hard dependency the library actually requires (`:commanded` is now declared — there is no longer a reason for this pattern anywhere in `lib/` or `test/`) |
| In-memory-only snapshot/event storage in examples and CI | Fast, no external services | Doesn't prove the Postgres path `core` actually needs; a snapshot config that "works" against `InMemory` may not survive a real adapter's serialization requirements | Acceptable for docs/CI speed **only if** a second, Postgres-backed example/test also exists per the project's own "two example adapters" decision |
| Generating one dispatch mechanism for handlers/projectors/process-managers | Less code to write once | Projectors inherit process-manager machinery (state-sourcing via `apply/2`, `after_command`) they never use, inflating the generated surface for the common case | Never — the three Commanded shapes are cheap to keep separate and this project's stated goal is thin, legible generated code |
| Reading `Application.get_env/2` (not `compile_env/3`) inside generated code for config-driven defaults | Slightly less ceremony | Config changes don't force recompilation, so behaviour can silently diverge from what the generated code appears to encode | Never inside `quote` blocks; acceptable in ordinary runtime helper functions that read config at call time by design |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
| -------------- | ------------------ | -------------------- |
| `Commanded.Application` + Ash `Domain` | Assuming the domain's transformers run only after all its resources finish compiling | Read each resource's persisted DSL state explicitly via `Ash.Domain.Info.resources/1` + `Spark.Dsl.Extension.get_persisted/2`, or generate router-then-application inside one transformer's sequential `Module.create/3` calls |
| `Commanded.Event.Upcaster` + event store replay | Registering per-version-hop upcasters and expecting them to chain | Every historical struct type's `upcast/2` clause must return the *current* struct directly; compose intermediate transformations at generation/definition time |
| `Commanded.Snapshotting` + Ash resources | Trying to snapshot the Ash resource struct itself instead of the aggregate's own state struct | Snapshot the aggregate module's own struct (whatever `apply/2` builds and returns) — that is what `Snapshotting.take_snapshot/3` persists and what `read_snapshot` returns as initial state |
| `Commanded.Middleware` + AshCommanded's own middleware modules | Assuming the project's `CommandMiddleware`/`ValidationMiddleware`/`LoggingMiddleware` naming reflects a Commanded API | Verify against `@behaviour Commanded.Middleware`'s three required callbacks (`before_dispatch/1`, `after_dispatch/1`, `after_failure/1`) operating on `%Pipeline{}` — treat `CLAUDE.md` naming as unverified until confirmed |
| Multiple `Commanded.Application`s in one VM (the eventual `core` migration shape) | Testing only ever one uniquely-named application per test process | Add at least one test starting two independently-named applications simultaneously, including handler-name-uniqueness checks across them |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
| ------ | ---------- | ------------ | ------------------ |
| Runtime list/keyword concatenation of compile-time-known values inside `execute/2`/`apply/2` | Every dispatch does allocation work (`:erlang.++/2` chains) that produces the same literal every time | Compute the merged literal in the transformer, `unquote` it once | Immediately, on every dispatch — not a scale threshold, a per-call tax from day one |
| `batch_size` configured without `batch_timeout`, expecting steady-state batching | Live traffic still calls `handle_batch/1` with single-event lists; no batching benefit observed until backpressure/replay | Set `batch_timeout` alongside `batch_size` if steady-state batching (not just replay-time batching) is the goal | As soon as anyone benchmarks steady-state throughput expecting batched writes and doesn't see them |
| Large `quote` blocks (>40 lines) per generated entity | Compile time grows superlinearly with DSL entity count across a large resource | Keep generated clauses thin (Rewrite Rule 3); measure via the generator audit table | Noticeable once a resource has dozens of commands/events, as `core`'s eventual migration will |
| Unnecessary compile-time dependency edges from generated code to large modules | Touching one small module triggers a much larger recompile cascade across unrelated DSL entities | Fully-qualify references, avoid needless `alias`/`use` inside generated code, `Macro.expand/2` where genuinely useful | Noticeable in CI/dev-loop compile times as the DSL-using codebase (eventually `core`, 163+ modules) grows |

## Security Mistakes

| Mistake | Risk | Prevention |
| --------- | ------ | ------------ |
| `String.to_atom/1` on any runtime-sourced string (event type strings during upcasting/routing, actor input) | Unbounded atom table growth — a process-wide, ungarbage-collected DoS vector | `String.to_existing_atom/1` against a known closed set, or avoid the atom conversion entirely by dispatching on the struct that already exists |
| Interpolating DSL-declared values into a string that is then `Code.eval_string`/`Code.string_to_quoted!`'d | Arbitrary-code-shaped injection surface, however unlikely the immediate source; also defeats every static tool | Never build generated code as strings; always construct AST directly |
| Metadata passed to `Upcaster.upcast/2` treated as trusted without validation | Upcast functions receive enriched metadata (`application`, `event_id`, `causation_id`, etc. — `upcaster.ex:30-46`) alongside user-supplied metadata keys (string-keyed, vs. the system's atom-keyed values) — conflating the two trust levels in a generated upcaster could let user-supplied metadata influence upcast decisions unexpectedly | Document and enforce (in generated code) that only the atom-keyed system metadata fields drive upcast logic, never the string-keyed user metadata, unless a DSL author explicitly opts in |

## "Looks Done But Isn't" Checklist

- [ ] **Router/application generation compiles with no warnings:** compiling is not sufficient proof —
      confirm `AppModule.dispatch/1` actually succeeds against a real command, not just that
      `mix compile` is silent (this is precisely how the "router generation never fires" defect
      survived: it compiled cleanly and only failed at the first real dispatch).
- [ ] **A generated aggregate/projector "has no warnings":** confirm via `mix test`, not
      `mix compile` alone — `mix compile` does not compile `test/**/*_test.exs`, so a defect in code
      generated only when a test-only fixture compiles (the dead `perform_action/2` clauses found in
      every generated projector) is invisible to a compile-only check.
- [ ] **Snapshotting "works" in tests:** confirm a snapshot survives a process restart against the
      *actual* configured event store adapter for a genuinely long-running aggregate, not just that
      `snapshot_every`/`snapshot_version` compile into a valid `%Commanded.Snapshotting{}` — an
      `InMemory`-only test proves nothing about the Postgres path.
- [ ] **Event upcasting "handles versioning":** confirm a *replay* of a real multi-version event
      stream (seed events at V1, V2, and V3 shapes, then rebuild aggregate state from scratch) reaches
      the same final state as a stream seeded entirely at the current version — a test that only
      checks the upcaster function's return value in isolation does not prove the replay path works.
- [ ] **A `dispatch/1` returns `:ok`:** confirm with `returning: :execution_result` or
      `:aggregate_state` at least once per component, since `:ok` alone hides whether the expected
      events were actually produced (an aggregate that silently no-ops still dispatches `:ok` if it
      returns `nil`/`[]` — `aggregate.ex:513`).
- [ ] **"Nine compile-time verifiers" documented in `CLAUDE.md`:** treat as false until each is found
      in `lib/commanded/verifiers/` and covered by a test that asserts DSL misuse is *rejected* (via
      `Spark.Test.assert_dsl_error/1,2`, not `assert_raise`, since Spark verifier errors surface via
      `@after_verify` and are not raise-catchable — see LEARNINGS.md §4, Spark).

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
| --------- | ---------------- | ------------------ |
| Router/application ordering defect (Pitfall 2) | MEDIUM | Restructure so router generation and application generation happen from one transformer's sequential `Module.create/3` calls, or have the domain transformer read resources' persisted state directly; restore the quarantined integration test and delete its `Code.ensure_loaded?` guard once fixed |
| Chained-upcast assumption discovered after events already exist at multiple versions (Pitfall 4) | HIGH | Cannot be fixed by changing the upcaster alone once bad data is already stored incorrectly-upcast in a read model; must re-derive read models from the event store with corrected upcasters (an argument for getting this right before any real events are written, i.e. before the `core` migration) |
| Snapshot adapter behaviour rebuilt around a nonexistent module (Pitfall 3) | LOW | Delete the fictional behaviour, replace with the documented `:snapshotting` config map; no runtime data is affected since the guard meant it was never actually exercised |
| Large `quote` blocks discovered late in a component (Pitfall 10/18) | MEDIUM | Render the generated output, identify the runtime-reassembled values, move each to transformer-time computation with a single `unquote`; re-run the generator audit table to confirm the largest block shrank |
| `Module.concat` module-name surgery discovered in a shipped generator (Pitfall 11) | LOW–MEDIUM | Replace with `Transformer.get_persisted/2` read, force a `mix clean && mix compile` once to confirm no stale-BEAM artifacts are hiding the fix's effect |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
| --------- | -------------------- | ---------------- |
| Aggregate `__using__` machinery inlined into `quote` (P1, P19) | Aggregates component | Generator audit table: largest `quote` block under ~40 lines, generated clause under ~10 |
| Router/application compile-time ordering (P2) | Application component (jointly with Routers/event handlers/process managers) | Quarantined integration test restored and green; a real multi-resource domain dispatches successfully, not just compiles |
| Snapshot adapter fiction (P3) | Snapshots component | No `@behaviour` reference to a nonexistent module; snapshot round-trips through the real configured event store adapter, not just `InMemory` |
| Upcast chaining assumption (P4) | Declarative event versioning component | Replay test seeds events at 3+ versions and asserts identical final state to an all-current-version seed |
| Lifespan/invariant conflation (P5) | Aggregates component | Invariant rejection tested via `execute/2` returning `{:error, _}`; lifespan tested independently via router `dispatch` opts |
| Handler/process-manager/projector conflation (P6) | Projections + Routers/event handlers/process managers components | Three distinct generated shapes exist; a projector test asserts it never calls `interested?/1,2` |
| Middleware shape drift (P7) | Middleware and transaction coordination component | `@behaviour Commanded.Middleware` compiles with all 3 callbacks, zero warnings |
| Multi-application blind spot (P8) | Application component; carried to `core` migration milestone | A test starts 2+ independently-named applications concurrently |
| Runtime AST reassembly (P10, P18) | Every component | Golden-render diff shows no `:erlang.++`/`Enum.concat` etc. on values known at generation time |
| Module-name surgery (P11) | Every component, esp. Aggregates | Custom Credo check flags `Module.concat` fed by `Module.split` results |
| String-built-and-reparsed AST (P12) | Every component | Code review checklist item; Credo check for `Code.string_to_quoted!`/`Code.eval_string` in `lib/` |
| Re-walked AST for an already-held value (P13) | Every component, esp. Aggregates/Projections | Code review: helper functions take specific values, not whole `dsl_state`, wherever avoidable |
| Hygiene misuse (`var!`, misapplied `Macro.escape/1`) (P14) | Every component | Grep audit before each component's rewrite begins |
| Spurious warnings/bad stacktraces (P15) | Foundation | Golden render + `mix compile --warnings-as-errors` on `test/support/parity/` catches these before component work starts |
| `Module.create/3` losing env (P16) | Foundation | Shared codegen helper wraps `Module.create/3` with explicit `file:`/`line:`; every component reuses it |
| Compile-time dependency cascades (P17) | Foundation (CI matrix work) | Compare recompilation scope before/after touching one DSL entity |
| "Use instead of import" surface creep (P19) | Aggregates component | `AshCommanded.Aggregate.__using__/1`'s injected surface is explicitly documented and reviewed as a deliberate list, not an accretion |
| Compile-time global config baked into generated code (P20) | Application component | Any config read inside generated `quote` uses `compile_env/3`, never `get_env/2` |
| Dynamic atom creation from runtime data (P21) | Declarative event versioning + Routers components | Audit every `String.to_atom`/`Module.concat` call introduced by these two components for a non-compile-time-literal input |

## Sources

- `deps/commanded/lib/commanded/aggregates/aggregate.ex` (1.4.11) — aggregate `GenServer`,
  `execute`/`apply` callback contract, lifespan timeout handling, snapshot triggering.
- `deps/commanded/lib/commanded/aggregates/aggregate_lifespan.ex`,
  `deps/commanded/lib/commanded/aggregates/default_lifespan.ex` — lifespan behaviour and default impl.
- `deps/commanded/lib/commanded/aggregates/aggregate_state_builder.ex` — snapshot read, event replay,
  upcast integration via `EventStore.stream_forward/4`.
- `deps/commanded/lib/commanded/aggregates/multi.ex` — `Commanded.Aggregate.Multi` for
  multi-event-from-one-command patterns.
- `deps/commanded/lib/commanded/snapshotting.ex`, `deps/commanded/lib/commanded/event_store/snapshot_data.ex`
  — snapshotting config shape and versioning; confirms no adapter behaviour exists.
- `deps/commanded/lib/commanded/event/upcaster.ex`, `deps/commanded/lib/commanded/event/upcast.ex`,
  and all five call sites (`event_store.ex:83`, `aggregate.ex:389`,
  `process_managers/process_router.ex:193`, `event/handler.ex:1076,1642`) — confirms single-pass
  upcasting, no chaining.
- `deps/commanded/lib/commanded/commands/router.ex`, `deps/commanded/lib/commanded/commands/composite_router.ex`
  — router/dispatch macro internals, `router/1` macro-expansion-time dependency on
  `__registered_commands__/0`, `generated: true`/`location: :keep` usage.
- `deps/commanded/lib/application.ex` — `Commanded.Application` config shape, composite-router
  inclusion, dynamic named applications.
- `deps/commanded/lib/commanded/event/handler.ex` — event handler behaviour, batching semantics,
  consistency, error handling.
- `deps/commanded/lib/commanded/process_managers/process_manager.ex` — process manager behaviour and
  distinguishing callbacks.
- `deps/commanded/lib/commanded/middleware/middleware.ex` — middleware behaviour contract.
- `deps/commanded/lib/commanded/assertions/event_assertions.ex` — testing helpers for event-sourced
  assertions.
- `lucasvegi/Elixir-Code-Smells` (GitHub catalogue, fetched 2026-09-15) — "Large code generation by
  macros," "Unnecessary macros," "'Use' instead of 'import'," "Compile-time global configuration,"
  "Dynamic atom creation."
- `.planning/PROJECT.md` and `.planning/LEARNINGS.md` (this repository) — established facts, the
  nine defects found in Phase 01, and the Rewrite Rules used throughout as the prevention framework.

---
*Pitfalls research for: AshCommanded v0.3 Library Rewrite (Commanded integration + Spark/macro
code generation)*
*Researched: 2026-09-15*
