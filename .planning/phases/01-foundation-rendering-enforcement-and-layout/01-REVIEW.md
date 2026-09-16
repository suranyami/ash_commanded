---
phase: 01-foundation-rendering-enforcement-and-layout
reviewed: 2026-09-16T00:00:00Z
depth: standard
files_reviewed: 52
files_reviewed_list:
  - .credo.exs
  - .dialyzer_ignore.exs
  - .github/workflows/ci.yml
  - AGENTS.md
  - cheatsheets/AshCommanded.Resource.Dsl.cheatmd
  - lib/ash_commanded/command_action_mapper.ex
  - lib/ash_commanded/credo_checks/exemption.ex
  - lib/ash_commanded/credo_checks/no_module_name_surgery.ex
  - lib/ash_commanded/credo_checks/no_runtime_string_to_ast.ex
  - lib/ash_commanded/domain/dsl.ex
  - lib/ash_commanded/domain/info.ex
  - lib/ash_commanded/domain/transformers/generate_commanded_application.ex
  - lib/ash_commanded/dump/golden.ex
  - lib/ash_commanded/dump/lint.ex
  - lib/ash_commanded/dump/render.ex
  - lib/ash_commanded/error.ex
  - lib/ash_commanded/parameter_transformer.ex
  - lib/ash_commanded/resource/dsl.ex
  - lib/ash_commanded/resource/info.ex
  - lib/ash_commanded/resource/transformers/base_transformer.ex
  - lib/ash_commanded/resource/transformers/collect_parameter_transforms.ex
  - lib/ash_commanded/resource/transformers/collect_parameter_validations.ex
  - lib/ash_commanded/resource/transformers/generate_aggregate_module.ex
  - lib/ash_commanded/resource/transformers/generate_command_modules.ex
  - lib/ash_commanded/resource/transformers/generate_domain_router_module.ex
  - lib/ash_commanded/resource/transformers/generate_event_handler_modules.ex
  - lib/ash_commanded/resource/transformers/generate_event_modules.ex
  - lib/ash_commanded/resource/transformers/generate_main_router_module.ex
  - lib/ash_commanded/resource/transformers/generate_projection_modules.ex
  - lib/ash_commanded/resource/transformers/generate_projector_modules.ex
  - lib/ash_commanded/resource/verifiers/validate_command_names.ex
  - lib/ash_commanded/resource/verifiers/validate_event_handler_events.ex
  - lib/ash_commanded/resource/verifiers/validate_event_names.ex
  - lib/ash_commanded/resource/verifiers/validate_projection_events.ex
  - lib/mix/tasks/ash_commanded.dump.ex
  - mix.exs
  - mix.lock
  - priv/seeded_violations/module_name_surgery.ex
  - priv/seeded_violations/oversized_clause.ex
  - priv/seeded_violations/oversized_quote.ex
  - priv/seeded_violations/runtime_reassembly.ex
  - priv/seeded_violations/string_to_ast.ex
  - scripts/compile_parity.sh
  - test/ash_commanded/credo_checks/no_module_name_surgery_test.exs
  - test/ash_commanded/credo_checks/no_runtime_string_to_ast_test.exs
  - test/ash_commanded/disable_phase_citation_test.exs
  - test/ash_commanded/dump_task_test.exs
  - test/ash_commanded/golden_budget_test.exs
  - test/ash_commanded/golden_render_test.exs
  - test/ash_commanded/info_test.exs
  - test/ash_commanded/seeded_violations_test.exs
  - test/ash_commanded/transformers/base_transformer_test.exs
  - test/golden/README.md
  - test/support/parity/parity_widget.ex
  - test/test_helper.exs
  - usage-rules.md
findings:
  critical: 3
  warning: 5
  info: 2
  total: 10
status: issues_found
---

# Phase 01: Code Review Report

**Reviewed:** 2026-09-16
**Depth:** standard
**Files Reviewed:** 52
**Status:** issues_found

## Summary

