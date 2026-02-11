defmodule AshCommanded.Commanded.Verifiers.ValidateProjectionActions do
  @moduledoc """
  Verifies that projections specify valid Ash actions.

  This ensures that each projection specifies an action that is appropriate for
  resource operations, such as :create, :update, or :destroy.
  """

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier
  alias Spark.Error.DslError

  # List of common valid Ash actions
  @valid_actions [:create, :update, :destroy, :read]

  @impl true
  def verify(dsl_state) do
    resource_module = Verifier.get_persisted(dsl_state, :module)
    projections = Verifier.get_entities(dsl_state, [:commanded, :projections])

    # Find projections with potentially invalid actions
    invalid_projections =
      Enum.filter(projections, fn projection ->
        projection.action not in @valid_actions
      end)

    case invalid_projections do
      [] ->
        :ok

      invalid ->
        message = build_error_message(resource_module, invalid)
        {:error, DslError.exception(message: message, path: [:commanded, :projections])}
    end
  end

  defp build_error_message(resource_module, invalid_projections) do
    projections_list =
      invalid_projections
      |> Enum.map(fn projection ->
        "  - Projection `#{projection.name}` specifies potentially invalid action `#{projection.action}`"
      end)
      |> Enum.join("\n")

    valid_actions_list =
      @valid_actions
      |> Enum.map(&"  - #{inspect(&1)}")
      |> Enum.join("\n")

    """
    Some projections in #{inspect(resource_module)} specify actions that might not be valid:

    #{projections_list}

    Common valid Ash actions include:

    #{valid_actions_list}

    If you're using a custom action name, ensure that it corresponds to a valid action defined in your resource.
    """
  end
end
