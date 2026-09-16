# AGENTS.md

This is the document a contributor or a coding agent reads first, before touching code in this
repository. It is hybrid by construction: the hand-written sections below this line describe
this project's own conventions; the block delimited by `<!-- usage-rules-start -->` /
`<!-- usage-rules-end -->` further down is managed by `mix usage_rules.sync` (FOUND-13,
`mix.exs`'s `usage_rules` config) and aggregates the real, current usage rules of dependencies
this project is built on (today: Spark, Igniter). Do not hand-edit inside that block — a future
sync overwrites it, and `mix usage_rules.sync --check` (wired into CI, see
`.github/workflows/ci.yml`) fails the build the moment it drifts from what a real sync would
produce.

**Do not use this document to reconcile `CLAUDE.md`.** `CLAUDE.md` documents three verifiers
(`ValidateCommandActions`, `ValidateCommandHandlers`, `ValidateCommandNameConflict`) that do not
exist in this codebase, and three stale dependency versions — treat every factual claim in it as
unverified until Phase 7 (`DOCS-01`/`DOCS-02`, `.planning/ROADMAP.md`) reconciles it against this
file. Reconciling it earlier would be invalidated by the rewrite this milestone is doing. This
document is written entirely against the code as it stands today, under the post-relocation
`AshCommanded.Resource`/`AshCommanded.Domain` namespace
(`.planning/phases/01-foundation-rendering-enforcement-and-layout/01-04-SUMMARY.md`) — never the
pre-move namespace `lib/commanded/` used before that relocation (D-13).

## Idiomatic Elixir for this project

- **Every public module carries a `@moduledoc`; every public function carries a `@doc` and a
  `@spec`.** See `lib/ash_commanded/error.ex` (moduledoc + typedoc + a `@doc`/`@spec` pair on
  every public function, e.g. `validation_error/2` at line 127) and
  `lib/ash_commanded/resource/transformers/base_transformer.ex` (every public function's `@doc`
  includes an `## Examples` block with a real `iex>` line).
- **`{:ok, value}` / `{:error, reason}` tuples, not exceptions, for anything that can fail** at
  the boundary a caller is expected to handle. `lib/ash_commanded/error.ex` is the shared error
  module: use its constructors (`AshCommanded.Error.validation_error/2`, `command_error/2`,
  `aggregate_error/2`, `dispatch_error/2`, `action_error/2`, `projection_error/2`,
  `transformation_error/2`) rather than building an ad hoc error map or raising a bare
  `RuntimeError` — they exist precisely so error shapes are consistent across the library, and
  `from_ash_error/1`/`from_commanded_error/1` normalize errors crossing in from those two
  dependencies.
- **Private helpers are plain `defp name(...)`, never underscore-prefixed.** This corrects a
  stale claim: an earlier planning document asserted this codebase prefixes private helpers with
  `_` (e.g. `_build_module_ast`). `grep -rn 'defp _[a-z]' lib/` returns nothing — real examples
  are `lib/ash_commanded/dump/render.ex`'s `maybe_add_guards/2` and `indent/1`, and
  `lib/ash_commanded/credo_checks/exemption.ex`'s `marker_covers?/3`. Do not introduce the
  underscore-prefix convention; it does not match the code that exists.
- **`?`-suffixed predicate names for boolean-returning functions** (`extension?/1` in
  `lib/ash_commanded/resource/dsl.ex`, `marker_covers?/3`, `before_next_def?/2`), never an
  `is_`-prefixed name for a function you control. (`AshCommanded.Error.is_error?/1` is an
  exception that predates this convention being written down — see the
  `# gsd-disable-until-phase: 6` comment at the top of `lib/ash_commanded/error.ex`: renaming it
  now would break every existing caller ahead of Phase 6's planned decomposition of that module,
  so it stays until then. Do not copy its naming for new code.)

## DSL conventions

- **Two extension modules, two trees.** `AshCommanded.Resource.Dsl` (applied via
  `use Ash.Resource, extensions: [AshCommanded.Resource.Dsl]`) lives under
  `lib/ash_commanded/resource/`, with its own `sections/`, `transformers/` and `verifiers/`
  subdirectories plus `info.ex`. `AshCommanded.Domain.Dsl` (applied via
  `use Ash.Domain, extensions: [AshCommanded.Domain.Dsl]`) lives under `lib/ash_commanded/domain/`
  with its own `transformers/` and `info.ex` (no `verifiers/` yet — nothing is registered there
  today). See `lib/ash_commanded/resource/dsl.ex` and `lib/ash_commanded/domain/dsl.ex` for both
  extensions' full `sections:`/`transformers:`/`verifiers:` lists as they stand.
- **The DSL block is `commanded do ... end`, not `resource do ... end` or `domain do ... end`
  (D-15, `.planning/phases/01-foundation-rendering-enforcement-and-layout/01-CONTEXT.md`).** The
  block names the integration being configured, the way `postgres do ... end` and
  `graphql do ... end` do in sibling Ash extensions — "Commanded" was redundant next to
  `AshCommanded` in the *module path*, which is why the module path dropped it (D-13), but inside
  the block it is exactly the information a reader needs.
- **Section, entity and schema conventions follow `Spark.Options`' vocabulary** (see "The Spark
  API surface" below) — a new DSL option's `type:` should come from that vocabulary (`:atom`,
  `{:list, :atom}`, `{:or, [...]}`, etc.) rather than a hand-rolled `is_atom(x) or raise` check in
  a transformer. `AshCommanded.Resource.Sections.CommandsSection` and its siblings under
  `lib/ash_commanded/resource/sections/` are the existing pattern to extend.