Reviewed the phase's rendering/enforcement foundation (`lib/ash_commanded/dump/`, the two custom
Credo checks and their shared `Exemption` helper, the `.Info` modules, the disable-citation and
seeded-violation test suites, CI, and `mix.exs`'s packaging logic), plus the runtime modules
pulled in by the `lib/commanded/` → `lib/ash_commanded/` relocation.

The high-value areas named in the review brief turned out to be exactly where the real problems
are. `AshCommanded.Dump.Golden.measure/1`'s KeyError crash (the one the brief said had "already
been found and worked around") is **not actually fixed** — it is fixed only in the sense that
every current caller happens to avoid the input shape that triggers it; a reproduction is given
below. The `Exemption` module's substring marker-matching has already produced a second, live
occurrence of the marker text in `base_transformer.ex`'s own moduledoc, and the regression test
written specifically to police "exactly one occurrence" does not actually count occurrences —
it counts files — so it passes without ever detecting the duplicate that already exists. A
security-relevant `String.to_atom/1` call on caller-supplied command parameter data was also
found in scope (`parameter_transformer.ex`), reachable from ordinary command dispatch.

Several additional issues were found in code adjacent to the phase's core work (a stale
pre-rename module reference, two DSL-collection transformers that silently ignore their own
input and substitute a hardcoded stub, and a test whose own moduledoc asserts a guarantee the
test file never actually checks). None of the findings below duplicate the deliberately-seeded
violations, the FOUND-18 `create_module/4` gap, the disabled `Design.AliasUsage` check, the 17
`gsd-disable-until-phase` citations, or the `base_transformer.ex` namespace-derivation exemption
itself — all of those are working as documented and were treated as ground truth, not defects.

## Critical Issues

### CR-01: `AshCommanded.Dump.Golden.measure/1` crashes on the exact clause shape its own docstring discusses

**File:** `lib/ash_commanded/dump/golden.ex:116-129`

**Issue:** `measure_clause_spans/1` reads `meta[:end][:line]` unconditionally via
`Keyword.fetch!(meta, :end)`. A `def`/`defp` clause written with the one-line `do:` shorthand
(`def foo(x), do: x + 1`) carries **no `:end` key at all** in its AST metadata (Elixir only emits
`:end` for the block `do ... end` form) — `Keyword.fetch!/2` raises `KeyError` for exactly this
shape. Confirmed by direct reproduction:

```text
iex> AshCommanded.Dump.Golden.measure("defmodule Foo do\n  def bar, do: :ok\nend\n")
** (KeyError) key :end not found in: [end_of_expression: [...], line: 2, column: 3]
```

This is precisely the crash class the module's own docstring says motivated the switch away from
a postwalk-min/max approach ("bare literals carry no line metadata"), but the fix only handles
*that* problem, not the sibling one: a clause using `do:` shorthand has no `:end` metadata at
all. It currently never fires because every committed golden is produced exclusively through
`Render.to_source/2` → `Macro.to_string/1` → `Code.format_string!/1`, and `Macro.to_string/1`
*always* expands `do:` shorthand into block form on the way out — so no golden file this
pipeline writes can ever contain the trigger shape. But `Golden.measure/1` is a public function
called directly by both `mix ash_commanded.dump` and `golden_budget_test.exs`'s `assert_within_budget!/1`
against *any* `.golden` file discovered on disk, including a hand-edited one — the golden
workflow's own README explicitly tells a human to hand-edit a golden's header line when growth
is intentional, so hand-editing golden content is not outside the workflow's contemplated usage.
A single one-line helper clause added to any future golden (accidentally or deliberately) turns
into an opaque `KeyError` crashing `mix test`/`mix check` instead of a clear budget-exceeded
message.

**Fix:**

```elixir
defp measure_clause_spans(quoted) do
  {_ast, spans} =
    Macro.prewalk(quoted, [], fn
      {kind, meta, _args} = node, acc when kind in [:def, :defp] ->
        start_line = Keyword.fetch!(meta, :line)
        end_line = clause_end_line(meta, start_line)
        {node, [end_line - start_line + 1 | acc]}

      node, acc ->
        {node, acc}
    end)

  spans
end

# `:end` metadata is absent for `do:` shorthand clauses (`def foo(x), do: expr`) — they have no
# `end` token to carry a line for. Fall back to the clause's own start line so a shorthand
# clause measures as span 1 instead of crashing.
defp clause_end_line(meta, start_line) do
  case Keyword.fetch(meta, :end) do
    {:ok, end_meta} -> Keyword.fetch!(end_meta, :line)
    :error -> start_line
  end
end
```

