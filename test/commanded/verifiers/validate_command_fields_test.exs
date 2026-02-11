defmodule AshCommanded.Commanded.Verifiers.ValidateCommandFieldsTest do
  use ExUnit.Case, async: false
  @moduletag :verifier_test

  alias AshCommanded.Commanded.Command
  alias AshCommanded.Commanded.Verifiers.ValidateCommandFields
  alias Spark.Dsl.Verifier

  import Mock

  describe "verify/1" do
    test "returns :ok when all command fields are valid resource attributes" do
      # Create mock commands with valid fields
      command = %Command{
        name: :register_user,
        fields: [:id, :email, :name]
      }

      # Mock the DSL state and verifier functions
      with_mock Verifier,
        get_persisted: fn _state, :module -> TestResource end,
        get_entities: fn
          _state, [:commanded, :commands] ->
            [command]

          _state, [:attributes] ->
            [
              %{name: :id},
              %{name: :email},
              %{name: :name}
            ]
        end do
        assert ValidateCommandFields.verify(%{}) == :ok
      end
    end

    test "returns an error when a command has fields that don't exist in the resource" do
      # Create mock commands with invalid fields
      command = %Command{
        name: :register_user,
        fields: [:id, :email, :nonexistent_field]
      }

      # Mock the DSL state and verifier functions
      with_mock Verifier,
        get_persisted: fn _state, :module -> TestResource end,
        get_entities: fn
          _state, [:commanded, :commands] ->
            [command]

          _state, [:attributes] ->
            [
              %{name: :id},
              %{name: :email},
              %{name: :name}
            ]
        end do
        result = ValidateCommandFields.verify(%{})
        assert {:error, error} = result
        assert error.message =~ "Command `register_user` has unknown fields"
        assert error.message =~ ":nonexistent_field"
      end
    end

    test "includes all commands with invalid fields in the error message" do
      # Create multiple mock commands with invalid fields
      command1 = %Command{
        name: :register_user,
        fields: [:id, :email, :nonexistent_field1]
      }

      command2 = %Command{
        name: :update_user,
        fields: [:id, :nonexistent_field2]
      }

      # Mock the DSL state and verifier functions
      with_mock Verifier,
        get_persisted: fn _state, :module -> TestResource end,
        get_entities: fn
          _state, [:commanded, :commands] ->
            [command1, command2]

          _state, [:attributes] ->
            [
              %{name: :id},
              %{name: :email},
              %{name: :name}
            ]
        end do
        result = ValidateCommandFields.verify(%{})
        assert {:error, error} = result
        assert error.message =~ "Command `register_user` has unknown fields"
        assert error.message =~ ":nonexistent_field1"
        assert error.message =~ "Command `update_user` has unknown fields"
        assert error.message =~ ":nonexistent_field2"
      end
    end
  end
end
