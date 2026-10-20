defmodule AshCommanded.GeneratedModuleLocationTest do
  @moduledoc """
  Proves FOUND-18 end to end: an error raised inside a *real* generated module names the DSL
  declaration that produced it, in the DSL module's own source file, rather than naming the
  transformer that generated it.

  The fixture is `test/support/parity/parity_widget.ex`, the one resource that compiles under
  both `:dev` and `:test`. `AshCommanded.TestSupport.Parity.Projections.WidgetCreated` is
  generated from its `projection :widget_created do` declaration.

  The expected line is *derived at test time* by reading the fixture, never hardcoded — a
  literal here would drift into asserting a stale constant the moment the fixture is edited,
  and the test would keep passing while proving nothing.
  """

  use ExUnit.Case, async: true

  alias AshCommanded.Resource.Transformers.BaseTransformer

  @fixture Path.expand("../support/parity/parity_widget.ex", __DIR__)
  @fixture_module AshCommanded.TestSupport.Parity.Widget
  @lib_tree Path.expand("../../lib", __DIR__)
  @base_transformer_path Path.expand(
                           "../../lib/ash_commanded/resource/transformers/base_transformer.ex",
                           __DIR__
                         )
  @transformer_tree Path.expand("../../lib/ash_commanded", __DIR__)
  @projection_module AshCommanded.TestSupport.Parity.Projections.WidgetCreated

  # The persisted registries every module-creating transformer in this library populates. Kept
  # as registry *keys*, not module names, so the sweep derives its members from live DSL state.
  @generated_module_registry_keys [
    :command_modules,
    :event_modules,
    :projection_modules,
    :event_handler_modules,
    :projector_modules,
    :aggregate_module
  ]

  describe "BaseTransformer.dsl_location/1" do
    test "returns an empty list when Spark persisted no file" do
      assert BaseTransformer.dsl_location(%{}) == []
    end

    test "returns the persisted file at line 1" do
      assert BaseTransformer.dsl_location(%{persist: %{file: @fixture}}) ==
               [file: @fixture, line: 1]
    end
  end

  describe "a generated module's error names its DSL declaration (FOUND-18)" do
    test "the projection module's own stacktrace frame points at the fixture declaration" do
      frame = projection_error_frame()

      frame_file = Path.expand(frame[:file])

      assert frame_file == @fixture,
             "expected the generated module's frame to name #{@fixture}, got #{frame_file}"

      refute String.starts_with?(frame_file, @transformer_tree <> "/"),
             "the generated module's frame still names the transformer tree: #{frame_file}"

      assert frame[:line] == fixture_line("projection :widget_created do")
    end

    test "the projection module's compile metadata names the fixture, not the transformer" do
      source = compiled_source(@projection_module)

      assert source == @fixture
      refute String.starts_with?(source, @lib_tree <> "/")
    end
  end

  describe "every module the parity fixture generates (FOUND-18 sweep)" do
    test "reports the fixture's own source path from __info__(:compile)" do
      modules = generated_modules()

      assert modules != [],
             "the persisted DSL state exposed no generated modules — this sweep would pass vacuously"

      assert length(modules) >= 6,
             "expected at least the six modules the fixture generates, got " <>
               "#{length(modules)}: #{inspect(modules)}"

      for module <- modules do
        source = compiled_source(module)

        assert source == @fixture,
               "#{inspect(module)} reports #{source}, expected #{@fixture}"

        refute String.starts_with?(source, @lib_tree <> "/"),
               "#{inspect(module)} reports a path under the transformer tree: #{source}"
      end
    end
  end

  describe "no module-creating transformer is left unwired (T-01-BI-18)" do
    test "create_module is called with four arguments at least nine times and never with three" do
      arities = create_module_call_arities()
      three_argument_calls = Enum.count(arities, &(&1 == 3))
      four_argument_calls = Enum.count(arities, &(&1 == 4))

      assert three_argument_calls == 0,
             "found #{three_argument_calls} three-argument BaseTransformer.create_module call(s) " <>
               "under lib/ outside base_transformer.ex — those fall back to the transformer's own file"

      assert four_argument_calls >= 9,
             "found only #{four_argument_calls} four-argument BaseTransformer.create_module " <>
               "call(s); expected at least nine, so this guard cannot pass by finding nothing"
    end
  end

  # Reads the modules the fixture generated from the fixture's *own persisted DSL state*, so a
  # module added to an existing registry joins the sweep without a hand-edited list here.
  defp generated_modules do
    persisted = @fixture_module.persisted()

    @generated_module_registry_keys
    |> Enum.flat_map(fn key -> module_atoms(Map.get(persisted, key)) end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp module_atoms({_key, value}), do: module_atoms(value)
  defp module_atoms(value) when is_list(value), do: Enum.flat_map(value, &module_atoms/1)
  defp module_atoms(value) when is_map(value), do: value |> Map.values() |> module_atoms()
  defp module_atoms(value) when is_atom(value) and not is_nil(value), do: [value]
  defp module_atoms(_value), do: []

  # Counts *occurrences*, not files: a file with two call sites where only one was wired must
  # fail, which is the mistake phase 01 already shipped once in the no-module-name-surgery guard.
  defp create_module_call_arities do
    @lib_tree
    |> Path.join("**/*.ex")
    |> Path.wildcard()
    |> Enum.reject(&(&1 == @base_transformer_path))
    |> Enum.flat_map(&create_module_arities_in_file/1)
  end

  defp create_module_arities_in_file(path) do
    path
    |> File.read!()
    |> Code.string_to_quoted!()
    |> create_module_arities_in_ast()
  end

  defp create_module_arities_in_ast(ast) do
    {_ast, arities} =
      Macro.prewalk(ast, [], fn
        {{:., _, [callee, :create_module]}, _, args} = node, acc when is_list(args) ->
          collect_create_module_arity(node, callee, args, acc)

        node, acc ->
          {node, acc}
      end)

    arities
  end

  defp collect_create_module_arity(node, callee, args, acc) do
    if base_transformer_callee?(callee) do
      {node, [length(args) | acc]}
    else
      {node, acc}
    end
  end

  defp base_transformer_callee?({:__aliases__, _, parts}),
    do: List.last(parts) == :BaseTransformer

  defp base_transformer_callee?(_callee), do: false

  defp projection_error_frame do
    stacktrace =
      try do
        @projection_module.apply(:not_a_resource, %{})
        :no_error
      rescue
        _error -> __STACKTRACE__
      end

    assert is_list(stacktrace),
           "expected the generated projection's apply/2 to raise on a non-resource argument"

    frames =
      Enum.filter(stacktrace, fn {module, _fun, _arity, _location} ->
        module == @projection_module
      end)

    assert length(frames) == 1,
           "expected exactly one frame from #{inspect(@projection_module)}, got #{length(frames)}"

    [{_module, _fun, _arity, location}] = frames
    location
  end

  defp fixture_line(declaration) do
    line =
      @fixture
      |> File.read!()
      |> String.split("\n")
      |> Enum.find_index(&(String.trim(&1) == declaration))

    assert line != nil,
           "could not find #{inspect(declaration)} in #{@fixture}"

    line + 1
  end

  defp compiled_source(module) do
    module.__info__(:compile)
    |> Keyword.fetch!(:source)
    |> to_string()
    |> Path.expand()
  end
end
