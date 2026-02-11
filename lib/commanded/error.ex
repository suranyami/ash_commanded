defmodule AshCommanded.Commanded.Error do
  @moduledoc """
  Standardized error handling for AshCommanded.

  This module provides a consistent approach to error handling across the AshCommanded extension.
  It defines error types, formatting, and helper functions for error creation and handling.
  """

  @typedoc """
  Standard error structure for AshCommanded
  """
  @type t :: %__MODULE__{
          type: error_type(),
          message: String.t(),
          path: list(String.t() | atom()),
          field: atom() | nil,
          value: any(),
          context: map()
        }

  @typedoc """
  Types of errors that can occur in AshCommanded
  """
  @type error_type ::
          :command_error
          | :validation_error
          | :transformation_error
          | :aggregate_error
          | :dispatch_error
          | :action_error
          | :projection_error

  defstruct [
    :type,
    :message,
    :path,
    :field,
    :value,
    context: %{}
  ]

  @doc """
  Creates a new error with the specified type and message.

  ## Parameters
    * `type` - The type of error
    * `message` - The error message
    * `opts` - Additional options for the error

  ## Options
    * `:path` - The path to the error in the data structure
    * `:field` - The specific field that caused the error
    * `:value` - The value that caused the error
    * `:context` - Additional context about the error

  ## Examples

      iex> AshCommanded.Commanded.Error.new(:validation_error, "Field must be a string")
      %AshCommanded.Commanded.Error{
        type: :validation_error,
        message: "Field must be a string",
        path: [],
        field: nil,
        value: nil,
        context: %{}
      }

      iex> AshCommanded.Commanded.Error.new(:validation_error, "Field must be a string", field: :name, value: 123)
      %AshCommanded.Commanded.Error{
        type: :validation_error, 
        message: "Field must be a string",
        path: [],
        field: :name,
        value: 123,
        context: %{}
      }
  """
  @spec new(error_type(), String.t(), keyword()) :: t()
  def new(type, message, opts \\ []) do
    %__MODULE__{
      type: type,
      message: message,
      path: Keyword.get(opts, :path, []),
      field: Keyword.get(opts, :field),
      value: Keyword.get(opts, :value),
      context: Keyword.get(opts, :context, %{})
    }
  end

  @doc """
  Creates a validation error.

  ## Parameters
    * `message` - The validation error message
    * `opts` - Additional options for the error

  ## Examples

      iex> AshCommanded.Commanded.Error.validation_error("Value must be positive", field: :age, value: -5)
      %AshCommanded.Commanded.Error{
        type: :validation_error,
        message: "Value must be positive",
        path: [],
        field: :age,
        value: -5,
        context: %{}
      }
  """
  @spec validation_error(String.t(), keyword()) :: t()
  def validation_error(message, opts \\ []) do
    new(:validation_error, message, opts)
  end

  @doc """
  Creates a transformation error.

  ## Parameters
    * `message` - The transformation error message
    * `opts` - Additional options for the error

  ## Examples

      iex> AshCommanded.Commanded.Error.transformation_error("Failed to cast value to integer", field: :age, value: "abc")
      %AshCommanded.Commanded.Error{
        type: :transformation_error,
        message: "Failed to cast value to integer",
        path: [],
        field: :age,
        value: "abc",
        context: %{}
      }
  """
  @spec transformation_error(String.t(), keyword()) :: t()
  def transformation_error(message, opts \\ []) do
    new(:transformation_error, message, opts)
  end

  @doc """
  Creates a command error.

  ## Parameters
    * `message` - The command error message
    * `opts` - Additional options for the error

  ## Examples

      iex> AshCommanded.Commanded.Error.command_error("Command is missing required field", field: :id)
      %AshCommanded.Commanded.Error{
        type: :command_error,
        message: "Command is missing required field",
        path: [],
        field: :id,
        value: nil,
        context: %{}
      }
  """
  @spec command_error(String.t(), keyword()) :: t()
  def command_error(message, opts \\ []) do
    new(:command_error, message, opts)
  end

  @doc """
  Creates an aggregate error.

  ## Parameters
    * `message` - The aggregate error message
    * `opts` - Additional options for the error

  ## Examples

      iex> AshCommanded.Commanded.Error.aggregate_error("Aggregate not found", context: %{aggregate_id: "123"})
      %AshCommanded.Commanded.Error{
        type: :aggregate_error,
        message: "Aggregate not found",
        path: [],
        field: nil,
        value: nil,
        context: %{aggregate_id: "123"}
      }
  """
  @spec aggregate_error(String.t(), keyword()) :: t()
  def aggregate_error(message, opts \\ []) do
    new(:aggregate_error, message, opts)
  end

  @doc """
  Creates a dispatch error.

  ## Parameters
    * `message` - The dispatch error message
    * `opts` - Additional options for the error

  ## Examples

      iex> AshCommanded.Commanded.Error.dispatch_error("Failed to dispatch command", context: %{command: "RegisterUser"})
      %AshCommanded.Commanded.Error{
        type: :dispatch_error,
        message: "Failed to dispatch command",
        path: [],
        field: nil,
        value: nil,
        context: %{command: "RegisterUser"}
      }
  """
  @spec dispatch_error(String.t(), keyword()) :: t()
  def dispatch_error(message, opts \\ []) do
    new(:dispatch_error, message, opts)
  end

  @doc """
  Creates an action error.

  ## Parameters
    * `message` - The action error message
    * `opts` - Additional options for the error

  ## Examples

      iex> AshCommanded.Commanded.Error.action_error("Failed to execute action", context: %{action: :create_user})
      %AshCommanded.Commanded.Error{
        type: :action_error,
        message: "Failed to execute action",
        path: [],
        field: nil,
        value: nil,
        context: %{action: :create_user}
      }
  """
  @spec action_error(String.t(), keyword()) :: t()
  def action_error(message, opts \\ []) do
    new(:action_error, message, opts)
  end

  @doc """
  Creates a projection error.

  ## Parameters
    * `message` - The projection error message
    * `opts` - Additional options for the error

  ## Examples

      iex> AshCommanded.Commanded.Error.projection_error("Failed to apply projection", context: %{event: "UserRegistered"})
      %AshCommanded.Commanded.Error{
        type: :projection_error,
        message: "Failed to apply projection",
        path: [],
        field: nil,
        value: nil,
        context: %{event: "UserRegistered"}
      }
  """
  @spec projection_error(String.t(), keyword()) :: t()
  def projection_error(message, opts \\ []) do
    new(:projection_error, message, opts)
  end

  @doc """
  Formats an error for display.

  ## Parameters
    * `error` - The error to format

  ## Examples

      iex> error = AshCommanded.Commanded.Error.validation_error("Value must be positive", field: :age, value: -5)
      iex> AshCommanded.Commanded.Error.format(error)
      "Validation error: Value must be positive (field: age, value: -5)"
  """
  @spec format(t()) :: String.t()
  def format(%__MODULE__{} = error) do
    type_string = error.type |> Atom.to_string() |> String.replace("_", " ")

    details =
      cond do
        error.field && error.value !== nil ->
          " (field: #{error.field}, value: #{inspect(error.value)})"

        error.field ->
          " (field: #{error.field})"

        error.value !== nil ->
          " (value: #{inspect(error.value)})"

        true ->
          ""
      end

    "#{String.capitalize(type_string)}: #{error.message}#{details}"
  end

  @doc """
  Converts an Ash error to an AshCommanded error.

  ## Parameters
    * `ash_error` - The Ash error to convert

  ## Examples

      iex> AshCommanded.Commanded.Error.from_ash_error(%Ash.Error.Invalid{errors: [%Ash.Error.Changes.InvalidAttribute{field: :name, message: "can't be blank"}]})
      %AshCommanded.Commanded.Error{
        type: :validation_error,
        message: "can't be blank",
        path: [],
        field: :name,
        value: nil,
        context: %{source: :ash}
      }
  """
  @spec from_ash_error(Ash.Error.t()) :: t() | [t()]
  def from_ash_error(%Ash.Error.Invalid{errors: errors}) do
    Enum.map(errors, &from_ash_error/1)
  end

  def from_ash_error(%Ash.Error.Changes.InvalidAttribute{field: field, message: message}) do
    validation_error(message, field: field, context: %{source: :ash})
  end

  def from_ash_error(%Ash.Error.Query.InvalidQuery{message: message}) do
    action_error(message, context: %{source: :ash})
  end

  def from_ash_error(%{message: message}) do
    action_error(message, context: %{source: :ash})
  end

  def from_ash_error(other) do
    action_error("Unknown Ash error: #{inspect(other)}", context: %{source: :ash})
  end

  @doc """
  Converts a Commanded error to an AshCommanded error.

  ## Parameters
    * `commanded_error` - The Commanded error to convert

  ## Examples

      iex> AshCommanded.Commanded.Error.from_commanded_error(%Commanded.Aggregates.ExecutionError{message: "Failed to execute command"})
      %AshCommanded.Commanded.Error{
        type: :aggregate_error,
        message: "Failed to execute command",
        path: [],
        field: nil,
        value: nil,
        context: %{source: :commanded}
      }
  """
  @spec from_commanded_error(any()) :: t()
  def from_commanded_error(error) do
    # Mock implementation for tests
    case error do
      %{message: message} ->
        aggregate_error(message, context: %{source: :commanded})

      _ ->
        aggregate_error("Unknown Commanded error",
          context: %{source: :commanded, error: inspect(error)}
        )
    end
  end

  # Skip the second definition of this function for testing

  # These clauses are now handled by the main from_commanded_error/1 function

  @doc """
  Converts a list of errors to a standardized format.

  ## Parameters
    * `errors` - The list of errors to normalize

  ## Examples

      iex> errors = [
      ...>   %Ash.Error.Changes.InvalidAttribute{field: :name, message: "can't be blank"},
      ...>   %Commanded.Aggregates.ExecutionError{message: "Failed to execute command"}
      ...> ]
      iex> AshCommanded.Commanded.Error.normalize_errors(errors)
      [
        %AshCommanded.Commanded.Error{type: :validation_error, message: "can't be blank", field: :name, context: %{source: :ash}},
        %AshCommanded.Commanded.Error{type: :aggregate_error, message: "Failed to execute command", context: %{source: :commanded}}
      ]
  """
  @spec normalize_errors(list()) :: [t()]
  def normalize_errors(errors) when is_list(errors) do
    Enum.flat_map(errors, &normalize_error/1)
  end

  @doc """
  Converts a single error to a standardized format.

  ## Parameters
    * `error` - The error to normalize

  ## Examples

      iex> AshCommanded.Commanded.Error.normalize_error(%Ash.Error.Changes.InvalidAttribute{field: :name, message: "can't be blank"})
      [%AshCommanded.Commanded.Error{type: :validation_error, message: "can't be blank", field: :name, context: %{source: :ash}}]
  """
  @spec normalize_error(any()) :: [t()]
  def normalize_error(error) do
    cond do
      is_struct(error, __MODULE__) ->
        [error]

      is_struct(error, Ash.Error.Invalid) ->
        from_ash_error(error)

      match?(%Ash.Error.Changes.InvalidAttribute{}, error) ->
        [from_ash_error(error)]

      match?(%Ash.Error.Query.InvalidQuery{}, error) ->
        [from_ash_error(error)]

      # Test-friendly version without direct pattern matching against Commanded types
      commanded_error?(error, "Commanded.Aggregates.ExecutionError") ->
        [from_commanded_error(error)]

      commanded_error?(error, "Commanded.Aggregates.AggregateNotFoundError") ->
        [from_commanded_error(error)]

      commanded_error?(error, "Commanded.EventStore.EventStoreError") ->
        [from_commanded_error(error)]

      is_binary(error) ->
        [validation_error(error)]

      is_map(error) and Map.has_key?(error, :message) ->
        [from_ash_error(error)]

      true ->
        [validation_error("Unknown error: #{inspect(error)}")]
    end
  end

  # Helper for detecting Commanded errors without direct pattern matching
  defp commanded_error?(error, module_name) do
    try do
      module = module_name |> String.to_existing_atom() |> Code.ensure_loaded?()
      module && is_struct(error, module_name |> String.to_existing_atom())
    rescue
      _ -> false
    end
  end

  @doc """
  Returns whether a value is an AshCommanded error.

  ## Parameters
    * `value` - The value to check

  ## Examples

      iex> AshCommanded.Commanded.Error.is_error?(%AshCommanded.Commanded.Error{type: :validation_error, message: "Invalid"})
      true

      iex> AshCommanded.Commanded.Error.is_error?("Not an error")
      false
  """
  @spec is_error?(any()) :: boolean()
  def is_error?(value) do
    is_struct(value, __MODULE__)
  end

  @doc """
  Returns whether a result is an error result.

  ## Parameters
    * `result` - The result to check

  ## Examples

      iex> AshCommanded.Commanded.Error.is_error_result?({:error, %AshCommanded.Commanded.Error{}})
      true

      iex> AshCommanded.Commanded.Error.is_error_result?({:ok, "Success"})
      false
  """
  @spec is_error_result?(any()) :: boolean()
  def is_error_result?({:error, _}), do: true
  def is_error_result?(_), do: false

  @doc """
  Returns the errors from a result.

  ## Parameters
    * `result` - The result to extract errors from

  ## Examples

      iex> error = %AshCommanded.Commanded.Error{type: :validation_error, message: "Invalid"}
      iex> AshCommanded.Commanded.Error.errors_from_result({:error, error})
      [%AshCommanded.Commanded.Error{type: :validation_error, message: "Invalid"}]

      iex> AshCommanded.Commanded.Error.errors_from_result({:error, [%AshCommanded.Commanded.Error{type: :validation_error, message: "Invalid"}]})
      [%AshCommanded.Commanded.Error{type: :validation_error, message: "Invalid"}]

      iex> AshCommanded.Commanded.Error.errors_from_result({:ok, "Success"})
      []
  """
  @spec errors_from_result(any()) :: [t()]
  def errors_from_result({:error, error}) when is_list(error) do
    normalize_errors(error)
  end

  def errors_from_result({:error, error}) do
    normalize_error(error)
  end

  def errors_from_result(_) do
    []
  end
end
