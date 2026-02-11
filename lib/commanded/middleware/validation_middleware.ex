defmodule AshCommanded.Commanded.Middleware.ValidationMiddleware do
  @moduledoc """
  Middleware that validates commands before processing.

  This middleware applies validation functions to commands
  before they are dispatched. If validation fails, the command
  is rejected with an error.

  ## Configuration

  Validation can be configured in several ways:

  ```elixir
  # Simple validation of required fields
  middleware AshCommanded.Commanded.Middleware.ValidationMiddleware,
    required: [:id, :name, :email]
    
  # Custom validation function
  middleware AshCommanded.Commanded.Middleware.ValidationMiddleware,
    validate: fn command ->
      # Return :ok or {:error, reason}
      if String.contains?(command.email, "@") do
        :ok
      else
        {:error, "Invalid email format"}
      end
    end
    
  # Multiple validations
  middleware AshCommanded.Commanded.Middleware.ValidationMiddleware,
    validations: [
      required: [:id, :name, :email],
      format: [email: ~r/@/],
      custom: fn command ->
        # Custom validation logic
        :ok
      end
    ]
  ```
  """

  use AshCommanded.Commanded.Middleware.BaseMiddleware

  @impl true
  def before_dispatch(command, context, next) do
    # Extract configuration from context
    config = Map.get(context, :middleware_config, %{})

    # Apply validations based on configuration
    case validate_command(command, config) do
      :ok ->
        # Validation passed, proceed to next middleware
        next.(command, context)

      {:error, reason} ->
        # Validation failed, return error
        {:error, {:validation_error, reason}}
    end
  end

  # Validate command based on configuration
  defp validate_command(command, config) do
    cond do
      # Single validation function
      validate_fn = config[:validate] ->
        apply_validation_fn(validate_fn, command)

      # List of validations
      validations = config[:validations] ->
        validate_multiple(command, validations)

      # Required fields validation
      required = config[:required] ->
        validate_required(command, required)

      # Format validations
      format = config[:format] ->
        validate_format(command, format)

      # No validation specified
      true ->
        :ok
    end
  end

  # Apply a validation function
  defp apply_validation_fn(validate_fn, command) when is_function(validate_fn, 1) do
    validate_fn.(command)
  end

  # Apply multiple validations
  defp validate_multiple(command, validations) do
    Enum.reduce_while(validations, :ok, fn
      {:required, fields}, :ok ->
        case validate_required(command, fields) do
          :ok -> {:cont, :ok}
          error -> {:halt, error}
        end

      {:format, format_specs}, :ok ->
        case validate_format(command, format_specs) do
          :ok -> {:cont, :ok}
          error -> {:halt, error}
        end

      {:custom, validate_fn}, :ok ->
        case apply_validation_fn(validate_fn, command) do
          :ok -> {:cont, :ok}
          error -> {:halt, error}
        end

      {_other, _}, :ok ->
        {:cont, :ok}
    end)
  end

  # Validate that required fields are present and non-nil
  defp validate_required(command, fields) do
    missing =
      Enum.filter(fields, fn field ->
        value = Map.get(command, field)
        is_nil(value)
      end)

    if Enum.empty?(missing) do
      :ok
    else
      {:error, "Missing required fields: #{inspect(missing)}"}
    end
  end

  # Validate field format using regular expressions
  defp validate_format(command, format_specs) do
    invalid =
      Enum.reduce(format_specs, [], fn {field, pattern}, acc ->
        value = Map.get(command, field)

        if is_binary(value) && Regex.match?(pattern, value) do
          acc
        else
          [{field, "invalid format"} | acc]
        end
      end)

    if Enum.empty?(invalid) do
      :ok
    else
      {:error, "Invalid field formats: #{inspect(invalid)}"}
    end
  end
end
