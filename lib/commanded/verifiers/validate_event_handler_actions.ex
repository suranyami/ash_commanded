defmodule AshCommanded.Commanded.Verifiers.ValidateEventHandlerActions do
  @moduledoc """
  Verifies that event handlers reference valid actions when using atom-based actions.

  This ensures that when an event handler uses an action name (atom) rather than a function,
  the action exists as a valid action in the resource.
  """

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier
  alias Spark.Error.DslError

  # List of common valid Ash actions
  @common_valid_actions [:create, :update, :destroy, :read]

  @doc """
  Verifies that all action names referenced by event handlers exist or are common actions.

  ## Returns

  * `:ok` - If all action references are valid or handlers use function definitions
  * `{:error, error}` - If any event handler references a potentially invalid action
  """
  @impl true
  def verify(dsl_state) do
    resource_module = Verifier.get_persisted(dsl_state, :module)
    event_handlers = Verifier.get_entities(dsl_state, [:commanded, :event_handlers])

    # Find resource's custom action names if we can access them
    custom_actions =
      if Code.ensure_loaded?(Ash.Resource.Info) do
        Ash.Resource.Info.actions(resource_module)
        |> Enum.map(& &1.name)
      else
        []
      end

    # All valid actions (common + custom)
    valid_actions = @common_valid_actions ++ custom_actions

    # Find handlers with potentially invalid actions - only looking at atom-based actions
    invalid_handlers =
      event_handlers
      |> Enum.filter(fn handler ->
        case handler.action do
          # No action is valid (no-op handler)
          nil -> false
          action when is_atom(action) -> action not in valid_actions
          # Function-based actions are valid by definition
          _quoted_function -> false
        end
      end)

    case invalid_handlers do
      [] ->
        :ok

      invalid ->
        message = build_error_message(resource_module, invalid, valid_actions)
        {:error, DslError.exception(message: message, path: [:commanded, :event_handlers])}
    end
  end

  defp build_error_message(resource_module, invalid_handlers, valid_actions) do
    handlers_list =
      invalid_handlers
      |> Enum.map(fn handler ->
        "  - Handler `#{handler.name}` specifies potentially invalid action `#{handler.action}`"
      end)
      |> Enum.join("\n")

    valid_actions_list =
      valid_actions
      |> Enum.map(&"  - #{inspect(&1)}")
      |> Enum.join("\n")

    """
    Some event handlers in #{inspect(resource_module)} specify actions that might not be valid:

    #{handlers_list}

    Valid Ash actions for this resource include:

    #{valid_actions_list}

    You can either:
    1. Use one of the valid action names listed above
    2. Define the missing action in your resource
    3. Use a quoted function instead of an action name
    """
  end
end