Add a regression test feeding `Golden.measure/1` a body containing a `do:`-shorthand clause
directly (not routed through `Render.to_source/2`), asserting it returns a budget instead of
raising.

### CR-02: `Exemption`'s substring marker match has already produced an undetected second occurrence, and the test built to police that is checking the wrong thing

**Files:** `lib/ash_commanded/credo_checks/exemption.ex:37-48`,
`lib/ash_commanded/resource/transformers/base_transformer.ex:20,50`,
`test/ash_commanded/credo_checks/no_module_name_surgery_test.exs:168-179`,
`test/ash_commanded/credo_checks/no_runtime_string_to_ast_test.exs:85-96`

**Issue:** `Exemption.exempted?/2` finds "marker lines" by plain `String.contains?/2` against
*every* line in the file, not just `#`-comment lines. `base_transformer.ex`'s own moduledoc
explains the exemption in prose and, in doing so, quotes the marker's literal text on line 20
("...is deliberately exempt via the `# ash_commanded:namespace-derivation` marker below"). That
line is itself a `marker_line?/1` hit, in addition to the real marker comment on line 50:

```text
$ grep -n "ash_commanded:namespace-derivation" lib/ash_commanded/resource/transformers/base_transformer.ex
20:  that shape, and is deliberately exempt via the `# ash_commanded:namespace-derivation` marker
50:  # ash_commanded:namespace-derivation
```

This is exactly the self-exemption failure mode the project already knows about and warns
against elsewhere — `priv/seeded_violations/module_name_surgery.ex`'s own comment says "do not
paste the marker's literal text into this comment block, even to describe it, or
`Exemption.exempted?/2`'s plain substring search will silently exempt this fixture" — but the
same mistake was made in the one real production file the marker actually protects.

It happens to be harmless *today* only by coincidence: both the doc-text occurrence (line 20)
and the real marker (line 50) resolve to the same enclosing function
(`get_module_prefix/1`, the next `def` after either line), so no other function is
accidentally exempted. But the regression test both credo-check test suites run
("appears in exactly one function across all of lib/") does not actually verify that:

```elixir
count =
  "lib" |> Path.join("**/*.ex") |> Path.wildcard() |> Enum.map(&File.read!/1)
  |> Enum.count(&String.contains?(&1, Exemption.marker()))

assert count == 1
```

`Enum.count/2` here counts *files* containing the marker at least once, not *occurrences* of the
marker. A file with the marker text appearing twice (as `base_transformer.ex` already does)
still counts as `1`. Confirmed by running the suite: both test files pass in full (14/14) despite
the duplicate already existing. Nothing would catch a future edit that mentions the marker in a
docstring positioned before a *different*, unrelated function — that edit would silently exempt
real violations in that function from both `NoModuleNameSurgery` and `NoRuntimeStringToAst`,
and the "exactly one occurrence" test would keep passing.

**Fix:** Two independent fixes, both needed:

1. Reword `base_transformer.ex`'s moduledoc so it does not reproduce the marker's literal text
   (e.g. "...is deliberately exempt via the marker `Exemption.marker/0` names" without quoting
   the string), removing the accidental duplicate.
2. Fix the regression test to count occurrences, not files, so a future duplicate is caught even
   when it happens to be harmless:

   ```elixir
   count =
     "lib" |> Path.join("**/*.ex") |> Path.wildcard() |> Enum.map(&File.read!/1)
     |> Enum.map(&count_occurrences(&1, Exemption.marker()))
     |> Enum.sum()

   assert count == 1
   ```

   Consider also tightening `marker_line?/1` itself to require the marker appear as a `#`
   comment (`^\s*#.*ash_commanded:namespace-derivation`) rather than matching prose anywhere in
   the file, which would have prevented this specific instance entirely.

