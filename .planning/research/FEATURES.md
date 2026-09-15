# Spark DSL Reference for the AshCommanded Rewrite

**Scope:** What Spark itself provides an extension author, and the idiomatic use of each
capability. Not product features — this is an API reference for implementers of the v0.3
generation-layer rewrite.

**Researched:** 2026-09-15
**Confidence:** HIGH — every claim below is read directly from the vendored source at
`deps/spark` (hex `2.7.2`) and `deps/ash` (hex `3.5.8`) inside this repo's own `mix.lock`,
not recalled from training data or blog posts. Line numbers are cited so a reviewer can
re-open the same file.

---

## 0. Version correction — read this first

`CLAUDE.md` and the research brief both say "Spark 2.3.5." **That is stale.** `mix.lock`
resolves `spark` to **2.7.2**, and `.planning/LEARNINGS.md` §4 already recorded why: a
locked decision (D-14) was made against 2.3.5, then the same phase's own dependency bump
(REPO-03) moved the project to 2.7.2, invalidating it mid-phase. `mix.exs` itself declares
`{:spark, "~> 2.6"}`. Every API surface in this document is 2.7.2 as actually installed —
if you see 2.3.5-era blog posts or the old CLAUDE.md prose disagree with this document,
this document (and the source it cites) wins.

`Ash.Domain.Info.depend_on_resources/1` is a second, smaller version trap: it is
`@deprecated "Use Ash.Domain.Info.resources/1 instead. This macro is no longer necessary"`
(`deps/ash/lib/ash/domain/info.ex:172-174`). Older Ash/Ash-extension blog posts that tell
you to wrap domain-resource access in `depend_on_resources/1` to force a compile-time
dependency are describing a workaround Ash itself no longer needs or recommends.

---

## 1. Entities and Sections

### `Spark.Dsl.Entity` — full field list

Source: `deps/spark/lib/spark/dsl/entity.ex:70-91` (`@fields`).

| Field | Type | Purpose |
| --- | --- | --- |
| `name` | `atom` | The DSL keyword the user types, e.g. `command :register_user do`. |
| `target` | `module` | The struct this entity builds. Must have a field for every schema key, every `entities` key, and every `auto_set_fields` key. |
| `schema` | `Spark.Options.schema()` | Validated keyword-list options for the entity body. See §2. |
| `args` | `[atom \| {:optional, atom} \| {:optional, atom, default}]` | Turns schema keys into **positional** arguments, e.g. `command :register_user, :create` instead of `command :register_user do action :create end`. Order in the list is call order. |
| `entities` | `keyword(Entity.t())` | Nested entity definitions, keyed by the field name on the target struct that holds them. This is how `commands do command ... end` nests under a section, and how a `command` could itself nest a `field` sub-entity. |
| `singleton_entity_keys` | `[atom]` | Any key named here (must also be a key in `entities`) is validated to have **at most one** value and is unwrapped from `[x]` to `x` (or `nil`) automatically — no verifier needed for "only one X allowed here." |
| `identifier` | `term()` or `{:auto, :unique_integer}` | Declares the entity unique by this field. **This is what turns on automatic duplicate-detection — see §6, this is not optional boilerplate you write yourself.** |
| `transform` | `{module, function, args}` | Runs immediately after the struct is built, before nested/`auto_set_fields` merge settles. Returns `{:ok, new_entity}` or `{:error, reason}` — can both mutate and validate. Cannot see anything outside the entity itself (no dsl_state, no sibling entities); reach for a transformer if you need cross-entity data. |
| `auto_set_fields` | `keyword(any)` | Sets literal values onto the built struct without requiring them in `schema` or in user-supplied opts. Good for e.g. always stamping `autogenerate_handler?: true` unless overridden. |
| `describe` / `examples` / `snippet` / `docs` | `String.t()` / `[String.t()]` | Feeds `mix docs` and `spark.cheat_sheets` generation (§7). `docs` is internal/computed — don't set it yourself, `Spark.Dsl.Extension.set_docs/1` does. |
| `deprecations` | `keyword(String.t())` | Per-field deprecation messages, surfaced as compile warnings when that field is used. |
| `imports` / `modules` / `no_depend_modules` | various | `imports` are auto-imported inside the entity's `do` block; `modules`/`no_depend_modules` affect ElixirSense autocomplete and (for `no_depend_modules`) suppress compile-time dependency tracking for a field that holds a module reference you don't want to force-compile. |
| `recursive_as` | `atom \| nil` | Lets an entity nest inside copies of itself under a different key name (e.g. a `group` entity containing more `group`s). |
| `hide` / `links` | doc-only | Hide a field from generated docs; attach external doc links. |

**Building an entity by hand** (used inside a transformer, not by DSL users):

