defmodule AshCommanded.Dump.Golden do
  @moduledoc """
  Shared golden-file header parsing and size measurement (D-03, D-10, D-11), used by both
  `Mix.Tasks.AshCommanded.Dump`'s `--write` ratchet and `test/ash_commanded/golden_budget_test.exs`'s
  self-consistency gate. Extracted so the mix task and the test cannot drift in how they count —
  without this, the task could write a golden the test measures differently.

  A golden file's own first line is a `# gsd-budget: clause_max=N module_lines=N` header. An
  optional second line, `# gsd-staged-until-phase: N`, marks the golden exempt from FOUND-06's
  absolute `clause_max <= 10` ceiling because a later roadmap phase rewrites that component
  (D-01's staging idiom, applied to goldens). The ratchet still applies to a staged golden — it
  cannot grow either.
  """

  @type budget :: %{clause_max: non_neg_integer(), module_lines: non_neg_integer()}

  @budget_regex ~r/^# gsd-budget: clause_max=(\d+) module_lines=(\d+)$/
  @staged_prefix "# gsd-staged-until-phase:"

  @doc """
  Splits golden file content into its header lines (the budget line, plus an optional staged
  line) and the committed body.

  ## Examples

      iex> AshCommanded.Dump.Golden.split_header("# gsd-budget: clause_max=0 module_lines=1\\ndefmodule Foo do\\nend\\n")
      {["# gsd-budget: clause_max=0 module_lines=1"], "defmodule Foo do\\nend\\n"}
  """
  @spec split_header(String.t()) :: {[String.t()], String.t()}
  def split_header(content) do
    case String.split(content, "\n", parts: 3) do
      [budget_line, maybe_staged, rest] ->
        if String.starts_with?(maybe_staged, @staged_prefix) do
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

  @doc """
  Parses the `# gsd-budget:` header line. Raises (naming `golden_path`) when the line is missing
  or malformed.
  """
  @spec parse_budget!(String.t() | nil, String.t()) :: budget()
  def parse_budget!(nil, golden_path) do
    raise "#{golden_path}: golden file is empty, no `# gsd-budget:` header found"
  end

  def parse_budget!(budget_line, golden_path) do
    case Regex.run(@budget_regex, budget_line) do
      [_, clause_max, module_lines] ->
        %{
          clause_max: String.to_integer(clause_max),
          module_lines: String.to_integer(module_lines)
        }

      nil ->
        raise "#{golden_path}: missing or malformed `# gsd-budget:` header line"
    end
  end

  @doc "True if the header lines carry a `# gsd-staged-until-phase:` marker."
  @spec staged?([String.t()]) :: boolean()
  def staged?(header_lines) do
    Enum.any?(header_lines, &String.starts_with?(&1, @staged_prefix))
  end

  @doc "Extracts the staged phase number from the header lines, or `nil` when not staged."
  @spec staged_phase([String.t()]) :: pos_integer() | nil
  def staged_phase(header_lines) do
    Enum.find_value(header_lines, fn line ->
      case Regex.run(~r/^# gsd-staged-until-phase: (\d+)$/, line) do
        [_, phase] -> String.to_integer(phase)
        nil -> nil
      end
    end)
  end

  @doc """
  Measures a rendered module body's `clause_max` (the widest `def`/`defp` clause span, in lines)
  and `module_lines` (the whole body's line count).

  Measures every `:def`/`:defp` node's own span directly off its node metadata
  (`meta[:line]..meta[:end][:line]`) rather than postwalking descendants for min/max of `:line` —
  bare literals carry no line metadata, so a postwalk-min/max approach can undercount a clause
  whose last statement is a bare literal return value.
  """
  @spec measure(String.t()) :: budget()
  def measure(body) do
    quoted = Code.string_to_quoted!(body, columns: true, token_metadata: true)

    clause_max =
      quoted
      |> measure_clause_spans()
      |> Enum.max(fn -> 0 end)

    module_lines =
      body
      |> String.trim_trailing("\n")
      |> String.split("\n")
      |> length()

    %{clause_max: clause_max, module_lines: module_lines}
  end

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

  @doc """
  Formats the golden header: the budget line, and — when `staged_phase` is given — the staged
  marker line beneath it.
  """
  @spec format_header(budget(), pos_integer() | nil) :: String.t()
  def format_header(budget, staged_phase \\ nil)

  def format_header(budget, nil) do
    "# gsd-budget: clause_max=#{budget.clause_max} module_lines=#{budget.module_lines}"
  end

  def format_header(budget, staged_phase) do
    format_header(budget, nil) <> "\n# gsd-staged-until-phase: #{staged_phase}"
  end
end
