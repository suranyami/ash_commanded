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
  @lib_tree Path.expand("../../lib", __DIR__)
  @transformer_tree Path.expand("../../lib/ash_commanded", __DIR__)
  @projection_module AshCommanded.TestSupport.Parity.Projections.WidgetCreated

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