```elixir
{:ok, command} =
  Spark.Dsl.Transformer.build_entity(
    AshCommanded.Commanded.Dsl,
    [:commands],
    :command,
    name: :register_user,
    fields: [:id, :email]
  )

dsl_state = Spark.Dsl.Transformer.add_entity(dsl_state, [:commands], command)
```

This runs the entity's own `schema` validation and `transform` callback — it is not a
raw `struct/2` call, so a transformer that synthesizes entities (e.g. an
auto-derived `:mark_inactive` command from a resource action) gets the same
validation a hand-written DSL usage gets.

### `Spark.Dsl.Section` — full field list

Source: `deps/spark/lib/spark/dsl/section.ex:33-52`.

Sections are the `commands do ... end` / `events do ... end` blocks. Same core idea as
Entity minus `target`/`args`/`transform`/`identifier` (a section doesn't build a struct —
its entities and options are read back via `get_entities/2`/`get_opt/3`). Distinct fields
worth calling out:

| Field | Purpose |
| --- | --- |
| `top_level?` | If `true`, the section's DSL can be written with no wrapping block at all — directly in the module body. **This is how a domain-level `application` block that feels like a top-level concept (one per domain) could be exposed without an extra layer of nesting**, though AshCommanded currently nests it (`commanded do application do ... end end`) — a legitimate simplification to consider if the nesting reads as noise. |
| `singleton_entity_keys` | Same semantics as Entity's field, applied at the section level — e.g. ensuring only one `application` entity exists under a domain's `commanded` section, again with zero custom verifier code (see §6). |
| `patchable?` | Allows other extensions to inject entities into this section via `Spark.Dsl.Patch.AddEntity` (dsl_patches) — relevant only if AshCommanded wants to let other libraries extend its sections; not needed for this rewrite. |
| `sections` | Nested sub-sections (a section inside a section), distinct from `entities` (entity structs inside a section). |

### What Spark removes that authors commonly hand-write

- **Duplicate-name checking** for any entity with `identifier` set (§6) — do not write
  `ValidateCommandNames`/`ValidateEventNames` by hand; set `identifier: :name` on the
  Entity struct.
- **"At most one of these" checking** via `singleton_entity_keys` on the Section or
  Entity — do not write a verifier that counts entities.
- **Schema/option validation, coercion and defaulting** (§2) — do not hand-roll
  `is_atom(opts[:action]) or raise`.
- **Doc generation** for every section/entity/option, driven by `describe`, `examples`,
  and schema `:doc` — do not hand-write a "DSL reference" doc; generate it (§7).
- **The `ModuleName.Info` accessor boilerplate** — `use Spark.InfoGenerator` (§5)
  generates `commands/1`, `command/2`, `commands_options/1` etc. for free from the
  section list; do not write `def commands(resource), do: Spark.Dsl.Extension.get_entities(resource, [:commands])` by hand for every section.

---

## 2. Schema and option types — `Spark.Options`

Source: `deps/spark/lib/spark/options/options.ex`. This is Spark's own fork of
`NimbleOptions` (moduledoc, lines 116-122), not a wrapper around it — do not look for a
`NimbleOptions` dependency, there isn't one.

### Per-option keys (the schema-of-a-schema)

Every entry in an entity/section `schema` keyword list is itself validated against this
shape (`@options_schema`, lines 6-111):

| Key | Type | Notes |
| --- | --- | --- |
| `type` | see type vocabulary below | Defaults to `:any`. |
| `required` | `boolean` | Default `false`. |
| `default` | `any` | **Validated against `:type` at schema-compile time** — `type: :integer, default: "x"` is itself a schema error, not a runtime surprise. |
| `keys` | nested schema | Only meaningful for `:keyword_list`/`:non_empty_keyword_list`/`:map` — describes the shape inside. |
| `deprecated` | `String.t()` | Warns when the option is passed at all. |
| `doc` | `String.t() \| false` | `false` hides it from generated docs entirely (useful for internal-only options). |
| `type_doc` | `String.t() \| false` | Override the auto-derived type documentation string. |
| `type_spec` | quoted term | Override the auto-derived `@spec` fragment — needed for `{:custom, ...}` types, whose inferred spec is otherwise just `term()`. |
| `as` | `atom` | Remaps the DSL-facing name to a different struct field name. |
| `snippet` / `links` / `subsection` / `hide` / `private?` | doc/autocomplete only | |

### Type vocabulary (full list, `deps/spark/lib/spark/options/options.ex:143-297`)

Basic scalars: `:any`, `:atom`, `:string`, `:boolean`, `:integer`, `:non_neg_integer`,
`:pos_integer`, `:float`, `:number`, `:timeout`, `:pid`, `:reference`, `nil`, `:mfa`,
`:mod_arg`, `:regex`, `:regex_as_mfa`, `:module`, `:struct`, `:literal`, `:quoted`.

Containers: `:keyword_list`, `:non_empty_keyword_list`, `{:keyword_list, schema}`,
`{:non_empty_keyword_list, schema}`, `:map`, `{:map, key_type, value_type}`.

