# Phase 1: Foundation — Rendering, Enforcement and Layout - Pattern Map

**Mapped:** 2026-09-15
**Files analyzed:** 15 (Wave 0 list from 01-VALIDATION.md + FOUND-13/16/17 file-level work)
**Analogs found:** 6 / 15 (this phase builds tooling, not component code — many files have no
in-repo analog by design; see "No Analog Found" below)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
| --- | --- | --- | --- | --- |
| `lib/mix/tasks/ash_commanded.dump.ex` | mix task (CLI/controller-equivalent) | request-response (invoke → render → print/diff) | `scripts/render_generated.exs` | role-match (script → task promotion) |
| `lib/commanded/transformers/base_transformer.ex` (extended: AST capture flag, `file:`/`line:` metadata) | utility / codegen helper | transform (AST in, module out) | itself — extend in place | exact (same file, D-06/FOUND-18 evolve it) |
| `lib/commanded/transformers/base_transformer.ex#get_module_prefix/1` (FOUND-10 remediation) | utility | transform | itself, lines 22-41 | exact — this is the flagged code, not a template for new code |
| `test/ash_commanded/dump_task_test.exs` | test (integration) | request-response | `test/commanded/transformers/base_transformer_test.exs` | role-match |
| `test/ash_commanded/golden_render_test.exs` | test (integration, golden diff) | file-I/O (read `.golden`, compare) | none in repo — see below | no analog |
| `test/ash_commanded/golden_budget_test.exs` | test (static/unit, size ratchet) | file-I/O + batch (scan all `.golden`) | `scripts/compile_parity.sh`'s "explicit module list, check each" shape | partial (shell → ExUnit port of the enumerate-and-check idea) |
| `test/ash_commanded/credo_checks/no_runtime_string_to_ast_test.exs` | test for custom Credo check | static-analysis | `test/commanded/transformers/base_transformer_test.exs` (as an ExUnit-testing-a-lib-module template only) | partial |
| `lib/ash_commanded/credo_checks/no_runtime_string_to_ast.ex` | custom Credo check (utility, static analysis plugin) | transform (AST in, issues out) | none in repo — no custom Credo checks exist | no analog (see STACK.md for Credo.Check API) |
| `lib/ash_commanded/credo_checks/no_module_name_surgery.ex` | custom Credo check | transform | none in repo, but flagged code lives at `base_transformer.ex:22-41`, `generate_command_modules.ex:99`, `logging_middleware.ex:37,57,75`, `generate_commanded_application.ex:130,135,231-248` | no analog for the check itself; those lines are the fixtures/counter-examples it must classify |
| `test/ash_commanded/seeded_violations_test.exs` | test (meta-test over fixtures) | batch | none in repo | no analog |
| `priv/seeded_violations/*.ex` (5 fixtures) | fixture / fixture resource | n/a (compiled, not run) | `test/support/parity/parity_widget.ex` | role-match (dependency-free, compile-only Ash.Resource) |
| `test/ash_commanded/disable_phase_citation_test.exs` | test (static parse of source comments) | batch/transform | none in repo | no analog |
| `.github/workflows/ci.yml` | CI config | batch (matrix) | none — no CI exists | no analog |
| `.credo.exs` (modified: `plugins:`, `requires:`, `LongQuoteBlocks` config, `ex_dna` wiring) | config | config | itself — extend in place | exact |
| `mix.exs` (modified: `check` alias extended, `ex_dna` dep added) | config | config | itself — extend in place | exact |
| `scripts/compile_parity.sh` (modified: `EXPECTED_MODULES` list grows with D-09 fixtures) | shell script / config | batch | itself — extend in place | exact |
| `AGENTS.md` (new) | documentation | n/a | none — no AGENTS.md exists yet in this repo (CLAUDE.md plays a partial, stale role) | no analog |
| `lib/ash_commanded/` new tree: `resource/{dsl.ex,transformers/,verifiers/,info.ex}`, `domain/{dsl.ex,transformers/,verifiers/,info.ex}` (D-13/14/17 relocation) | DSL extension / transformer / verifier (relocation, no new behavior) | transform | current `lib/commanded/dsl.ex`, `lib/commanded/transformers/*.ex`, `lib/commanded/verifiers/*.ex` (being moved, not templated) | exact — this is a move+rename, not new code needing a pattern |
| Five `# credo:disable-for-this-file` headers re-pointed (D-02) | comment/annotation convention | n/a | the 8 files listed in "Established Patterns" below (verified count: 8, not 5 — see note) | exact |

