defmodule AshCommanded.Resource.Verifiers.ValidateProjectionActions do
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
        not valid_action?(projection.action)
      end)

    case invalid_projections do
      [] ->
        :ok

      invalid ->
        message = build_error_message(resource_module, invalid)
        {:error, DslError.exception(message: message, path: [:commanded, :projections])}
    end
  end

  # Function-head clauses rather than a membership test against the literal list:
  # Elixir 1.20 + OTP 27 mis-expand `in` against a literal list longer than three
  # elements into a `case` with unsafe variables, and `:cover` re-compilation then raises
  # `MatchError :error` (erlang/otp#11524, surfaced as elixir#15546). The compiler fix is
  # in OTP 28+, so these clauses may collapse back into one membership test once this
  # project's OTP floor is 28 or newer.
  defp valid_action?(:create), do: true
  defp valid_action?(:update), do: true
  defp valid_action?(:destroy), do: true
  defp valid_action?(:read), do: true
  defp valid_action?(_action), do: false

  defp build_error_message(resource_module, invalid_projections) do
    projections_list =
      invalid_projections
      |> Enum.map_join("\n", fn projection ->
        "  - Projection `#{projection.name}` specifies potentially invalid action `#{projection.action}`"
      end)

    valid_actions_list =
      @valid_actions
      |> Enum.map_join("\n", &"  - #{inspect(&1)}")

    """
    Some projections in #{inspect(resource_module)} specify actions that might not be valid:

    #{projections_list}

    Common valid Ash actions include:

    #{valid_actions_list}

    If you're using a custom action name, ensure that it corresponds to a valid action defined in your resource.
    """
  end
end