Combinators — **the ones that remove the most hand-rolled validation code**:

- `{:or, [subtypes]}` — tries each subtype in order; first match (with its coercion)
  wins. Example: `type: {:or, [:string, :boolean, {:fun, 2}]}`.
- `{:and, [subtypes]}` — all must match, applied in sequence so an earlier subtype's
  coercion feeds the next.
- `{:list, subtype}` — homogeneous list, each element validated/coerced by `subtype`.
- `{:tuple, [subtypes]}` — fixed-arity tuple, position-by-position.
- `{:in, choices}` / `{:one_of, choices}` — membership in a list or `Range`.
- `{:tagged_tuple, tag, inner_type}` — matches `{tag, value}`.
- `{:wrap_list, type}` — accept either a bare value or a list of them, always returns a
  list. Useful for `fields([:id, :email])` vs. a hypothetical `fields(:id)` single form.

Function-shaped options:

- `:fun` — any arity.
- `{:fun, arity}` / `{:fun, arg_types}` / `{:fun, arg_types, return_type}`.
- `{:function, arity: n, args: [...], returns: type}` — **preferred over the 3-tuple
  `{:fun, args, return}` form** per the moduledoc (line 208-212): it's a 2-tuple, so it
  nests cleanly inside `{:or, [...]}` etc. without AST-escaping edge cases the 3-tuple
  form can hit.
- `{:mfa_or_fun, arity}` — accepts either an anonymous function of that arity or an
  `{mod, fun, args}` tuple.

Module/behaviour-shaped options — **read the caveat below, it is easy to get wrong**:

- `{:behaviour, module}` — accepts a bare atom.
- `{:spark_behaviour, module}` — accepts an atom, or `{module, opts}`, normalizing a
  bare atom to `{atom, []}`.
- `{:spark_behaviour, module, builtin_module}` — same, plus a builtin-templates module
  for ElixirSense.
- `{:spark_function_behaviour, module, {function_mod, arity}}` — accepts a module atom,
  `{module, opts}`, **or a bare anonymous function/MFA of `arity`** — Spark
  auto-generates a small wrapper module implementing `function_mod`'s behaviour that
  calls the supplied function. This is the exact mechanism Ash uses for
  `changes [{Change, opts}]` also accepting an anonymous function — reach for it if
  `projections do projection :x do changes(fn event -> ... end) end end` needs to keep
  accepting either a module or a lambda.
- `{:protocol, protocol}` / `{:impl, protocol}` — the only two module/behaviour types
  that are **actually checked at validation time** (`protocol.impl_for!/1` /
  `Protocol.assert_impl!/2`, lines 1453-1487).

  **Caveat, verified by reading `validate_type/3` directly (lines 1417-1512):**
  `{:behaviour, module}`, `{:spark_behaviour, ...}` and `{:spark_function_behaviour, ...}`
  do **not** verify the supplied atom actually implements the named behaviour — the
  runtime clause is just `is_atom(value) and not is_boolean(value) -> {:ok, value}`. The
  behaviour name in the type is documentation and ElixirSense metadata, not an
  enforcement mechanism. **If AshCommanded needs "this module must implement
  `AshCommanded.Middleware`" enforced, that check has to be written explicitly** — the
  idiomatic place is a verifier calling `Spark.implements_behaviour?(module, Behaviour)`
  (`deps/spark/lib/spark.ex:38-66`), not the schema type.

- `{:custom, mod, fun, args}` — escape hatch: `mod.fun(value, ...args)` must return
  `{:ok, coerced_value}` or `{:error, message}`.

### Compile-time schema validation

`Spark.Options.new!/1` validates a schema once and returns a compiled struct; assigning
it to a module attribute (`@options_schema Spark.Options.new!([...])`) does that
validation **at compile time** rather than on every call to `validate/2` — worth using
for any schema referenced from a hot runtime path (e.g. a per-command validation schema
checked on every dispatch), not just DSL-time schemas.

### `Spark.Options.Validator` — a candidate for "generated command structs carry no

validation independent of middleware" (PROJECT.md known debt)

```elixir
defmodule MyApp.Commands.RegisterUser.Options do
  use Spark.Options.Validator,
    schema: [
      id: [type: :string, required: true],
      email: [type: :string, required: true]
    ]
end

MyApp.Commands.RegisterUser.Options.validate!(id: "1", email: "a@b.com")
# => %MyApp.Commands.RegisterUser.Options{id: "1", email: "a@b.com"}
```

This generates a struct type with a `validate/1`/`validate!/1` that is independent of
Commanded middleware entirely — it validates a keyword list against `Spark.Options`
types and produces a struct. It is designed for **function options**, not domain
entities, so field types come from the `Spark.Options` vocabulary (§2) rather than Ash
attribute types (`:string`, not `Ash.Type.String`) — a real mismatch if command fields
need Ash-attribute-level validation (e.g. `Ash.Type.CiString`, constraints). Flag this
as "available, partial fit" rather than "the answer" — worth a design decision, not an
assumption.