### CR-03: `String.to_atom/1` on caller-supplied command parameter data — atom-exhaustion DoS reachable from ordinary command dispatch

**File:** `lib/ash_commanded/parameter_transformer.ex:291-292`

**Issue:**

```elixir
defp cast_value(value, :atom) when is_atom(value), do: {:ok, value}
defp cast_value(value, :atom) when is_binary(value), do: {:ok, String.to_atom(value)}
```

`cast_value/2` backs the `cast field, :atom` transform declared in a resource's
`transform_params do ... end` block, applied by `ParameterTransformer.transform_params/2`, which
is invoked from `AshCommanded.CommandActionMapper.execute_action_internal/11` on every dispatched
command whose command definition declares such a cast. The value being cast is a **command
parameter** — data that, in any real Commanded application, ultimately originates from an
external caller (an API request, a form submission, another service). Atoms are never garbage
collected in the BEAM; converting an unbounded stream of caller-controlled strings to atoms via
`String.to_atom/1` (rather than `String.to_existing_atom/1`) is the textbook atom-table
exhaustion DoS, and it sits directly on the command-dispatch hot path this library exists to
support.

**Fix:**

```elixir
defp cast_value(value, :atom) when is_binary(value) do
  {:ok, String.to_existing_atom(value)}
rescue
  ArgumentError -> {:error, "Unknown atom value: #{inspect(value)}"}
end
```

`String.to_existing_atom/1` only succeeds for atoms already known to the runtime (module names,
declared field values, etc.), which is the correct trust boundary for a value being cast from
untrusted external input. If the DSL genuinely needs to mint new atoms from caller data, that
requirement needs an explicit, bounded allow-list, not `String.to_atom/1` on arbitrary strings.

## Warnings

### WR-01: `CollectParameterTransforms`/`CollectParameterValidations` ignore their own DSL input and substitute a hardcoded stub

**Files:** `lib/ash_commanded/resource/transformers/collect_parameter_transforms.ex:21-42`,
`lib/ash_commanded/resource/transformers/collect_parameter_validations.ex:21-40`

**Issue:** Both transformers walk every command's `transform_params`/`validate_params` DSL
blocks and then discard whatever was actually declared inside them, replacing it with a fixed
literal list ("Hard-code a minimal set for testing purposes until DSL is fully complete" /
"For testing purposes, provide a minimal set of validations"):

```elixir
transform_params = [
  {:map, [:name, [to: :full_name]]},
  {:cast, [:age, :integer]},
  {:transform, [:email, &String.downcase/1]},
  {:default, [:status, [value: "active"]]}
]
```

Any command anywhere that declares a `transform_params`/`validate_params` block — regardless of
what it actually contains — silently gets this same stub set applied instead. This produces
plausible-looking but *wrong* output with no error signal: e.g. a command that declares
`map :user_id, to: :owner_id` inside `transform_params` will not get that rename; it will instead
get `:name`→`:full_name`, `:age` cast to integer, `:email` downcased, and `:status` defaulted to
`"active"`, whatever the resource's actual attributes are. This is qualitatively different from
(and unlike) the sibling generator debt in the same directory: those all carry a
`# gsd-disable-until-phase:` citation naming the phase that owns the rewrite; these two do not,
so nothing currently tracks this as known, staged debt.

**Fix:** Either wire these transformers to actually read the DSL block's real declarations
(the entities under `[:transform_params]`/`[:validate_params]` already carry the real spec —
`Enum.flat_map(transform_blocks, fn block -> real_spec_from(block) end)` instead of discarding
`block` via `fn _transform_block -> ... end`), or, if this is intentionally a placeholder ahead
of a later phase, give it the same `gsd-disable-until-phase:` citation and roadmap tracking every
other known-incomplete transformer in this directory already has, so `disable_phase_citation_test.exs`
and the roadmap can hold it accountable the same way.

### WR-02: `seeded_violations_test.exs`'s moduledoc claims an assertion that does not exist in the file

