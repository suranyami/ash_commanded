defmodule AshCommanded.Commanded.Verifiers.ValidateProjectionEvents do
  @moduledoc """
  Verifies that projections reference valid events defined in the resource.

  This ensures that each projection is tied to a valid event that was defined
  in the resource's events section, preventing references to non-existent events.
  """

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier
  alias Spark.Error.DslError

  @impl true
  def verify(dsl_state) do
    resource_module = Verifier.get_persisted(dsl_state, :module)
    projections = Verifier.get_entities(dsl_state, [:commanded, :projections])
    events = Verifier.get_entities(dsl_state, [:commanded, :events])

    event_names = Enum.map(events, & &1.name)

    # Find projections with invalid event names
    invalid_projections =
      Enum.filter(projections, fn projection ->
        event_name = projection.event_name || projection.name
        event_name not in event_names
      end)

    case invalid_projections do
      [] ->
        :ok

      invalid ->
        message = build_error_message(resource_module, invalid, event_names)
        {:error, DslError.exception(message: message, path: [:commanded, :projections])}
    end
  end

  defp build_error_message(resource_module, invalid_projections, valid_event_names) do
    # Build a list of projection-to-invalid-event references
    projections_list =
      invalid_projections
      |> Enum.map(fn projection ->
        event_name = projection.event_name || projection.name
        "  - Projection `#{projection.name}` references unknown event `#{event_name}`"
      end)
      |> Enum.join("\n")

    # Show valid event names to help the user correct their code
    valid_events_list =
      case valid_event_names do
        [] ->
          "No events are defined in #{inspect(resource_module)}."

        events ->
          valid_list = events |> Enum.map(&"  - #{inspect(&1)}") |> Enum.join("\n")
          "The following events are defined in #{inspect(resource_module)}:\n\n#{valid_list}"
      end

    """
    Some projections reference events that don't exist in #{inspect(resource_module)}:

    #{projections_list}

    #{valid_events_list}

    Each projection must reference an event defined in the resource's events section.
    You can either update the projection to use an existing event name or add the missing event to the events section.
    """
  end
end