---

## 3. Transformers — `Spark.Dsl.Transformer`

Source: `deps/spark/lib/spark/dsl/transformer.ex`.

### Callbacks

```elixir
@callback transform(map) ::
  :ok | {:ok, map} | {:error, term} | {:warn, map, warning | [warning]} | :halt
@callback before?(module) :: boolean
@callback after?(module) :: boolean
@callback after_compile?() :: boolean
```

`use Spark.Dsl.Transformer` defaults all three predicates to `false` and makes them
`defoverridable`. You only implement `transform/1` in the common case.

### Ordering

`before?/1` and `after?/1` build a dependency graph (`Spark.Dsl.Transformer.sort/1`,
`transformer.ex:400-474`, a topological sort via `:digraph`). Declare **only** the
relationships that matter (`def after?(GenerateEventModules), do: true` inside
`GenerateCommandModules` isn't needed — a command generator doesn't depend on events);
over-declaring order creates coincidental coupling that the sort has to reconcile. A
transformer that must run after *everything else in the extension* can implement
`after?(_), do: true` for every other module, which the sort explicitly tolerates as "go
last" rather than a cycle (comment at line 417-421).

### Reading helpers

| Function | Signature | Notes |
| --- | --- | --- |
| `get_entities/2` | `(dsl_state, path) :: [entity]` | Missing path → `[]`, never `nil`. |
| `get_option/4` | `(dsl_state, path, option, default \\ nil)` | |
| `fetch_option/3` | `(dsl_state, path, option) :: {:ok, v} \| :error` | |
| `get_persisted/3` | `(dsl_state, key, default \\ nil)` | Reads the `:persist` map — see §6, this is the one function that also works on an already-compiled *module atom* via `Spark.Dsl.Extension.get_persisted/3`, not just a dsl_state map. |
| `fetch_persisted/2` | `(dsl_state, key) :: {:ok, v} \| :error` | |
| `get_section_anno/2`, `get_opt_anno/3` | source-location annotations | For pointing `Spark.Error.DslError` at the right line. |

### Writing helpers

| Function | Signature | Notes |
| --- | --- | --- |
| `add_entity/4` | `(dsl_state, path, entity, opts \\ [])` | Prepends by default; `type: :append` to append. |
| `replace_entity/4` | `(dsl_state, path, replacement, matcher \\ nil)` | Default matcher compares `__struct__` + `__identifier__`. |
| `remove_entity/3` | `(dsl_state, path, filter_fun)` | `filter_fun` returns `true` for entities to drop. |
| `set_option/4` | `(dsl_state, path, option, value)` | |
| `persist/3` | `(dsl_state, key, value)` | Writes into `:persist` — the ONLY channel `get_persisted` reads. |
| `build_entity/4` / `build_entity!/4` | `(extension, path, name, opts)` | Runs the entity's real schema validation + `transform`, not `struct/2`. Use this, not manual struct construction, whenever a transformer synthesizes an entity (e.g. an implicit command derived from a `create` action). |
| `eval/3` | `(dsl_state, bindings, quoted_block)` | Injects code **into the same module being compiled** (the resource/domain itself), not a new module. "Use extremely sparingly" (moduledoc, line 108) — prefer `Info` module functions or `persist/3`. Real use case: making the DSL module itself expose a convenience function like `resource.primary_key/0`. |
| `async_compile/2` | `(dsl_state, fun)` | Registers `fun` to run on a `Task`/`Kernel.ParallelCompiler.async`, tracked so `Spark.Dsl.Extension.await_tasks/1` waits for it before the module finishes compiling. Use for generating a module whose creation is independent of other generated modules, to parallelize compilation — not required for correctness, only for build speed. |

### Transformers vs. Persisters vs. Verifiers — the documented pipeline

From the extension moduledoc (`extension.ex:87-105`), the actual compile-time order is:

1. **Transformers** — during compilation, `before?`/`after?` ordered, full read/write
   access to dsl_state.
2. **Persisters** — same `use Spark.Dsl.Transformer` behaviour, declared under
   `persisters:` instead of `transformers:`, always run after **all** transformers
   regardless of any `before?`/`after?` targeting a transformer module (only ordering
   *among persisters* is honored). Convention: only call `persist/3`, never
   `add_entity`/`replace_entity`. AshCommanded currently has no persisters — this is a
   clean separation to adopt: transformers compute and shape, a persister is the single
   place that writes the final cached values (`:commands`, `:events`, etc.) that
   `Info` and other modules will read.
3. **Verifiers** — after compilation, read-only. See §4.

### `after_compile?/0` — the mechanism for §6's cross-module problem

