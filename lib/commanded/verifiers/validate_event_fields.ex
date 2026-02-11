defmodule AshCommanded.Commanded.Verifiers.ValidateEventFields do
  @moduledoc """
  Verifies that all fields declared in events exist as attributes in the resource.

  This ensures that events don't reference non-existent fields, which would lead to
  runtime errors.
  """

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier
  alias Spark.Error.DslError

  @impl true
  def verify(dsl_state) do
    resource_module = Verifier.get_persisted(dsl_state, :module)
    events = Verifier.get_entities(dsl_state, [:commanded, :events])
    resource_attributes = get_resource_attributes(dsl_state)

    events_with_invalid_fields =
      events
      |> Enum.filter(&event_has_invalid_fields?(&1, resource_attributes))
      |> Enum.map(fn event ->
        invalid_fields = event.fields -- resource_attributes
        {event.name, invalid_fields}
      end)

    case events_with_invalid_fields do
      [] ->
        :ok

      invalid_events ->
        message = build_error_message(resource_module, invalid_events)
        {:error, DslError.exception(message: message, path: [:commanded, :events])}
    end
  end

  defp get_resource_attributes(dsl_state) do
    dsl_state
    |> Verifier.get_entities([:attributes])
    |> Enum.map(& &1.name)
  end

  defp event_has_invalid_fields?(event, resource_attributes) do
    Enum.any?(event.fields, &(&1 not in resource_attributes))
  end

  defp build_error_message(resource_module, invalid_events) do
    events_with_errors =
      invalid_events
      |> Enum.map(fn {event_name, invalid_fields} ->
        "  - Event `#{event_name}` has unknown fields: #{inspect(invalid_fields)}"
      end)
      |> Enum.join("\n")

    """
    The following events in #{inspect(resource_module)} reference fields that don't exist as attributes:

    #{events_with_errors}

    All event fields must correspond to existing resource attributes.
    """
  end
end
