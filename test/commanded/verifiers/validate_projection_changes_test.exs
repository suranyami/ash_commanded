defmodule AshCommanded.Commanded.Verifiers.ValidateProjectionChangesTest do
  use ExUnit.Case, async: false
  @moduletag :verifier_test

  alias AshCommanded.Commanded.Projection
  alias AshCommanded.Commanded.Verifiers.ValidateProjectionChanges
  alias Spark.Dsl.Verifier

  import Mock

  describe "verify/1" do
    test "returns :ok when all static projection changes reference valid attributes" do
      # Create projection with valid attribute changes
      projection = %Projection{
        name: :user_registered,
        action: :create,
        changes: %{
          name: "Test User",
          email: "test@example.com",
          status: :active
        }
      }

      # Mock the DSL state and verifier functions
      with_mock Verifier,
        get_persisted: fn _state, :module -> TestResource end,
        get_entities: fn
          _state, [:commanded, :projections] ->
            [projection]

          _state, [:attributes] ->
            [
              %{name: :id},
              %{name: :name},
              %{name: :email},
              %{name: :status}
            ]
        end do
        assert ValidateProjectionChanges.verify(%{}) == :ok
      end
    end

    test "skips validation for function-based changes" do
      # Create a projection with a function for changes
      # The validator should skip this as it can't validate function output
      changes_fn = fn _event -> %{} end

      projection = %Projection{
        name: :user_registered,
        action: :create,
        changes: changes_fn
      }

      # Mock the DSL state and verifier functions
      with_mock Verifier,
        get_persisted: fn _state, :module -> TestResource end,
        get_entities: fn
          _state, [:commanded, :projections] ->
            [projection]

          _state, [:attributes] ->
            [
              %{name: :id},
              %{name: :name},
              %{name: :email}
            ]
        end do
        assert ValidateProjectionChanges.verify(%{}) == :ok
      end
    end

    test "returns an error when static changes reference invalid attributes" do
      # Create projection with invalid attribute references
      projection = %Projection{
        name: :user_registered,
        action: :create,
        changes: %{
          name: "Test User",
          nonexistent_field: "test value",
          another_bad_field: 123
        }
      }

      # Mock the DSL state and verifier functions
      with_mock Verifier,
        get_persisted: fn _state, :module -> TestResource end,
        get_entities: fn
          _state, [:commanded, :projections] ->
            [projection]

          _state, [:attributes] ->
            [
              %{name: :id},
              %{name: :name},
              %{name: :email}
            ]
        end do
        result = ValidateProjectionChanges.verify(%{})
        assert {:error, error} = result
        assert error.message =~ "Projection `user_registered` has unknown attributes:"
        assert error.message =~ ":nonexistent_field"
        assert error.message =~ ":another_bad_field"
        assert error.message =~ "The following attributes are defined in TestResource"
        assert error.message =~ "- :id"
        assert error.message =~ "- :name"
        assert error.message =~ "- :email"
      end
    end

    test "returns an error with multiple invalid projections" do
      # Create multiple projections with invalid attributes
      projection1 = %Projection{
        name: :user_registered,
        action: :create,
        changes: %{
          name: "Test User",
          nonexistent_field1: "value"
        }
      }

      projection2 = %Projection{
        name: :email_changed,
        action: :update,
        changes: %{
          email: "new@example.com",
          nonexistent_field2: "value"
        }
      }

      valid_projection = %Projection{
        name: :user_active,
        action: :update,
        changes: %{status: :active}
      }

      # Mock the DSL state and verifier functions
      with_mock Verifier,
        get_persisted: fn _state, :module -> TestResource end,
        get_entities: fn
          _state, [:commanded, :projections] ->
            [projection1, projection2, valid_projection]

          _state, [:attributes] ->
            [
              %{name: :id},
              %{name: :name},
              %{name: :email},
              %{name: :status}
            ]
        end do
        result = ValidateProjectionChanges.verify(%{})
        assert {:error, error} = result

        # Check that both invalid projections are mentioned
        assert error.message =~
                 "Projection `user_registered` has unknown attributes: :nonexistent_field1"

        assert error.message =~
                 "Projection `email_changed` has unknown attributes: :nonexistent_field2"

        # Check that valid attributes are listed
        assert error.message =~ "The following attributes are defined in TestResource"
        assert error.message =~ "- :id"
        assert error.message =~ "- :name"
        assert error.message =~ "- :email"
        assert error.message =~ "- :status"
      end
    end
  end
end