A transformer with `after_compile?() -> true` is **excluded** from the normal
in-compilation transformer run and deferred to run inside the module's `@after_verify`
hook, *after* all of that module's own verifiers have passed with no errors. Verified
directly in `deps/spark/lib/spark/dsl.ex:470-474` (exclusion from the early pass) and
`deps/spark/lib/spark/dsl/extension.ex:693-699` (same exclusion, `set_state/3`) paired
with `deps/spark/lib/spark/dsl.ex:521-529` (the deferred run, gated on
`final_errors == []`, inside `__verify_spark_dsl__/1`). This is the answer to §6 — read
it there for the full mechanics and the concrete fix for AshCommanded's router
generation.

---

## 4. Verifiers — `Spark.Dsl.Verifier`

Source: `deps/spark/lib/spark/dsl/verifier.ex`.

```elixir
@callback verify(map) :: :ok | {:error, term} | {:warn, warning | [warning]}
```

`use Spark.Dsl.Verifier` gives you the behaviour and nothing else; `get_persisted/2,3`,
`get_option/3,4`, `fetch_option/3`, `get_entities/2` are `defdelegate`d straight through
to the same functions on `Spark.Dsl.Transformer` (`verifier.ex:65-70`) — same reads, no
writes.

**How it actually runs, and why it's safe to reference other modules:** verifiers
execute inside the `@after_verify` callback (`extension.ex:453`,
`dsl.ex:464` region), which Elixir does not invoke until the module itself is fully
compiled — and because Spark's own compile-time transformer pass has already finished by
then, calling `Ash.Resource.Info.actions(some_other_resource)` or similar from inside a
verifier does not create the compile-time dependency edge that the same call would create
from inside a `transform/1`. This is the documented difference (verifier moduledoc, lines
9-11) and it is exactly why `Ash.Domain.Verifiers.ValidateRelatedResourceInclusion`
freely calls `Ash.Resource.Info.relationships(resource)` for every resource in the
domain (`deps/ash/lib/ash/domain/verifiers/validate_related_resource_inclusion.ex:15-16`)
— see §6, this is the load-bearing example for the whole cross-module question.

**Testing gotcha, already recorded in LEARNINGS.md §4 and worth restating here because
it is Spark-API-specific, not project-specific:** verifier errors are NOT catchable with
`assert_raise`, because the `@after_verify` mechanism converts a raised
`Spark.Error.DslError` to a compiler diagnostic/stderr warning rather than a normal
exception propagating to the test process. Use `Spark.Test` — `assert_dsl_error/1,2`,
`refute_dsl_errors/1`, `dsl_errors/1`, `assert_dsl_warning/2`, `dsl_warnings/1` — which
exists specifically to turn these into pattern-matchable data for ExUnit.

### When a verifier is strictly correct over a transformer

- **Any check with no code-generation side effect.** If the only thing you're doing is
  raising when something is missing or malformed, it's a verifier — full stop (rewrite
  rule 5 in PROJECT.md is this exact point, and it is a correctness rule, not a style
  preference: a transformer that only validates still runs during compilation and can
  spuriously create compile-order dependencies on modules it merely *inspects*).
- **Any check that needs to inspect another already-compiled module** (a domain
  verifying its resources; a command verifying a referenced Ash action exists) —
  transformers can't safely do this (see §6), verifiers can.
- **Never** when the check's failure should also produce or block generated code inline
  in the same pass — that's still fine as a verifier, since verifiers run strictly after
  all transformers/persisters for the *same* module, but if the "check" is really
  "compute a value other code needs," it's a transformer + `persist/3`, not a verifier.

---

## 5. Introspection — `Spark.InfoGenerator`

Source: `deps/spark/lib/spark/info_generator.ex`. **AshCommanded currently has zero
`Info` modules** — confirmed by `find lib -iname '*info*'` returning nothing — despite
rewrite rule 6 ("introspection belongs in `ModuleName.Info`") already being a stated
constraint. This is a straightforward gap to close, not a design decision to make.

```elixir
defmodule AshCommanded.Commanded.Info do
  use Spark.InfoGenerator,
    extension: AshCommanded.Commanded.Dsl,
    sections: [:commands, :events, :projections, :event_handlers]
end
```

For each listed section (and every section nested under it), this generates, for free,
with `@doc`/`@spec` already attached and every function `defoverridable`:

- **`commands/1`** — `(dsl_or_extended) :: [%AshCommanded.Command{}]`, delegating to
  `Spark.Dsl.Extension.get_entities/2`. Works identically whether called on a raw
  `dsl_state` map (inside a transformer/verifier) or on a compiled resource module atom
  (at runtime) — same accessor, both phases.
- **`commands_options/1`** — a map of every schema option under `:commands` (its own
  section-level `schema`, not the entities) with defaults filled in.
- **Per-option accessor pairs**, if the section itself has scalar options: e.g. for a
  hypothetical `default_middleware` option on the `commands` section, both
  `default_middleware/1 :: {:ok, value} | :error` and `default_middleware!/1 :: value |
  no_return` (the `!` form raising with the module name from `get_persisted(dsl, :module)`
  in the error message).
