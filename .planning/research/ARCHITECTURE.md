# Architecture Research — Mature Spark/Ash Extension Code Generation

**Domain:** Spark DSL / Ash extension architecture, applied to AshCommanded's aggregate-and-router rewrite
**Researched:** 2026-09-15
**Confidence:** HIGH — every claim below is grounded in source read directly (local `deps/` checkouts
of `ash` 3.5.8, `ash_graphql`, `ash_authentication`, `ash_postgres`, `reactor`, `spark` 2.7.2,
`commanded` 1.4.11, all resolved against `work/core`'s real lockfile; plus `ash_oban` and
`ash_json_api` fetched live from `ash-project/*` on GitHub via `gh api` since they are not in any
local `deps/`). File paths are given for everything so claims are independently checkable.

**Libraries read, and how:**

| Library | Source | Depth |
| --- | --- | --- |
| `ash` 3.5.8 | `work/core/deps/ash` | `domain/dsl.ex`, `resource/dsl.ex` (compile-dependency schema) |
| `ash_graphql` (current, via `work/core` lockfile) | `work/core/deps/ash_graphql` | `domain/domain.ex`, `domain/info.ex`, `resource/info.ex`, `ash_graphql.ex`, transformers/verifiers, `test/verify_field_references_test.exs` (GitHub) |
| `ash_authentication` (current) | `work/core/deps/ash_authentication` | `token_resource/transformer.ex` (entity-injection pattern) |
| `ash_postgres` (current) | `work/core/deps/ash_postgres` | directory layout, migration/snapshot machinery |
| `ash_json_api` (main branch) | GitHub via `gh api repos/ash-project/ash_json_api` | `domain/info.ex`, `domain/transformers/set_base_routes.ex`, `lib/ash_json_api/router.ex` |
| `ash_oban` (main branch) | GitHub via `gh api repos/ash-project/ash_oban` | `lib/transformers/define_action_workers.ex` |
| `reactor` (current) | `work/core/deps/reactor` | `reactor.ex`, `reactor/info.ex`, `reactor/builder.ex`, directory tree (non-Ash Spark DSL) |
| `spark` 2.7.2 | `work/core/deps/spark` | `dsl.ex`, `dsl/extension.ex`, `dsl/transformer.ex`, `dsl/extension/entity_option.ex`, `info_generator.ex`, `test.ex` |
| `commanded` 1.4.11 | `work/core/deps/commanded` (== AshCommanded's own `deps/commanded`) | `commands/router.ex`, `event/handler.ex`, `application.ex` — the three `__using__` macros AshCommanded's own generators already lean on |

`ash_phoenix` was checked for relevance and found not to add anything beyond what `ash_graphql`
already establishes (it wraps changesets for LiveView forms; it does not generate Commanded-shaped
modules). AshOban and AshJsonApi were not available locally and were fetched from GitHub directly;
treat their citations as MEDIUM confidence relative to the HIGH confidence of the locally-compiled,
version-pinned libraries, though nothing found from them was surprising or load-bearing on its own —
they corroborate patterns already established from local sources.

---

## 1. The `__using__` front door pattern

### The precedent AshCommanded already depends on

AshCommanded's own generators for events handlers, routers and the application already delegate to
Commanded's `__using__` macros. Reading them directly (not just knowing they exist) shows the exact
shape a well-designed `__using__/1` takes, and it is the same shape three times over:

**`Commanded.Commands.Router`** (`deps/commanded/lib/commanded/commands/router.ex:230-272`):

```elixir
defmacro __using__(opts) do
  quote do
    import unquote(__MODULE__)
    @before_compile unquote(__MODULE__)
    @behaviour Router
    Module.register_attribute(__MODULE__, :registered_commands, accumulate: true)
    Module.register_attribute(__MODULE__, :registered_middleware, accumulate: true)
    Module.register_attribute(__MODULE__, :registered_identities, accumulate: false)
    @default_dispatch_opts [...]
    @default_middleware [...]
    @registered_identities %{}
  end
end
```

The body of the `use`-ing module then calls plain macros (`dispatch`, `identify`, `middleware`)
which do nothing but `@registered_commands {command_module, opts}` — accumulate into a module
attribute. All the real work happens in `__before_compile__/1`
(`router.ex:497-535`), which runs once, after the accumulation is complete, and materializes ONE
small `defp do_dispatch(%@command_module{} = command, opts)` clause per registered command:

```elixir
defmacro __before_compile__(_env) do
  quote generated: true do
    def __registered_commands__ do
      Enum.map(@registered_commands, fn {command_module, _opts} -> command_module end)
    end
    ...
    for {command_module, command_opts} <- @registered_commands do
      @aggregate Keyword.fetch!(command_opts, :aggregate)
      @command_module command_module
      defp do_dispatch(%@command_module{} = command, opts) do
        alias Commanded.Commands.Dispatcher
        ...
        Dispatcher.dispatch(%Payload{...})
      end
    end
  end
end
```

This is rewrite rule #1 and #3, verbatim, in the library AshCommanded already vendors: **the
generated clause is a pattern match on the command struct plus a handful of `@`-injected literals,
and the entire dispatch mechanics live in `Commanded.Commands.Dispatcher`, a hand-written runtime
module.** Nothing about consistency, retries, telemetry or timeout handling is inlined into the
per-command clause. `Commanded.Event.Handler` (`deps/commanded/lib/commanded/event/handler.ex:695-804`)
and `Commanded.Application` (`deps/commanded/lib/application.ex:172-`) follow the identical shape:
`@before_compile` + `@behaviour` + `defoverridable` for the handful of callbacks a user is allowed to
customize (`init/1`, `after_start/1`, `before_reset/0`), with everything else supplied by the macro.

**Anatomy of a well-designed `__using__/1`, distilled from all three:**

1. `@before_compile unquote(__MODULE__)` — defers code generation from "as the body executes" to
   "once, after the body has finished accumulating state." This is the mechanism that lets a DSL body
   call several small macros (`dispatch`, `identify`) in any order and still produce one coherent
   compiled artifact.
2. `@behaviour X` — declares the contract in a way Dialyzer and the compiler can check, independent of
   whether every callback is actually implemented (paired with `@optional_callbacks`).
3. `Module.register_attribute(__MODULE__, :foo, accumulate: true)` — the accumulator that macros
   called in the body write into.
4. `defoverridable a: 1, b: 0` on a set of DEFAULT implementations supplied by `__using__` itself —
   the same pattern as `GenServer`'s own `use GenServer` (default `handle_info/2`, `terminate/2`,
   etc., all `defoverridable`). This is what lets a using-module override only what it cares about.
