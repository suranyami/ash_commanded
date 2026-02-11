defmodule AshCommanded.Commanded.Verifiers.ValidateProjectionActionsTest do
  use ExUnit.Case, async: false
  @moduletag :verifier_test

  alias AshCommanded.Commanded.Projection
  alias AshCommanded.Commanded.Verifiers.ValidateProjectionActions
  alias Spark.Dsl.Verifier

  import Mock

  describe "verify/1" do
    test "returns :ok when all projections have valid actions" do
      # Create projections with valid actions
      create_projection = %Projection{
        name: :user_registered,
        action: :create,
        changes: %{status: :active}
      }

      update_projection = %Projection{
        name: :email_changed,
        action: :update,
        changes: %{email: "new@example.com"}
      }

      destroy_projection = %Projection{
        name: :user_deleted,
        action: :destroy,
        changes: %{}
      }

      # Mock the DSL state and verifier functions
      with_mock Verifier,
        get_persisted: fn _state, :module -> TestResource end,
        get_entities: fn
          _state, [:commanded, :projections] ->
            [create_projection, update_projection, destroy_projection]
        end do
        assert ValidateProjectionActions.verify(%{}) == :ok
      end
    end

    test "returns an error when a projection has an invalid action" do
      # Create a projection with an invalid action
      invalid_projection = %Projection{
        name: :user_registered,
        action: :invalid_action,
        changes: %{status: :active}
      }

      # Mock the DSL state and verifier functions
      with_mock Verifier,
        get_persisted: fn _state, :module -> TestResource end,
        get_entities: fn
          _state, [:commanded, :projections] -> [invalid_projection]
        end do
        result = ValidateProjectionActions.verify(%{})
        assert {:error, error} = result

        assert error.message =~
                 "Projection `user_registered` specifies potentially invalid action `invalid_action`"

        assert error.message =~ "Common valid Ash actions include"
        assert error.message =~ "- :create"
        assert error.message =~ "- :update"
        assert error.message =~ "- :destroy"
      end
    end

    test "returns an error with multiple invalid projections" do
      # Create multiple projections with invalid actions
      invalid_projection1 = %Projection{
        name: :user_registered,
        action: :invalid_action1,
        changes: %{status: :active}
      }

      invalid_projection2 = %Projection{
        name: :email_changed,
        action: :invalid_action2,
        changes: %{email: "new@example.com"}
      }

      valid_projection = %Projection{
        name: :user_deleted,
        action: :destroy,
        changes: %{}
      }

      # Mock the DSL state and verifier functions
      with_mock Verifier,
        get_persisted: fn _state, :module -> TestResource end,
        get_entities: fn
          _state, [:commanded, :projections] ->
            [invalid_projection1, invalid_projection2, valid_projection]
        end do
        result = ValidateProjectionActions.verify(%{})
        assert {:error, error} = result

        # Check that both invalid projections are mentioned
        assert error.message =~
                 "Projection `user_registered` specifies potentially invalid action `invalid_action1`"

        assert error.message =~
                 "Projection `email_changed` specifies potentially invalid action `invalid_action2`"

        # Check that valid actions are listed
        assert error.message =~ "Common valid Ash actions include"
        assert error.message =~ "- :create"
        assert error.message =~ "- :update"
        assert error.message =~ "- :destroy"
      end
    end
  end
end
