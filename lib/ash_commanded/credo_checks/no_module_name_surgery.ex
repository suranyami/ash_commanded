defmodule AshCommanded.CredoChecks.NoModuleNameSurgery do
  @moduledoc """
  Flags module names built by splitting and reconcatenating another module's name, rather than
  deriving them from `Transformer.get_persisted/2` (rewrite rule 4, PROJECT.md Constraints:
  "Derive from `Transformer.get_persisted/2`, never by module-name surgery.").

  Flags exactly two shapes, scoped to `lib/` only, one function body at a time:

  1. A `Module.split/1` call whose result reaches a `Module.concat/1` or `Module.concat/2` call
     within the same function body — through a pipe chain, or through a local variable bound
     with `=`.
  2. A `Module.concat/1` or `Module.concat/2` call whose argument list contains a string literal
     or an interpolated string segment.

  Does NOT flag:

  * A `Module.split/1` call terminating in `List.last/1` or `List.first/1` with no concatenation
    in the same function — this is a display string (e.g. a log label or a moduledoc), not a
    reconstructed module reference.
  * A `Module.concat/1` or `Module.concat/2` call whose arguments are all module aliases or
    plain variables, with no string segment and no `Module.split/1` result feeding them — this
    is process/child-spec naming from an already-resolved module atom, not surgery.

  The single named exemption marker (see `AshCommanded.CredoChecks.Exemption.marker/0` for the
  literal text) exempts the one function it precedes — today,
  `BaseTransformer.get_module_prefix/1`, the one utility that legitimately derives a *new* child
  namespace from a DSL module's own name rather than reconstructing an existing reference.
  """

  use Credo.Check,
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      Module names must be derived from `Transformer.get_persisted/2`, never reconstructed by
      splitting and reconcatenating another module's name (rewrite rule 4). Both
      `Module.split/1` results feeding a later `Module.concat/1,2` call, and a `Module.concat/1,2`
      call built from a string literal or interpolated segment, are flagged.

          # bad — reconstructs a module reference that was already available
          resource_module =
            command_module |> Module.split() |> Enum.drop(-2) |> Module.concat()

          # good — read it from persisted DSL state instead
          resource_module = Transformer.get_persisted(dsl_state, :module)
      """
    ]

  alias AshCommanded.CredoChecks.Exemption
  alias Credo.IssueMeta

  @doc false
  @impl Credo.Check
  def run(%Credo.SourceFile{} = source_file, params \\ []) do
    if under_lib?(source_file) do
      issue_meta = IssueMeta.for(source_file, params)

      source_file
      |> function_asts()
      |> Enum.flat_map(&issues_for_function(&1, source_file, issue_meta))
    else
      []
    end
  end

  defp under_lib?(source_file) do
    String.starts_with?(source_file.filename || "", "lib/")
  end

  defp function_asts(source_file) do
    Credo.Code.prewalk(source_file, fn
      {:def, _, _} = ast, acc -> {ast, [ast | acc]}
      {:defp, _, _} = ast, acc -> {ast, [ast | acc]}
      ast, acc -> {ast, acc}
    end)
  end

  defp issues_for_function(def_ast, source_file, issue_meta) do
    tainted = tainted_variables(def_ast)

    (direct_flagged_concat_lines(def_ast, tainted) ++ pipe_flagged_concat_lines(def_ast, tainted))
    |> Enum.uniq()
    |> Enum.reject(&Exemption.exempted?(source_file, &1))
    |> Enum.map(&issue_for(issue_meta, &1))
  end

  # A local variable is "tainted" for the rest of this function when either:
  #
  #   - it is bound (via `=`) to something containing a Module.split/1 call anywhere on its
  #     right-hand side, or
  #   - it is a bare-variable `case` clause pattern whose subject is itself already tainted (or
  #     itself contains a split) — this is exactly `base_transformer.ex`'s
  #     `get_module_prefix/1` shape: `parts = Module.split(...)`, then
  #     `case parts do ... multiple_parts -> multiple_parts |> ... |> Module.concat() end`.
  #
  # Threaded as a single accumulator through one top-to-bottom prewalk so a `case` sees taint
  # from any assignment earlier in the same function body.
  defp tainted_variables(def_ast) do
    {_, tainted} =
      Macro.prewalk(def_ast, MapSet.new(), fn
        {:=, _, [{name, _, ctx}, rhs]} = node, acc when is_atom(name) and is_atom(ctx) ->
          if contains_split?(rhs), do: {node, MapSet.put(acc, name)}, else: {node, acc}

        {:case, _, [subject, [do: clauses]]} = node, acc ->
          if case_subject_tainted?(subject, acc) do
            {node, taint_case_bindings(clauses, acc)}
          else
            {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    tainted
  end

  defp case_subject_tainted?({name, _, ctx}, acc) when is_atom(name) and is_atom(ctx) do
    MapSet.member?(acc, name)
  end

  defp case_subject_tainted?(subject, _acc), do: contains_split?(subject)

  defp taint_case_bindings(clauses, acc) do
    Enum.reduce(clauses, acc, fn
      {:->, _, [[{name, _, ctx}], _body]}, acc2 when is_atom(name) and is_atom(ctx) ->
        MapSet.put(acc2, name)

      _clause, acc2 ->
        acc2
    end)
  end

  defp contains_split?(ast) do
    {_, found} =
      Macro.prewalk(ast, false, fn
        {{:., _, [{:__aliases__, _, [:Module]}, :split]}, _, _} = node, _acc -> {node, true}
        node, acc -> {node, acc}
      end)

    found
  end

  # Shape 2 (literal/interpolated-string argument) and the local-variable half of shape 1
  # (a tainted variable passed directly as an argument) both apply to a "direct" (non-piped)
  # Module.concat/1,2 call, since both are visible from the call's own argument list.
  defp direct_flagged_concat_lines(def_ast, tainted) do
    {_, lines} =
      Macro.prewalk(def_ast, [], fn
        {{:., _, [{:__aliases__, _, [:Module]}, :concat]}, meta, args} = node, acc
        when is_list(args) ->
          if args_have_literal?(args) or args_reference_tainted?(args, tainted) do
            {node, [meta[:line] | acc]}
          else
            {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    lines
  end

  defp args_have_literal?(args) do
    {_, found} =
      Macro.prewalk(args, false, fn
        node, _acc when is_binary(node) -> {node, true}
        {:<<>>, _, _} = node, _acc -> {node, true}
        node, acc -> {node, acc}
      end)

    found
  end

  defp args_reference_tainted?(args, tainted) do
    {_, found} =
      Macro.prewalk(args, false, fn
        {name, _, ctx} = node, acc when is_atom(name) and is_atom(ctx) ->
          {node, acc or MapSet.member?(tainted, name)}

        node, acc ->
          {node, acc}
      end)

    found
  end

  # The pipe-chain half of shape 1: `... |> Module.split() |> ... |> Module.concat()`. Pipe
  # operators are not expanded in the AST Credo parses, so a chain stays a nested `:|>` tree —
  # flattening it into an ordered list of stages lets us check "does a split stage precede the
  # concat stage" directly.
  defp pipe_flagged_concat_lines(def_ast, tainted) do
    {_, lines} =
      Macro.prewalk(def_ast, [], fn
        {:|>, meta, [_lhs, {{:., _, [{:__aliases__, _, [:Module]}, :concat]}, _, _}]} = node,
        acc ->
          stages = flatten_pipe(node)

          if Enum.any?(stages, &(contains_split?(&1) or tainted_ref?(&1, tainted))) do
            {node, [meta[:line] | acc]}
          else
            {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    lines
  end

  defp flatten_pipe({:|>, _, [lhs, rhs]}), do: flatten_pipe(lhs) ++ [rhs]
  defp flatten_pipe(other), do: [other]

  defp tainted_ref?({name, _, ctx}, tainted) when is_atom(name) and is_atom(ctx) do
    MapSet.member?(tainted, name)
  end

  defp tainted_ref?(_node, _tainted), do: false

  defp issue_for(issue_meta, line_no) do
    format_issue(issue_meta,
      message:
        "Module name built by splitting/reconcatenating another module's name — derive it from Transformer.get_persisted/2 instead (rewrite rule 4).",
      trigger: "Module.concat",
      line_no: line_no
    )
  end
end
