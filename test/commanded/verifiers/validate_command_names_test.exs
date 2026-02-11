defmodule AshCommanded.Commanded.Verifiers.ValidateCommandNamesTest do
  use ExUnit.Case, async: false
  @moduletag :verifier_test

  alias AshCommanded.Commanded.Command
  alias AshCommanded.Commanded.Verifiers.ValidateCommandNames
  alias Spark.Dsl.Verifier

  import Mock

  describe "verify/1" do
    test "returns :ok when all command names are unique" do
      # Create mock commands with unique names
      command1 = %Command{name: :register_user}
      command2 = %Command{name: :update_user}
      command3 = %Command{name: :delete_user}

      # Mock the DSL state and verifier functions
      with_mock Verifier,
        get_persisted: fn _state, :module -> TestResource end,
        get_entities: fn _state, [:commanded, :commands] -> [command1, command2, command3] end do
        assert ValidateCommandNames.verify(%{}) == :ok
      end
    end

    test "returns an error when duplicate command names exist" do
      # Create mock commands with duplicate names
      command1 = %Command{name: :register_user}
      command2 = %Command{name: :update_user}
      # Duplicate
      command3 = %Command{name: :register_user}

      # Mock the DSL state and verifier functions
      with_mock Verifier,
        get_persisted: fn _state, :module -> TestResource end,
        get_entities: fn _state, [:commanded, :commands] -> [command1, command2, command3] end do
        result = ValidateCommandNames.verify(%{})
        assert {:error, error} = result
        assert error.message =~ "command names are duplicated"
        assert error.message =~ ":register_user"
      end
    end

    test "lists all duplicate command names in the error message" do
      # Create multiple duplicate command names
      command1 = %Command{name: :register_user}
      command2 = %Command{name: :update_user}
      # Duplicate
      command3 = %Command{name: :register_user}
      # Duplicate
      command4 = %Command{name: :update_user}

      # Mock the DSL state and verifier functions
      with_mock Verifier,
        get_persisted: fn _state, :module -> TestResource end,
        get_entities: fn _state, [:commanded, :commands] ->
          [command1, command2, command3, command4]
        end do
        result = ValidateCommandNames.verify(%{})
        assert {:error, error} = result
        assert error.message =~ ":register_user"
        assert error.message =~ ":update_user"
      end
    end
  end
end