5. Heavy logic never appears inside the `quote` block emitted by `__using__` or `__before_compile__`
   at all — it is a plain function call into a runtime module (`Commanded.Commands.Dispatcher`,
   `Commanded.Event.Handler.parse_config!/2`, etc.) that can be read, unit-tested and stepped through
   without mentally expanding a macro.

### AshGraphql's variant: `__using__` as the compile-time SCHEMA ASSEMBLY point, not per-resource codegen

`AshGraphql.__using__/1` (`deps/ash_graphql/lib/ash_graphql.ex:65-401`) is a different, and equally
important, variant: it is not attached to a DSL-generated module at all. It is what a HUMAN writes
(`use AshGraphql, domains: [MyApp.Accounts, MyApp.Blog]`) in their own hand-authored Absinthe schema
module. Its body does real work directly inside `quote bind_quoted: [...]`, including
`defmodule Module.concat([__MODULE__, domain, AshTypes])` (a nested, dynamically-named submodule
implementing the `Absinthe.Schema.Notation` pipeline-modifier for each domain) and an
`Enum.each(ash_resources, &Code.ensure_compiled!/1)` (line 168) that forces every resource to be a
fully compiled module before schema assembly proceeds. This is the answer to "how does AshGraphql
avoid the compile-order problem for domain-level artifacts" for the RUNTIME/rendering half of its
architecture — see §3 for the compile-time-transformer half, which uses a different, narrower
mechanism.

### Implication for AshCommanded

AshCommanded already has three generators (event handler, router, application) that get this right
by riding Commanded's own `__using__` macros. The ONE generator that doesn't (`GenerateAggregateModule`)
is broken for exactly the reason PROJECT.md and LEARNINGS.md identify: **there is no
`Commanded.Aggregates.Aggregate` behaviour or `__using__` macro to lean on**, so the fix is not to
find one in Commanded — there isn't one — but to WRITE one, in AshCommanded's own namespace, using
the same five-part anatomy above. §2 gives the concrete design.

---

## 2. The aggregate-shaped problem: designing `AshCommanded.Aggregate.__using__/1`

### Precedent for "generate a module against a plain callback contract, no framework `use` macro"

Two real precedents were found for this exact shape — a target callback contract that the underlying
library does NOT wrap in a `use` macro, so the DSL author must supply one:

1. **Elixir's own `GenServer`** (stdlib, not a dep, but definitive precedent every Elixir engineer
   already accepts as idiomatic): `use GenServer` supplies default `init/1`, `handle_call/3`,
   `handle_cast/2`, `handle_info/2`, `code_change/3`, `terminate/2` — all `defoverridable` — against
   the RAW `@behaviour GenServer` callbacks, which have no inherent "use macro" at the OTP layer
   (`:gen_server` is an Erlang behaviour, not an Elixir one). This is precisely AshCommanded's
   situation: Commanded's aggregate is the "raw behaviour," and AshCommanded needs to be the layer
   that adds the `use`.