- Predicate naming: an option ending in `?` (e.g. `autogenerate_handler?`) gets a
  generated reader named with the `?` preserved as `default_middleware?/1` returning the
  boolean directly (not an `{:ok, _}` tuple) — see `generate_config_function/1`'s
  `%{pred?: true}` clause.

This is precisely the mechanism that should replace any hand-written
`AshCommanded.Commanded.Dsl.commands(resource)` helper the current code has scattered
around transformers — one `use Spark.InfoGenerator` line replaces N hand-written getter
functions, one per section, always in sync with the DSL's actual shape because it reads
`extension.sections()` directly rather than being hand-copied.

---

## 6. Cross-module state — the router-generation defect and its fix

This is the central open question carried from PROJECT.md: *"a domain transformer that
walks `Ash.Domain.Info.resources/1` and reads each resource's persisted state via
`Spark.Dsl.Extension.get_persisted/2`; Spark dsl_state is per-module with no built-in
cross-module aggregation."*

### The mechanism exists. It is not a gap in Spark — it is a phase you have to run in

**Fact 1 — `Spark.Dsl.Extension.get_persisted/3` already works on a compiled module
atom, not only a dsl_state map.** Read directly:

```elixir
# deps/spark/lib/spark/dsl/extension.ex:282-298
def get_persisted(resource, key, default \\ nil)
def get_persisted(%struct{}, key, default), do: get_persisted(struct, key, default)
def get_persisted(map, key, default) when is_map(map),
  do: Spark.Dsl.Transformer.get_persisted(map, key, default)
def get_persisted(resource, :module, _) when is_atom(resource), do: resource
def get_persisted(resource, key, default), do: persisted!(resource, key, default)
```

`persisted!/3` (`extension.ex:149-168`) calls `resource.persisted(key, default)` — a
function every compiled Spark DSL module has generated on it. **So the question was
never "can a domain read a resource's persisted state" — it can, trivially, once the
resource is compiled.** The actual problem, confirmed against LEARNINGS.md §3.5, is
*timing*: the old `GenerateCommandedApplication` domain transformer tried to do this
during the domain's own normal compile-time transformer pass, before the resource
modules it needed were necessarily compiled.

**Fact 2 — `Ash.Domain.Info.resources/1` is safe to call at compile time; it is only
calling functions *on* the returned resource atoms that is the hazard.** Its `@spec` is
`(Spark.Dsl.t() | Ash.Domain.t()) :: list(Ash.Resource.t())` and the implementation is
just `Extension.get_entities(domain, [:resources]) |> Enum.map(& &1.resource)`
(`deps/ash/lib/ash/domain/info.ex:11-16`) — it reads entities already present in the
domain's own (in-progress) dsl_state, no compilation of the listed resources required.
Its sibling `resource_references/1` is annotated **"DO NOT USE AT COMPILE TIME"**
(line 19) for a different reason (it returns DSL entity structs, not resource modules,
and using it to reason about compiled resource state at compile time is the anti-pattern)
— and `depend_on_resources/1`, the macro that used to force resources to compile early,
is now `@deprecated` with the note "this macro is no longer necessary" (line 173),
confirming Ash itself moved away from forcing early compilation as the fix.

**Fact 3 — the actual, load-bearing example of "domain code reading already-compiled
resource state" is Ash's own domain verifiers**, not a transformer:

```elixir
# deps/ash/lib/ash/domain/verifiers/validate_related_resource_inclusion.ex
use Spark.Dsl.Verifier
def verify(dsl) do
  resources = dsl |> Verifier.get_entities([:resources]) |> Enum.map(& &1.resource)
  for resource <- resources do
    for relationship <- Ash.Resource.Info.relationships(resource) do  # <- calls INTO a resource module
      ...
```

`Ash.Resource.Info.relationships/1` ultimately calls `Spark.Dsl.Extension.get_entities/2`
on the resource module atom — exactly the shape of read AshCommanded needs for commands.
This works, unconditionally, for every resource in the domain, with zero special-casing,
**because it runs as a verifier**, i.e. inside `@after_verify`, which per §4 does not
create a compile-time dependency edge and — critically — does not run until every module
in the same `mix compile` invocation has already been compiled. By the time any
`@after_verify` callback fires, ordering among sibling modules is a non-issue.

### The fix for AshCommanded, concretely

Router/application generation is not "only validation" — it must **create a module**
(the router, and the `Commanded.Application`). That rules out a plain verifier (verifiers
are read-only by contract, even though nothing stops arbitrary Elixir side effects inside
`verify/1`, doing code generation there abuses the contract and every future maintainer's
expectations). The correct construct is a **domain-level transformer marked
`after_compile?() -> true`**:

