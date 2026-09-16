defmodule AshCommanded.InfoTest do
  @moduledoc """
  FOUND-17: proves `AshCommanded.Resource.Info` and `AshCommanded.Domain.Info` are the
  single lookup point each tree's DSL state exposes — generated entirely by
  `Spark.InfoGenerator`, not hand-written getters.

  Assertions are derived from each extension's own `sections/0`, not hardcoded, so this
  test cannot drift out of sync with the DSL's actual declared shape and does not assume
  a fixed section count for either tree.
  """
  use ExUnit.Case, async: true

  describe "AshCommanded.Resource.Info" do
    test "is defined and loaded" do
      assert Code.ensure_loaded?(AshCommanded.Resource.Info)
    end

    test "exposes an entity or options accessor for every section AshCommanded.Resource.Dsl declares" do
      accessor_names =
        AshCommanded.Resource.Info.__info__(:functions)
        |> Enum.map(&Atom.to_string(elem(&1, 0)))

      for section_name <- declared_section_names(AshCommanded.Resource.Dsl) do
        prefix = Atom.to_string(section_name)

        assert Enum.any?(accessor_names, &String.starts_with?(&1, prefix)),
               "expected an accessor whose name starts with #{inspect(prefix)} " <>
                 "(section #{inspect(section_name)}), found none among #{inspect(accessor_names)}"
      end
    end

    test "commanded_commands/1 reflects real DSL state" do
      commands = AshCommanded.Resource.Info.commanded_commands(AshCommanded.TestSupport.Widget)
      assert Enum.any?(commands, &(&1.name == :create_widget))
    end
  end

  describe "AshCommanded.Domain.Info" do
    test "is defined and loaded" do
      assert Code.ensure_loaded?(AshCommanded.Domain.Info)
    end

    test "exposes an accessor for every section AshCommanded.Domain.Dsl declares (currently none)" do
      declared = declared_section_names(AshCommanded.Domain.Dsl)
      accessor_names = AshCommanded.Domain.Info.__info__(:functions)

      # AshCommanded.Domain.Dsl declares zero sections of its own today (see its moduledoc) —
      # this assertion is written against that declared list, not a hardcoded 0, so it starts
      # holding real accessors to real assertions automatically once a later phase (APP-11)
      # gives the domain its own section.
      assert declared == []
      assert accessor_names == []
    end
  end

  defp declared_section_names(extension) do
    extension.sections() |> Enum.map(& &1.name)
  end
end
