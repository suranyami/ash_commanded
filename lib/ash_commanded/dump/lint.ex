defmodule AshCommanded.Dump.Lint do
  @moduledoc """
  Enforces PROJECT.md rewrite rule 2: anything computable at macro-expansion time is computed
  there and `unquote`d as a literal, never reassembled at runtime (FOUND-08). This is the one
  rewrite rule whose evidence lives exclusively in rendered output — the defect is invisible in
  generator source and visible only after macro expansion.

  The confirmed instance (`.planning/LEARNINGS.md` §1) is the pre-rewrite aggregate's
  `execute/2`, which built a fully compile-time-known keyword list through six nested `++`
  concatenations, five of them on already-empty lists:

  ```elixir
  :erlang.++([],
    :erlang.++([],
      :erlang.++([transforms: [], validations: []],
        :erlang.++([], :erlang.++([], :erlang.++([], []))))))
  ```

  Two shapes are detected:

    * The compiled remote-call form, `:erlang` module's `++` function of arity 2 — visible
      after full macro expansion (the post-compile `--beam` view).
    * The operator form, `left ++ right`, where either `left` or `right` is itself a literal
      list or keyword list in the AST — visible in the pre-`Module.create/3` view goldens
      actually store.

  Kept a plain, directly unit-testable function with no Credo dependency:
  `.planning/research/SUMMARY.md` "Open Question 3" found no way to write this check as a
  Credo AST check without re-deriving the same walk this module already does, since Credo's
  check protocol does not distinguish literal from bound list operands any more directly than
  a bare `Macro.prewalk/3` does.
  """

  @type violation :: %{line: non_neg_integer() | nil, description: String.t()}

  @doc """
  Walks a quoted AST and returns every runtime-reassembly violation found, each naming the
  line it occurred on and a short description.

  ## Examples

      iex> AshCommanded.Dump.Lint.check(quote(do: [] ++ [1, 2]))
      [%{line: nil, description: "compile-time-known list literal concatenated at runtime via ++/2"}]

      iex> AshCommanded.Dump.Lint.check(quote(do: def(foo, do: :ok)))
      []
  """
  @spec check(Macro.t()) :: [violation()]
  def check(quoted) do
    {_ast, violations} = Macro.prewalk(quoted, [], &visit/2)
    Enum.reverse(violations)
  end

  # The compiled form: a remote call to :erlang's own concatenation function. Elixir lowers
  # `a ++ b` to exactly this shape by the time a module has been fully compiled — visible in
  # the --beam view, though not in the pre-Module.create/3 AST golden bodies store today.
  defp visit({{:., meta, [:erlang, :++]}, _call_meta, [_left, _right]} = node, acc) do
    {node,
     [violation(meta, "compile-time-known value reassembled at runtime via :erlang.++/2") | acc]}
  end

  # The operator form. `is_list/1` is true here precisely when the operand is a list literal
  # written directly at this call site in source — a variable holding a list is a different
  # AST shape (a variable reference tuple), never a bare list — so this only flags concatenation
  # where at least one side is syntactically already a literal (list or keyword list) rather
  # than a runtime value.
  defp visit({:++, meta, [left, right]} = node, acc) when is_list(left) or is_list(right) do
    {node,
     [
       violation(meta, "compile-time-known list literal concatenated at runtime via ++/2")
       | acc
     ]}
  end

  defp visit(node, acc), do: {node, acc}

  defp violation(meta, description) do
    %{line: Keyword.get(meta, :line), description: description}
  end
end
