defmodule AshCommanded.Commanded.Verifiers.ValidateProjectionEventsTest do
  use ExUnit.Case, async: false
  @moduletag :verifier_test

  alias AshCommanded.Commanded.Event
  alias AshCommanded.Commanded.Projection
  alias AshCommanded.Commanded.Verifiers.ValidateProjectionEvents
  alias Spark.Dsl.Verifier

  import Mock

  describe "verify/1" do
    test "returns :ok when all projections reference valid events" do
      # Mock events and projections
      event = %Event{
        name: :user_registered,
        fields: [:id, :email, :name]
      }

      projection = %Projection{
        name: :activate_user,
        event_name: :user_registered,
        action: :create,
        changes: %{status: :active}
      }

      # Mock the DSL state and verifier functions
      with_mock Verifier,
        get_persisted: fn _state, :module -> TestResource end,
        get_entities: fn
          _state, [:commanded, :projections] -> [projection]
          _state, [:commanded, :events] -> [event]
        end do
        assert ValidateProjectionEvents.verify(%{}) == :ok
      end
    end

    test "returns :ok when projection name matches event name" do
      # Mock events and projections with matching names
      event = %Event{
        name: :user_registered,
        fields: [:id, :email, :name]
      }

      projection = %Projection{
        # Matches event name
        name: :user_registered,
        # No explicit event_name, will use name
        event_name: nil,
        action: :create,
        changes: %{status: :active}
      }

      # Mock the DSL state and verifier functions
      with_mock Verifier,
        get_persisted: fn _state, :module -> TestResource end,
        get_entities: fn
          _state, [:commanded, :projections] -> [projection]
          _state, [:commanded, :events] -> [event]
        end do
        assert ValidateProjectionEvents.verify(%{}) == :ok
      end
    end

    test "returns an error when a projection references a non-existent event" do
      # Mock events and invalid projections
      event = %Event{
        name: :user_registered,
        fields: [:id, :email, :name]
      }

      projection = %Projection{
        name: :activate_user,
        # This event doesn't exist
        event_name: :nonexistent_event,
        action: :create,
        changes: %{status: :active}
      }

      # Mock the DSL state and verifier functions
      with_mock Verifier,
        get_persisted: fn _state, :module -> TestResource end,
        get_entities: fn
          _state, [:commanded, :projections] -> [projection]
          _state, [:commanded, :events] -> [event]
        end do
        result = ValidateProjectionEvents.verify(%{})
        assert {:error, error} = result

        assert error.message =~
                 "Projection `activate_user` references unknown event `nonexistent_event`"

        assert error.message =~ "The following events are defined in TestResource"
        assert error.message =~ "- :user_registered"
      end
    end

    test "returns an error with multiple invalid projections" do
      # Mock events and multiple invalid projections
      event = %Event{
        name: :user_registered,
        fields: [:id, :email, :name]
      }

      invalid_projection1 = %Projection{
        name: :activate_user,
        event_name: :nonexistent_event1,
        action: :create,
        changes: %{status: :active}
      }

      invalid_projection2 = %Projection{
        name: :update_email,
        event_name: :nonexistent_event2,
        action: :update,
        changes: %{email: "new@example.com"}
      }

      valid_projection = %Projection{
        name: :handle_registration,
        event_name: :user_registered,
        action: :create,
        changes: %{registered: true}
      }

      # Mock the DSL state and verifier functions
      with_mock Verifier,
        get_persisted: fn _state, :module -> TestResource end,
        get_entities: fn
          _state, [:commanded, :projections] ->
            [invalid_projection1, invalid_projection2, valid_projection]

          _state, [:commanded, :events] ->
            [event]
        end do
        result = ValidateProjectionEvents.verify(%{})
        assert {:error, error} = result

        # Check that both invalid projections are mentioned
        assert error.message =~
                 "Projection `activate_user` references unknown event `nonexistent_event1`"

        assert error.message =~
                 "Projection `update_email` references unknown event `nonexistent_event2`"

        # Check that valid events are listed
        assert error.message =~ "The following events are defined in TestResource"
        assert error.message =~ "- :user_registered"
      end
    end
  end
end
