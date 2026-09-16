defmodule AshCommanded.CredoChecks.Exemption do
  @moduledoc """
  Shared exemption logic for `AshCommanded.CredoChecks.NoRuntimeStringToAst` and
  `AshCommanded.CredoChecks.NoModuleNameSurgery` (rewrite rule 11, PROJECT.md
  Constraints).

  A single named marker comment exempts the one function it is placed immediately above from
  both checks — see `marker/0` for the literal text. This resolves the collision documented in
  `01-RESEARCH.md` ("Open Question 3" / Correction #2): the module-name-surgery shape is also
  the *legitimate* way to derive a fresh child namespace from a DSL module's own name, and
  `BaseTransformer.get_module_prefix/1` does exactly that.

  Both checks call `exempted?/2` with the `Credo.SourceFile` under analysis and the line number
  of the flagged construct. A violation is exempted when it falls between the marker's def (the
  first `def`/`defp` line after the marker) and the next `def`/`defp` line in the file — i.e.
  inside the one function the marker precedes, and nowhere else.

  Deliberately built from two joined attributes (`@marker_namespace`/`@marker_topic`) rather
  than one contiguous string literal: the marker's whole point is to be a single, countable
  occurrence in `lib/` (asserted by both check test suites, walking `lib/` directly) — a literal
  copy of it sitting in this module's own source would be a second, spurious match.
  """

  @marker_namespace "ash_commanded"
  @marker_topic "namespace-derivation"
  @marker "#{@marker_namespace}:#{@marker_topic}"

  @doc "The literal marker text checks look for, exposed so tests do not duplicate the string."
  @spec marker() :: String.t()
  def marker, do: @marker

  @doc """
  Returns `true` when `violation_line` falls inside the function immediately preceded by the
  marker comment returned by `marker/0`.
  """
  @spec exempted?(Credo.SourceFile.t(), pos_integer()) :: boolean()
  def exempted?(source_file, violation_line) do
    numbered_lines =
      source_file
      |> Credo.SourceFile.source()
      |> String.split("\n")
      |> Enum.with_index(1)

    def_lines = for {text, n} <- numbered_lines, def_line?(text), do: n
    marker_lines = for {text, n} <- numbered_lines, marker_line?(text), do: n

    Enum.any?(marker_lines, &marker_covers?(&1, def_lines, violation_line))
  end

  defp marker_covers?(marker_line, def_lines, violation_line) do
    case Enum.filter(def_lines, &(&1 > marker_line)) do
      [] ->
        false

      [enclosing_def | rest] ->
        next_def = List.first(rest)
        violation_line >= enclosing_def and before_next_def?(violation_line, next_def)
    end
  end

  defp before_next_def?(_violation_line, nil), do: true
  defp before_next_def?(violation_line, next_def), do: violation_line < next_def

  defp def_line?(text), do: Regex.match?(~r/^\s*def(p)?\s/, text)
  defp marker_line?(text), do: String.contains?(text, @marker)
end
