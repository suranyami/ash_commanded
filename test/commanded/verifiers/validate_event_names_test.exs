defmodule AshCommanded.Commanded.Verifiers.ValidateEventNamesTest do
  use ExUnit.Case, async: false
  @moduletag :verifier_test

  alias AshCommanded.Commanded.Event
  alias AshCommanded.Commanded.Verifiers.ValidateEventNames
  alias Spark.Dsl.Verifier

  import Mock

  describe "verify/1" do
    test "returns :ok when all event names are unique" do
      # Create mock events with unique names
      event1 = %Event{
        name: :user_registered,
        fields: [:id, :email, :name]
      }

      event2 = %Event{
        name: :user_updated,
        fields: [:id, :email, :name]
      }

      # Mock the DSL state and verifier functions
      with_mock Verifier,
        get_persisted: fn _state, :module -> TestResource end,
        get_entities: fn
          _state, [:commanded, :events] -> [event1, event2]
        end do
        assert ValidateEventNames.verify(%{}) == :ok
      end
    end

    test "returns an error when duplicate event names are found" do
      # Create mock events with duplicate names
      event1 = %Event{
        name: :user_event,
        fields: [:id, :email, :name]
      }

      event2 = %Event{
        name: :user_event,
        fields: [:id, :email, :name]
      }

      # Mock the DSL state and verifier functions
      with_mock Verifier,
        get_persisted: fn _state, :module -> TestResource end,
        get_entities: fn
          _state, [:commanded, :events] -> [event1, event2]
        end do
        result = ValidateEventNames.verify(%{})
        assert {:error, error} = result
        assert error.message =~ "The following event names are duplicated in TestResource"
        assert error.message =~ ":user_event"
        assert error.path == [:commanded, :events]
      end
    end

    test "identifies all duplicate event names in the error message" do
      # Create multiple duplicate event names
      event1 = %Event{
        name: :user_registered,
        fields: [:id, :email, :name]
      }

      event2 = %Event{
        name: :user_registered,
        fields: [:id, :email]
      }

      event3 = %Event{
        name: :password_changed,
        fields: [:id, :password]
      }

      event4 = %Event{
        name: :password_changed,
        fields: [:id, :password]
      }

      # Mock the DSL state and verifier functions
      with_mock Verifier,
        get_persisted: fn _state, :module -> TestResource end,
        get_entities: fn
          _state, [:commanded, :events] -> [event1, event2, event3, event4]
        end do
        result = ValidateEventNames.verify(%{})
        assert {:error, error} = result
        assert error.message =~ "The following event names are duplicated in TestResource"
        assert error.message =~ ":user_registered"
        assert error.message =~ ":password_changed"
      end
    end
  end
end