```elixir
defmodule AshCommanded.Commanded.Transformers.GenerateMainRouterModule do
  use Spark.Dsl.Transformer

  # Deferred to run inside @after_verify, after every module in this compilation
  # unit — including every resource this domain lists — is fully compiled.
  def after_compile?, do: true

  def transform(dsl_state) do
    domain = Spark.Dsl.Transformer.get_persisted(dsl_state, :module)

    resources =
      dsl_state
      |> Spark.Dsl.Transformer.get_entities([:resources])
      |> Enum.map(& &1.resource)

    commands =
      Enum.flat_map(resources, fn resource ->
        # Safe now: `resource` is a real, already-compiled module atom.
        AshCommanded.Commanded.Info.commands(resource)
      end)

    router_module = Module.concat(domain, Router)
    ast = build_router_ast(router_module, commands)  # thin wiring, per rewrite rule 1
    Module.create(router_module, ast, Macro.Env.location(__ENV__))

    {:ok, Spark.Dsl.Transformer.persist(dsl_state, :router, router_module)}
  end
end
```

Register it under the **domain** extension's `transformers:` list (not `verifiers:` —
it still needs `before?`/`after?` semantics relative to any *other* `after_compile?`
transformers on the same domain, e.g. ordering router generation before
`GenerateCommandedApplication`, which needs the router's module name to exist first).
`GenerateCommandedApplication` becomes a second `after_compile?: true` transformer with
`after?(GenerateMainRouterModule), do: true`, reading the persisted `:router` key
instead of calling `Router.__registered_commands__/0` against a module that (under the
old, non-deferred design) hadn't been built yet.

**Why this is not "the same bug, later":** the old code's failure was that a *normal*
(non-`after_compile?`) domain transformer ran during the domain's own ordinary compile
pass, at which point sibling resource modules are compiled in whatever order the Elixir
/ `mix` build graph happens to choose — sometimes before, sometimes after, the domain.
Marking the transformer `after_compile?: true` moves its execution to a phase that is
*defined* to happen after the whole compilation unit is done, matching exactly the phase
in which Ash's own domain verifiers already do this same cross-resource read.

### How AshGraphQL solves the same problem, for confirmation

AshGraphQL and AshJsonApi (not vendored in this repo's `deps/`, so not source-verified
here — flag as MEDIUM confidence, direction only) are known to build their schema from
`Ash.Domain.Info.resources/1` plus per-resource introspection at **schema-build time**,
which for AshGraphQL is explicitly a runtime/query-time or `mix ash_graphql.schema`-time
operation, not a DSL-compile-time transformer at all — they sidestep the ordering problem
entirely by not doing the aggregation during `mix compile`. That is a second valid
strategy (build the router lazily, e.g. the first time `dispatch/1` is called, memoized),
but it trades compile-time guarantees (a missing/misconfigured command fails at
`mix compile` today) for runtime discovery (it fails at first dispatch). Given
AshCommanded's existing rewrite rule "golden renders of generated output, diffed in CI,"
the `after_compile?: true` transformer approach is the better fit — it keeps router
generation a real, renderable, compile-time artifact.

---

## 7. Docs — cheat sheets and `spark.cheat_sheets`

Source: `deps/spark/lib/spark/cheat_sheet.ex`, `deps/spark/lib/mix/tasks/spark.cheat_sheets.ex`.

`Spark.CheatSheet.cheat_sheet/1` takes a single extension module and renders its
sections/entities (using `describe`, `examples`, schema `:doc` fields — this is why §1's
"doc removes hand-written code" claim matters, cheat sheets are not editable prose, they
are generated from the DSL definition). The mix task takes a **comma-separated list**:

```bash
mix spark.cheat_sheets --extensions AshCommanded.Commanded.Dsl,AshCommanded.Commanded.DomainDsl
```

(`spark.cheat_sheets.ex:41-44`, `schema: [extensions: :csv]`). This is a direct,
mechanical fix for the carry-forward item "`spark.cheat_sheets` to cover `DomainDsl`, not
only `Dsl`" — the current `mix.exs` alias is:

```elixir
"spark.cheat_sheets": "spark.cheat_sheets --extensions AshCommanded.Commanded.Dsl",
```

and needs only:

```elixir
"spark.cheat_sheets": "spark.cheat_sheets --extensions AshCommanded.Commanded.Dsl,AshCommanded.Commanded.DomainDsl",
```

The other carry-forward item — `mix.exs` `files:` omitting `documentation/` and
`cheatsheets/` — is confirmed by reading `mix.exs:85` directly:
`files: ~w(lib mix.exs README.md LICENSE .formatter.exs)`. Both generated-doc
directories are absent from the published package's `files:` list, so `mix hex.publish`
today would ship a package whose own generated docs it doesn't include.

---

## 8. Code generation helpers

