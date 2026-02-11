defmodule AshCommanded.Commanded.Verifiers.ValidateEventNames do
  @moduledoc """
  Verifies that each event name within a resource is unique.

  This ensures that there are no duplicate event names, which would lead to
  confusion and potentially overwriting modules.
  """

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier
  alias Spark.Error.DslError

  @impl true
  def verify(dsl_state) do
    resource_module = Verifier.get_persisted(dsl_state, :module)
    events = Verifier.get_entities(dsl_state, [:commanded, :events])

    event_names = Enum.map(events, & &1.name)
    duplicate_names = find_duplicates(event_names)

    case duplicate_names do
      [] ->
        :ok

      duplicates ->
        message = build_error_message(resource_module, duplicates)
        {:error, DslError.exception(message: message, path: [:commanded, :events])}
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
      |> Enum.map(fn name -> "  - #{inspect(name)}" end)
      |> Enum.join("\n")

    """
    The following event names are duplicated in #{inspect(resource_module)}:

    #{duplicates_list}

    Each event must have a unique name within a resource.
    """
  end
end
