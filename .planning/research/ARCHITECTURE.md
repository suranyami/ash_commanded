# Architecture Research

**Domain:** Spark DSL extension for Ash Framework (CQRS / Event Sourcing via Commanded)
**Researched:** 2026-09-11
**Confidence:** HIGH — every claim below is verified against actual source: Spark 2.4.1 (`lib/spark/dsl/{extension,transformer,verifier,entity,section}.ex`, installed locally at `~/development/projects/kestrel/deps/spark`, API-compatible with the project's pinned `~> 2.3`/2.3.5), and real Ash extensions read directly from `deps/` in sibling projects: `ash` (3.x, from `work/core`), `ash_graphql`, `ash_oban`, `ash_state_machine`, `ash_events`, `ash_authentication`. No claim in this document is inferred from hexdocs prose alone without cross-checking the shipped `.ex` file.

## Standard Architecture

### System Overview — how a Spark/Ash extension actually compiles

```text
┌───────────────────────────────────────────────────────────────────────┐
│  User module: `use Ash.Resource, extensions: [AshCommanded.Dsl]`      │
│  or `use Ash.Domain, extensions: [AshCommanded.DomainDsl]`            │
│  Body: `commanded do ... end` block                                   │
└───────────────────────────┬─────────────────────────────────────────┘
                             │ Spark.Dsl.Extension.prepare/1 imports section
                             │ macros; each `command ... end` / `event ...`
                             │ block builds a struct via Entity schema
                             ▼
┌───────────────────────────────────────────────────────────────────────┐
│  DSL STATE  — a single plain map, keyed by section path               │
│  %{[:commanded, :commands] => %{entities: [%Command{}, ...]},         │
│    [:commanded, :application] => %{opts: [otp_app: ..., ...]},        │
│    persist: %{module: MyApp.User, ...}}                               │
│  This map is the *only* channel between all of the below stages.      │
└───────────────────────────┬─────────────────────────────────────────┘
                             │ Spark.Dsl.Transformer.sort/1 merges the
                             │ transformer lists of *every* extension on
                             │ this module (Ash core + AshCommanded + any
                             │ other extension) into one digraph, then
                             │ topologically sorts by before?/after?
                             ▼
┌───────────────────────────────────────────────────────────────────────┐
│  TRANSFORMERS  (run in the sorted, straight-line order, each          │
│  receiving the previous one's returned dsl_state)                     │
│  Collect* → Generate* (Module.create/2 side effects here) → persist   │
└───────────────────────────┬─────────────────────────────────────────┘
                             │ transform/1 returns {:ok, dsl_state} | :ok
                             │ | {:error, _} | :halt — errors abort compile
                             ▼
┌───────────────────────────────────────────────────────────────────────┐
│  VERIFIERS  (read-only; all run after all transformers; no ordering   │
│  guarantee between verifiers unless declared — treat as unordered)    │
└───────────────────────────┬─────────────────────────────────────────┘
                             │ module finishes compiling; dsl_state is
                             │ frozen and exposed as `resource.entities/1`,
                             │ `resource.opt/1` etc. (persisted functions)
                             ▼
┌───────────────────────────────────────────────────────────────────────┐
│  RUNTIME  — `Spark.Dsl.Extension.get_entities(ResourceAtom, path)`    │
│  now calls compiled functions on the module, not the map. Same API,   │
│  different implementation, selected by pattern-matching on the first │
│  argument (`%struct{}` / raw `map` / bare `atom`).                    │
└───────────────────────────────────────────────────────────────────────┘
```

Source for every claim in this diagram:

- `prepare/1` building imports from `extension.sections()`: `deps/spark/lib/spark/dsl/extension.ex:483-610`.
- Global transformer merge + sort: `deps/spark/lib/spark/dsl.ex:470-473` — `Enum.flat_map(& &1.transformers()) |> Spark.Dsl.Transformer.sort()`. **This is not resource-local** — it merges every extension applied to the module, including Ash's own core transformers, `AshPostgres`'s, etc.
- `run_transformers/4` straight-line reduce, one `transform/1` call per transformer, in the already-sorted order: `deps/spark/lib/spark/dsl/extension.ex:726-790`.
- `get_entities/2` dual dispatch (map vs. struct vs. atom): `deps/spark/lib/spark/dsl/extension.ex:242-263`.

([Spark.Dsl.Extension](https://hexdocs.pm/spark/Spark.Dsl.Extension.html), [Spark.Dsl.Transformer](https://hexdocs.pm/spark/Spark.Dsl.Transformer.html), [Spark.Dsl.Entity](https://hexdocs.pm/spark/Spark.Dsl.Entity.html), [Spark.Dsl.Section](https://hexdocs.pm/spark/Spark.Dsl.Section.html), [Spark.Dsl.Verifier](https://hexdocs.pm/spark/Spark.Dsl.Verifier.html))

### Component Responsibilities (Spark anatomy, answering Q1)

| Component | Responsibility | Typical Implementation |
| ----------- | ---------------- | ------------------------ |
| `Spark.Dsl.Section` | Declares a nestable named block (`commanded do commands do ... end end`); carries `schema` (option validation, via `Spark.Options`/NimbleOptions) and `entities` (sub-constructors) and `sections` (further nesting) | A module attribute `%Spark.Dsl.Section{name: :commands, schema: [...], entities: [@command]}` referenced from the extension's `sections:` list |
| `Spark.Dsl.Entity` | A DSL constructor that produces a struct instance (`command :foo do ... end` → `%Command{name: :foo, ...}`); validates its own `schema` at build time, supports `args` (positional), `auto_set_fields`, `transform` (post-build struct fixups), and recursive `entities:` for nesting (e.g. `route_to` nested inside `replay_override`, see `ash_events`) | `%Spark.Dsl.Entity{name: :command, target: Command, schema: CommandsSection.schema(), args: [:name]}` |
| `Spark.Dsl.Extension` | The `use`-able module that wires `sections:`, `transformers:`, `verifiers:` together and generates the macros/imports for the DSL. Also carries the full runtime introspection API (`get_entities/2`, `get_opt/4`, `get_persisted/3`) | `use Spark.Dsl.Extension, sections: [...], transformers: [...], verifiers: [...]` — exactly what `AshCommanded.Commanded.Dsl` already does |
| `Spark.Dsl.Transformer` | A compile-time step that reads and rewrites the whole `dsl_state` map; the only place with write access to DSL data and the only place code generation (`Module.create/3`) belongs | `use Spark.Dsl.Transformer`; implements `transform/1`, optionally `before?/1`, `after?/1`, `after_compile?/0` |
| `Spark.Dsl.Verifier` | A read-only compile-time check that returns `:ok`/`{:error, _}`/`{:warn, _}`; cannot mutate `dsl_state`, exists purely to reject invalid DSL usage with a good error message | `use Spark.Dsl.Verifier`; implements `verify/1` |
| `Spark.InfoGenerator` | Macro that auto-generates the boilerplate `Info` module (per-section option getters, per-section entity getters) from just `extension:` + `sections:` | `use Spark.InfoGenerator, extension: MyDsl, sections: [:commanded, :commands]` — **AshCommanded does not currently use this anywhere**; every info accessor (e.g. `AshCommanded.Commanded.Dsl.application/1`) is hand-written |

Section nesting is literal struct nesting: `@commanded_section` (top level) has `sections: [@commands_section, @events_section, @projections_section, @event_handlers_section, @application_section]` — this is exactly what `lib/commanded/dsl.ex` already does, and it is the correct, idiomatic shape (confirmed against `deps/spark/lib/spark/dsl/section.ex:1-142`, which documents nested `sections` and per-nesting-level `get_entities([:parent, :child])` paths).

**`get_entities/2`, compile time vs. runtime — the duality that matters for Q3:**

- **Compile time** (inside a transformer/verifier currently running for *this* module): `Spark.Dsl.Transformer.get_entities(dsl_state, path)` (or the `Spark.Dsl.Extension.get_entities/2` delegate, which pattern-matches to the same code when given a raw map) reads directly out of the in-progress map — no other module needs to be compiled. This is always safe.
- **Runtime, or compile time from a *different* module** (e.g., a domain transformer wanting a resource's DSL state): `Spark.Dsl.Extension.get_entities(ResourceAtom, path)` matches the `resource` clause at `extension.ex:254-263`, which calls `resource.entities(path)` — a real function call on a real module. **This requires `ResourceAtom` to already be compiled.** If it isn't (e.g., it's compiling in parallel, or there's a genuine cycle), this either raises `UndefinedFunctionError`, blocks the compiler, or (with `Code.ensure_compiled/1`-guarded call sites) silently returns `{:error, :unavailable}`. There is no dynamic "wait for it" semantics — Elixir's parallel compiler decides serialization order from *lexical* references (aliases, `Code.ensure_compiled!/1`), not from Spark's cooperation.

## Recommended Project Structure

This is not a generic web-app layer split — it is the actual shape the library should converge on, derived from where the current code already diverges from that shape (`GenerateAggregateModule`, `CommandActionMapper`) and from how comparable Ash extensions are organized.

```text
lib/commanded/
├── dsl.ex                          # Ash.Resource extension: sections + transformer/verifier lists only
├── domain_dsl.ex                   # Ash.Domain extension: sections + transformer/verifier lists only
├── info.ex                         # NEW — `use Spark.InfoGenerator` for the Resource extension
├── domain_info.ex                  # NEW — `use Spark.InfoGenerator` for the Domain extension
├── sections/                       # schema + entity declarations only (no logic)
├── command.ex / event.ex / ...     # entity target structs (pure data)
├── transformers/
│   ├── generate_command_modules.ex
│   ├── generate_event_modules.ex
│   ├── generate_aggregate_module.ex       # orchestrator only: after?/2 + transform/1 + Module.create call
│   ├── aggregate/                          # NEW — AST-builder helpers, one concern each, unit-testable
│   │   ├── struct_builder.ex               #   moduledoc + defstruct + module skeleton
│   │   ├── execute_clause_builder.ex        #   command → event AST (was 360 of the 861 lines)
│   │   ├── apply_clause_builder.ex          #   event → state AST
│   │   └── snapshot_clause_builder.ex       #   snapshot_state/2, restore/2 etc. (was 215 lines)
│   ├── generate_projector_modules.ex
│   ├── generate_domain_router_module.ex
│   ├── generate_main_router_module.ex
│   └── generate_commanded_application.ex   # domain-only; reads resources via Ash.Domain.Info.resources/1
├── verifiers/
├── action_mapping/                 # NEW — split out of the 640-line CommandActionMapper
│   ├── command_action_mapper.ex    #   orchestrator: map_to_action/4, infer_action_type/1
│   ├── executors/                  #   one module per Ash action type, common behaviour
│   │   ├── create.ex
│   │   ├── update.ex
│   │   ├── destroy.ex
│   │   ├── read.ex
│   │   └── custom.ex
│   └── (transactional_map_to_action/3 moves into lib/commanded/transaction.ex — it already owns
│         transaction concerns and CommandActionMapper should not duplicate that responsibility)
├── parameter_transformer.ex        # absorbs transform_params/2, safely_transform_params/2,
│                                    # safely_apply_advanced_transforms/2 currently duplicated
│                                    # inside command_action_mapper.ex
├── middleware/
└── snapshot*.ex
```

### Structure Rationale

- **`transformers/aggregate/` and `action_mapping/executors/`:** both existing 800+/600+ line files already have clean internal seams — they are single files containing 4-5 functions that don't share state beyond the DSL data passed as arguments. Splitting along those existing function boundaries (see "Component Boundaries" decomposition below) costs nothing in behavior and everything in reviewability; this is a pure refactor, not a redesign.
- **`info.ex` / `domain_info.ex` via `Spark.InfoGenerator`:** every comparable extension surveyed (`ash_events`, and Ash core itself) generates its `Info` module this way (`deps/ash_events/lib/event_log/event_log.ex:152-157`: `use Spark.InfoGenerator, extension: AshEvents.EventLog, sections: [:event_log, :replay_overrides]`). AshCommanded hand-writes accessors like `AshCommanded.Commanded.Dsl.application/1` instead — this is boilerplate the framework already eliminates.
- **Transaction logic staying in one module:** `CommandActionMapper.transactional_map_to_action/3` exists alongside a dedicated `AshCommanded.Commanded.Transaction` module — that is duplicated ownership of one concern (transaction boundaries) and should be resolved by deletion, not addition.

## Architectural Patterns

### Pattern 1: Total-order transformer list, backed by explicit `before?/after?` pairwise declarations (Q2)

**What:** Spark's actual ordering algorithm (`deps/spark/lib/spark/dsl/transformer.ex:305-380`, `sort/1`) builds a `:digraph`, adds an edge `left → right` whenever `left.before?(right)` or `right.after?(left)` is true, then topologically walks it. Crucially, **this merge happens across every extension applied to the same module**, not just within AshCommanded's own list (`deps/spark/lib/spark/dsl.ex:470-473`: `extensions |> Enum.flat_map(& &1.transformers()) |> Transformer.sort()`). If a resource has both `AshCommanded.Dsl` and, say, `AshPostgres.DataLayer` or a future extension applied, all of their transformers land in one digraph together.

**When to use:** every transformer that reads data another transformer writes (which, in a codegen pipeline, is nearly all of them) must declare its dependency explicitly via `after?/1` — never rely on the transformer's position in the `transformers:` list of `use Spark.Dsl.Extension`.

**Trade-offs:** explicit `after?/before?` is more boilerplate per transformer, but it is the only mechanism that survives (a) reordering the list, (b) another extension being added to the same resource, (c) a future contributor adding a transformer in the "wrong" list position.

**Failure modes, verified from the sort algorithm itself:**

1. **Silent tie-break by original list position, not an error.** `walk_rest/3` (`transformer.ex:351-379`) first looks for a vertex with no in-edges (a valid "ready to run" transformer); if none exists (every remaining transformer has *something* depending on it, i.e. a true cycle among 3+ nodes), it falls back to picking whichever vertex has the smallest index in the *original, unsorted* transformer list and force-removes it from the graph. **A genuine ordering cycle across ≥3 transformers does not raise a compile error — it silently resolves to an order controlled by an accident of list position**, which can then produce a working build today and a subtly-wrong one after an unrelated file is reordered. This is the sharpest failure mode to guard against with tests, not just declarations.
2. **Contradictory pairwise declarations are explicitly tolerated, not rejected.** If `A.before?(B)` and `A.after?(B)` are both true (or, symmetrically, `B` claims both about `A`), the algorithm's `cond do left_before_right? && left_after_right? -> :ok` branch (`transformer.ex:325-327`) just does nothing — no edge, no error, no warning. The comment in the source calls this out directly: *"some modules have `def after?(_), do: true` … Same with `def before?(_), do: true"* — i.e. a common but sloppy pattern (declare "I go after everything, unless it also explicitly goes after me") that Spark deliberately allows to no-op rather than reject.
3. **Errors from `transform/1` itself abort the whole compile with a raised `Spark.Error.DslError`, attributed to the calling module** (`extension.ex:726-741`) — this is well-behaved and not a hazard, but means a transformer that raises instead of returning `{:error, _}` loses the nice `DslError` formatting.

**Current-codebase evidence this is already a live risk, not theoretical (grep of every `before?/after?` in `lib/commanded/transformers/*.ex`):**

- `CollectParameterTransforms.after?/1` and `CollectParameterValidations.after?/1` both declare `after?(AshCommanded.Commanded.Transformers.ExtractCommands), do: true` — **`ExtractCommands` does not exist anywhere in the codebase and is not in the `transformers:` list in `dsl.ex`.** This `after?` clause is dead: since `ExtractCommands` is never in the sorted set, the edge is never added, and these two transformers' *actual* ordering is determined purely by list position in `dsl.ex` (they happen to already be listed first, so this has not yet caused a bug — but it is exactly the fragile-by-accident state Pattern 1 warns against).
- Only 7 of the 13 registered transformers declare any `before?/after?` at all (`GenerateCommandModules`, `GenerateEventModules`, `GenerateAggregateModule`, `GenerateEventHandlerModules`, `GenerateProjectionModules`, `GenerateProjectorModules`, `GenerateDomainRouterModule`, `GenerateMainRouterModule`, `GenerateCommandedApplication` — the last only declares `after?(GenerateMainRouterModule)`, nothing about the resource-level transformers it actually depends on). `CollectTransactionOptions` declares neither.
- The existing `lib/commanded/transformers/transformer_order.md` (read as required reading) already identifies this gap in 2024-era notes ("As we add more transformers, we should consider these dependencies…") but the plan was never carried out for most transformers.

**Convention this project should adopt for its 13+ transformers:** don't hand-declare a sparse pairwise graph — declare a single canonical stage list once (e.g. in a shared `AshCommanded.Commanded.Transformers.Order` module: `@order [CollectParameterTransforms, CollectParameterValidations, CollectTransactionOptions, GenerateCommandModules, GenerateEventModules, GenerateProjectionModules, GenerateProjectorModules, GenerateEventHandlerModules, GenerateAggregateModule, GenerateDomainRouterModule, GenerateMainRouterModule]`) and generate every transformer's `after?/1` from "everything earlier in `@order`" via a shared `use` macro, rather than writing 13 bespoke `after?` bodies by hand. This turns "sparse, easy to leave stale" into "total order, mechanically derived," and directly fixes the dead `ExtractCommands` reference by construction (it can't reference a name that isn't in the canonical list).

### Pattern 2: Resource-owns-its-DSL, Domain-reads-downward-only (Q3)

**What:** the correct shape for the Resource/Domain split already underway on `fix-application-generation` is a strict one-directional dependency: **Domain transformers may read Resource DSL state; Resource transformers must never read Domain DSL state.** This is not a stylistic preference — it is what keeps the compile graph acyclic.

- **Safe direction, verified:** `Ash.Domain.Info.resources/1` (`deps/ash/lib/ash/domain/info.ex:16-19`) is `Extension.get_entities([:resources]) |> Enum.map(& &1.resource)` — reading the *domain's own* already-parsed `resources do resource Foo end` entities. This is a compile-time-safe, zero-risk read because it never leaves the current module's `dsl_state` map. Historically Ash needed `Ash.Domain.Info.depend_on_resources/1` (a macro that force-`Code.ensure_compiled!/1`'d every listed resource) to make this safe to *combine with a subsequent per-resource call*; that macro is now `@deprecated "... This macro is no longer necessary"` (`deps/ash/lib/ash/domain/info.ex:187-189`) because Ash's `resource Foo` entity parsing itself now establishes `Foo` as a compile-time dependency of the domain (via alias expansion / `Spark.Dsl.Extension.expand_alias`), so by the time a domain transformer runs, every resource named in its `resources do end` block is guaranteed already compiled.
- **What that licenses AshCommanded to do:** `GenerateCommandedApplication` (a domain transformer) may safely call `Ash.Domain.Info.resources(dsl_state)` to enumerate resource atoms, and then, for each one, call `Spark.Dsl.Extension.get_entities(resource_atom, [:commanded, :events])` / `[:commanded, :commands]` etc. — this is the correct way to auto-discover projectors/events across a domain's resources (directly addressing the open TODO at `generate_commanded_application.ex:115`). It works *because* the compile-order edge (resource before domain) already exists for free through Ash's own `resources` section.
- **What must never happen:** a **Resource**-level AshCommanded transformer (anything registered in `dsl.ex`, not `domain_dsl.ex`) must never call `Ash.Domain.Info` functions, or `AshCommanded.Commanded.DomainDsl.Info` functions, against its own domain during its own compilation. Doing so creates the reverse edge (resource needs domain compiled) on top of the edge that already exists (domain needs resource compiled) — a genuine cycle. Concretely: today, `AshCommanded.Commanded.Dsl.application/1` (in `dsl.ex`) reads `[:commanded, :application]` off of *whatever module's* `dsl_state` is passed to it — as long as resource-level generated code (e.g. inside `GenerateAggregateModule` or `GenerateDomainRouterModule`) only ever calls this function with its **own** `dsl_state` (which is what "resource declares nothing about the domain except the bare atom `domain: MyApp.Domain`" implies), there is no cycle today. This constraint should be written down (in `AGENTS.md`/module docs) as an explicit rule, because it is easy to violate accidentally once someone wants "the resource's generated router to know the domain's event store module" and reaches for `Ash.Resource.Info.domain(resource) |> AshCommanded.Commanded.DomainDsl.Info.event_store()` inside a *resource* transformer.
- **A more defensive alternative some Ash extensions choose instead:** `AshGraphql` does not put its cross-resource aggregation inside a `Domain` transformer at all. It has domain-level DSL entities for GraphQL-specific config, but the actual schema assembly (`AshGraphql.schemas/0`, `AshGraphql.Codegen`) runs in a **third, separately-compiled module** that the user writes explicitly (`use AshGraphql, domains: [MyApp.Domain1, MyApp.Domain2]` inside their own `MyApp.Schema` module, which by definition compiles after both domains and resources) — see `deps/ash_graphql/lib/ash_graphql.ex:131`, `resource/resource.ex:4247`, `domain/verifiers/verify_subscription_pubsub.ex:46`, all of which call `Ash.Domain.Info.resources/1` from *outside* any Domain-DSL transformer. This sidesteps the domain-transformer-reaches-into-resources hazard entirely by pushing the aggregation to a point in compilation guaranteed to be after everything else. **AshCommanded's `GenerateCommandedApplication` doing this work inside the domain's own transformer pipeline is more fragile than AshGraphQL's approach**, even though it currently works — it is worth at minimum a compile-order integration test (a domain + several resources compiled together, asserting the generated `Application`/router modules see every resource's projectors) to catch regressions, and worth considering, if the auto-discovery TODO proves troublesome, moving it to an explicit "assemble after everything" step analogous to AshGraphQL's pattern.

### Pattern 3: Codegen only where the *runtime* library needs a named module implementing a real behaviour (Q4)

**What, with the actual trade-off argued rather than asserted:**

Two strategies exist in the wild for "the DSL should produce code":

1. **`quote` + `Module.create/3` at compile time** (what AshCommanded already does, and what `AshOban` does for exactly the same reason).
2. **Source-file generation via Igniter/Sourceror**, writing real `.ex` files to disk that the user then owns/edits/commits.

**Evidence for which the Ash ecosystem actually uses for *this* kind of problem:**

- `AshOban.Transformers.DefineActionWorkers` (`deps/ash_oban/lib/transformers/define_action_workers.ex:35-75`) does exactly what `GenerateAggregateModule` does: builds a module name from the resource + trigger name, then `Module.create(worker_module_name, quote do use Oban.Worker, ...; def perform(...) do ... end end, ...)`. The reason is structural, not stylistic: **`Oban.Worker` and `Commanded.Aggregate`/`Commanded.Commands.Router` are behaviours owned by a *different* runtime library, which dispatches to modules by name and expects them to export specific callbacks (`perform/1`, `execute/2`, `apply/2`).** There is no way to satisfy "Commanded calls `MyApp.UserAggregate.execute/2`" without a real, named, compiled module existing — an anonymous function or a data structure cannot stand in for it. Codegen here isn't a style choice, it's a hard requirement imposed by the library being integrated.
- `AshStateMachine` (`deps/ash_state_machine/lib/`, all 16 files checked — **zero occurrences of `Module.create`**) takes the opposite approach for a different reason: state-machine behavior is expressed entirely through **existing Ash extension points** (`Ash.Resource.Change`, `Ash.Resource.Validation` modules provided by the library, parameterized at runtime by reading the DSL via `AshStateMachine.Info` — no new module needs to exist per resource, because Ash's own action pipeline is the "runtime dispatcher," and it already accepts data-configured changes/validations. No codegen is needed because nothing *external* to Ash requires a named module.
- `AshGraphql` also generates **no modules per resource**. Types are registered as data inside the single, user-written `Absinthe.Schema` module via macros expanded at that module's own compile time (`object`, `field`, etc., called from inside `use AshGraphql`'s expansion) — again because Absinthe's own compile-time macros are the dispatch mechanism, and one already-compiling module can absorb arbitrarily many type definitions without needing N separate modules.

**The actual trade-off, argued:**

| | `quote` + `Module.create/3` (compile time) | Igniter/Sourceror-generated source files |
| --- | --- | --- |
| Satisfies "Commanded needs a real named module with `execute/2`/`apply/2`" | Yes, directly — `Module.create/3` produces exactly this | Also yes, but only *after* the user runs a generator step and the file is compiled normally |
| Debuggability / stack traces | `location: :keep` (used in both AshCommanded's and AshOban's generators) makes stack traces point at the **DSL declaration site** (the `commanded do ... end` block), not a synthetic file — this is usually *better* for the DSL author's own errors, but worse when the bug is in the *generated logic itself*, since there's no real file to open and set a breakpoint in | Stack traces point at a real file on disk the user can open, edit, and set breakpoints in directly |
| Dialyzer | Generated modules exist as real `.beam` files at the same point in the pipeline either way — Dialyzer sees both identically once compiled. No difference here, contrary to a common assumption. | Same |
| ExDoc / `@moduledoc`/`@doc` | Fully supported — both `AshCommanded.GenerateAggregateModule` and `AshOban`'s worker generator `unquote` real `@moduledoc`/`@doc` strings built from DSL data (verified: `generate_aggregate_module.ex:210` sets `@moduledoc unquote(moduledoc)`) | Also fully supported, no difference |
| Developer inspection before compiling | None — the user cannot see the generated code without adding tooling (`IEx.Helpers.` introspection, or a debug flag that prints the quoted AST) | The user can `git diff` the generated file before/after a DSL change |
| Keeping generated code in sync with DSL edits | Automatic — recompiling the resource regenerates the module; no drift is possible | Requires the user to re-run the generator and reconcile; drift (stale generated file vs. current DSL) is a real, reported failure mode of Igniter-based codegen in other ecosystems |
| Appropriate when... | The generated artifact is *pure derived data* the user should never hand-edit (this describes 100% of what AshCommanded currently generates: command/event structs, aggregate execute/apply clauses, routers) | The generated artifact is a *starting point* the user is expected to customize afterward (an Igniter installer scaffolding a new resource file, a mix task like `ash_authentication.add_strategy` — not the recurring, DSL-driven regeneration this library needs) |

**Recommendation, with the "why":** keep `quote` + `Module.create/3` as the code-generation strategy for everything Commanded needs as a real dispatchable module (commands, events, aggregates, routers, the `Commanded.Application`) — this matches both what AshCommanded already does and the closest real precedent (`AshOban`), and is justified because Commanded, like Oban, requires named modules implementing its own behaviours. Reserve Igniter/Sourceror for what the project already lists as separate scope: **installer tasks** (`mix ash_commanded.install`, analogous to `ash_authentication.add_strategy` at `deps/ash_authentication/lib/mix/tasks/ash_authentication.add_strategy.ex`) that scaffold a *starting* resource file for a human to edit — never for the recurring aggregate/router/event generation itself. Do not introduce Igniter-based generation for the DSL-driven modules; it would be strictly worse on every axis in the table above for artifacts the user is never meant to hand-edit.

### Pattern 4: Escape hatches as typed schema options, not ad hoc `case`/`is_function` checks (Q5)

**What, with concrete source references:**

Spark's option validator (`Spark.Options`, `deps/spark/lib/spark/options/options.ex`) has first-class types built exactly for "let the user drop into hand-written code":

- **`{:behaviour, SomeBehaviour}`** (`options.ex:226`) — validates that the given value is a module implementing `SomeBehaviour`. Used by `AshEvents.EventLog`'s `event_log` section for `clear_records_for_replay: [type: {:behaviour, AshEvents.ClearRecordsForReplay}]` and `advisory_lock_key_generator: [type: {:behaviour, AshEvents.AdvisoryLockKeyGenerator}, default: AshEvents.AdvisoryLockKeyGenerator.Default]` (`deps/ash_events/lib/event_log/event_log.ex:98-109`) — note the pattern of **shipping a sensible default implementation module alongside the behaviour**, so the escape hatch only needs to be reached for when the default is wrong.
- **`{:spark_behaviour, Behaviour}`** (`options.ex:218`, validated at `options.ex:1406-1438`) — like `{:behaviour, _}` but additionally accepts `{module, opts}` tuples (`validate_type({:spark_behaviour, module}, key, {module, opts})`), i.e. "a module, optionally parameterized with its own options at the DSL call site." This is the idiomatic shape for AshCommanded's existing pluggable snapshot adapter (`snapshot_store`) and would also be the correct type for a pluggable middleware entry, rather than accepting a bare atom and hand-validating it.
- **`{:spark_function_behaviour, Behaviour, {FunctionWrapperModule, arity}}`** (`options.ex:222`) — accepts *either* a module implementing `Behaviour`, *or* a bare anonymous function of the given arity, which Spark auto-wraps into a synthetic module implementing `Behaviour` on the caller's behalf via `FunctionWrapperModule`. This is the exact, already-half-implemented shape of AshCommanded's `projection :x do changes(fn event -> ... end) end` and `event_handlers`' `action fn event, _metadata -> ... end` — currently these are validated ad hoc rather than through this Spark primitive, meaning they get none of the automatic elixir_sense/autocomplete support Spark provides for real uses of this type.

**Concrete pattern to adopt:** every DSL option in AshCommanded that currently accepts "a function OR a module" via hand-rolled `is_function/is_atom` branching (projection `changes`, event handler `action`, command `param_mapping`, middleware entries, snapshot adapter) should be re-typed through `{:spark_behaviour, _}` or `{:spark_function_behaviour, _, _}` in its `schema/0`. This is not a new capability — it changes *where* the escape-hatch validation logic lives, from bespoke code scattered across `Projection`, `EventHandler`, `CommandActionMapper`, and `ParameterTransformer`, to one declarative line in each entity's schema, gaining consistent error messages and doc generation for free.

## Data Flow

### Compile-time flow (DSL → generated modules)

```text
User's `commanded do ... end` block
    ↓ (Entity.build/struct construction, immediate, per-entity validation only)
dsl_state map: [:commanded, :commands] → [%Command{}, ...], etc.
    ↓ (Collect* transformers — pure reads + `persist/3` writes; no codegen)
CollectParameterTransforms / CollectParameterValidations / CollectTransactionOptions
    ↓ (Generate* transformers — reads dsl_state, calls Module.create/3 as a *side effect*,
    ↓  then persists e.g. the generated module name back into dsl_state for the next stage)
GenerateCommandModules → GenerateEventModules → GenerateProjectionModules →
GenerateProjectorModules → GenerateEventHandlerModules → GenerateAggregateModule →
GenerateDomainRouterModule → GenerateMainRouterModule → GenerateCommandedApplication
    ↓ (Verifiers — read-only, no dsl_state mutation, all run after the last transformer)
ValidateCommandFields / ValidateCommandNames / ValidateEventFields / ... (9 total)
    ↓
Resource/Domain module finishes compiling; generated modules exist as real .beam files
```

**Direction is one-way and append-only within a single resource's compilation:** every transformer only ever reads what an earlier transformer wrote into the same `dsl_state` map (via `persist/3` or `add_entity/replace_entity`) — there is no "later transformer changes earlier transformer's output" pattern anywhere in Spark, by construction (`transform/1` always receives and returns the *whole* map, threaded through `Enum.reduce_while`).

**Cross-module direction (the Domain/Resource split, Q3) is strictly downward:** Domain transformers may read Resource dsl_state (via the compiled-module form of `get_entities/2`, after Ash's own `resources do resource Foo end` parsing has already forced compile ordering); Resource transformers must never read Domain dsl_state. See Pattern 2 above for the concrete hazard if this is violated.

### Runtime flow (command dispatch)

```text
Command struct built by user code
    ↓
Router.dispatch/1  (generated by GenerateDomainRouterModule / GenerateMainRouterModule)
    ↓
Middleware chain (CommandMiddlewareProcessor → user-declared middleware, in declared order)
    ↓
CommandActionMapper.map_to_action/4
    ↓ (param transform via ParameterTransformer, validation via ParameterValidator)
Ash action execution (optionally wrapped by Transaction)
    ↓
{:ok, record} or {:error, Error.t()}
```

This runtime path is orthogonal to the compile-time flow above — it only depends on the *generated modules*, not on `dsl_state`, which no longer exists at runtime except through the persisted `entities/1`/`opt/1` accessor functions.

## Component Boundaries — decomposition of the two oversized modules (Q6)

### `GenerateAggregateModule` (861 lines → orchestrator + 4 focused builders)

Reading the file's actual function boundaries (`lib/commanded/transformers/generate_aggregate_module.ex`), the seams already exist as private functions; they are simply not yet separate modules:

| Current function | Lines (approx.) | Proposed home |
| --- | --- | --- |
| `transform/1`, `after?/1` | 82-153 | Stays in `GenerateAggregateModule` (the transformer itself — this is the only part that needs to be a `Spark.Dsl.Transformer`) |
| `build_aggregate_module_ast/…` (moduledoc, `defstruct`, module skeleton assembly) | 161-232 | `AshCommanded.Commanded.Transformers.Aggregate.StructBuilder` — pure function: `(resource_name, fields, moduledoc) -> quoted_ast` |
| `generate_execute_functions/4` | 232-590 (**~360 lines, 40%+ of the file**) | `AshCommanded.Commanded.Transformers.Aggregate.ExecuteClauseBuilder` — pure function: `(commands, events, command_modules, event_modules) -> [quoted_clause]`; this is the single highest-value split since it's the largest, most independently testable unit |
| `generate_apply_functions/2` | 591-646 | `AshCommanded.Commanded.Transformers.Aggregate.ApplyClauseBuilder` |
| `generate_snapshot_functions/1` | 647-861 (**~215 lines, another 25%**) | `AshCommanded.Commanded.Transformers.Aggregate.SnapshotClauseBuilder` — this is a genuinely separate *feature* (snapshotting) bolted onto the aggregate generator; splitting it also makes it trivial to skip entirely when `snapshotting: false`, rather than generating and then discarding dead clauses |

Each builder module becomes a pure `data -> Macro.t()` function with no `Spark.Dsl.Transformer` behaviour of its own — meaning each is unit-testable with plain ExUnit assertions on the returned AST (`assert {:def, _, _} = ...` or `Macro.to_string/1` snapshot comparisons) without needing to compile a fake resource through the whole Spark pipeline. This directly serves the PROJECT.md gap "tests largely assert that transformers ran rather than that DSL misuse is rejected" — small pure builders are what make true unit tests of the *generated code shape* possible.

### `CommandActionMapper` (640 lines → orchestrator + executor family + merge into existing modules)

| Current function | Lines (approx.) | Proposed home |
| --- | --- | --- |
| `map_to_action/4`, `execute_action_internal/…`, `infer_action_type/1` | 94-357 | Stays as the `CommandActionMapper` orchestrator — this is the actual public API surface |
| `transactional_map_to_action/3` | 304-333 | **Delete from here; merge into `AshCommanded.Commanded.Transaction`**, which already exists and already owns "wrap command execution in a transaction." Two modules currently share this one responsibility. |
| `transform_params/2` (4 clauses), `safely_transform_params/2`, `safely_apply_advanced_transforms/2`, `safely_apply_preprocessor/3`, `safely_apply_postprocessor/3` | 358-434 | **Merge into `AshCommanded.Commanded.ParameterTransformer`**, which already exists (`lib/commanded/parameter_transformer.ex`) and already owns "transform command fields to action params." This is duplicated ownership, not a new boundary. |
| `execute_create/4`, `execute_update/5`, `execute_destroy/4`, `execute_read/5`, `execute_custom/4` | 471-640 (**~170 lines, one function per Ash action type**) | `AshCommanded.Commanded.ActionExecutors.{Create,Update,Destroy,Read,Custom}` — five small modules behind a shared `AshCommanded.Commanded.ActionExecutor` behaviour (`@callback execute(resource, action_name, params, context) :: {:ok, record} or {:error, Error.t()}`). This is also the natural point to expose a`{:spark_behaviour, ActionExecutor}` escape hatch (Pattern 4) for a command that needs an execution strategy the library doesn't special-case. |

After this split, `command_action_mapper.ex` shrinks from 640 lines spanning five concerns to roughly 150-200 lines doing exactly one thing (map a command to the right executor and invoke it), matching the project's own 200-400-line target.

## Suggested Build Order Implications

Sequencing that follows from everything above, for the roadmap:

1. **Land the total-order transformer convention (Pattern 1) before anything else touches `transformers/`.** Every subsequent phase (event versioning, aggregate invariants, projector auto-discovery) adds *more* transformers; retrofitting ordering discipline onto 20 transformers is much more expensive than establishing it now onto 13, and the dead `ExtractCommands` reference should be deleted or resolved as part of this same pass since it's a pre-existing correctness gap, not new work.
2. **Land the Domain/Resource one-directional-read rule (Pattern 2) as part of finishing `fix-application-generation`**, before the projector auto-discovery TODO (`generate_commanded_application.ex:115`) is implemented — auto-discovery is precisely the feature that will tempt a reach across the resource/domain boundary, so the rule needs to exist first, ideally enforced by a verifier that rejects any resource-level transformer calling `Ash.Domain.Info`/`DomainDsl.Info` functions, or at minimum documented in `AGENTS.md` before that code is written.
3. **Decompose `GenerateAggregateModule` and `CommandActionMapper` (Q6) before adding aggregate invariants/non-attribute state or declarative event upcasting** — both of those Active requirements extend exactly the two files that are already oversized (aggregate invariants add more `execute_clause` logic; event upcasting adds logic that belongs in `GenerateEventModules`/`ExecuteClauseBuilder`-adjacent code). Splitting first means new logic lands in a 100-200 line focused module instead of growing the existing 861/640-line files further.
4. **Adopt `Spark.InfoGenerator` and the `{:spark_behaviour, _}}`/`{:spark_function_behaviour, _, _}` escape-hatch types (Patterns 4) opportunistically, module by module, without a dedicated phase** — these are low-risk, additive, mechanical changes (replace hand-written `Info` accessors; retype existing "function or module" options) that can ride along with whichever phase happens to touch each module, but should be done before the documented testing story and `usage_rules`/`AGENTS.md` work, since both of those need to describe the *final* escape-hatch shape, not the current ad hoc one.
5. **Documentation generation (Q7) is a trailing, not leading, concern** — `mix spark.cheat_sheets --extensions AshCommanded.Commanded.Dsl` (the current `mix.exs` alias, `mix.exs:168`) **already omits `AshCommanded.Commanded.DomainDsl`** and will keep doing so silently until the alias is updated; this should be fixed in the same phase that lands the Domain/Resource split (item 2), not deferred to the documentation-reconciliation phase, since otherwise the domain-level `application` section will have zero generated cheat-sheet coverage for however many phases pass in between.

## Documentation Generation for Humans and Agents (Q7)

- **Cheat sheets** (`mix spark.cheat_sheets`, `deps/spark/lib/mix/tasks/spark.cheat_sheets.ex`) are generated *per extension module*, driven purely from `Section`/`Entity` `describe`/`schema`/`examples` metadata already present in the DSL declaration — meaning better cheat sheets are a side effect of writing better `describe:`/`examples:` fields on the existing sections, not separate documentation work. AshCommanded's `mix.exs` already wires `"gen.docs": ["spark.cheat_sheets", "docs"]` and includes the one cheat sheet file it currently generates as an ExDoc `extras:` entry (`mix.exs:84,104`) — the mechanism is sound; it just needs the second extension added once `DomainDsl` exists as its own module, and the `--extensions` flag updated to `AshCommanded.Commanded.Dsl,AshCommanded.Commanded.DomainDsl`.
- **`usage_rules`** (the dev-only dependency already used by `core`, `~> 1.2`, per `work/core/mix.exs:84`) generates an `usage-rules.md` + `usage-rules/` directory of LLM-oriented, terse "how to use this library correctly" facts distinct from human-facing ExDoc prose — this is the mechanism the PROJECT.md Active list already earmarks ("Add `usage_rules` (dev-only) and generate LLM-facing usage rules for the library"). It is additive to, not a replacement for, cheat sheets: cheat sheets document DSL *syntax*, usage rules document *conventions and gotchas* (e.g., "never call Domain.Info from a resource transformer," "declare `after?` explicitly rather than relying on list order" — i.e., exactly the two hazards this document identifies as needing to be written down before they're forgotten).
- **`AGENTS.md`** (also an Active PROJECT.md item) is where the transformer-ordering convention (Pattern 1) and the Domain/Resource read-direction rule (Pattern 2) belong as explicit, standing rules for future contributors and coding agents — these are exactly the two rules in this document most likely to be silently violated by someone (human or agent) adding the next transformer without reading the full history.

## Anti-Patterns

### Anti-Pattern 1: Relying on `transformers:` list order instead of `before?/after?`

**What people do:** add a new transformer to the end of the `transformers:` list in `dsl.ex`/`domain_dsl.ex` and trust that Spark preserves that order.
**Why it's wrong:** Spark *does* preserve original list order, but only as the tie-break of last resort inside `walk_rest/3`, and only within transformers that have no declared relationship to each other. The moment another extension's transformers get merged into the same digraph (Pattern 1), or a genuine 3-way ordering cycle exists among *this* library's own transformers, list position stops being a reliable signal — and the failure is silent, not a compile error.
**Do this instead:** every transformer that reads state another transformer writes declares `after?/1` for that specific dependency (or, per the recommended convention, generates it mechanically from one shared ordered list).

### Anti-Pattern 2: A resource-level transformer or verifier reaching into its own domain's DSL state at compile time

**What people do:** inside a resource-level transformer (or the code it generates at compile time — not runtime), call something equivalent to `Ash.Resource.Info.domain(dsl_state) |> AshCommanded.Commanded.DomainDsl.Info.event_store()` to "know" domain-level configuration while generating resource-level code.
**Why it's wrong:** this is the reverse of the only safe direction (Pattern 2) — Domain-reads-Resource is safe because Ash's own `resources do resource Foo end` parsing already forces `Foo` to compile before its domain; there is no equivalent mechanism forcing a Domain to compile before its Resources, so the resource transformer would be calling `Extension.get_entities(domain_atom, path)` on a module that is, at best, not yet compiled, and at worst mid-compilation on another module in a genuine cycle with this one.
**Do this instead:** resource-level generated code that needs domain-level facts (event store module, application module name) should resolve them **at runtime** via `Ash.Resource.Info.domain(resource)` (which only needs the domain *atom*, not its compiled DSL state) followed by a plain, static naming convention (e.g. `Module.concat([domain, "Application"])`) rather than a compile-time DSL introspection call — exactly mirroring how the existing generated routers already reference `<DomainPrefix>.Router`/`<AppPrefix>.Router` by convention rather than by reading domain DSL state from inside resource compilation.

### Anti-Pattern 3: Growing `GenerateAggregateModule`/`CommandActionMapper` further instead of splitting first

**What people do:** add aggregate invariants, non-attribute state, or event upcasting logic as more clauses inside the existing 861-line `generate_execute_functions/4` or more branches inside the existing 640-line `CommandActionMapper`.
**Why it's wrong:** both files already mix 4-5 independently-testable concerns in one module (Q6); adding more logic to the biggest existing function in each file compounds the exact debt PROJECT.md already flags, and makes the eventual split strictly harder (more entangled state, more call sites to update at once).
**Do this instead:** split first (see Component Boundaries above), then add new logic to the newly-focused module it actually belongs to (aggregate invariants → `ExecuteClauseBuilder`; event upcasting → likely a new `GenerateEventModules`-adjacent concern, not `GenerateAggregateModule` at all).

## Integration Points

### External Libraries

| Library | Integration Pattern | Notes |
| --------- | --------------------- | ------- |
| Commanded 1.4.8 | Generated modules (`Aggregate`, `Router`, `Application`) implement Commanded's own behaviours/macros directly — Commanded is the reason codegen (Pattern 3) is required at all | Version-pinned; any Commanded API change to `execute/2`/`apply/2` shapes ripples into `ExecuteClauseBuilder`/`ApplyClauseBuilder` |
| Ash 3.x | AshCommanded's resource extension is *one of potentially several* extensions on the same `Ash.Resource` — its transformers are merged into Ash's own global sort (Pattern 1); generated code calls Ash actions via `Ash.Changeset`/`Ash.create`/etc. | Never assume AshCommanded's transformers are the only ones running against a given resource |
| Spark 2.3.x/2.4.x | The entire DSL/transformer/verifier/entity mechanism | Locally verified against Spark 2.4.1; API used (`Extension`, `Transformer`, `Verifier`, `Entity`, `Section`, `InfoGenerator`, `Options` types) is stable across 2.3.x–2.4.x |

### Internal Boundaries

| Boundary | Communication | Notes |
| ---------- | --------------- | ------- |
| Resource DSL ↔ Domain DSL | One-directional: Domain transformers read Resource `dsl_state` via `Ash.Domain.Info.resources/1` + `Spark.Dsl.Extension.get_entities/2`; never the reverse (Pattern 2, Anti-Pattern 2) | This is the single most important boundary in the whole library and the one most likely to be violated by a future contributor solving "the resource needs to know its domain's event store" |
| Transformers ↔ Verifiers | Transformers run first and may mutate `dsl_state`; verifiers run after all transformers, are read-only, and have no defined ordering relative to each other unless declared | Don't put correctness-affecting logic in verifier order; verifiers should be independent of each other |
| `CommandActionMapper` ↔ `ParameterTransformer` / `Transaction` | Currently overlapping (duplicated `transform_params`/`transactional_map_to_action` logic); should become strictly "CommandActionMapper delegates to, never duplicates, these two modules" (Component Boundaries, Q6) | Fix as part of the decomposition, not a separate effort |

## Sources

- [Spark.Dsl.Extension](https://hexdocs.pm/spark/Spark.Dsl.Extension.html) — verified against local source `deps/spark/lib/spark/dsl/extension.ex` (Spark 2.4.1, API-compatible with pinned 2.3.5)
- [Spark.Dsl.Transformer](https://hexdocs.pm/spark/Spark.Dsl.Transformer.html) — verified against `deps/spark/lib/spark/dsl/transformer.ex`, including the `sort/1`/`walk_rest/3` ordering algorithm read line-by-line
- [Spark.Dsl.Verifier](https://hexdocs.pm/spark/Spark.Dsl.Verifier.html) — verified against `deps/spark/lib/spark/dsl/verifier.ex`
- [Spark.Dsl.Entity](https://hexdocs.pm/spark/Spark.Dsl.Entity.html) — verified against `deps/spark/lib/spark/dsl/entity.ex`
- [Spark.Dsl.Section](https://hexdocs.pm/spark/Spark.Dsl.Section.html) — verified against `deps/spark/lib/spark/dsl/section.ex`
- Spark.InfoGenerator, Spark.Options escape-hatch types (`{:behaviour, _}`, `{:spark_behaviour, _}`, `{:spark_function_behaviour, _, _}`) — verified against `deps/spark/lib/spark/info_generator.ex` and `deps/spark/lib/spark/options/options.ex`
- `Ash.Domain.Info` (`resources/1`, `resource_references/1`, deprecated `depend_on_resources/1`) — verified against `deps/ash/lib/ash/domain/info.ex` (Ash 3.x, from `work/core/deps/ash`)
- `AshOban.Transformers.DefineActionWorkers` — real `Module.create/3` + Commanded-analogous behaviour-satisfying codegen, `deps/ash_oban` (from `projects/lemonade_stand/deps/ash_oban`)
- `AshStateMachine` — a real Ash extension with **zero** `Module.create` usage, confirming codegen is a choice driven by external-library requirements, not a default (`deps/ash_state_machine`, from `projects/lemonade_stand`)
- `AshEvents.EventLog` — `{:behaviour, _}` escape-hatch schema types with shipped defaults, `Spark.InfoGenerator` usage, nested entity example (`deps/ash_events`, from `projects/lemonade_stand`)
- `AshGraphql` — domain-resource aggregation deliberately pushed to a third, later-compiled module rather than a Domain transformer; SDL file generation via `__after_compile__`, not Igniter (`deps/ash_graphql`, from `work/core/deps/ash_graphql`)
- `AshAuthentication` — strategy modules and the `mix ash_authentication.add_strategy` installer task as the precedent for where Igniter-style scaffolding *does* belong (`deps/ash_authentication`, from `work/core/deps/ash_authentication`)
- This repository's own `lib/commanded/dsl.ex`, `lib/commanded/transformers/*.ex`, `lib/commanded/command_action_mapper.ex`, `lib/commanded/transformers/transformer_order.md`, `mix.exs`, `.planning/codebase/ARCHITECTURE.md`, `.planning/codebase/STRUCTURE.md`, `.planning/PROJECT.md` — read directly, current as of 2026-09-11

---
*Architecture research for: Spark DSL / Ash Framework CQRS-ES extension (`ash_commanded`)*
*Researched: 2026-09-11*
