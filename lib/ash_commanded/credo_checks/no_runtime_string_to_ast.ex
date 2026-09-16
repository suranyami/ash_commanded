defmodule AshCommanded.CredoChecks.NoRuntimeStringToAst do
  @moduledoc """
  Flags transformer code under `lib/` that builds AST from an interpolated string at runtime
  instead of writing it directly with `quote`/`unquote` (rewrite rule 10, PROJECT.md
  Constraints: "Idiomatic macros... never lists of tuples and maps assembled into strings and
  reparsed into AST.").

  A transformer that calls `Code.string_to_quoted/1,2`, `Code.string_to_quoted!/1,2`,
  `Code.eval_string/1,2,3`, or `Code.compile_string/1,2` is reparsing text into AST at
  macro-expansion or runtime — the exact anti-pattern FOUND-09 targets. Idiomatic macros build
  AST directly with `quote` and substitute per-entity literals with `unquote`.

  Scoped to `lib/` only, excluding `lib/ash_commanded/dump/`: hand-authored test fixtures, the
  golden-measurement helpers under `test/`, and the renderer's own measurement helpers under
  `lib/ash_commanded/dump/` (`AshCommanded.Dump.Golden.measure/1` calls `Code.string_to_quoted!/2`
  to count an already-rendered module's clause/line spans) all legitimately parse rendered
  *output* — not build AST that gets compiled into a transformer's own generated code — which is
  a different concern this check does not target. Found live during 01-03's own D-01 suppression
  pass: `golden.ex` sits under `lib/` (the renderer ships in the published package per D-08), so
  the blanket `lib/` guard this check shipped with in its first commit flagged the renderer's own
  tooling alongside real transformer defects. The exclusion is by directory, not by call site, so
  a *transformer* accidentally added under `lib/ash_commanded/dump/` in the future would also
  escape the check — considered and accepted, since that directory is renderer tooling by
  construction (D-05/D-06/D-08), not a home for DSL transformers.

  The single named exemption marker (see `AshCommanded.CredoChecks.Exemption.marker/0` for the
  literal text) is honoured here for symmetry with
  `AshCommanded.CredoChecks.NoModuleNameSurgery`, even though the one function it currently
  marks (`BaseTransformer.get_module_prefix/1`) does not itself trigger this check.
  """

  use Credo.Check,
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      Transformers must not build AST from interpolated strings (rewrite rule 10). Reparsing a
      runtime string into AST via `Code.string_to_quoted/1,2`, `Code.string_to_quoted!/1,2`,
      `Code.eval_string/1,2,3`, or `Code.compile_string/1,2` inside `lib/` defeats the point of
      writing a macro: idiomatic generated code is mostly-static `quote` with `unquote`
      substitutions, not text assembled and reparsed.

          # bad
          Code.eval_string("defmodule \#{name} do end")

          # good
          quote do
            defmodule unquote(Module.concat(name)) do
            end
          end
      """
    ]

  alias AshCommanded.CredoChecks.Exemption
  alias Credo.IssueMeta

  @flagged_functions [:string_to_quoted, :string_to_quoted!, :eval_string, :compile_string]

  @doc false
  @impl Credo.Check
  def run(%Credo.SourceFile{} = source_file, params \\ []) do
    if under_lib?(source_file) do
      issue_meta = IssueMeta.for(source_file, params)
      Credo.Code.prewalk(source_file, &traverse(&1, &2, source_file, issue_meta))
    else
      []
    end
  end

  defp under_lib?(source_file) do
    filename = source_file.filename || ""

    String.starts_with?(filename, "lib/") and
      not String.starts_with?(filename, "lib/ash_commanded/dump/")
  end

  defp traverse(
         {{:., _, [{:__aliases__, _, [:Code]}, fun]}, meta, _args} = ast,
         issues,
         source_file,
         issue_meta
       )
       when fun in @flagged_functions do
    line = meta[:line]

    if line && Exemption.exempted?(source_file, line) do
      {ast, issues}
    else
      {ast, [issue_for(issue_meta, line, fun) | issues]}
    end
  end

  defp traverse(ast, issues, _source_file, _issue_meta), do: {ast, issues}

  defp issue_for(issue_meta, line_no, fun) do
    format_issue(issue_meta,
      message:
        "Avoid Code.#{fun}/* in transformer code — build AST directly with quote/unquote instead of reparsing a string (rewrite rule 10).",
      trigger: "Code.#{fun}",
      line_no: line_no
    )
  end
end
