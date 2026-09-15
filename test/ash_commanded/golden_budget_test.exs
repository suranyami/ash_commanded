defmodule AshCommanded.GoldenBudgetTest do
  @moduledoc """
  Enforces FOUND-06's absolute clause-size ceiling and D-03's per-golden size ratchet against
  every committed golden render under `test/golden/`.

  Each `.golden` file's own first line is a `# gsd-budget: clause_max=N module_lines=N` header
  declaring what its committed body was measured at. This test parses that header, re-measures
  the committed body, and asserts the declared numbers still match — it never regenerates
  anything, so it is independent of D-12's formatter/version sensitivity (Elixir's *parser* is
  stable across the supported minor range even though its pretty-printer is not).

  A golden whose header carries a `# gsd-staged-until-phase:` marker is exempt from the
  `clause_max <= 10` absolute-ceiling assertion only — plan 02 introduces staged goldens for
  not-yet-rewritten components.

  One test is generated per discovered golden file: a `test/golden/**/*.golden` glob that finds
  nothing generates zero tests, which is itself the failure signal that the gate measured
  nothing (T-01-BI-01).
  """

  use ExUnit.Case, async: true

  golden_files =
    [File.cwd!(), "test", "golden", "**", "*.golden"]
    |> Path.join()
    |> Path.wildcard()
    |> Enum.sort()

  for golden_path <- golden_files do
    @golden_path golden_path
    relative_path = Path.relative_to_cwd(golden_path)

    test "enforces the declared budget for #{relative_path}" do
      AshCommanded.GoldenBudgetTest.assert_within_budget!(@golden_path)
    end
  end

  @doc false
  def assert_within_budget!(golden_path) do
    content = File.read!(golden_path)
    {header_lines, body} = split_header(content)

    budget = parse_budget_header!(header_lines, golden_path)

    unless staged?(header_lines) do
      assert budget.clause_max <= 10,
             "#{golden_path}: declared clause_max #{budget.clause_max} exceeds FOUND-06's absolute ceiling of 10 lines"
    end

    quoted = Code.string_to_quoted!(body, columns: true, token_metadata: true)
    max_clause_span = quoted |> measure_clause_spans() |> Enum.max(fn -> 0 end)

    assert max_clause_span <= budget.clause_max,
           "#{golden_path}: measured clause span #{max_clause_span} exceeds declared clause_max #{budget.clause_max}"

    # A committed golden ends with a trailing newline (as text files do); trim it before
    # splitting so that trailing artifact does not inflate the count by one.
    module_lines = body |> String.trim_trailing("\n") |> String.split("\n") |> length()

    assert module_lines <= budget.module_lines,
           "#{golden_path}: measured module_lines #{module_lines} exceeds declared module_lines #{budget.module_lines}"
  end

  # The header is the first line (`# gsd-budget: ...`), plus an optional second line
  # (`# gsd-staged-until-phase: ...`). Everything after is the committed body.
  defp split_header(content) do
    case String.split(content, "\n", parts: 3) do
      [budget_line, maybe_staged, rest] ->
        if String.starts_with?(maybe_staged, "# gsd-staged-until-phase:") do
          {[budget_line, maybe_staged], rest}
        else
          {[budget_line], Enum.join([maybe_staged, rest], "\n")}
        end

      [budget_line, rest] ->
        {[budget_line], rest}

      [budget_line] ->
        {[budget_line], ""}

      [] ->
        {[], ""}
    end
  end

  defp parse_budget_header!([budget_line | _], golden_path) do
    case Regex.run(~r/^# gsd-budget: clause_max=(\d+) module_lines=(\d+)$/, budget_line) do
      [_, clause_max, module_lines] ->
        %{
          clause_max: String.to_integer(clause_max),
          module_lines: String.to_integer(module_lines)
        }

      nil ->
        flunk("#{golden_path}: missing or malformed `# gsd-budget:` header line")
    end
  end

  defp parse_budget_header!([], golden_path) do
    flunk("#{golden_path}: golden file is empty, no `# gsd-budget:` header found")
  end

  defp staged?(header_lines) do
    Enum.any?(header_lines, &String.starts_with?(&1, "# gsd-staged-until-phase:"))
  end

  # Measures every :def/:defp node's own span directly off its node metadata
  # (meta[:line]..meta[:end][:line]) rather than postwalking descendants for min/max of :line —
  # bare literals carry no line metadata, so a postwalk-min/max approach can undercount a clause
  # whose last statement is a bare literal return value.
  defp measure_clause_spans(quoted) do
    {_ast, spans} =
      Macro.prewalk(quoted, [], fn
        {kind, meta, _args} = node, acc when kind in [:def, :defp] ->
          start_line = Keyword.fetch!(meta, :line)
          end_line = meta |> Keyword.fetch!(:end) |> Keyword.fetch!(:line)
          {node, [end_line - start_line + 1 | acc]}

        node, acc ->
          {node, acc}
      end)

    spans
  end
end
