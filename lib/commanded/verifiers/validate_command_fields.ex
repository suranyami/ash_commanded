defmodule AshCommanded.Commanded.Verifiers.ValidateCommandFields do
  @moduledoc """
  Verifies that all fields declared in commands exist as attributes in the resource.

  This ensures that commands don't reference non-existent fields, which would lead to
  runtime errors.
  """

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier
  alias Spark.Error.DslError

  @impl true
  def verify(dsl_state) do
    resource_module = Verifier.get_persisted(dsl_state, :module)
    commands = Verifier.get_entities(dsl_state, [:commanded, :commands])
    resource_attributes = get_resource_attributes(dsl_state)

    commands_with_invalid_fields =
      commands
      |> Enum.filter(&command_has_invalid_fields?(&1, resource_attributes))
      |> Enum.map(fn command ->
        invalid_fields = command.fields -- resource_attributes
        {command.name, invalid_fields}
      end)

    case commands_with_invalid_fields do
      [] ->
        :ok

      invalid_commands ->
        message = build_error_message(resource_module, invalid_commands)
        {:error, DslError.exception(message: message, path: [:commanded, :commands])}
    end
  end

  defp get_resource_attributes(dsl_state) do
    dsl_state
    |> Verifier.get_entities([:attributes])
    |> Enum.map(& &1.name)
  end

  defp command_has_invalid_fields?(command, resource_attributes) do
    Enum.any?(command.fields, &(&1 not in resource_attributes))
  end

  defp build_error_message(resource_module, invalid_commands) do
    commands_with_errors =
      invalid_commands
      |> Enum.map(fn {command_name, invalid_fields} ->
        "  - Command `#{command_name}` has unknown fields: #{inspect(invalid_fields)}"
      end)
      |> Enum.join("\n")

    """
    The following commands in #{inspect(resource_module)} reference fields that don't exist as attributes:

    #{commands_with_errors}

    All command fields must correspond to existing resource attributes.
    """
  end
end