## Pattern Assignments

### `lib/mix/tasks/ash_commanded.dump.ex` (mix task, request-response)

**Analog:** `scripts/render_generated.exs` (full file read; 78 lines)

**Core rendering pattern to port** (whole file is the template — key excerpt, the `:beam_lib` path for FOUND-03's `--beam` flag):

```elixir
mod = Module.concat([name])

with {:module, _} <- Code.ensure_loaded(mod),
     path when is_list(path) <- :code.which(mod),
     {:ok, {_, [debug_info: {:debug_info_v1, :elixir_erl, {:elixir_v1, map, _}}]}} <-
       :beam_lib.chunks(path, [:debug_info]) do
  defs = Map.get(map, :definitions, [])
  ...
end
```

**Formatter-fallback pattern to reuse verbatim** (D-07's "print full render" path must not crash on
AST that round-trips imperfectly — this is exactly `render_generated.exs`'s `safe_format/1`):

```elixir
defp safe_format(src) do
  try do
    src |> Code.format_string!() |> IO.iodata_to_binary()
  rescue
    _ -> src
  end
end
```

**Note for the planner:** `render_generated.exs` only implements the post-compile `:beam_lib` path
(FOUND-03 / `--beam`). The pre-`Module.create/3` AST path (FOUND-01/02/05, the *default* bare
invocation per D-05/D-07) has **no existing prototype anywhere in this repo** — it depends on
D-06's capture hook being added to `base_transformer.ex`. Do not treat `render_generated.exs` as
covering the primary code path; it covers only the `--beam` flag.

**Task argument/module conventions:** no `Mix.Task` exists in this repo to copy from (`lib/mix/tasks/`
does not exist). Use `Mix.Task` + `Mix.Task.Compiler` idioms from RESEARCH.md/STACK.md (external
precedent — e.g. `spark.cheat_sheets`'s invocation style in `mix.exs:193`, which is the only
existing evidence of a mix task being wired into this project's `aliases`, though its own source
lives in the `spark` dependency, not this repo).

---

### `lib/commanded/transformers/base_transformer.ex` (utility / codegen helper — extend in place)

**Analog:** itself (full file read, 78 lines) — this is the single seam FOUND-18/D-06 attach to.

**`create_module/3` — the exact seam to extend with AST-capture + `file:`/`line:` metadata**
(lines 70-74 as currently written; already routed through by all nine module-creating
transformers per RESEARCH.md's confirmed grep):

```elixir
@spec create_module(module(), Macro.t(), Macro.Env.t()) :: :ok
def create_module(module_name, ast, env) do
  Module.create(module_name, ast, Macro.Env.location(env))
  :ok
end
```

FOUND-18 needs this to set explicit `file:`/`line:` in generated code's metadata (today
`Macro.Env.location(env)` only supplies the transformer's own file/line, not a mapping back to the
DSL declaration). D-06 needs it to conditionally capture `ast` before this call, gated by a flag,
without touching the nine call sites.

**`get_module_prefix/1` — the FOUND-10 collision, lines 22-41 (read in full above):**

```elixir
def get_module_prefix(resource_module) do
  parts = Module.split(resource_module)

  case parts do
    [_single_module] -> resource_module
    multiple_parts -> multiple_parts |> Enum.drop(-1) |> Module.concat()
  end
end
```

This is real `Module.split`/`Module.concat` module-name surgery — the exact pattern FOUND-10's Credo
check must flag elsewhere (e.g. `generate_command_modules.ex:99`) but must NOT force the planner into
an infinite regress on its own infrastructure. Two legitimate resolutions, either is acceptable:
(a) rewrite to derive the prefix via `Spark.Dsl.Transformer.get_persisted/2` instead of raw
`Module.split`, or (b) suppress under a D-01/D-02-style disable naming the phase that removes it.
Existing test to extend, not recreate: `test/commanded/transformers/base_transformer_test.exs`
(full file read, 42 lines) already has a `describe "get_module_prefix/1"` block with 3 cases and a
`describe "create_module/3"` block that asserts the created module loads and its function runs —
add cases for the new `file:`/`line:` metadata assertion and AST-capture flag here.

---

### FOUND-10 false-positive taxonomy (for `lib/ash_commanded/credo_checks/no_module_name_surgery.ex`)

No in-repo analog for the check itself, but the three lookalike uses it must distinguish are all
real, verified code in this repo (grep-confirmed 2026-09-15):

**1. Real defect — deriving a module atom to reference** (`generate_command_modules.ex:99`):

```elixir
Module.concat([app_prefix, "Commands", command_name_str])
```

**2. False positive — building a display string** (`logging_middleware.ex:37,57,75`, all three
identical):

```elixir
command_type = command.__struct__ |> Module.split() |> List.last()
```

**3. False positive — naming a process** (`generate_commanded_application.ex:130,135`):

```elixir
id: Module.concat(unquote(app_module), Supervisor),
...
[strategy: :one_for_one, name: Module.concat(unquote(app_module), Supervisor)]
```

Also note `generate_commanded_application.ex:231-248` has a **fourth**, subtler case worth checking
against real defect #1 (constructing an application module name from a domain module) — likely also
a genuine defect instance, not a false positive; the planner should have the check's test suite
assert on all of these four sites explicitly rather than inventing synthetic examples only.

---

### `test/ash_commanded/dump_task_test.exs` (integration test)

**Analog:** `test/commanded/transformers/base_transformer_test.exs` (structural template only —
`use ExUnit.Case, async: true`, `alias` the module under test, `describe`/`test` blocks per
function). No mix-task-invocation test exists in this repo to copy the "invoke task, assert on
`Mix.shell()` output" idiom from; that pattern must come from ExUnit/Mix conventions directly
(`Mix.Task.run/2` + `Mix.shell(Mix.Shell.Process)` swap is the standard external idiom — see
RESEARCH.md/STACK.md).

---

### `scripts/compile_parity.sh` (extend in place — D-09 growth)

**Analog:** itself (full file read, 68 lines).

**The exact array to extend** as D-09 grows `test/support/parity/`:

```bash
EXPECTED_MODULES=(
  "AshCommanded.TestSupport.Parity.Widget"
  "AshCommanded.TestSupport.Parity.WidgetAggregate"
  "AshCommanded.TestSupport.Parity.Commands.CreateWidget"
  "AshCommanded.TestSupport.Parity.Events.WidgetCreated"
  "AshCommanded.TestSupport.Parity.Projections.WidgetCreated"
  "AshCommanded.TestSupport.Parity.Projectors.WidgetProjector"
)
```

Fixture source to follow for any new parity fixture: `test/support/parity/parity_widget.ex` — a
domain-neutral, dependency-free `Ash.Resource` (defaults to `Ash.DataLayer.Simple`, explicitly
documented as existing "to be compiled, not written to"). New fixtures for D-09/D-10 golden
generation should follow this same shape: minimal `commanded do ... end` block exercising exactly
the DSL surface whose generated output is being golden-tested, nothing else.

---

### `priv/seeded_violations/*.ex` (5 fixtures)

**Analog:** `test/support/parity/parity_widget.ex` (same role: compile-only, dependency-free Ash
resource fixture). Difference: seeded-violation fixtures should each intentionally trip exactly one
gate (FOUND-06 clause-length, FOUND-07 quote-block-length, FOUND-08 runtime reassembly, FOUND-09
runtime `Code.string_to_quoted!`, FOUND-10 module-name surgery) rather than compiling cleanly —
model each on the widget fixture's minimalism but push one dimension over its limit.

---

## Shared Patterns

### `# credo:disable-for-this-file` suppression idiom (D-01/D-02)

**Source files carrying this header today** (verified count: **8**, not the "five files" cited in
CONTEXT.md/REQUIREMENTS.md — re-verify exact count before writing D-02's parser test):

```text
lib/commanded/error.ex
lib/commanded/command_action_mapper.ex
lib/commanded/transformers/generate_projector_modules.ex
lib/commanded/transformers/generate_main_router_module.ex
lib/commanded/transformers/generate_aggregate_module.ex
lib/commanded/transformers/generate_event_handler_modules.ex
lib/commanded/transformers/generate_commanded_application.ex
lib/commanded/transformers/generate_domain_router_module.ex
```

**Apply to:** every gate-disable header touched by D-02 (structured phase citation) and every new
disable added while staging the rewrite (D-01). Read each file's actual header text before writing
FOUND-10/`disable_phase_citation_test.exs` — do not assume a single fixed format; confirm the
current phase-number citation syntax in at least 2-3 of these files first, since CONTEXT.md notes
they "all cite ARCHIVED phase numbers" and D-02 requires re-pointing all of them as a side effect.

### `mix.exs` `check` alias (extend in place, D-09/FOUND-16)

**Source:** `mix.exs:205-213` (excerpted above in full). Ordering rationale is documented inline —
cheapest gate first, `test` spawned in its own `MIX_ENV=test` `cmd` subprocess to avoid polluting
the `:dev` Dialyzer PLT with ExUnit-only modules. Any new gate this phase adds (golden diff, budget
check, seeded-violations meta-test, custom Credo checks) should be inserted into this same list in
increasing-cost order, and CI (`.github/workflows/ci.yml`, new) should invoke this alias rather than
restate its steps — exactly as the existing comment already prescribes for the current steps.

### `.credo.exs` extension points (FOUND-07, FOUND-09, FOUND-10, FOUND-11)

**Source:** `.credo.exs:39` (`plugins: []`), `:44` (`requires: []`), `:128`
(`{Credo.Check.Refactor.LongQuoteBlocks, []}` — inside `enabled:`, opened at `:68`), `:177`
(`{Credo.Check.Design.DuplicatedCode, []}` — inside `disabled:`, opened at `:166`, confirmed
DISABLED per CONTEXT.md's correction). FOUND-07 needs only `{Credo.Check.Refactor.LongQuoteBlocks,
[max_line_count: 40]}` plus deletion of the existing hand-disable on
`generate_aggregate_module.ex`. FOUND-09/FOUND-10 custom checks go in `requires:` (a glob to their
source files, e.g. `"lib/ash_commanded/credo_checks/*.ex"`) and get referenced by module name in
`enabled:`. FOUND-11 (`ex_dna`) is a pure addition to both `plugins:` and `mix.exs` deps — nothing
to disable first, per the corrected D-note.

## No Analog Found

Files/areas with no close match in this repo — planner should build from RESEARCH.md's external
precedent (STACK.md's Credo custom-check mechanics, `Credo.Code.prewalk/2`, `Credo.Test.Case`) rather
than a forced in-repo template:

| File | Role | Data Flow | Reason |
| --- | --- | --- | --- |
| `lib/mix/tasks/ash_commanded.dump.ex` (primary AST-capture path) | mix task | request-response | No mix task exists anywhere in this repo; `render_generated.exs` only covers the `--beam` fallback path, not the default pre-`Module.create/3` path |
| `lib/ash_commanded/credo_checks/no_runtime_string_to_ast.ex` | custom Credo check | transform | No custom Credo checks exist in this repo; `plugins:`/`requires:` are empty and unused today |
| `lib/ash_commanded/credo_checks/no_module_name_surgery.ex` | custom Credo check | transform | Same — no custom check precedent; only the *flagged* code (base_transformer, generate_command_modules, logging_middleware, generate_commanded_application) exists, as fixtures not templates |
| `test/ash_commanded/golden_render_test.exs`, `golden_budget_test.exs` | test (golden-file harness) | file-I/O | No golden-file test harness exists anywhere in this repo (confirmed: no `mneme`/`assert_value`/`.golden` convention present) |
| `test/ash_commanded/seeded_violations_test.exs` | test (meta-test) | batch | No meta-test-over-fixtures pattern exists in this repo |
| `test/ash_commanded/disable_phase_citation_test.exs` | test (source-comment parser) | batch/transform | No source-scanning test exists; nearest cousin is `compile_parity.sh`'s enumerate-and-check shell shape, not an ExUnit analog |
| `.github/workflows/ci.yml` | CI config | batch/matrix | `.github/workflows/` does not exist at all in this repo — author from scratch per D-12/D-16, using `mix.exs`'s `check` alias as the single invocation point |
| `AGENTS.md` | documentation | n/a | Does not exist; CLAUDE.md exists but is explicitly flagged stale/unreliable for this phase and is being reconciled only in Phase 7 |

## Metadata

**Analog search scope:** `lib/commanded/`, `scripts/`, `test/commanded/`, `test/support/parity/`,
`.credo.exs`, `mix.exs`, root of repo for `.github/`, `AGENTS.md`, `lib/mix/tasks/`.
**Files scanned:** ~20 (base_transformer.ex, render_generated.exs, compile_parity.sh, .credo.exs,
mix.exs, base_transformer_test.exs, parity_widget.ex, parity_domain.ex, 8 credo-disable-header
files, generate_command_modules.ex, logging_middleware.ex, generate_commanded_application.ex).
**Pattern extraction date:** 2026-09-15
**Correction to CONTEXT.md/REQUIREMENTS.md:** the "five files" cited as carrying
`# credo:disable-for-this-file` headers is actually **eight** (grep-verified). Re-verify this count
during planning before D-02's test hardcodes an expected count.