2. **`AshOban.Transformers.DefineActionWorkers`** (`ash_oban` GitHub,
   `lib/transformers/define_action_workers.ex:60-90`) generates a *new* module per scheduled action
   via `Module.create/3`, whose body does `use unquote(worker), priority: ..., queue: ...` (where
   `worker` is `Oban.Worker` or `Oban.Pro.Worker`) followed by ONE `def perform(%Oban.Job{args: args})`
   clause. Oban.Worker *does* have a `use` macro, so this isn't a no-`use`-available case, but it is
   the most directly relevant precedent for the OTHER half of the aggregate problem: **what a
   generated clause looks like when it needs a large amount of per-trigger configuration it does not
   want to inline as a literal.** Rather than inlining every field of the `scheduled_action` struct
   into the quoted body, the generated `perform/1` does:

   ```elixir
   def perform(%Oban.Job{args: args} = job) do
     scheduled_action =
       AshOban.Info.oban_scheduled_action(unquote(resource), unquote(scheduled_action.name))
     tenants = scheduled_action.list_tenants || AshOban.Info.oban_list_tenants!(unquote(resource))
     ...
   end
   ```

   Only small, genuinely-static values (`priority`, `queue`, `max_attempts`, the resource module, the
   trigger's `:name` atom) are `unquote`'d as literals into the `use Oban.Worker` options and the
   `Info` lookup key. Everything structurally larger (the full trigger config, `list_tenants`,
   `shared_context`) is fetched BACK OUT of the DSL at runtime via `AshOban.Info.oban_scheduled_action/2`
   — a cheap keyed lookup, not a re-derivation. **This is the resolution to the tension between
   rewrite rule #2 ("compute at macro-expansion time, unquote as literal") and the anti-pattern the
   audit found** (six nested `:erlang.++/2` calls reassembling `[transforms: [], validations: []]` at
   runtime in `evidence-generated-aggregate.txt:101-110`): the old code was reassembling a value that
   was BOTH static AND already available as a literal, at runtime, for no reason. The AshOban
   precedent shows the legitimate alternative to over-inlining is not "compute everything at
   compile-time" — it's "compute the SMALL identifying key at compile time, and let the runtime
   module ask the `.Info` module for the rest, once, by that key." Both are compliant with the rule;
   re-deriving a value that is already sitting fully-formed in a variable is what the rule forbids.

### Concrete design: `AshCommanded.Aggregate.__using__/1`

Given both precedents, the shape that fits Commanded's actual contract (`execute/2`, `apply/2`, no
`@behaviour` in Commanded itself — confirmed in LEARNINGS.md §4: "Aggregates are plain modules with
`execute/2` and `apply/2` — no `use` macro, no callbacks") is:

```elixir
defmodule AshCommanded.Aggregate do
  @moduledoc """
  The `__using__` front door for generated aggregate modules. Commanded has no
  aggregate behaviour to lean on (unlike Router/EventHandler/Application, which
  supply their own `use` macros) — this module is that missing piece, written
  once, by hand, so every generated aggregate is thin wiring over it.
  """

  @callback execute(state :: struct(), command :: struct()) ::
              {:ok, struct()} | {:error, term()} | struct() | [struct()]
  @callback apply(state :: struct(), event :: struct()) :: struct()
  @optional_callbacks execute: 2

  defmacro __using__(opts) do
    resource = Keyword.fetch!(opts, :resource)

    quote location: :keep, bind_quoted: [resource: resource] do
      @before_compile AshCommanded.Aggregate
      @behaviour AshCommanded.Aggregate
      @ash_commanded_resource resource

      import AshCommanded.Aggregate, only: [command: 2, command: 3]
      Module.register_attribute(__MODULE__, :ash_commanded_commands, accumulate: true)

      @doc false
      def __ash_commanded_resource__, do: @ash_commanded_resource
    end
  end

  @doc "Declares one command→event mapping. Called from the DSL-generated module body."
  defmacro command(command_module, event_module, opts \\ []) do
    quote do
      @ash_commanded_commands {unquote(command_module), unquote(event_module), unquote(opts)}
    end
  end

  defmacro __before_compile__(_env) do
    quote generated: true do
      resource = @ash_commanded_resource

      for {command_module, event_module, _opts} <- @ash_commanded_commands do
        def execute(%__MODULE__{} = state, %unquote(command_module){} = command) do
          # Small, resource-scoped runtime lookup — NOT a re-derivation of a
          # literal that was already known. See AshOban precedent above.
          config = AshCommanded.Aggregate.Info.command(unquote(resource), unquote(command_module))
          AshCommanded.Aggregate.Runtime.execute(state, command, unquote(event_module), config)
        end
      end

      def apply(%__MODULE__{} = state, event) do
        AshCommanded.Aggregate.Runtime.apply(state, event)
      end

      defoverridable execute: 2, apply: 2
    end
  end
end
```

What this buys, compared to the 333-line rendered artifact in `evidence-generated-aggregate.txt`:

- The generated `execute/2` clause is one pattern match plus TWO function calls — comparable in size
  to Commanded's own `do_dispatch/2` clause, and structurally identical to it.
- `AshCommanded.Aggregate.Runtime` (a plain, hand-written, unit-testable module — analogous to
  `Commanded.Commands.Dispatcher`) owns identity checking, middleware invocation, snapshot threshold
  logic, and error wrapping — everything that used to be inlined per-clause in
  `generate_aggregate_module.ex`'s 225-line `quote` block.
- `AshCommanded.Aggregate.Info.command/2` (a `.Info` module, see §5) is the ONE place that knows how
  to look up per-command configuration (`transforms`, `validations`, identity field) — by resource and
  command module, at runtime, cheaply. No six-deep `:erlang.++/2` concatenation of empty lists is ever
  emitted, because nothing is being reassembled: it's a single map/struct lookup.
- `defoverridable execute: 2, apply: 2` means a resource author can hand-write a clause for one
  command (an escape hatch for genuinely bespoke aggregate logic) without losing the generated
  clauses for every other command — exactly the `GenServer` pattern.

**What belongs where:**

| Concern | Lives in |
| --- | --- |
| Per-command dispatch clause shape (`execute/2` matching on command struct) | Generated aggregate module (`Module.create/3` output), via `AshCommanded.Aggregate.__using__/1` + `__before_compile__/1` |
| Identity checks, middleware pipeline invocation, event construction, error wrapping | `AshCommanded.Aggregate.Runtime` — hand-written, plain module, unit-testable with no macro expansion involved |
| "What are this resource's commands/events/config" | `AshCommanded.Aggregate.Info` — reads persisted DSL state (see §5); this is what replaces the runtime `:erlang.++` reconstruction |
| Snapshot threshold/version logic | A third hand-written module (`AshCommanded.Aggregate.Snapshotting`, given LEARNINGS.md's finding that Commanded's real snapshotting is `Commanded.Snapshotting`, an internal, non-pluggable mechanism configured via a plain map — not a behaviour AshCommanded needs to satisfy per-aggregate at all) |
| Struct definition (`defstruct`, `@type t`) | Generated, same as today — this part of the old generator was never the problem |

---

## 3. Domain-aggregates-resources: the exact mechanism, with the compile-order answer

This is the highest-value section: it explains precisely why the old `GenerateCommandedApplication` /
`GenerateMainRouterModule` / `GenerateDomainRouterModule` fail, and gives an implementable fix backed
by Spark's own compile-time-dependency machinery — not a workaround, the INTENDED mechanism.

### Three real precedents, and they are not identical

**AshGraphql** (queries/mutations/subscriptions declared AT THE DOMAIN LEVEL): the domain-level
`queries`/`mutations` sections (`deps/ash_graphql/lib/domain/domain.ex:20-32`) reuse the SAME entity
definitions as the resource-level ones, but with `resource` prepended as an explicit DSL ARGUMENT,
typed `{:spark, Ash.Resource}` (`domain.ex:27-28`):

```elixir
schema: Keyword.put(&1.schema, :resource, type: {:spark, Ash.Resource}, doc: "...")
```

Every validating transformer that reads these back (`AshGraphql.Domain.Transformers.ValidateActions`,
`AshGraphql.Domain.Transformers.RequireKeysetForRelayQueries`,
`deps/ash_graphql/lib/domain/transformers/validate_actions.ex:12`,
`require_keyset_for_relay_queries.ex:12`) declares `def after_compile?, do: true`. This defers their
execution from ordinary compile-time (which runs `@extensions |> ... |> Enum.reject(& &1.after_compile?())`,
`deps/spark/lib/spark/dsl/extension.ex:698`) to Elixir's `@after_verify` hook
(`deps/spark/lib/spark/dsl.ex:457-474`), which fires only once ALL modules in the compilation unit
have finished generating bytecode — the built-in Elixir mechanism specifically designed to let a
module inspect ANOTHER module's exported functions without creating a hard compile-time dependency
(and therefore without risking a cycle). These transformers exist for VALIDATION (raising
`Spark.Error.DslError` if an action doesn't exist), not for building the artifact itself.

The actual SCHEMA ASSEMBLY (the domain-spanning artifact) happens in a completely different place: a
THIRD, hand-written module (`use AshGraphql, domains: [...]`, see §1) whose `__using__` runs when
THAT module compiles — ordinary Elixir file-compile order, forced explicit by
`Enum.each(ash_resources, &Code.ensure_compiled!/1)` (`ash_graphql.ex:168`). AshGraphql sidesteps the
domain-reads-resources compile-order problem for its primary artifact by NOT building it inside any
Ash.Domain/Ash.Resource transformer at all.

**AshJsonApi** (routes declared per-resource, domain only carries a `router:` option and top-level
`base_route`s): `AshJsonApi.Router.__using__/1` (`lib/ash_json_api/router.ex`, fetched from GitHub)
is written by the human, exactly like AshGraphql's schema module, and its `formatted_routes/1`
function walks `router.domains() |> Enum.flat_map(&Ash.Domain.Info.resources/1) |> Enum.flat_map(fn
resource -> AshJsonApi.Resource.Info.routes(resource) end)` — but crucially this function runs at
RUNTIME (called by `mix phx.routes` tooling and by `verified_route?/2`), not at compile time, and
actual HTTP dispatch is NOT compiled into per-route function clauses at all: `plug(:dispatch)` /
`match(_, to: AshJsonApi.Controllers.Router, init_opts: @opts)` forwards every request to one generic
controller that resolves domain/resource/route by inspecting the request path against
`Ash.Domain.Info.resources/1` + `AshJsonApi.Resource.Info.routes/1` on demand. AshJsonApi avoids the
domain-reads-resources compile-order problem entirely for routing: there IS no compile-time-generated
domain router artifact. `AshJsonApi.Domain.Transformers.SetBaseRoutes`
(`domain/transformers/set_base_routes.ex`) is the one domain-level transformer that DOES read
resource-adjacent state at ordinary (non-`after_compile?`) compile time — but note what it reads: it
flattens `AshJsonApi.Domain.Info.routes(dsl)`, i.e., entities declared ON THE DOMAIN'S OWN dsl_state
(`base_route`/`route` blocks), not another module's persisted state. It never needs to reach into a
resource module at transform time.

**AshOban** sidesteps the problem a third way: `domain` is a plain DSL OPTION persisted directly on
the SAME resource the trigger/scheduled_action is declared on
(`AshOban.Info.oban_domain!(dsl)` in `define_action_workers.ex:41` reads the CURRENT dsl, not a
cross-module one). There is no cross-resource aggregation step for AshOban's worker generation at all.

### The mechanism that actually resolves AshCommanded's problem

None of the three examples above needed to reach into ANOTHER module's persisted DSL state at
ordinary transform time — which is exactly what AshCommanded's router generation needs to do (combine
per-resource command→aggregate mappings into ONE domain-level Commanded router). The tool for that
case exists in Spark and Ash already uses it, just not where you'd read the generator names to expect:

**`Ash.Domain.Dsl`'s own `resources` section forces a genuine, asymmetric compile-time dependency.**
Read directly at `deps/ash/lib/ash/domain/dsl.ex:134-157`:

```elixir
@resource %Spark.Dsl.Entity{
  name: :resource,
  target: ResourceReference,
  args: [:resource],
  modules: [],
  schema: [
    resource: [type: {:spark, Ash.Resource}, required: true],
    ...
  ]
}
```

There is NO `no_depend_modules: [:resource]` override here. Contrast with
`deps/ash/lib/ash/resource/dsl.ex:1089`, the resource's OWN `code_interface` section, which declares
its `domain:` back-reference with `no_depend_modules: [:domain]` explicitly, specifically to avoid the
reverse edge (a resource that named its domain would otherwise force the domain to compile first,
creating exactly the cycle a naive reading might expect).

**What `type: {:spark, Ash.Resource}` without the opt-out actually does**, traced to
`deps/spark/lib/spark/dsl/extension/entity_option.ex:8-31` and
`deps/spark/lib/spark/dsl/extension.ex:1716-1728`: any DSL argument typed as a module is passed
through `Spark.Dsl.Extension.expand_alias/2`, which calls `Macro.expand` with a synthetic
`function: {:module_info, 0}` context on the `env` — the idiom that makes the Elixir compiler register
a genuine compile-time dependency edge on that module, the same class of edge an ordinary `alias
Foo, as: Bar; Bar.some_call()` would create. `expand_alias_no_require/2` (used when `no_depend_modules`
lists the field) walks the AST WITHOUT that trick, resolving aliases by hand — no dependency edge, no
forced ordering.

**The consequence, verified against real Ash source, not inferred:** because `resource Foo` inside a
domain's `resources do ... end` block is declared with a plain `{:spark, Ash.Resource}` type and no
opt-out, **`Foo` (and everything ITS OWN transformers produced via `Module.create/3` — command
modules, event modules, aggregate modules, persisted state) is guaranteed to be a fully compiled
module before ANY transformer belonging to the domain — core Ash or an extension like
`AshCommanded.Commanded.DomainDsl` — runs.** This forcing happens during entity/option construction,
which precedes ALL transformer execution for ALL extensions attached to the domain module (confirmed
at `deps/spark/lib/spark/dsl/extension.ex:672-702`: option validation happens, THEN
`transformers_to_run` is computed and executed). No `after_compile?: true` deferral is needed for this
case — `after_compile?` is for validating cross-module state that ISN'T guaranteed by a hard
dependency (AshGraphql's case, where the domain-level `resource:` argument type ALSO forces the
dependency, but the library still defers to `after_compile?` for its verifiers, likely out of an
abundance of caution / consistency with resource-level verifiers that share the same module. AshCommanded
does not need to copy that caution once the dependency is confirmed, though doing so anyway for
VERIFIERS — as opposed to the generating transformer — costs nothing and is good practice).

**Cross-module state is read back via `Spark.Dsl.Extension.get_persisted/3`, which works on a plain
module atom, not just a live dsl_state map** (`deps/spark/lib/spark/dsl/extension.ex:282-298`):

```elixir
def get_persisted(resource, key, default \\ nil)
def get_persisted(resource, key, default) when is_atom(resource), do: persisted!(resource, key, default)
```

...which bottoms out (`extension.ex:149-168`) in `resource.persisted(key, default)` — a genuine
cross-module function call to a function every compiled Spark DSL module exports. This is safe
PRECISELY BECAUSE of the dependency-forcing above: `resource` is already a loaded module with a
`persisted/2` function by the time the domain's transformer calls it.

### The concrete, implementable fix for AshCommanded's router

1. **Resource-level** (already-correct pattern, keep it): `GenerateCommandModules` /
   `GenerateEventModules` / the new aggregate generator run as ORDINARY resource transformers, and a
   PERSISTER (Spark's third phase — runs after all of that resource's own transformers, writes only to
   `dsl_state.persist`, per `deps/spark/lib/spark/dsl/transformer.ex:88-90`) stores a small, literal
   list under a resource-scoped key, e.g. `Transformer.persist(dsl, :ash_commanded_commands,
   [{CommandModule, EventModule, AggregateModule, opts}, ...])`.
2. **Domain-level, NEW**: `AshCommanded.Commanded.DomainDsl` attaches an ORDINARY transformer (no
   `after_compile?` needed) that:
   - Reads the domain's own resource list — either via `Ash.Domain.Info.resources(domain_module)` if
     called after the domain module is itself fully built, or, more idiomatically for a
     same-extension transformer, via `Transformer.get_entities(dsl_state, [:resources])` to read the
     `%Ash.Domain.Dsl.ResourceReference{}` list straight off the domain's own in-progress dsl_state
     (this is what `AshGraphql.Domain.Transformers.ValidateActions` effectively parallels by reading
     its OWN persisted entities, though those are domain-declared, not resource-declared).
   - For each resource module in that list, calls
     `Spark.Dsl.Extension.get_persisted(resource, :ash_commanded_commands, [])` — safe, per the
     dependency proof above.
   - Builds ONE consolidated list of `dispatch`/`identify` clauses and does
     `Module.create(RouterModuleName, quoted_router_body, Macro.Env.location(__ENV__))`, where
     `quoted_router_body` is `use Commanded.Commands.Router` followed by one `dispatch` call per
     collected command (mirroring the `AshOban.Transformers.DefineActionWorkers` precedent for
     `Module.create/3` usage, `define_action_workers.ex:60-90`).
   - Then a second, DEPENDENT domain transformer (ordered `after?` the router-builder — Spark's
     ordinary before?/after? sort, not `after_compile?`) creates the `Commanded.Application` module
     with `router: RouterModuleName` — because THAT module was just created in the SAME compile pass,
     by the domain's OWN transformer, ordering between the two is controlled by Spark's normal
     transformer sort, not by cross-file compile order at all.
3. **This is what was structurally wrong before**: per PROJECT.md's Falsified section, the old
   `GenerateDomainRouterModule`/`GenerateMainRouterModule` were attached to
   `AshCommanded.Commanded.Dsl` — the RESOURCE extension — so each one ran once per resource, in
   isolation, with `Transformer.get_persisted(dsl, :module)` resolving to that ONE resource, never
   able to see any other resource's commands, and never actually run as a true domain aggregation
   step. The fix is not a workaround for a Spark limitation; it is moving the router-building
   transformer to the extension it always should have been on (`DomainDsl`), where the resource-list
   dependency Ash already establishes makes the read-back safe by construction.

### Where the `after_compile?: true` mechanism SHOULD still be used in AshCommanded

For pure validation that legitimately can't lean on the entity-typed dependency (e.g., a verifier that
wants to double check a resource's command names haven't collided AFTER accounting for something only
knowable once a sibling extension's transformer has also run, on modules not reachable via a plain
`{:spark, Ash.Resource}`-typed argument) — follow `AshGraphql.Domain.Transformers.ValidateActions`'s
`def after_compile?, do: true` exactly. It costs nothing extra to mark a pure-validation domain
verifier this way defensively, and rewrite rule #5 ("prefer a verifier over a transformer when only
validating") already points AshCommanded at verifiers for this class of check.

