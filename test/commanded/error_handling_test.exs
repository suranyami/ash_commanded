defmodule AshCommanded.ErrorHandlingTest do
  use ExUnit.Case, async: true

  alias AshCommanded.Commanded.Error
  alias AshCommanded.TestSupport.Widget

  # These commands and events are used only by the "Error module" and "Error
  # normalization" describe blocks below, which exercise AshCommanded.Commanded.Error
  # construction/formatting directly — they never route through CommandActionMapper,
  # so a plain struct is sufficient and unaffected by the mapper's real-Ash rewrite.
  defmodule TestCommand do
    defstruct [:id, :name, :email]
  end

  defmodule TestEvent do
    defstruct [:id, :name, :email]
  end

  # Used by the "Command action mapper error handling" describe block below —
  # its fields are scoped to what AshCommanded.TestSupport.Widget actually accepts
  # ([:id, :name]), since those tests now route through the real mapper against a
  # real Ash resource.
  defmodule MapperTestCommand do
    defstruct [:id, :name]
  end

  describe "Error module" do
    test "creates a new error" do
      error = Error.new(:validation_error, "Field must be a string")

      assert error.type == :validation_error
      assert error.message == "Field must be a string"
      assert error.path == []
      assert error.field == nil
      assert error.value == nil
      assert error.context == %{}
    end

    test "creates a validation error" do
      error = Error.validation_error("Value must be positive", field: :age, value: -5)

      assert error.type == :validation_error
      assert error.message == "Value must be positive"
      assert error.field == :age
      assert error.value == -5
    end

    test "creates a transformation error" do
      error =
        Error.transformation_error("Failed to cast value to integer", field: :age, value: "abc")

      assert error.type == :transformation_error
      assert error.message == "Failed to cast value to integer"
      assert error.field == :age
      assert error.value == "abc"
    end

    test "creates a command error" do
      error = Error.command_error("Command is missing required field", field: :id)

      assert error.type == :command_error
      assert error.message == "Command is missing required field"
      assert error.field == :id
    end

    test "creates an aggregate error" do
      error = Error.aggregate_error("Aggregate not found", context: %{aggregate_id: "123"})

      assert error.type == :aggregate_error
      assert error.message == "Aggregate not found"
      assert error.context == %{aggregate_id: "123"}
    end

    test "creates a dispatch error" do
      error =
        Error.dispatch_error("Failed to dispatch command", context: %{command: "RegisterUser"})

      assert error.type == :dispatch_error
      assert error.message == "Failed to dispatch command"
      assert error.context == %{command: "RegisterUser"}
    end

    test "creates an action error" do
      error = Error.action_error("Failed to execute action", context: %{action: :create_user})

      assert error.type == :action_error
      assert error.message == "Failed to execute action"
      assert error.context == %{action: :create_user}
    end

    test "formats an error for display" do
      error = Error.validation_error("Value must be positive", field: :age, value: -5)
      formatted = Error.format(error)

      assert formatted == "Validation error: Value must be positive (field: age, value: -5)"
    end
  end

  describe "Error normalization" do
    test "normalizes different error types" do
      # Basic error string
      string_error = "Something went wrong"

      # Ash-style error
      ash_error = %{message: "Invalid attribute", field: :name}

      # AshCommanded error
      ash_commanded_error =
        Error.validation_error("Value must be positive", field: :age, value: -5)

      # Normalize each error
      normalized =
        [
          Error.normalize_error(string_error),
          Error.normalize_error(ash_error),
          Error.normalize_error(ash_commanded_error)
        ]
        |> List.flatten()

      # Check that all normalized errors are proper Error structs
      assert Enum.all?(normalized, &Error.is_error?/1)
      assert length(normalized) == 3
    end

    test "extracts errors from results" do
      ok_result = {:ok, "Success"}
      error_result = {:error, "Something went wrong"}
      struct_error_result = {:error, Error.validation_error("Invalid")}

      list_error_result =
        {:error, [Error.validation_error("Error 1"), Error.validation_error("Error 2")]}

      assert Error.errors_from_result(ok_result) == []
      assert length(Error.errors_from_result(error_result)) == 1
      assert length(Error.errors_from_result(struct_error_result)) == 1
      assert length(Error.errors_from_result(list_error_result)) == 2
    end
  end

  describe "Parameter validator error handling" do
    test "returns standardized validation errors" do
      params = %{name: "John", email: "invalid-email", age: 15}

      validations = [
        {:validate, :name, [type: :string, min_length: 5]},
        {:validate, :email, [type: :string, format: ~r/@.*\./]},
        {:validate, :age, [type: :integer, min: 18]}
      ]

      # Validate params with the validations
      result = AshCommanded.Commanded.ParameterValidator.validate_params(params, validations)

      # Check that we get expected errors
      assert match?({:error, _errors}, result)

      {:error, errors} = result

      # Check that we have three validation errors
      assert length(errors) == 3

      # Check that all errors are proper Error structs
      assert Enum.all?(errors, &Error.is_error?/1)

      # Check that all errors have the appropriate type
      assert Enum.all?(errors, fn e -> e.type == :validation_error end)

      # Check for specific expected error fields
      name_error = Enum.find(errors, fn e -> e.field == :name end)
      email_error = Enum.find(errors, fn e -> e.field == :email end)
      age_error = Enum.find(errors, fn e -> e.field == :age end)

      assert name_error != nil
      assert email_error != nil
      assert age_error != nil

      assert name_error.message =~ "must be at least 5 characters"
      assert email_error.message =~ "does not match required format"
      assert age_error.message =~ "must be at least 18"
    end
  end

  describe "Command action mapper error handling" do
    test "handles transformation errors" do
      command = %MapperTestCommand{id: "123", name: "Test"}

      # Create a param mapping function that raises an error
      param_mapping = fn _params -> raise "Transformation error" end

      # Try to map the command to an action against the real Widget fixture —
      # the raise happens in the param-mapping stage, before the resource is
      # ever touched, so this error's origin is unaffected by which resource
      # is passed. Pointed at Widget for consistency with the rest of the suite.
      result =
        AshCommanded.Commanded.CommandActionMapper.map_to_action(
          command,
          Widget,
          :create,
          param_mapping: param_mapping
        )

      # Check that we get a standardized error
      assert match?({:error, %Error{type: :transformation_error}}, result)
    end

    test "handles validation errors" do
      command = %MapperTestCommand{id: "123", name: "T"}

      # Create validations that will fail (Widget's :name is the only string
      # field these commands carry)
      validations = [
        {:validate, :name, [min_length: 5]}
      ]

      # Try to map the command to an action with validations — validation runs
      # before any Ash action executes, so this also never touches the resource.
      result =
        AshCommanded.Commanded.CommandActionMapper.map_to_action(
          command,
          Widget,
          :create,
          validations: validations
        )

      # Check that we get a standardized error
      assert match?({:error, [%Error{type: :validation_error}]}, result)
    end

    test "handles missing identity fields" do
      command = %MapperTestCommand{name: "Test"}

      # Try to map the command to an update action which requires an ID
      result =
        AshCommanded.Commanded.CommandActionMapper.map_to_action(
          command,
          Widget,
          :update,
          action_type: :update
        )

      # Check that we get a standardized error about the missing ID
      assert match?({:error, %Error{type: :command_error}}, result)

      {:error, error} = result
      assert error.message =~ "Missing identity field"
    end

    test "normalizes a real Ash error raised by a failing create action" do
      # "abc" is neither a formatted UUID string nor a 16-byte raw binary, so
      # Ash.Type.UUID genuinely rejects it at cast time — this is a real
      # Ash.Error.Invalid flowing through CommandActionMapper's error handling
      # and Error.from_ash_error/1, a path the create mock previously made
      # impossible to reach (it always returned {:ok, _} regardless of input).
      command = %MapperTestCommand{id: "abc", name: "Test"}

      result =
        AshCommanded.Commanded.CommandActionMapper.map_to_action(
          command,
          Widget,
          :create,
          action_type: :create
        )

      assert {:error, error} = result
      errors = List.wrap(error)
      assert errors != []
      assert Enum.all?(errors, &Error.is_error?/1)
    end
  end
end
