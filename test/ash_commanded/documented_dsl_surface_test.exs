defmodule AshCommanded.DocumentedDslSurfaceTest do
  @moduledoc """
  Guards the boundary between what this library's documentation claims its DSL accepts and
  what `AshCommanded.Resource.Dsl` actually declares.

  The `command` entity declares `entities: []`. That one fact is why the deleted
  `CollectParameterTransforms` and `CollectParameterValidations` transformers could never
  have worked: `Transformer.get_entities(command, [:transform_params])` can only ever return
  an empty list when the entity declares no nested entities at all. Recording it here as an
  assertion means the next person who wonders why those blocks do not work gets an answer
  from the suite instead of from a review document.
  """

  use ExUnit.Case, async: true

  describe "the declared DSL surface" do
    test "the `command` entity declares no nested entities" do
      commands_section = commands_section()

      assert commands_section,
             "AshCommanded.Resource.Dsl declares no :commands section — the DSL shape changed " <>
               "and this assertion no longer inspects what it claims to"

      command_entity = Enum.find(commands_section.entities, &(&1.name == :command))

      assert command_entity,
             "the :commands section declares no :command entity — the entity was renamed or " <>
               "removed, so this assertion would otherwise pass vacuously"

      assert command_entity.entities == [],
             "the :command entity now declares nested entities " <>
               "#{inspect(Enum.map(command_entity.entities, & &1.name))}; the parameter and " <>
               "transaction blocks previously documented against commands may now be real, " <>
               "and this plan's deletions assumed they could not exist"
    end
  end

  # Read the shape from the extension rather than from a copy of it, so this test tracks the
  # real declaration. `__sections__/0` returns the `%Spark.Dsl.Section{}` the extension was
  # built from, including every nested section and entity.
  defp commanded_section, do: AshCommanded.Resource.Dsl.__sections__()

  defp commands_section do
    Enum.find(commanded_section().sections, &(&1.name == :commands))
  end
end