---

## 4. Module naming and creation

**Derive names from real module references, never string surgery** (rewrite rule #4, and this is the
literal defect LEARNINGS.md §4 calls out — `generate_aggregate_module.ex:235` re-split and
re-concatenated a module name that was already correctly available at line 97 of the same file).
Every precedent read does this the same way — build a list of atoms/aliases and `Module.concat/1`:

- AshGraphql: `Module.concat([__MODULE__, domain, AshTypes])` (`ash_graphql.ex:202,398`) — schema
  module, the actual `domain` MODULE (not its name as a string), and a fixed literal suffix.
- AshOban: `module |> List.wrap() |> Enum.concat(["AshOban", "ActionWorker"]) |> Enum.concat([Macro.camelize(to_string(trigger.name))]) |> Module.concat()`
  (`define_action_workers.ex:33-38`) — note even here, where a STRING is unavoidably involved (the
  trigger's `:name` atom must become a CamelCase segment), the string operation
  (`Macro.camelize/1`) is applied to a single atom-derived segment, never to an already-fully-qualified
  module name being taken apart and reassembled.

**Registration for introspection is via `Transformer.persist/3` + a matching `.Info` reader**, not by
inventing a naming convention a caller must independently reconstruct. A resource that wants to know
"what router module did the domain build for me" should call
`AshCommanded.Commanded.DomainDsl.Info.router(domain)` (an `Extension.get_opt`/`get_persisted` read),
never re-derive the name via `Module.concat([domain, "Router"])` at the call site.

**For AshCommanded's aggregate/router/application generation, name derivation should follow the
AshGraphql/AshOban shape:** `Module.concat([resource_module, "Aggregate"])` for the resource-scoped
aggregate (or an explicit `aggregate_module:` DSL override, persisted and read back the same way), and
`Module.concat([domain_module, "Router"])` / `Module.concat([domain_module, "Application"])` for the
domain-scoped artifacts, each overridable via an explicit option in the same pattern
`AshOban.DefineActionWorkers` uses (`scheduled_action.worker_module_name || module_name(module,
scheduled_action)`, `define_action_workers.ex:19-20`) — compute a default, but always let an explicit
DSL option win.

---

## 5. The `.Info` convention

**What belongs in `.Info`:** every read of DSL-configured state that ANY other code (runtime, tests,
other extensions, other transformers on a different module) needs. This includes both raw option
reads (`Extension.get_opt/4`) and entity reads (`Extension.get_entities/2`), and — per rewrite rule #6
— it is the ONLY sanctioned way to reach into a DSL module's configuration from outside its own
transformer/verifier pipeline.

**AshGraphql's `.Info` modules are hand-written, not generated**, and split cleanly along the
Resource/Domain axis: `AshGraphql.Resource.Info` (`resource/info.ex`, 283 lines) and
`AshGraphql.Domain.Info` (`domain/info.ex`, 62 lines) each expose ONLY functions, no macros, each a
thin wrapper over `Spark.Dsl.Extension.get_opt/4` or `get_entities/2`, with defaults expressed as
function-call defaults (e.g. `def authorize?(domain), do: Extension.get_opt(domain, [:graphql],
:authorize?, true)`). Where a value can come from EITHER level (e.g. `queries/2` needs both the
resource's own `graphql do queries do ... end end` entities AND the domain's `queries do get Resource,
... end end` entities filtered down to that resource), `AshGraphql.Resource.Info.queries/2`
(`resource/info.ex:11-24`) explicitly calls `AshGraphql.Domain.Info.queries/1` and concatenates — the
`.Info` layer is where cross-level merging logic lives, not the transformers.

**`AshJsonApi.Domain.Info`** (fetched from GitHub, `lib/ash_json_api/domain/info.ex`) is even more
minimal — almost every function is a one-line `Extension.get_opt/4` call, confirming that for the
common case (a straight option passthrough with a default), hand-writing `.Info` functions is
reasonable, but `Spark.InfoGenerator` exists for exactly this and should be preferred where nothing
beyond passthrough is needed.

**`Spark.InfoGenerator`** (`deps/spark/lib/spark/info_generator.ex:1-45`) is the mechanical option:
`use Spark.InfoGenerator, extension: MyDsl, sections: [:my_section]` auto-derives config functions,
options functions and entity functions for every field/entity in the given sections. `Reactor.Info`
(`deps/reactor/lib/reactor/info.ex:9`) uses exactly this — `use Spark.InfoGenerator, sections:
[:reactor], extension: Reactor.Dsl` — and then hand-writes ONLY the one function that needs real
logic beyond passthrough (`to_struct/1`, which assembles the runtime `%Reactor{}` from the generated
entity accessors).

**Recommendation for AshCommanded:** `AshCommanded.Commanded.Dsl.Info` (resource-level) and
`AshCommanded.Commanded.DomainDsl.Info` (domain-level), split exactly like AshGraphql's
Resource/Domain split, each starting from `use Spark.InfoGenerator, extension: ..., sections: [...]`
for the mechanical accessors (`commands/1`, `events/1`, `projections/1`), with hand-written functions
layered on top ONLY for genuine cross-cutting logic: `AshCommanded.Aggregate.Info.command/2` (the
runtime lookup used in §2's `__using__` sketch) and a domain-level `router/1`/`application/1` that
returns the `Module.concat`-derived (or overridden) module name, mirroring
`AshJsonApi.Domain.Info.router/1`'s override-then-fallback shape. **Currently there is no `.Info`
module anywhere in `lib/commanded/` at all** (confirmed: `find lib -iname "*info*"` returns nothing) —
this is a complete gap against every precedent read, not a partial one, and should be treated as
foundational work alongside the renderer, not an afterthought bolted on per-component.

---

## 6. Testing generated code

**Three distinct, real techniques found, each suited to a different layer:**

1. **Direct unit-testing of a verifier/transformer as a plain function against a hand-built or
   mutated `dsl_state`** — bypassing compilation entirely. `AshGraphql.VerifyFieldReferencesTest`
   (GitHub, `test/verify_field_references_test.exs:1-70`) defines a small real resource, grabs its
   dsl_state via `BaseResource.spark_dsl_config()` (every compiled Spark DSL module exports this),
   mutates one option with `Spark.Dsl.Transformer.set_option(dsl, [:graphql], :show_fields, [...])`,
   and calls `VerifyFieldReferences.verify(dsl)` directly, asserting on the return value or wrapping
   it in `assert_raise Spark.Error.DslError, ~r/.../, fn -> ... end`. This works because
   `assert_raise` around a DIRECT function call is fine — LEARNINGS.md's "verifier errors are not
   catchable with `assert_raise`" caveat applies only to errors raised through the REAL `@after_verify`
   compile pipeline of an entire module, not to calling the verifier's `verify/1` as an ordinary
   function in a test.
2. **`Spark.Test`** (`deps/spark/lib/spark/test.ex`, current version — this project already
   identified it in LEARNINGS.md §4 as the fix for the `assert_raise` gap) — `assert_dsl_error/1,2`,
   `refute_dsl_errors/1`, via a per-process collector registered before the DSL module is DEFINED
   (typically inside the test itself via `defmodule` in a `do...end` block passed to
   `Spark.Test.dsl_errors/1`), for the case where you genuinely want to compile a MISCONFIGURED
   module and assert on the resulting DslError — i.e., true compile-time-rejection testing of the full
   pipeline, not just one verifier function.
3. **Golden-render / snapshot testing of GENERATED ARTIFACTS is a real, production practice in this
   ecosystem, not a novel idea AshCommanded is inventing** — `ash_postgres` ships
   `mix ash_postgres.generate_migrations` (`deps/ash_postgres/lib/migration_generator/migration_generator.ex`)
   which writes both a migration file AND a JSON "resource snapshot" (`priv/resource_snapshots/`) of
   the resource's compiled schema state, and subsequent runs DIFF against that snapshot to decide what
   changed — this is the same "render, commit, diff in CI" idea FOUND-07 (this project's `mix
   ash_commanded.dump`) already proposes, just for a different generated artifact (SQL migrations
   instead of Elixir AST). No SDL/schema snapshot test file was found in `ash_graphql`'s test suite
   specifically (test dir listing checked directly via GitHub API), so AshGraphql does NOT snapshot
   its Absinthe SDL output in CI — this is a place where AshCommanded's planned golden-render
   discipline is MORE rigorous than the most mature sibling library, not less; treat it as a genuine
   differentiator worth keeping, not over-engineering.

**Naming convention for compile-time-rejection tests**: `ash_graphql`'s test suite names these files
after the verifier they exercise — `verify_field_dependencies_test.exs`, `verify_field_references_test.exs`,
`verify_filter_handlers_test.exs`, `verify_reserved_type_name_test.exs` — a 1:1 file-to-verifier
mapping worth adopting directly, replacing the current
`test/commanded/verifiers/event_handler_tests.exs`-style grouping (which LEARNINGS.md's Context
section already flags as insufficient: "only checks that the verifier modules load").

---

## 7. Repo layout

**Consistent top-level shape across every current-generation Ash-project library inspected**
(`ash_graphql`, `ash_postgres`, `ash_authentication`, `reactor` — all four, checked directly via
`find <dep> -maxdepth 1 -type d`):

```text
lib/
documentation/       # guides, tutorials, topics — source for ExDoc + hex docs
usage-rules/         # per-topic usage-rules fragments (ash_graphql, ash_postgres; the
                      # `usage_rules` package AshCommanded's own PROJECT.md already plans to adopt)
usage-rules.md        # top-level entry point / index into usage-rules/
LICENSES/             # REUSE-spec SPDX license texts (every file carries an SPDX header)
CHANGELOG.md
```

**`lib/` internal shape — the Resource/Domain split, taken directly from `ash_graphql/lib/`:**

```text
lib/
  ash_graphql.ex                    # top-level __using__ (the schema-assembly front door, §1/§3)
  resource/
    resource.ex                     # AshGraphql.Resource — the resource-level Spark.Dsl.Extension
    info.ex                         # AshGraphql.Resource.Info
    mutation.ex, query.ex, subscription.ex, managed_relationship.ex   # entity target structs
    transformers/
      validate_actions.ex
      validate_compatible_names.ex
      require_keyset_for_relay_queries.ex
      subscription.ex
    verifiers/
      verify_actions_public.ex
      verify_field_references.ex
      verify_filterable_fields.ex
      ...
  domain/
    domain.ex                       # AshGraphql.Domain — the domain-level Spark.Dsl.Extension
    info.ex                         # AshGraphql.Domain.Info
    transformers/
      validate_actions.ex
      require_keyset_for_relay_queries.ex
    verifiers/
      verify_actions_public.ex
      verify_subscription_pubsub.ex
  graphql/                          # runtime machinery: resolver, error formatting, id translation
    resolver.ex
    errors.ex
    id_translator.ex
  subscription/                     # runtime machinery for the subscriptions feature specifically
    notifier.ex, runner.ex, batcher.ex, config.ex, endpoint.ex
```

The pattern generalizes cleanly: **top-level directory per DSL surface** (`resource/`, `domain/`),
each with its OWN `transformers/`, `verifiers/`, and `info.ex`; **separate top-level directories per
runtime concern** that isn't tied to compile-time DSL processing at all (`graphql/`, `subscription/`
are pure runtime — resolvers, error formatting — analogous to what `AshCommanded.Aggregate.Runtime`,
`AshCommanded.Commands.Dispatcher`-equivalent modules, and the middleware pipeline already are or
should become in AshCommanded).

**Reactor's layout** (non-Ash Spark DSL, confirms the pattern generalizes beyond Ash extensions):
`lib/reactor/dsl/` (entities + `Dsl.Build`), `lib/reactor/step/` (behaviour implementations —
`compose/`, `switch/`, `map/`, `recurse/`, `around/`, `group/`, `anon_fn/` — one directory per
built-in step KIND, each a plain runtime module implementing the `Reactor.Step` behaviour),
`lib/reactor/error/` (a full exception hierarchy — `invalid/`, `internal/`, `unknown/`, `validation/`),
`lib/reactor/builder/` (the programmatic, non-DSL construction API), `lib/reactor/info.ex` +
`lib/reactor/dsl/info.ex` (two `.Info` modules — one for the DSL entities themselves, one that builds
the runtime `%Reactor{}` struct from them via `Reactor.Info.to_struct/1`,
`deps/reactor/lib/reactor/info.ex:17-27`). **Reactor's most important structural lesson for
AshCommanded**: it demonstrates a Spark DSL need not generate ANY new modules via `Module.create/3`
at all — `use Reactor` just accumulates DSL entities, and `Reactor.run/2` calls
`Reactor.Info.to_struct(ReactorModule)` at RUNTIME to interpret those entities into an executable
struct on demand. This is not directly applicable to AshCommanded's aggregate (Commanded's process
model requires a real, named module it can `apply/2` against), but it IS the model for anything in
AshCommanded that does NOT strictly need a generated module — e.g., projection dispatch tables,
middleware ordering, or snapshot configuration could plausibly be "read via `.Info` at the point of
use" rather than "baked into a generated module," per rewrite rule #11 ("tricky AST transformation is
a smell").

### Recommended `lib/` layout for AshCommanded

Adapting the AshGraphql resource/domain split onto AshCommanded's actual DSL surfaces (commands,
events, projections, event_handlers on the resource; application on the domain — per the
already-in-flight `Dsl`/`DomainDsl` split noted in PROJECT.md):

```text
lib/
  ash_commanded.ex                       # top-level module, if any cross-cutting __using__ is needed
  ash_commanded/
    resource/
      dsl.ex                             # AshCommanded.Commanded.Dsl (renamed/kept as today)
      info.ex                            # AshCommanded.Commanded.Resource.Info — commands/2, events/2, projections/2
      entities/
        command.ex, event.ex, projection.ex, event_handler.ex   # target structs (today's command.ex/event.ex/projection.ex)
      sections/
        commands_section.ex, events_section.ex, ...             # unchanged
      transformers/
        generate_command_modules.ex
        generate_event_modules.ex
        generate_aggregate_module.ex      # rewritten per §2 — thin, delegates to Aggregate.__using__
        generate_projection_modules.ex
        generate_projector_modules.ex
        generate_event_handler_modules.ex
        persist_commanded_commands.ex     # NEW — the persister §3 depends on (resource → domain handoff)
      verifiers/
        validate_command_names.ex, validate_command_fields.ex, ...   # unchanged, kept as verifiers not transformers
    domain/
      dsl.ex                             # AshCommanded.Commanded.DomainDsl
      info.ex                            # AshCommanded.Commanded.Domain.Info — router/1, application/1
      transformers/
        generate_domain_router_module.ex  # rewritten per §3 — walks domain's own resource list, Module.create
        generate_commanded_application.ex # rewritten per §3 — ordered after the router transformer
      verifiers/
        validate_router_completeness.ex   # candidate NEW verifier, after_compile?: true per §3's guidance
    aggregate.ex                          # AshCommanded.Aggregate — the __using__ front door, §2
    aggregate/
      runtime.ex                          # AshCommanded.Aggregate.Runtime — hand-written, unit-tested directly
      info.ex                             # AshCommanded.Aggregate.Info — per-command config lookup
      snapshotting.ex                     # targets Commanded.Snapshotting per LEARNINGS.md §4, not the
                                           # nonexistent Snapshotter behaviour
    command_action_mapper.ex              # kept, this is genuine runtime machinery (already correctly separate)
    middleware/                           # kept as-is — already the right shape (hand-written runtime modules)
    error.ex                              # kept
mix/
  tasks/
    ash_commanded.dump.ex                 # FOUND-07, the renderer — foundation, lands before component work
documentation/                            # NEW, matches every sibling library — currently absent per
                                           # PROJECT.md's open item "mix.exs files: omits documentation/"
usage-rules/                              # NEW, matches ash_graphql/ash_postgres convention
```

**Rationale for the split, stated plainly:** the current flat `lib/commanded/transformers/` and
`lib/commanded/verifiers/` directories mix resource-scoped and (attempted, broken) domain-scoped
generators in the same namespace with no structural signal for which is which — which is plausibly
part of why `GenerateDomainRouterModule` ended up attached to the wrong extension in the first place
(PROJECT.md's Falsified section). Every mature sibling library encodes the resource/domain boundary in
the DIRECTORY STRUCTURE, not just in extension registration, making "which compile-time guarantees
apply to this transformer" legible from the file path alone.

---

## Sources

All sources are primary — real library source, read directly, not documentation:

- `work/core/deps/ash/lib/ash/domain/dsl.ex` (compile-dependency schema for `resource:`)
- `work/core/deps/ash/lib/ash/resource/dsl.ex` (contrasting `no_depend_modules: [:domain]`)
- `work/core/deps/ash_graphql/lib/{domain,resource}/{domain.ex,resource.ex,info.ex}`
- `work/core/deps/ash_graphql/lib/{domain,resource}/transformers/*.ex`, `verifiers/*.ex`
- `work/core/deps/ash_graphql/lib/ash_graphql.ex` (the schema-assembly `__using__`)
- `work/core/deps/ash_authentication/lib/ash_authentication/token_resource/transformer.ex`
- `work/core/deps/ash_postgres/lib/migration_generator/migration_generator.ex` and directory layout
- `work/core/deps/reactor/lib/reactor.ex`, `reactor/info.ex`, `reactor/builder.ex`, directory tree
- `work/core/deps/spark/lib/spark/dsl.ex`, `dsl/extension.ex`, `dsl/transformer.ex`,
  `dsl/extension/entity_option.ex`, `info_generator.ex`, `test.ex`
- `work/core/deps/commanded/lib/commanded/commands/router.ex`, `commanded/event/handler.ex`,
  `application.ex` (== AshCommanded's own vendored `deps/commanded`)
- `ash-project/ash_json_api` (GitHub, `main`): `lib/ash_json_api/domain/info.ex`,
  `lib/ash_json_api/domain/transformers/set_base_routes.ex`, `lib/ash_json_api/router.ex`
- `ash-project/ash_oban` (GitHub, `main`): `lib/transformers/define_action_workers.ex`
- `ash-project/ash_graphql` (GitHub, `main`): `test/verify_field_references_test.exs` (test file not
  shipped in the hex package / local `deps/`)
- This repo's own `.planning/evidence-generated-aggregate.txt` and `.planning/LEARNINGS.md` as the
  baseline the above is measured against

---
*Architecture research for: AshCommanded's code-generation rewrite (Spark/Ash extension design)*
*Researched: 2026-09-15*