**File:** `test/ash_commanded/seeded_violations_test.exs:1-17`

**Issue:** The moduledoc states the fixtures are safe because they live "on no `elixirc_paths`
entry and swept by no `.credo.exs` `included:` glob (**asserted directly below**)". No such
assertion exists anywhere in this file — it was verified against `mix.exs`'s `elixirc_paths/1`
and `.credo.exs`'s `included:` list by direct inspection during this review, not by any test.
Today those two configs genuinely do exclude `priv/`, so nothing is currently broken — but the
review brief's own high-value-area guidance for this phase specifically asks whether the seeded
violations "could accidentally become compiled, linted, or shipped," and right now nothing in
the test suite would catch either config drifting to include `priv/` in the future; the claim in
the docstring that this is checked is simply false.

**Fix:** Add the assertion the docstring already claims exists:

```elixir
test "priv/seeded_violations is on no elixirc_paths entry and swept by no .credo.exs included: glob" do
  refute Enum.any?(
           Mix.Project.config()[:elixirc_paths] ++
             for env <- [:dev, :test, :prod], do: elixirc_paths_for(env),
           &String.starts_with?(&1, "priv")
         )
  # plus a check against .credo.exs's `files.included` list, e.g. by parsing the file or by
  # invoking `Credo.Sources.find/2` against the seeded fixtures directory and asserting it
  # returns [].
end
```

(Adapt to however this project prefers to introspect `elixirc_paths`; the point is that the
docstring's claim needs a real assertion behind it, not that this exact snippet is final.)

### WR-03: Stale pre-rename module reference in `domain/dsl.ex`'s own moduledoc

**File:** `lib/ash_commanded/domain/dsl.ex:35`

**Issue:** `# The commanded do application do ... end block is processed by Commanded.Dsl, which
stores config at [:commanded, :application] for our transformer to read.` No module named
`Commanded.Dsl` exists anywhere in this tree (`grep -rn "^defmodule Commanded\." lib/` returns
nothing); the module that actually declares and stores the `:application` section is
`AshCommanded.Resource.Dsl` (confirmed at `lib/ash_commanded/resource/dsl.ex:93-100`). This is a
small but real leftover from the "everything relocated from `lib/commanded/` to
`lib/ash_commanded/{resource,domain}/` with modules renamed" claim this phase makes about itself
— the rename sweep missed at least this one comment.

**Fix:**

```elixir
# The `commanded do application do ... end` block is processed by AshCommanded.Resource.Dsl,
# which stores config at [:commanded, :application] for our transformer to read.
```

### WR-04: `ParameterTransformer.apply_transform/2` silently swallows exceptions from user-supplied transform functions

**File:** `lib/ash_commanded/parameter_transformer.ex:174-227`

**Issue:** The `:compute`, `:transform`, `:default`, and `:custom` clauses of `apply_transform/2`
each end in a bare `rescue _ -> params`, discarding *any* exception raised by a caller-supplied
function (a typo causing `KeyError`, a `nil` field causing `ArithmeticError`, etc.) and silently
returning the input unchanged, with no logging and no way for the caller to know a transform
failed. Contrast with `CommandActionMapper`'s own rescues (`safely_apply_advanced_transforms/2`
et al.), which convert the same class of failure into a returned `{:error, ...}` tuple the caller
can act on. Here, a broken `compute`/`custom` function just quietly produces a record with a
missing or stale field, with nothing in the returned value or logs indicating a transform was
skipped.

**Fix:** At minimum, log the swallowed exception before returning the original params, e.g.:

```elixir
defp apply_transform({:compute, field, opts}, params) do
  ...
rescue
  e ->
    require Logger
    Logger.warning("compute transform for #{inspect(field)} raised: #{Exception.message(e)}")
    params
end
```

Better: surface the failure to the caller (return `{:error, ...}` and thread it through
`transform_params/2` the way `CommandActionMapper` already threads transform errors) rather than
silently discarding it.

### WR-05: `.dialyzer_ignore.exs`'s substring-matched entries can silently absorb a future, unrelated warning

