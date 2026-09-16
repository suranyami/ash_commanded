# Phase 1 Gate Evidence — ROADMAP Success Criterion 3

**Date:** 2026-09-16
**Elixir/OTP:** Elixir 1.18.4 (compiled with Erlang/OTP 27) — the canonical version D-12 declares
**Commit at time of run:** `d1348f7` (01-05 Task 2's commit; HEAD at the start of Task 3)

This is a **one-time record**, not a permanent test. It answers ROADMAP.md Phase 1 success
criterion 3 literally: for each of the five deliberately-seeded violations, the real `mix check`
alias actually failed, naming the file and the rule, and going green again once the violation was
removed. The **permanent regression coverage** — proof that each gate's detection logic still
fires, run on every `mix test` — lives in `test/ash_commanded/seeded_violations_test.exs` (01-05
Task 1). Do not mistake this document for that test; this document is evidence a human read once,
the test is a control that runs forever.

Each violation below was introduced into a location the real `mix check` alias actually sweeps
(`lib/ash_commanded/` for the three source-level gates, `test/golden/parity_widget/` for the two
golden-level gates — never `priv/seeded_violations/`, which is deliberately invisible to every
tool per Task 1), the real `mix check` was run and its output captured verbatim below, the
violation was reverted, and `mix check` was run again to confirm green. All five runs were
performed fresh in this session rather than reusing 01-03's original deliberate-violation proof,
because that proof was recorded only as commit-message prose (`dc370d7`), not as an archived
verbatim transcript — reusing a paraphrase rather than the real thing would have quietly weakened
the literal evidence this document exists to provide.

`git status --porcelain -- test/golden lib priv` is empty at the end of this document — no seeded
violation was left in the tree.

---

## FOUND-06 — a rendered clause over ~10 lines

**Requirement:** FOUND-06. **Gate:** `AshCommanded.Dump.Golden.measure/1`, run inside
`test/ash_commanded/golden_budget_test.exs` against every committed golden.

**Seeded where:** `test/golden/parity_widget/AshCommanded.Evidence.OversizedClause.golden`, a new
golden with a `def execute/2` clause spanning 6 lines against a declared `clause_max=3`:

```elixir
# gsd-budget: clause_max=3 module_lines=8
defmodule AshCommanded.Evidence.OversizedClause do
  def execute(state, command) do
    a = command.a
    b = command.b
    c = command.c
    {:ok, state, a, b, c}
  end
end
```

**Failing `mix check` output (verbatim excerpt):**

```text
1) test enforces the declared budget for test/golden/parity_widget/AshCommanded.Evidence.OversizedClause.golden (AshCommanded.GoldenBudgetTest)
   test/ash_commanded/golden_budget_test.exs:57
   /Users/djp/development/forks/ash_commanded/test/golden/parity_widget/AshCommanded.Evidence.OversizedClause.golden: measured clause span 6 exceeds declared clause_max 3
   code: AshCommanded.GoldenBudgetTest.assert_within_budget!(@golden_path)
   stacktrace:
     test/ash_commanded/golden_budget_test.exs:137: AshCommanded.GoldenBudgetTest.assert_within_budget!/1
     test/ash_commanded/golden_budget_test.exs:58: (test)
```

Names the file and both numbers (measured `6`, declared `3`), per SC3's literal wording.
`mix check` also failed a second way for the same file — `AshCommanded.GoldenRenderTest` (FOUND-04)
raised `no captured module matched AshCommanded.Evidence.OversizedClause under
AshCommanded.TestSupport.Parity.Widget`, because this scratch golden sits in the `parity_widget`
fixture directory but is not one of the modules that fixture actually generates. This is expected,
not a bug: both tests walk the identical `test/golden/**/*.golden` glob, so a stray golden trips
both the size gate and the render-parity gate independently — belt-and-suspenders, not double
counting. **`mix check` exit code: `1`.**

**Recovery:** deleted the scratch golden.

**Green `mix check` output (verbatim excerpt, tail):**

```text
    │   ~~~~~~~~
    │
    └─ (ash_commanded 0.2.0) lib/ash_commanded/domain/transformers/generate_commanded_application.ex:40: AshCommanded.Domain.Transformers.GenerateCommandedApplication.transform/1

View "html" docs at "doc/index.html"
```

**Exit code: `0`.**

---

## FOUND-07 — a `quote` block over 40 lines

**Requirement:** FOUND-07. **Gate:** `Credo.Check.Refactor.LongQuoteBlocks`, configured at
`max_line_count: 40` in `.credo.exs`.

**Seeded where:** `lib/ash_commanded/scratch_gate_evidence_quote_block.ex`, a scratch module whose
`build/1` returns a `quote do ... end` block spanning 42 field assignments (well over the 40-line
ceiling):

```elixir
defmodule AshCommanded.ScratchGateEvidenceQuoteBlock do
  @moduledoc "Scratch evidence file for 01-05 Task 3 — deleted immediately after capture."

  def render(command), do: build(command)

  defp build(_command) do
    quote do
      def execute(state, command) do
        field_01 = command.field_01
        # ... 41 more field assignments ...
        field_42 = command.field_42
        {:ok, state}
      end
    end
  end
end
```

**Failing `mix check` output (verbatim excerpt):**

```text
Checking 125 source files (this might take a while) ...

  Refactoring opportunities
┃
┃ [F] ↗ Avoid long quote blocks.
┃       lib/ash_commanded/scratch_gate_evidence_quote_block.ex:7:5 #(AshCommanded.ScratchGateEvidenceQuoteBlock.build)

Please report incorrect results: https://github.com/rrrene/credo/issues

Analysis took 0.2 seconds (0.01s to load, 0.2s running 71 checks on 125 files)
645 mods/funs, found 1 refactoring opportunity.
```

Names the file (`lib/ash_commanded/scratch_gate_evidence_quote_block.ex`) and the rule
(`Avoid long quote blocks.` — `Credo.Check.Refactor.LongQuoteBlocks`). **`mix check` exit code:
`8`.**

**Recovery:** deleted the scratch file.

**Green `mix check` output:** exit code `0` (re-run confirmed silently; see the shared final
green run at the end of this document for the full transcript style).

---

## FOUND-08 — compile-time-known values reassembled at runtime (the `:erlang.++` defect)

**Requirement:** FOUND-08. **Gate:** `AshCommanded.Dump.Lint.check/1`, run inside
`test/ash_commanded/golden_budget_test.exs` against every committed golden.

**Seeded where:** `test/golden/parity_widget/AshCommanded.Evidence.RuntimeReassembly.golden`, a
new golden whose body concatenates two literal lists at runtime via `++/2`:

```elixir
# gsd-budget: clause_max=1 module_lines=5
defmodule AshCommanded.Evidence.RuntimeReassembly do
  def execute(state) do
    [] ++ [transforms: [], validations: []] ++ state
  end
end
```

**Failing `mix check` output (verbatim excerpt):**

```text
1) test has no runtime-reassembly violations for test/golden/parity_widget/AshCommanded.Evidence.RuntimeReassembly.golden (AshCommanded.GoldenBudgetTest)
   test/ash_commanded/golden_budget_test.exs:61
   /Users/djp/development/forks/ash_commanded/test/golden/parity_widget/AshCommanded.Evidence.RuntimeReassembly.golden: runtime-reassembly violations: [%{line: 3, description: "compile-time-known list literal concatenated at runtime via ++/2"}, %{line: 3, description: "compile-time-known list literal concatenated at runtime via ++/2"}]
   code: AshCommanded.GoldenBudgetTest.assert_no_lint_violations!(@golden_path)
   stacktrace:
     test/ash_commanded/golden_budget_test.exs:62: (test)

2) test enforces the declared budget for test/golden/parity_widget/AshCommanded.Evidence.RuntimeReassembly.golden (AshCommanded.GoldenBudgetTest)
   test/ash_commanded/golden_budget_test.exs:57
   /Users/djp/development/forks/ash_commanded/test/golden/parity_widget/AshCommanded.Evidence.RuntimeReassembly.golden: measured clause span 3 exceeds declared clause_max 1
   code: AshCommanded.GoldenBudgetTest.assert_within_budget!(@golden_path)
   stacktrace:
     test/ash_commanded/golden_budget_test.exs:137: AshCommanded.GoldenBudgetTest.assert_within_budget!/1
     test/ash_commanded/golden_budget_test.exs:58: (test)
```

Names the file and the exact line (`line: 3`) the two nested `++/2` operations occur on, per SC3's
literal wording. (The declared `clause_max=1` was deliberately under-budgeted to also demonstrate
the size ratchet firing on the same fixture — a bonus, not a substitute, for the lint's own
message.) As with FOUND-06, `AshCommanded.GoldenRenderTest` also raised on this same file for the
same "unregistered fixture module" reason. **`mix check` exit code: `1`.**

**Recovery:** deleted the scratch golden.

**Green `mix check` output:** exit code `0`, confirmed via the same full run recorded at the end of
this document.

---

## FOUND-09 — `Code.string_to_quoted!`/`eval_string` in a transformer

**Requirement:** FOUND-09. **Gate:** `AshCommanded.CredoChecks.NoRuntimeStringToAst`.

**Seeded where:** `lib/ash_commanded/scratch_gate_evidence_string_to_ast.ex`:

```elixir
defmodule AshCommanded.ScratchGateEvidenceStringToAst do
  @moduledoc "Scratch evidence file for 01-05 Task 3 — deleted immediately after capture."

  def build_module_ast(module_name) do
    Code.string_to_quoted!("defmodule #{module_name} do\n  def run, do: :ok\nend")
  end
end
```

**Failing `mix check` output (verbatim excerpt):**

```text
Checking 125 source files (this might take a while) ...

  Warnings - please take a look
┃
┃ [W] ↗ Avoid Code.string_to_quoted!/* in transformer code — build AST directly
┃       with quote/unquote instead of reparsing a string (rewrite rule 10).
┃       lib/ash_commanded/scratch_gate_evidence_string_to_ast.ex:5:5 #(AshCommanded.ScratchGateEvidenceStringToAst.build_module_ast)

Please report incorrect results: https://github.com/rrrene/credo/issues

Analysis took 0.2 seconds (0.01s to load, 0.2s running 71 checks on 125 files)
643 mods/funs, found 1 warning.
```

Names the file and the rule, and the message itself names the called function
(`Code.string_to_quoted!`). **`mix check` exit code: `16`.**

**Recovery:** deleted the scratch file.

**Green `mix check` output (verbatim excerpt):**

```text
Checking 124 source files (this might take a while) ...

Please report incorrect results: https://github.com/rrrene/credo/issues

Analysis took 0.2 seconds (0.02s to load, 0.2s running 71 checks on 124 files)
641 mods/funs, found no issues.
```

**Exit code: `0`.**

---

## FOUND-10 — a module name built by `Module.split`/`Module.concat` surgery

**Requirement:** FOUND-10. **Gate:** `AshCommanded.CredoChecks.NoModuleNameSurgery`.

**Seeded where:** `lib/ash_commanded/scratch_gate_evidence_module_name_surgery.ex`:

```elixir
defmodule AshCommanded.ScratchGateEvidenceModuleNameSurgery do
  @moduledoc "Scratch evidence file for 01-05 Task 3 — deleted immediately after capture."

  def rebuild_parent_namespace(existing_module) do
    existing_module
    |> Module.split()
    |> Enum.drop(-1)
    |> Module.concat()
  end
end
```

**Failing `mix check` output (verbatim excerpt):**

```text
Checking 125 source files (this might take a while) ...

  Warnings - please take a look
┃
┃ [W] ↗ Module name built by splitting/reconcatenating another module's name —
┃       derive it from Transformer.get_persisted/2 instead (rewrite rule 4).
┃       lib/ash_commanded/scratch_gate_evidence_module_name_surgery.ex:8:8 #(AshCommanded.ScratchGateEvidenceModuleNameSurgery.rebuild_parent_namespace)

Please report incorrect results: https://github.com/rrrene/credo/issues

Analysis took 0.2 seconds (0.01s to load, 0.2s running 71 checks on 125 files)
643 mods/funs, found 1 warning.
```

Names the file and the rule. **`mix check` exit code: `16`.**

**Recovery:** deleted the scratch file.

**Green `mix check` output:** exit code `0` (identical shape to FOUND-09's green run above, run
immediately after deletion).

---

## Final confirmation

After all five violations were introduced and reverted in turn, one last full run confirms the
tree is clean and green:

```text
$ git status --porcelain -- test/golden lib priv
(empty)

$ mix check
... (format, compile --warnings-as-errors, credo, coveralls, compile_parity.sh, dialyzer, gen.docs — all pass)
$ echo $?
0

$ MIX_ENV=test mix test
Finished in 4.4 seconds (1.1s async, 3.2s sync)
249 tests, 0 failures
```

249 ≥ 176 (the standing baseline), and `mix check` exits `0` with a clean working tree. The
permanent regression coverage for all five gates now lives in
`test/ash_commanded/seeded_violations_test.exs`; this document is its one-time literal
counterpart, not a substitute for it.
