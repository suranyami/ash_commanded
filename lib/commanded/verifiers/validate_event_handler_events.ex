defmodule AshCommanded.Commanded.Verifiers.ValidateEventHandlerEvents do
  @moduledoc """
  Verifies that event handlers only reference valid events defined in the resource.

  This ensures that each event handler is tied to valid events that were defined
  in the resource's events section, preventing references to non-existent events.
  """

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier
  alias Spark.Error.DslError

  @doc """
  Verifies that all events referenced by event handlers exist in the resource.

  ## Returns

  * `:ok` - If all events referenced by event handlers exist
  * `{:error, error}` - If any event handler references a non-existent event
  """
  @impl true
  def verify(dsl_state) do
    resource_module = Verifier.get_persisted(dsl_state, :module)
    event_handlers = Verifier.get_entities(dsl_state, [:commanded, :event_handlers])
    events = Verifier.get_entities(dsl_state, [:commanded, :events])

    event_names = Enum.map(events, & &1.name)

    # Collect all invalid event references from all handlers
    invalid_references =
      event_handlers
      |> Enum.flat_map(fn handler ->
        # Filter the list of events this handler subscribes to
        Enum.filter(handler.events, fn event_name ->
          event_name not in event_names
        end)
        |> Enum.map(fn invalid_event ->
          {handler.name, invalid_event}
        end)
      end)

    case invalid_references do
      [] ->
        :ok

      invalid ->
        message = build_error_message(resource_module, invalid, event_names)
        {:error, DslError.exception(message: message, path: [:commanded, :event_handlers])}
    end
  end

  defp build_error_message(resource_module, invalid_references, valid_event_names) do
    # Group references by handler for better error reporting
    references_by_handler =
      invalid_references
      |> Enum.group_by(
        fn {handler_name, _event_name} -> handler_name end,
        fn {_handler_name, event_name} -> event_name end
      )

    # Build a list of handler-to-invalid-event references
    handlers_list =
      references_by_handler
      |> Enum.map(fn {handler_name, invalid_events} ->
        events_str = invalid_events |> Enum.map(&"`#{&1}`") |> Enum.join(", ")
        "  - Handler `#{handler_name}` references unknown event(s): #{events_str}"
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
    Some event handlers reference events that don't exist in #{inspect(resource_module)}:

    #{handlers_list}

    #{valid_events_list}

    Each event handler must only reference events defined in the resource's events section.
    You can either update the handler to use existing event names or add the missing events to the events section.
    """
  end
end