**File:** `.dialyzer_ignore.exs`

**Issue:** Dialyxir's ignore-file format matches `{file, message}` pairs by substring on both
fields. Three of the four seeded entries here are generic enough ("The pattern can never match
the type true.", "The guard clause can never succeed.") that a genuinely new, unrelated Dialyzer
finding introduced later in the same file (`generate_aggregate_module.ex`, which this phase's own
context notes is slated for a Phase 4 rewrite, so it will keep changing) with the same message
text would be silently absorbed by the existing entry rather than surfacing as a new failure —
undermining the stated ratchet ("Anything NEW that Dialyzer reports beyond this list blocks `mix
dialyzer`"). This is an inherent property of the ignore-file mechanism rather than something this
phase introduced, and there is no practical fix inside this file itself, but it is worth a code
comment (or a test that Dialyzer output entry-count stays a fixed length matching the four
committed entries) so a future contributor knows the ratchet's precision is bounded by dialyxir's
own substring matching, not exact identity.

**Fix:** No change strictly required; consider noting the limitation in the file's own header
comment, and/or adding a lightweight test that runs `mix dialyzer --format ignore_file_strict`
and diffs the result against the committed file's entry count, so a genuinely new warning
landing in the same file is at least visible as a count change during review.

## Info

### IN-01: Dead reference to a nonexistent module in two transformers' `after?/1`

**Files:** `lib/ash_commanded/resource/transformers/collect_parameter_transforms.ex:62`,
`lib/ash_commanded/resource/transformers/collect_parameter_validations.ex:60`

**Issue:** Both declare `def after?(AshCommanded.Transformers.ExtractCommands), do: true`. No
module by that name exists anywhere in the tree (`grep -rn "defmodule AshCommanded.Transformers.ExtractCommands" lib/`
returns nothing) — it appears to be a name from a design that predates the current
`Collect*`/`Generate*` transformer pipeline. Harmless today (Spark only queries `after?/1` with
transformer modules that are actually registered in the extension's own `transformers:` list, and
this one is not), but it is dead, misleading code that should be removed the next time either
file is touched.

**Fix:** Delete the dead clause, or replace it with a real ordering dependency if one is
intended (e.g. `after?(AshCommanded.Resource.Transformers.GenerateCommandModules)` if these
collectors are meant to run after commands are generated — verify against the actual
transformer list in `resource/dsl.ex` before choosing a replacement).

### IN-02: `AshCommanded.Domain.Info` exporting zero functions is honestly documented, but the stated fix path is incomplete

**Files:** `lib/ash_commanded/domain/info.ex`, `lib/ash_commanded/domain/dsl.ex`

**Issue:** `Domain.Info`'s moduledoc says a later phase (APP-11) "only has to extend the
`sections:` list below" to get real accessors. That is not sufficient by itself:
`Spark.InfoGenerator`'s `sections: [:commanded]` resolves against `AshCommanded.Domain.Dsl.sections/0`,
which is `[]` today because `Domain.Dsl` only `imports:` `Resource.Dsl`'s macros rather than
declaring a `:commanded` section of its own (confirmed: `AshCommanded.Domain.Dsl.sections()`
returns `[]` and `AshCommanded.Domain.Info.__info__(:functions)` returns `[]` at runtime).
Extending `Domain.Info`'s own `sections:` list without also giving `Domain.Dsl` a real section of
its own (not just an import) will still generate zero accessors. Not a defect in what exists
today — the moduledoc is accurate about the current state — but the forward-looking guidance is
worth correcting now so the Phase 3 implementer doesn't spend time on the wrong half of the
fix.

**Fix:** Amend the moduledoc's forward-looking sentence to name both halves of the real fix:
`AshCommanded.Domain.Dsl` needs its own `:commanded` (or nested `:application`) section declared
via `use Spark.Dsl.Extension, sections: [...]`, not merely an import, before extending
`Domain.Info`'s `sections:` list has any effect.

---

*Reviewed: 2026-09-16*
*Reviewer: Claude (gsd-code-reviewer)*
*Depth: standard*