Spark does not provide a "create a new named module" helper beyond bare
`Module.create/3` — it uses `Module.create/3` internally for its own section/entity
modules (e.g. `extension.ex:1205-1222`, `:1231-1234`, `:1356-1360`, `:1630-1636`), always
paired with `Macro.Env.location(env)` for correct compiler warnings/stacktraces pointing
at the calling `.ex` file rather than "nofile." AshCommanded already has this exact
wrapper (`AshCommanded.Commanded.Transformers.BaseTransformer.create_module/3`,
`lib/commanded/transformers/base_transformer.ex:70-74`) — keep it, it matches the
idiom Spark itself uses; there is no more-official alternative to switch to.

What Spark *does* provide beyond bare `Module.create/3`:

- **`Spark.Dsl.Transformer.async_compile/2`** — schedules a function (typically a
  `Module.create/3` call) to run on a `Task`, tracked in the dsl_state's
  `:spark_compile_tasks` so the framework calls `Task.await_many/2` before the DSL module
  finishes compiling (`Spark.Dsl.Extension.await_tasks/1`, `extension.ex:742-745`). Use
  this to parallelize generation of independent modules (e.g. each command struct module
  doesn't depend on any other) — a build-speed optimization, not a correctness
  requirement, and orthogonal to the `after_compile?` timing question in §6.
- **`Spark.CodeHelpers.lift_functions/3`** — not a general code-gen helper; specifically
  turns an anonymous function or `&Mod.fun/n` capture passed as a DSL option value into a
  named function defined on the calling module, returning a function-capture AST plus the
  `def` to inject. This is the machinery behind `{:spark_function_behaviour, ...}` (§2)
  and behind Ash's `changes(fn event -> ... end)`-style DSL ergonomics — relevant if
  AshCommanded's `projections do projection :x do changes(fn event -> ... end) end end`
  needs the same "accept a lambda, it becomes a real named function" treatment.
- **`Spark.Dsl.Transformer.eval/3`** — injects code into the *currently-compiling DSL
  module itself* (the resource or domain), not a new module. Different tool from
  `Module.create/3`; see §3's caution against overusing it.

---

## 9. The formatter plugin — `Spark.Formatter`

Source: `deps/spark/lib/spark/formatter.ex:1-51`. Requires `Sourceror` (already a
dev/test dependency here). Add to `.formatter.exs`:

```elixir
plugins: [Spark.Formatter]
```

Default behavior with no config: sorts all top-level DSL sections **alphabetically**.
To impose a specific order instead (e.g. `commands`, then `events`, then
`projections`), configure per-DSL-module in `config/config.exs`:

```elixir
config :spark, :formatter,
  "AshCommanded.Commanded.Dsl": [
    section_order: [:commands, :events, :projections, :event_handlers]
  ],
  "AshCommanded.Commanded.DomainDsl": [
    section_order: [:application]
  ]
```

Sections not named in `section_order` keep their relative position; the list only
constrains the ones it names. `type:`/`extensions:` keys under a per-module config entry
are for consumers whose own DSL wraps AshCommanded under a different module name — not
needed for AshCommanded's own repo, only relevant to document for downstream users of the
library later.

---

## 10. Out-of-date advice to flag

- **"Spark 2.3.5" anywhere in this codebase's own docs** (§0) — the installed version is
  2.7.2; treat every 2.3.5-specific claim (including CLAUDE.md's own text) as unverified
  until re-checked against `deps/spark`.
- **`Ash.Domain.Info.depend_on_resources/1`** — deprecated in the installed Ash version;
  any tutorial/blog content recommending it for compile-time resource access is
  describing a workaround Ash no longer needs.
- **"Verifiers can't reference other resources" folk wisdom** — backwards. Verifiers are
  specifically the safe place to do this (§4, §6); it's *transformers* (outside
  `after_compile?: true`) that cannot safely do it.
- **Treating `{:behaviour, module}` / `{:spark_behaviour, ...}` schema types as enforcing
  the behaviour** (§2) — they do not; this is a common misreading of the type name and
  worth a one-line comment in any AshCommanded schema that uses one, so a future reader
  doesn't assume Spark is checking it.

---

## Sources

All claims above are cited inline to specific files/line ranges under
`deps/spark/lib/` (hex `spark` 2.7.2, resolved via this repo's own `mix.lock`) and
`deps/ash/lib/` (hex `ash` 3.5.8, same `mix.lock`) — i.e. the exact dependency versions
this project already builds against, read directly rather than fetched from hexdocs or
recalled. `.planning/PROJECT.md` and `.planning/LEARNINGS.md` (this repo) supplied the
open questions and the already-established framework facts this document extends rather
than repeats.

AshGraphQL/AshJsonApi's domain-aggregation approach (§6) is **not** vendored in this
repo's `deps/` and was not independently source-verified — marked MEDIUM confidence,
included for direction only. If it becomes load-bearing for a design decision, add it as
a dependency (even transiently) and re-verify against its source before relying on it.
