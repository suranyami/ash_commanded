# credo:disable-for-this-file ExDNA.Credo
# gsd-disable-until-phase: 2 — `find_duplicates/1`'s body is a confirmed structural clone
# (Type-I, mass 51/54) of
# `AshCommanded.Commanded.Verifiers.ValidateEventNames.find_duplicates/1`, found by the
# FOUND-11 clone check (01-CLONE-REPORT.md). ROADMAP.md Phase 2 ("Commands and Events") owns
# both this verifier's and the event-name verifier's rewrite, per D-01.
defmodule AshCommanded.Commanded.Verifiers.ValidateCommandNames do
  @moduledoc """
  Verifies that each command name within a resource is unique.

  This ensures that there are no duplicate command names, which would lead to
  confusion and potentially overwriting modules.
  """

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier
  alias Spark.Error.DslError

  @impl true
  def verify(dsl_state) do
    resource_module = Verifier.get_persisted(dsl_state, :module)
    commands = Verifier.get_entities(dsl_state, [:commanded, :commands])

    command_names = Enum.map(commands, & &1.name)
    duplicate_names = find_duplicates(command_names)

    case duplicate_names do
      [] ->
        :ok

      duplicates ->
        message = build_error_message(resource_module, duplicates)
        {:error, DslError.exception(message: message, path: [:commanded, :commands])}
    end
  end

  defp find_duplicates(list) do
    list
    |> Enum.reduce({%{}, []}, fn item, {counts, duplicates} ->
      new_counts = Map.update(counts, item, 1, &(&1 + 1))

      if new_counts[item] > 1 && item not in duplicates do
        {new_counts, [item | duplicates]}
      else
        {new_counts, duplicates}
      end
    end)
    |> elem(1)
  end

  defp build_error_message(resource_module, duplicate_names) do
    duplicates_list =
      duplicate_names
      |> Enum.map_join("\n", fn name -> "  - #{inspect(name)}" end)

    """
    The following command names are duplicated in #{inspect(resource_module)}:

    #{duplicates_list}

    Each command must have a unique name within a resource.
    """
  end
end