- **Introspection belongs in a `.Info` module — no other code reads DSL state directly.**
  `AshCommanded.Resource.Info` (`lib/ash_commanded/resource/info.ex`) and
  `AshCommanded.Domain.Info` (`lib/ash_commanded/domain/info.ex`) are both generated entirely by
  `Spark.InfoGenerator` — zero hand-written accessor functions in either file (`grep -c 'def '
  lib/ash_commanded/resource/info.ex` and the domain equivalent are both `0`, ignoring the `use`
  line). A transformer, verifier, or application code that wants to know what a resource declared
  calls `AshCommanded.Resource.Info.commanded_commands(resource)` (or the equivalent generated
  accessor for another section) — never `Spark.Dsl.Extension.get_entities/2` directly from outside
  a transformer/verifier that already has the raw `dsl_state`.
- **A capability the DSL currently accepts but does not deliver: domain-level application and
  router generation never fires for any domain** (see `usage-rules.md`'s own callout, and
  `.planning/PROJECT.md`'s Falsified section). Do not treat a domain compiling cleanly with a
  `commanded do application do ... end end` block as proof the application or router it appears
  to configure actually exists — it doesn't, until Phase 3.

## Transformer ordering

`lib/ash_commanded/resource/transformers/transformer_order.md` is the existing statement of
transformer ordering for the resource extension; read it there rather than here (it documents
`before?/1`/`after?/1` and the extension's own declared order in
`lib/ash_commanded/resource/dsl.ex`). One rule this document adds on top of it, because it is
easy to violate silently: **every transformer that creates a new module MUST route through
`AshCommanded.Resource.Transformers.BaseTransformer.create_module/3` (or the explicit-location
`/4` form), never call `Module.create/3` directly.** `mix ash_commanded.dump`'s AST capture (D-06)
attaches to that one shared helper — a transformer that bypasses it and calls `Module.create/3`
itself renders as a silent hole in `mix ash_commanded.dump`'s output: the module exists at
runtime, but the renderer has nothing captured for it. Research confirmed all nine current
module-creating transformers already route through it
(`.planning/phases/01-foundation-rendering-enforcement-and-layout/01-CONTEXT.md`'s "Integration
Points"); keep that invariant when adding a tenth.

## The Spark API surface (FOUND-15)

The claims below are true of **Spark 2.7.2** (the version resolved in this repository's own
`mix.lock` — not the 2.3.5 some older planning documents and `CLAUDE.md` cite). Read
`.planning/research/FEATURES.md` for the fully cited version of this section; the summary here is
what to reach for before hand-rolling the equivalent:

- **`identifier:` on an `Entity`, and `singleton_entity_keys` on a `Section`/`Entity`, replace
  hand-written uniqueness verifiers.** Spark auto-prepends `VerifyEntityUniqueness` (driven by
  `identifier:`) and `VerifySectionSingletonEntities` (driven by `singleton_entity_keys`) to every
  extension. **This codebase does not use either today** —
  `AshCommanded.Resource.Verifiers.ValidateCommandNames` and `ValidateEventNames`
  (`lib/ash_commanded/resource/verifiers/`) hand-write exactly the check `identifier: :name` would
  give for free. This is a real, checkable gap, not a hypothetical one — CMD-05/EVT-03 (Phase 2)
  is where it should close, by adding `identifier: :name` to the `command`/`event` entities and
  deleting the two hand-written verifiers, not by writing a third one.
- **`use Spark.InfoGenerator, extension: ..., sections: [...]`** generates every `.Info` accessor
  a section needs (entity list, section options, per-option `!`/non-`!` pairs, `?`-suffixed
  predicate readers) from the extension's own declared shape. `lib/ash_commanded/resource/info.ex`
  and `lib/ash_commanded/domain/info.ex` are this codebase's two uses of it; do not hand-write a
  getter it can generate instead.
- **`use Spark.Dsl.Transformer`** gives `transform/1` plus `before?/1`/`after?/1`/`after_compile?/0`
  defaulted to `false` and `defoverridable`; **`use Spark.Dsl.Verifier`** gives `verify/1` and
  read-only delegates to the same `get_entities/2`/`get_option/3,4`/`get_persisted/2,3` helpers.
  Prefer a verifier over a transformer whenever the only thing being done is raising on something
  missing or malformed (rewrite rule 5) — a transformer that only validates still runs during
  compilation and can create a spurious compile-order dependency on a module it merely inspects,
  while a verifier runs inside `@after_verify`, after the module itself has already compiled, so
  it can safely inspect other modules (this is *why* the "verifiers can't reference other
  resources" folk wisdom in `.planning/research/FEATURES.md` §10 is backwards).
- **`Transformer.get_persisted(dsl_state, :module)`** (and `Spark.Dsl.Extension.get_persisted/3`,
  which works on an already-compiled module atom too, not only a raw `dsl_state` map) is the one
  correct way to get the module currently being compiled. Never reconstruct it by
  `Module.split/1`-then-`Module.concat/1,2` surgery on another module's name — that shape is
  rewrite rule 4 and `AshCommanded.CredoChecks.NoModuleNameSurgery` (FOUND-10) blocks `mix check`
  on it, with exactly one permanent, named, counted exception:
  `lib/ash_commanded/resource/transformers/base_transformer.ex`'s `get_module_prefix/1`, which
  derives a *fresh child namespace* from a DSL module's own name (never reconstructs an existing
  reference) behind the `# ash_commanded:namespace-derivation` marker
  (`lib/ash_commanded/credo_checks/exemption.ex`). Do not add a second unmarked exception; extend
  the one marker if a second legitimate case is found.
- **`{:behaviour, module}` / `{:spark_behaviour, ...}` schema types do not verify the supplied
  atom actually implements the behaviour** — the runtime check is just "is this an atom." If a
  future DSL option (e.g. a declared middleware module) needs that enforced, write a verifier
  calling `Spark.implements_behaviour?/2`; the schema type alone is documentation, not a gate.

## Testing expectations

- **Baseline: 176 tests, 0 failures, is the floor this milestone does not relax**
  (`.planning/ROADMAP.md`'s Standing Constraints). The suite has grown past that floor as the
  phase has progressed (249 tests as of the last completed plan in this phase) — the number in
  this document is the floor the milestone is judged against, not a live count; re-run
  `MIX_ENV=test mix test` for the current one.
- **`mix check` is the real gate**, defined once in `mix.exs`'s `aliases/0` and never restated
  elsewhere (CI invokes the alias — see `.github/workflows/ci.yml` — rather than listing its
  steps independently, so the two cannot drift): `format --check-formatted` →
  `compile --warnings-as-errors` → `credo` → `cmd MIX_ENV=test mix coveralls` →
  `cmd ./scripts/compile_parity.sh` → `dialyzer` → `gen.docs`.
- **The test step runs in its own `MIX_ENV=test` subprocess (`cmd MIX_ENV=test mix coveralls`),
  not the alias's default `:dev` environment.** Dialyzer has no `:ex_unit` application in its
  PLT, so analysing `test/support` under `MIX_ENV=test` raises spurious `unknown_function`
  findings for `ExUnit.Callbacks` macros — keeping `dialyzer`/`credo`/
  `compile --warnings-as-errors` on `:dev` and spawning `test` separately avoids that, at the cost
  of the two environments never fighting over which one the whole alias runs under. Preserve this
  split if you ever touch the alias.
- **No mocking anywhere in the suite** — `:meck` was removed entirely
  (`.planning/LEARNINGS.md` §6, §7) after an intermittent `:cover`-server race, re-verified over
  35+ consecutive full-suite runs. Do not reintroduce `:meck` or `with_mock`; a real stub module
  satisfying a contract is the pattern to reach for instead (`.planning/LEARNINGS.md` §6,
  "Verifying a stub rather than mocking").
- **The cross-environment parity mechanism**: `test/support/parity/` fixtures (deliberately
  dependency-free, no data layer — "this resource exists to be compiled, not written to") sit on
  the `:dev` `elixirc_paths` entry as well as `:test`'s, and `scripts/compile_parity.sh` asserts
  an explicit list of expected generated modules loads under both. This is what turned the `:dev`
  compiler into a reviewer of generated output and found real, previously-invisible defects
  (`.planning/LEARNINGS.md` §1, §6).
- **The golden-render workflow** is documented in full at `test/golden/README.md` — read it
  there rather than here for the header format, the `--write` ratchet, the staged-until-phase
  marker, and D-12's canonical-version text-diff exclusion. The one fact worth restating: there is
  exactly one documented regeneration command, `mix ash_commanded.dump <Fixture> --write`.

## The eleven rewrite rules

Verbatim from `.planning/PROJECT.md`'s Constraints, each annotated with how (or whether) it is
mechanically enforced today. "Enforced" means a real, blocking `mix check` gate — not a check that
merely exists somewhere in isolation. Rule 9, no double-handling, gets particular attention below:
FOUND-12 and ROADMAP SC4 require it to carry an explicit reviewer checklist item together with an
explicit statement that no mechanical check for it exists.

1. **Generated code is thin wiring.** Logic lives in hand-written runtime modules reached through
   a `__using__` front door. A generated clause carries only the per-entity literals that vary.
   — *Not mechanically enforced.* Rule 3's clause-size gate is a rough proxy (thin wiring tends to
   produce short clauses) but a component could satisfy the line count while still inlining logic
   that belongs in a runtime module. Judged by human review at each component's render-and-approve
   step (the milestone's method, step 4).
2. **Anything computable at macro-expansion time is computed there** and `unquote`d as a literal,
   never reassembled at runtime.
   — *Enforced.* `AshCommanded.Dump.Lint` (`lib/ash_commanded/dump/lint.ex`, FOUND-08) walks every
   committed golden's rendered body and fails, naming the golden's path and the offending line, on
   the `:erlang.++`-shaped defect this rule targets (`test/ash_commanded/golden_budget_test.exs`).
3. **Measure the OUTPUT, not the generator.** Target: a generated clause under ~10 lines; no
   `quote` block over 40. Splitting a fat generator into several generator modules satisfies a
   line-count criterion while changing nothing about what is emitted.
   — *Enforced, two ways.* `Credo.Check.Refactor.LongQuoteBlocks` at `max_line_count: 40`
   (`.credo.exs`, FOUND-07) blocks on generator *source*; the golden budget ratchet
   (`test/ash_commanded/golden_budget_test.exs`, D-03) blocks on rendered *output* size and never
   lets a committed size grow, which is what actually answers "measure the output."
4. **Derive from `Transformer.get_persisted/2`**, never by module-name surgery.
   — *Enforced.* `AshCommanded.CredoChecks.NoModuleNameSurgery` (FOUND-10), with the one named
   exemption described above.
5. **Prefer a verifier over a transformer** when only validating.
   — *Not mechanically enforced.* This is a design-review judgment call at the point a new
   transformer or verifier is added — no Credo check distinguishes "this transformer only
   validates" from "this transformer also shapes state."
6. **Introspection belongs in `ModuleName.Info`.**
   — *Partially enforced.* FOUND-17 established the `.Info` convention and both trees have one,
   generated by `Spark.InfoGenerator`. There is currently no check that *forbids* other code from
   calling `Spark.Dsl.Extension.get_entities/2` (or similar) directly instead of going through
   `.Info` — the convention exists, but nothing yet blocks a violation of it.
7. **Golden renders of generated output, diffed in CI.**
   — *Enforced.* `AshCommanded.GoldenRenderTest` (FOUND-04) diffs every committed golden against a
   fresh render on every `mix test` run; the canonical-version leg of CI (see "The canonical
   Elixir version" below) is what makes "in CI" literally true once `.github/workflows/ci.yml`
   runs.
8. **DRY.** Repeated shapes extract to functions, modules or macros rather than recurring.
   — *Partially enforced.* `ex_dna`/`ExDNA.Credo` structural clone detection (FOUND-11) reports
   Type-II (renamed-variable) clones across `lib/` generator modules — see
   `.planning/phases/01-foundation-rendering-enforcement-and-layout/01-CLONE-REPORT.md` for a real
   example it catches that Credo's own built-in `Design.DuplicatedCode` (disabled; see
   `.credo.exs`) does not. It reports; it does not block `mix check` on every DRY violation.
9. **No double-handling.** Pass the value the caller already holds rather than re-deriving it by
   re-walking nested AST. An extra parameter is cheaper than a traversal.
   — **No mechanical check exists for this, and none is planned** (FOUND-12, ROADMAP SC4). This is
   a data-flow ownership question — does the caller already hold this value? — that no static
   analyser reasons about, and the honest position is to say so rather than build a check that
   looks like it works and does not. **Reviewer checklist question:** *"Does this diff hand a
   function a value it could instead re-derive by walking AST (or other structure) the caller
   already has in scope? If a callee re-walks something the caller already held to reconstruct the
   same value, ask the author to thread it through as a parameter instead."* One partial proxy
   exists and should be labelled a nudge, not enforcement: a tree walk appearing inside a
   transformer is a signal worth a reviewer's second look, not a rule violation by itself.
10. **Idiomatic macros.** Mostly-static code with occasional `unquote` substitutions — never lists
    of tuples and maps assembled into strings and reparsed into AST.
    — *Enforced.* `AshCommanded.CredoChecks.NoRuntimeStringToAst` (FOUND-09) flags
    `Code.string_to_quoted!/2`/`eval_string`-shaped code under `lib/`.
11. **Tricky AST transformation is a smell.** If Spark does not already offer it, the design is
    probably an overcomplicated version of something simple. Escalate and reconsider; a feature PR
    to Spark is the last resort, not the first move. Where genuinely needed, it goes behind a named
    utility module whose purpose is legible.
    — *Not mechanically enforced.* A design principle and an escalation path, not a countable
    property a check can measure. "The Spark API surface" section above is the reference to check
    against before concluding something needs hand-rolled AST work.

## The canonical Elixir version (D-12)

Golden renders (`test/golden/`) are generated on **Elixir 1.18** — the literal
`canonical_elixir_version = "1.18"` in `test/test_helper.exs`. This matters because the render
comes from `Macro.to_string/1` + `Code.format_string!/1`, both formatter- and version-sensitive:
a golden generated on the wrong minor produces a diff that *looks like* a generator change and is
not. `test/ash_commanded/golden_render_test.exs`'s text-diff comparison is tagged
`:canonical_version_only` and only runs when the executing Elixir starts with `"1.18"`; every
other CI matrix leg (see `.github/workflows/ci.yml`) still runs the full suite and the size gates,
which count sizes rather than compare text and so hold on every Elixir minor.

Regenerate goldens with exactly one command: `mix ash_commanded.dump <Fixture> --write`, run on
Elixir 1.18 — see `test/golden/README.md` for the full ratchet/refusal mechanics. Do not regenerate
goldens on any other Elixir minor; the diff you get will not mean what it appears to mean.

<!-- markdownlint-disable -->

<!-- usage-rules-start -->
<!-- spark-start -->
## spark usage
_Generic tooling for building DSLs_

# Rules for working with Spark

## Overview

Spark is a framework for building Domain-Specific Languages (DSLs) in Elixir. It enables developers to create declarative DSLs with minimal boilerplate.

## Core Architecture

### 1. Entity-Section-Extension Model

Spark DSLs are built using three core components:

```elixir
# 1. Entities - Individual DSL constructors
@field %Spark.Dsl.Entity{
  name: :field,                    # DSL function name
  target: MyApp.Field,            # Struct to build
  args: [:name, :type],           # Positional arguments
  schema: [                       # Validation schema
    name: [type: :atom, required: true],
    type: [type: :atom, required: true]
  ]
}

# 2. Sections - Organize related entities
@fields %Spark.Dsl.Section{
  name: :fields,
  entities: [@field],             # Contains entities
  sections: [],                   # Can nest sections
  schema: [                       # Section-level options
    required: [type: {:list, :atom}, default: []]
  ]
}

# 3. Extensions - Package DSL functionality
defmodule MyExtension do
  use Spark.Dsl.Extension,
    sections: [@fields],
    transformers: [MyTransformer],
    verifiers: [MyVerifier]
end
```

### 2. Compile-Time Processing Pipeline

```
DSL Definition → Parsing → Validation → Transformation → Verification → Code Generation
```

1. **Parsing**: DSL syntax converted to internal representation
2. **Validation**: Schema validation via `Spark.Options`
3. **Transformation**: Transformers modify DSL state
4. **Verification**: Verifiers validate final state
5. **Code Generation**: Generate runtime modules/functions

## Creating a DSL with Spark

### Basic DSL Structure

```elixir
# Step 1: Define your extension
defmodule MyLibrary.Dsl do
  @my_nested_entity %Spark.Dsl.Entity{
    name: :my_nested_entity,
    target: MyLibrary.MyNestedEntity,
    describe: """
    Describe the entity.
    """,
    examples: [
      "my_nested_entity :name, option: \"something\"",
      """
      my_nested_entity :name do
        option "something"
      end
      """
    ],
    args: [:name],
    schema: [
      name: [type: :atom, required: true, doc: "The name of the entity"],
      option: [type: :string, default: "default", doc: "An option that does X"]
    ]
  }

  @my_entity %Spark.Dsl.Entity{
    name: :my_entity,
    target: MyLibrary.MyEntity,
    args: [:name],
    entities: [
      entities: [@my_nested_entity]
    ],
   describe: ...,
    examples: [...],
    schema: [
      name: [type: :atom, required: true, doc: "The name of the entity"],
      option: [type: :string, default: "default", doc: "An option that does X"]
    ]
  }
  
  @my_section %Spark.Dsl.Section{
    name: :my_section,
    describe: ...,
    examples: [...],
    schema: [
      section_option: [type: :string]
    ],
    entities: [@my_entity]
  }
  
  use Spark.Dsl.Extension, sections: [@my_section]
end

# Entity Targets
defmodule MyLibrary.MyEntity do
  defstruct [:name, :option, :entities, :__spark_metadata__]
end

defmodule MyLibrary.MyNestedEntity do
  defstruct [:name, :option, :__spark_metadata__]
end

# Step 2: Create the DSL module
defmodule MyLibrary do
  use Spark.Dsl, 
    default_extensions: [
      extensions: [MyLibrary.Dsl]
    ]
end

# Step 3: Use the DSL
defmodule MyApp.Example do
  use MyLibrary
  
  my_section do
    my_entity :example_name do
      option "custom value"
      my_nested_entity :nested_name do
        option "nested custom value"
      end
    end
  end
end
```

### Working with Transformers

Transformers modify the DSL at compile time:

```elixir
defmodule MyLibrary.Transformers.AddDefaults do
  use Spark.Dsl.Transformer
  
  def transform(dsl_state) do
    # Add a default entity if none exist
    entities = Spark.Dsl.Extension.get_entities(dsl_state, [:my_section])
    
    if Enum.empty?(entities) do
      {:ok, 
       Spark.Dsl.Transformer.add_entity(
         dsl_state,
         [:my_section],
         %MyLibrary.MyEntity{name: :default}
       )}
    else
      {:ok, dsl_state}
    end
  end
  
  # Control execution order
  def after?(_), do: false
  def before?(OtherTransformer), do: true
  def before?(_), do: false
end
```

### Creating Verifiers

Verifiers validate the final DSL state:

```elixir
defmodule MyLibrary.Verifiers.UniqueNames do
  use Spark.Dsl.Verifier

  def verify(dsl_state) do
    entities = Spark.Dsl.Extension.get_entities(dsl_state, [:my_section])
    names = Enum.map(entities, & &1.name)

    if length(names) == length(Enum.uniq(names)) do
      :ok
    else
      # Find the duplicate entity to get its location
      duplicate_name =
        names
        |> Enum.frequencies()
        |> Enum.find_value(fn {name, count} -> if count > 1, do: name end)

      duplicate_entity = Enum.find(entities, &(&1.name == duplicate_name))
      location = Spark.Dsl.Entity.anno(duplicate_entity)

      {:error,
       Spark.Error.DslError.exception(
         message: "Entity names must be unique, found duplicate: #{duplicate_name}",
         path: [:my_section, duplicate_name],
         module: Spark.Dsl.Verifier.get_persisted(dsl_state, :module),
         location: location
       )}
    end
  end
end
```

## Info Modules

Spark provides an Info Generator system for introspection of DSL-defined modules. All introspection should go through info modules rather than accessing DSL state directly.

### 1. Info Module Generation
```elixir
# Define an info module for your extension
defmodule MyLibrary.Info do
  use Spark.InfoGenerator,
    extension: MyLibrary.Dsl,
    sections: [:my_section]
end

# The info generator creates accessor functions for DSL data:
# - MyLibrary.Info.my_section_entities(module)
# - MyLibrary.Info.my_section_option!(module, :option_name)
# - MyLibrary.Info.my_section_option(module, :option_name, default)

# Example usage:
entities = MyLibrary.Info.my_section_entities(MyApp.Example)
required_option = MyLibrary.Info.my_section_option!(MyApp.Example, :required)
{:ok,optional_value} = MyLibrary.Info.my_section_option(MyApp.Example, :optional, "default")

```

Benefits of using info modules:
- **Type Safety**: Generated functions provide compile-time guarantees
- **Performance**: Info data is cached and optimized for runtime access
- **Consistency**: Standardized API across all Spark-based libraries
- **Documentation**: Auto-generated docs for introspection functions

## Key APIs for Development

### Essential Functions

```elixir
# Get entities from a section
entities = Spark.Dsl.Extension.get_entities(dsl_state, [:section_path])

# Get section options
option = Spark.Dsl.Extension.get_opt(dsl_state, [:section_path], :option_name, default_value)

# Add entities during transformation
dsl_state = Spark.Dsl.Transformer.add_entity(dsl_state, [:section_path], entity)

# Persist data across transformers
dsl_state = Spark.Dsl.Transformer.persist(dsl_state, :key, value)
value = Spark.Dsl.Transformer.get_persisted(dsl_state, :key)

# Get current module being compiled
module = Spark.Dsl.Verifier.get_persisted(dsl_state, :module)

# Get annotation information for error reporting
section_anno = Spark.Dsl.Transformer.get_section_anno(dsl_state, [:section_path])
option_anno = Spark.Dsl.Transformer.get_opt_anno(dsl_state, [:section_path], :option_name)
entity_anno = Spark.Dsl.Entity.anno(entity)
```

### Schema Definition with Spark.Options

```elixir
schema = [
  required_field: [
    type: :atom,
    required: true,
    doc: "Documentation for the field"
  ],
  optional_field: [
    type: {:list, :string},
    default: [],
    doc: "Optional field with default"
  ],
  complex_field: [
    type: {:or, [:atom, :string, {:struct, MyStruct}]},
    required: false
  ]
]
```

## Important Implementation Details

### 1. Compile-Time vs Runtime

- **DSL processing happens at compile time**
- Transformers and verifiers run during compilation
- Generated code is optimized for runtime performance
- Use `persist/3` to cache expensive computations

### 2. Error Handling

Always provide context in errors:
```elixir
{:error,
 Spark.Error.DslError.exception(
   message: "Clear error message",
   path: [:section, :subsection],  # DSL path
   module: module,                  # Module being compiled
   location: annotation             # Source location (when available)
 )}
```

### Error Location Information

When creating DslErrors, include location information whenever possible to help developers quickly identify the source of issues:

```elixir
# For entity-related errors, get entity annotations
entity_location = Spark.Dsl.Entity.anno(entity)

# For section-related errors, get section annotations
section_location = Spark.Dsl.Transformer.get_section_anno(dsl_state, [:section_path])

# For option-related errors, get option annotations
option_location = Spark.Dsl.Transformer.get_opt_anno(dsl_state, [:section_path], :option_name)

# Include in DslError
{:error,
 Spark.Error.DslError.exception(
   message: "Detailed error message",
   path: [:section_path],
   module: module,
   location: entity_location  # or section_location, option_location
 )}
```

## Common Gotchas

### 1. Compilation Deadlocks
```elixir
# WRONG - Causes deadlock
def transform(dsl_state) do
  module = get_persisted(dsl_state, :module)
  module.some_function()  # Module isn't compiled yet!
end

# RIGHT - Use DSL state
def transform(dsl_state) do
  entities = get_entities(dsl_state, [:section])
  # Work with DSL state, not module functions
end
```

### 2. Extension Order
- Extensions are processed in order
- Later extensions can modify earlier ones
- Use transformer ordering for dependencies

## Performance Considerations

1. **Compilation Performance**
   - Heavy transformers slow compilation
   - Cache expensive computations with `persist/3`
   - Use verifiers instead of transformers when possible

2. **Runtime Performance**
   - DSL processing has zero runtime overhead
   - Generated code is optimized
   - Info modules cache DSL data efficiently

3. **Memory Usage**
   - DSL state is cleaned up after compilation
   - Runtime footprint is minimal
   - Use structs efficiently in entities

## Summary

Spark enables:
- Clean, declarative DSL syntax
- Compile-time validation and transformation
- Extensible architecture
- Excellent developer experience

When coding with Spark:
1. Think in terms of entities, sections, and extensions
2. Leverage compile-time processing for validation
3. Use transformers for complex logic
4. Test DSLs thoroughly
5. Provide clear error messages with location information
6. Use annotation introspection for better debugging
7. Document your DSLs well


<!-- spark-end -->
<!-- igniter-start -->
## igniter usage
_A code generation and project patching framework_

# Rules for working with Igniter

## Understanding Igniter

Igniter is a code generation and project patching framework that enables semantic manipulation of Elixir codebases. It provides tools for creating intelligent generators that can both create new files and modify existing ones safely. Igniter works with AST (Abstract Syntax Trees) through Sourceror.Zipper to make precise, context-aware changes to your code.

## Available Modules

### Project-Level Modules (`Igniter.Project.*`)

- **`Igniter.Project.Application`** - Working with Application modules and application configuration
- **`Igniter.Project.Config`** - Modifying Elixir config files (config.exs, runtime.exs, etc.)
- **`Igniter.Project.Deps`** - Managing dependencies declared in mix.exs
- **`Igniter.Project.Formatter`** - Interacting with .formatter.exs files
- **`Igniter.Project.IgniterConfig`** - Managing .igniter.exs configuration files
- **`Igniter.Project.MixProject`** - Updating project configuration in mix.exs
- **`Igniter.Project.Module`** - Creating and managing modules with proper file placement
- **`Igniter.Project.TaskAliases`** - Managing task aliases in mix.exs
- **`Igniter.Project.Test`** - Working with test and test support files

### Code-Level Modules (`Igniter.Code.*`)

- **`Igniter.Code.Common`** - General purpose utilities for working with Sourceror.Zipper
- **`Igniter.Code.Function`** - Working with function definitions and calls
- **`Igniter.Code.Keyword`** - Manipulating keyword lists
- **`Igniter.Code.List`** - Working with lists in AST
- **`Igniter.Code.Map`** - Manipulating maps
- **`Igniter.Code.Module`** - Working with module definitions and usage
- **`Igniter.Code.String`** - Utilities for string literals
- **`Igniter.Code.Tuple`** - Working with tuples

<!-- igniter-end -->
<!-- usage-rules-end -->

<!-- markdownlint-enable -->
