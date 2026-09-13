# Phase 1: Build Integrity - Pattern Map

**Mapped:** 2026-09-12
**Files analyzed:** 20 (edits) + 7 (new)
**Analogs found:** 15 exact/self / 5 external-only / 7 no-analog (greenfield)

This phase is unusual: most work is *uniform deletion across near-identical sites* (the analog
for each guard/mock site is the other three/five sites) or *pure greenfield infrastructure*
(CI, `.credo.exs`, `test/support/`) with **no in-repo analog at all**. Where that is the honest
answer, it is stated plainly below rather than invented.

## File Classification

| File | Role | Data Flow | Closest Analog | Match Quality |
| ------ | ------ | ----------- | ----------------- | ---------------- |
| `lib/commanded/transformers/generate_aggregate_module.ex` (guard site) | transformer | event-driven/codegen | the other 3 guard sites (self-referential) | exact (uniform pattern) |
| `lib/commanded/transformers/generate_projector_modules.ex` (guard + stub) | transformer | event-driven/codegen | `generate_event_handler_modules.ex` (same guard+stub shape) | exact |
| `lib/commanded/transformers/generate_main_router_module.ex` (guard + 2 stubs) | transformer | event-driven/codegen | itself (2 near-identical stub sites), plus projector/event-handler stub shape | exact |
| `lib/commanded/transformers/generate_event_handler_modules.ex` (guard + stub) | transformer | event-driven/codegen | `generate_projector_modules.ex` (identical guard+stub shape) | exact |
| `lib/commanded/transformers/generate_commanded_application.ex:244` (`has_commanded?/0` gate) | transformer | event-driven/codegen | the four guard sites above (same removal shape, but gates a top-level `case`, not a `create_module` call — see note) | role-match |
| `lib/commanded/snapshot_adapter.ex:14-16` (conditional `@behaviour`) | module/adapter | request-response | the six `Code.ensure_loaded?` sites above | role-match |
| `lib/commanded/command_action_mapper.ex` (5 mock sites: `:474,495,537,579,614`) | service (command→action mapper) | CRUD | `execute_create/4`'s real branch (already-correct code at same file, lines 477-484) is the analog for the other four | exact (self-referential) |
| `lib/commanded/command_action_mapper.ex` (`:by_id` bug, lines ~498, 540) | service | CRUD | `execute_read/4`'s real branch (line 582, correct `for_read(action_name)`) — analog within same file | exact |
| `lib/commanded/error.ex:349-361` (`from_commanded_error/1`) | utility (error normalization) | transform | no functional change needed; comment-only cleanup — analog is itself | n/a (comment fix) |
| `lib/commanded/snapshot_store.ex:111` (`IO.puts` in rescue) | service | error-handling | `lib/commanded/middleware/logging_middleware.ex:102-105` | exact |
| `lib/commanded/middleware/base_middleware.ex:18,25,31` (`IO.inspect` in `@moduledoc`) | middleware (doc example) | request-response | `lib/commanded/middleware/logging_middleware.ex:102-105` | exact |
| `mix.exs` (deps, aliases, elixirc_paths, dialyzer/coveralls config) | config | batch | itself (no analog; extends existing `deps/0`, `aliases/0`) | role-match (extend in place) |
| `test/test_helper.exs` (reduce to `ExUnit.start()`) | config/test | batch | itself — target state is simpler than current | n/a (deletion, not analog-copy) |
| `.credo.exs` (new) | config | batch | **no in-repo analog** — none exists | none (greenfield; use Credo's own default template as external reference) |
| `.dialyzer_ignore.exs` (new) | config | batch | **no in-repo analog** | none (greenfield; format dictated by dialyxir README, not this repo) |
| `.github/workflows/ci.yml` (new) | config/CI | batch | **no in-repo analog** — `.github/` does not exist | none (greenfield; `ash-project`'s reusable workflow cannot be reused per STACK.md — see below) |
| `test/support/parity/*.ex` (new, D-19 fixture) | model/fixture | CRUD | the three `use Ash.Domain` test modules below (structure), none has a data layer | role-match (structure only, data layer is new) |
| `test/support/test_domain.ex` + `test/support/widget.ex` (new, D-12/D-13 ETS fixture) | model/fixture | CRUD | `test/commanded/event_handlers_dsl_test.exs:5-11` (`use Ash.Domain` + `use Ash.Resource, extensions: [Dsl]` shape) | role-match (adds data_layer + real actions, which no existing fixture has) |
| `test/support/commanded_app_case.ex` (optional, D-15) | test helper | event-driven | `test/commanded/transformers/commanded_application_integration_test.exs:5-35` (`use Ash.Domain, extensions: [DomainDsl]` + `application do` block) | role-match |
| 7 `with_mock` verifier test files (rewrite per D-17) | test | event-driven (compile-time) | `.planning/research/PITFALLS.md:118-151` D-14 pattern (`Code.compile_string` + `assert_raise`), reproduced below | exact (external doc, not in-repo code, but is the locked pattern) |
| `command_action_mapper_test.exs` + 3 siblings (rewrite per D-17/D-08) | test | CRUD | `test/support/widget.ex` fixture (once built) replaces `resource_module = __MODULE__` | role-match (depends on new fixture) |

## Pattern Assignments

### Guard-site deletions (D-06): `generate_aggregate_module.ex`, `generate_projector_modules.ex`, `generate_main_router_module.ex`, `generate_event_handler_modules.ex`

**Analog:** each other. All four wrap the same call in an identical `unless Application.get_env(:ash_commanded, :skip_*_module_creation, Mix.env() == :test) do ... end` shape around `BaseTransformer.create_module/3`. Delete the `unless` wrapper uniformly at all four, leaving the guarded call unconditional.

**Current shape at all four sites** (verified verbatim):

```elixir
# generate_aggregate_module.ex:136-143
unless Application.get_env(
         :ash_commanded,
         :skip_aggregate_module_creation,
         Mix.env() == :test
       ) do
  BaseTransformer.create_module(aggregate_module, ast, __ENV__)
end
```

```elixir
# generate_projector_modules.ex:109-115  (skip_projector_module_creation)
# generate_main_router_module.ex:124-129 (skip_router_module_creation)
# generate_event_handler_modules.ex:95-100 (skip_event_handler_module_creation)
```

All four are structurally identical except the config key name and the call target
(`aggregate_module`/`projector_module`/domain+main router modules/`event_handler_module`). Delete
the `unless ... do / end` wrapper, keep the inner `BaseTransformer.create_module(...)` call
unconditional, at all four sites in one pass so the four commits stay mechanically uniform.

**`BaseTransformer.create_module/3`** — the chokepoint (unchanged, `lib/commanded/transformers/base_transformer.ex:69-72`):

```elixir
def create_module(module_name, ast, env) do
  Module.create(module_name, ast, Macro.Env.location(env))
  :ok
end
```

### `Code.ensure_loaded?(Commanded)` stub deletions (D-07)

**Analog:** `generate_projector_modules.ex:196-209` and `generate_event_handler_modules.ex:214-227` are byte-for-byte identical in structure — use one to fix the other:

```elixir
# generate_projector_modules.ex:196-209 (identical shape at generate_event_handler_modules.ex:214-227)
if Code.ensure_loaded?(Commanded) do
  quote do
    @moduledoc unquote(moduledoc)
    use Commanded.Event.Handler,
      application: unquote(application_name),
      name: unquote(projector_name)
  end
else
  quote do
    @moduledoc unquote(moduledoc)
    def init(config), do: {:ok, config}
  end
end
```

Fix: delete the `if/else`, keep only the `use Commanded.Event.Handler, ...` branch unconditionally.

`generate_main_router_module.ex` has **two** near-identical stub sites (domain router at
`:215-235`, main router at `:345-365`) — the more dangerous one, since its else-branch is a
silent accept-everything stub:

```elixir
# generate_main_router_module.ex:215-235 and :345-365 (near-identical)
if Code.ensure_loaded?(Commanded) do
  quote do
    @moduledoc unquote(moduledoc)
    use Commanded.Commands.Router
    unquote_splicing(dispatch_handlers)   # or router_body at the second site
  end
else
  quote do
    @moduledoc unquote(moduledoc)
    def dispatch(command) do
      {:ok, command}
    end
  end
end
```

Fix identically at both sites: delete the `if/else`, keep only the `use Commanded.Commands.Router`
branch. This is D-06's Integration Points warning made concrete — do this together with making
`:commanded` a hard dependency (D-01), not separately, since deleting the guard without the
dependency present breaks compilation.

`generate_commanded_application.ex:243-245` — the sixth, structurally different site (gates
*whether the whole module is generated*, not a stub swap):

```elixir
defp has_commanded? do
  Code.ensure_loaded?(Commanded.Application)
end
```

Read this session: `has_commanded?/0` feeds a top-level `case has_commanded?() do true -> ...
; false -> {:ok, dsl} end` in `transform/1` — confirm the `false` branch and delete the whole
conditional, not just this helper, leaving only the `true` branch's body.

`snapshot_adapter.ex:14-16` — the last site, a conditional `@behaviour`:

```elixir
if Code.ensure_loaded?(Commanded.Aggregates.Aggregate.Snapshotter) do
  @behaviour Commanded.Aggregates.Aggregate.Snapshotter
end
```

Fix: make the `@behaviour` declaration unconditional (drop the `if`).

### `CommandActionMapper` mock removal + `:by_id` fix (D-08)

**Analog:** `execute_create/4`'s real branch (lines 477-484) is already correct and is the
template the other four functions should converge toward; `execute_read/4`'s real branch
(line 582) is the analog for the correct `for_read` call the update/destroy branches are missing.

**Current shape, repeated 5x** (`execute_create/4`, `execute_update/5`, `execute_destroy/5`,
`execute_read/4`, `execute_custom/4`):

```elixir
# execute_create/4, lines 471-485 — pattern repeats at 492-524, 534-566, 576-604, 610-638
if Mix.env() == :test do
  {:ok, %{action: action_name, params: params, context: context}}
else
  changeset = Ash.Changeset.new(resource)
  changeset = Ash.Changeset.for_action(changeset, action_name, params)
  changeset = Ash.Changeset.set_context(changeset, context)

  case Ash.create(changeset) do
    {:ok, _} = success -> success
    {:error, error} -> {:error, error}
  end
end
```

Fix: delete the `if Mix.env() == :test do ... else` wrapper at all five sites, keep only the
`else` branch's body unconditionally. Optionally modernize `Ash.Changeset.new/1 |> for_action/4`
to `Ash.Changeset.for_create/4` per RESEARCH.md's "State of the Art" note — not required, low-risk
opportunistic cleanup since every line is already touched.

**The `:by_id` bug**, present at `execute_update/5:498` and `execute_destroy/5:540`:

```elixir
# BEFORE
query = resource |> Ash.Query.for_read(:by_id) |> Ash.Query.set_context(context)

# AFTER — matches execute_read/4's own correct pattern (line 582: for_read(action_name))
# and matches the test fixture's `defaults [:read, ...]` action name
query = resource |> Ash.Query.for_read(:read) |> Ash.Query.set_context(context)
```

Must be fixed in the same commit as the mock deletion — the first real update/destroy test will
otherwise raise `Ash.Error.Invalid.NoSuchAction` immediately.

`error.ex:349-361` — comment-only issue, no functional mock:

```elixir
def from_commanded_error(error) do
  # Mock implementation for tests   <-- stale/misleading comment, delete it
  case error do
    %{message: message} -> aggregate_error(message, context: %{source: :commanded})
    _ -> aggregate_error("Unknown Commanded error", context: %{source: :commanded, error: inspect(error)})
  end
end
```

This is real, working code (a duck-typed fallback), not a `Mix.env()` branch — just remove the
misleading comment; do not restructure the logic without the spike RESEARCH.md's Open Question 2
recommends.

### Logging fixes (D-09, D-10)

**Analog:** `lib/commanded/middleware/logging_middleware.ex:102-105` — the correct dispatch
pattern both fixes must conform to:

```elixir
defp log(:debug, message), do: Logger.debug(message)
defp log(:info, message), do: Logger.info(message)
defp log(:warn, message), do: Logger.warning(message)
defp log(:error, message), do: Logger.error(message)
```

`snapshot_store.ex:109-112` (D-09 — keep `:error` return, only swap the log call):

```elixir
rescue
  e ->
    IO.puts("Error retrieving snapshot: #{inspect(e)}")   # -> Logger.error(...)
    :error
end
```

Requires `require Logger` at module top if not already present — check before editing.
Precedent for `require Logger` + level-appropriate call **inside generated AST** already exists
at `lib/commanded/transformers/generate_aggregate_module.ex:541,636` (`Logger.warning`/
`Logger.error`), confirming this is an established, not novel, pattern in this codebase.

`base_middleware.ex:18,25,31` (D-10 — inside `@moduledoc`, not executable code, but must still
change per SC1's grep):

```elixir
# current @moduledoc example code block
IO.inspect(command, label: "Dispatching command")
IO.inspect(result, label: "Command succeeded")
IO.inspect(reason, label: "Command failed")
```

Replace each with the equivalent `Logger.debug/1` call using the same `logging_middleware.ex`
dispatch shape (e.g. `Logger.debug("Dispatching command: #{inspect(command)}")`).

### Test infrastructure — greenfield with partial-shape analogs (D-12, D-13, D-19)

**No file in the repo today declares a data layer on a test fixture.** The three existing
`use Ash.Domain` test modules are the closest starting shapes for structure only:

```elixir
# test/commanded/event_handlers_dsl_test.exs:5-19 — structural analog (no data layer)
defmodule TestDomain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false
  resources do
    resource AshCommanded.Commanded.EventHandlersDslTest.TestResource
  end
end

defmodule TestResource do
  @moduledoc false
  use Ash.Resource,
    domain: TestDomain,
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id
    attribute :name, :string
  end

  commanded do
    events do
      event :test_registered do
        fields([:id, :name])
      end
    end
  end
end
```

The new `test/support/widget.ex` (D-12/D-13) must add `data_layer: Ash.DataLayer.Ets`, an `ets do
private? true end` block, and `actions do defaults [:read, :destroy, create: [...], update: [...]]
end` — none of which exists anywhere in this repo today. Treat RESEARCH.md's Pattern 2 code block
as the concrete template (not reproduced twice here); this PATTERNS.md's contribution is
identifying that **no closer in-repo analog exists** so the planner does not waste time searching
further.

`test/commanded/transformers/commanded_application_integration_test.exs:5-35` is the structural
analog for the D-15 `test/support/commanded_app_case.ex` helper (shows the `use Ash.Domain,
extensions: [AshCommanded.Commanded.DomainDsl]` + `commanded do application do ... end end` shape)
— but its `if Code.ensure_loaded?(Commanded.Application) do ... end` wrapper around the `commanded
do` block, and its `@tag :skip_if_no_commanded` on every test, are both dead-by-construction
patterns this phase deletes (D-07, D-16), not patterns to copy forward.

### Compile-time DSL rejection tests (D-14, TEST-02) — rewriting the 7 `with_mock` verifier files

**No in-repo analog for the target pattern exists yet** — the 7 files currently use
`with_mock`/`import Mock` against `Spark.Dsl.Verifier`'s `get_persisted`/`get_entities`, not
`Code.compile_string`. The locked replacement pattern is external (from
`.planning/research/PITFALLS.md:118-151`, reproduced verbatim in RESEARCH.md's "Pattern 1"):

```elixir
test "duplicate command names are rejected" do
  assert_raise Spark.Error.DslError, ~r/command names are duplicated/, fn ->
    defmodule Module.concat([:"Test#{System.unique_integer([:positive])}", DuplicateCmd]) do
      use Ash.Resource, domain: nil, extensions: [AshCommanded.Commanded.Dsl]
      attributes do
        uuid_primary_key :id
      end
      commanded do
        commands do
          command :register_user, do: fields([:id])
          command :register_user, do: fields([:id])
        end
      end
    end
  end
end
```

Each of the 7 files' *own* verifier-under-test supplies the DSL shape and the distinguishing
regex fragment — read each verifier's error message (e.g.
`test/commanded/verifiers/validate_command_names_test.exs:39` already asserts `error.message =~
"command names are duplicated"`) to build the regex, rather than guessing.

### CI and tooling — no in-repo analog (D-20 through D-25)

`.github/workflows/ci.yml`, `.credo.exs`, `.dialyzer_ignore.exs` have **no in-repo analog** —
`.github/` does not exist, no lint/type-check config exists anywhere in this repo. State this
plainly to the planner rather than inventing a fabricated "closest file."

- `ash-project/ash`'s own reusable CI workflow is the nearest *external* reference, but per
  `.planning/research/STACK.md`'s own finding (cited in CONTEXT.md's canonical refs), it cannot be
  reused directly from `accountex-org` — the planner must write `ci.yml` from scratch using
  `erlef/setup-beam` directly (matrix shape and job list are in RESEARCH.md §CI Matrix / §D-20).
- `.credo.exs`: no template exists in-repo; base it on Credo's own default generated file
  (`mix credo.gen.config` output, or the default template referenced in RESEARCH.md's Package
  Legitimacy Audit), then add the D-21-required stated-reason disables for the two oversized
  modules.
- `.dialyzer_ignore.exs`: no template exists; format is dictated externally by dialyxir's README
  (RESEARCH.md's "Dialyzer Specifics" section has the exact three-tuple/regex shape) — seed it by
  running `mix dialyzer --format ignore_file` after the first real run, do not hand-write entries.

`mix.exs` — the one file with a genuine in-repo analog: **itself**. Current `deps/0` (verified
this session):

```elixir
defp deps do
  [
    {:ash, "~> 3.0"},
    {:sourceror, "~> 1.8", only: [:dev, :test]},
    {:spark, "~> 2.3"},
    {:igniter, "~> 0.5", only: [:dev, :test]},
    {:mock, "~> 0.3.0", only: [:test]},
    {:ex_doc, "~> 0.30", only: [:dev, :test], runtime: false}
  ]
end
```

and current `aliases/0`:

```elixir
defp aliases do
  [
    docs: ["docs", &copy_images/1],
    "gen.docs": ["spark.cheat_sheets", "docs"],
    "spark.cheat_sheets": "spark.cheat_sheets --extensions AshCommanded.Commanded.Dsl"
  ]
end
```

Extend both in place per D-01/D-02/D-03/D-04/D-05/D-18/D-21/D-22/D-23/D-25 (the deps and alias
additions in RESEARCH.md's Standard Stack section) — no `elixirc_paths/1` function exists yet;
add it fresh per the Cross-Env Compile Parity mechanism (D-19):

```elixir
defp elixirc_paths(:test), do: ["lib", "test/support"]
defp elixirc_paths(:dev), do: ["lib", "test/support/parity"]
defp elixirc_paths(_), do: ["lib"]
```

and reference it from `project/0` as `elixirc_paths: elixirc_paths(Mix.env())`.

### `test/test_helper.exs` (D-15, D-16)

**Analog:** itself — the target state is simpler than the current file, not modeled on another
file. Current (verified, full file):

```elixir
commanded_available? = Code.ensure_loaded?(Commanded.Application)
exclude_tags = if commanded_available?, do: [:skip], else: [:skip, :skip_if_no_commanded]
ExUnit.configure(exclude: exclude_tags, trace: false, seed: 0)
ExUnit.start()
```

Target: `ExUnit.start()` only. Delete `commanded_available?`, `exclude_tags`, the
`ExUnit.configure/1` call entirely, and remove `@tag :skip_if_no_commanded` from all tests that
carry it (grep to find all sites — RESEARCH.md's D-17 triage names
`commanded_application_integration_test.exs` as one confirmed carrier; there may be others).

## Shared Patterns

### Logger dispatch convention

**Source:** `lib/commanded/middleware/logging_middleware.ex:102-105`
**Apply to:** `snapshot_store.ex:111` (D-09), `base_middleware.ex:18,25,31` (D-10)

```elixir
defp log(:debug, message), do: Logger.debug(message)
defp log(:info, message), do: Logger.info(message)
defp log(:warn, message), do: Logger.warning(message)
defp log(:error, message), do: Logger.error(message)
```

### `require Logger` inside generated AST (precedent for logging in codegen, not directly touched this phase but confirms the practice is established)

**Source:** `lib/commanded/transformers/generate_aggregate_module.ex:541,636`

### Guard/stub deletion uniformity

**Source:** the four `unless Application.get_env(:ash_commanded, :skip_*_module_creation, ...)` sites and the six `Code.ensure_loaded?(Commanded*)` sites are each other's analogs — apply the same mechanical edit shape at every site in one pass rather than reasoning about each independently, per CONTEXT.md's own "Integration Points" note that D-06/D-07 and D-01 are mutually dependent.

### `BaseTransformer.create_module/3` chokepoint

**Source:** `lib/commanded/transformers/base_transformer.ex:69-72`
**Apply to:** confirms all four D-06 guard removals are safe — every guarded call routes through this one function, so uniform deletion cannot miss a differently-shaped call site.

## No Analog Found

| File | Role | Data Flow | Reason |
| ------ | ------ | ----------- | -------- |
| `.github/workflows/ci.yml` | config/CI | batch | `.github/` does not exist in this repo; greenfield. External reference (`ash-project`'s reusable workflow) explicitly not reusable per STACK.md — write from scratch using `erlef/setup-beam` per RESEARCH.md §CI Matrix |
| `.credo.exs` | config | batch | No lint config exists in-repo; base on Credo's own default template, then add D-21's stated-reason disables |
| `.dialyzer_ignore.exs` | config | batch | No type-check config exists in-repo; format dictated by dialyxir's README, seed via `mix dialyzer --format ignore_file` |
| `test/support/` (entire directory) | test fixtures | CRUD | Does not exist; `elixirc_paths(:test)` itself doesn't exist yet (`mix.exs` has no `elixirc_paths/1` function) |
| `test/support/parity/*.ex` | model/fixture | CRUD | D-19 dependency-free dual-env fixture; no existing fixture in this repo has a data layer or is dependency-free by design (all existing fixtures are `defmodule`-inline with `domain: nil`, none needs to compile under `:dev`) |
| `test/support/commanded_app_case.ex` | test helper | event-driven | Optional per Claude's discretion; no existing helper wraps unique-named Commanded app startup — every existing test either hardcodes a module name or is gated by the dead `:skip_if_no_commanded` tag |
| `mix setup` / `mix check` aliases | config | batch | Neither alias exists; `run_tests.sh` (the closest existing "how to run things" artifact) is recommended for deletion once `mix check` lands, per RESEARCH.md's explicit finding that it never runs format/Credo/Dialyzer and risks becoming a second drifting convention |

## Metadata

**Analog search scope:** `lib/commanded/`, `lib/commanded/transformers/`, `lib/commanded/middleware/`, `lib/commanded/verifiers/`, `test/commanded/`, `test/commanded/transformers/`, `config/`, `mix.exs`, repo root (`.github/`, `.credo.exs`, `.dialyzer_ignore.exs`, `run_tests.sh`)
**Files scanned:** ~25 read directly this session (guard/stub/mock sites, logging sites, test fixtures, config, mix.exs), cross-referenced against RESEARCH.md's own verified line numbers
**Pattern extraction date:** 2026-09-12
**Tracked-source gate:** all named analog paths confirmed via `git ls-files` this session (`config/config.exs`, `lib/commanded/command_action_mapper.ex`, `lib/commanded/error.ex`, `run_tests.sh`, `test/commanded/verifiers/integration_test.exs`, `test/test_helper.exs`) — no gitignored mirrors encountered; this repo has no `.gsd/capabilities/` mirror structure
