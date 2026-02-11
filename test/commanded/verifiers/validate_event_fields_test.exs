defmodule AshCommanded.Commanded.Verifiers.ValidateEventFieldsTest do
  use ExUnit.Case, async: false
  @moduletag :verifier_test

  alias AshCommanded.Commanded.Event
  alias AshCommanded.Commanded.Verifiers.ValidateEventFields
  alias Spark.Dsl.Verifier

  import Mock

  describe "verify/1" do
    test "returns :ok when all event fields are valid resource attributes" do
      # Create mock events with valid fields
      event = %Event{
        name: :user_registered,
        fields: [:id, :email, :name]
      }

      # Mock the DSL state and verifier functions
      with_mock Verifier,
        get_persisted: fn _state, :module -> TestResource end,
        get_entities: fn
          _state, [:commanded, :events] ->
            [event]

          _state, [:attributes] ->
            [
              %{name: :id},
              %{name: :email},
              %{name: :name}
            ]
        end do
        assert ValidateEventFields.verify(%{}) == :ok
      end
    end

    test "returns an error when an event has fields that don't exist in the resource" do
      # Create mock events with invalid fields
      event = %Event{
        name: :user_registered,
        fields: [:id, :email, :nonexistent_field]
      }

      # Mock the DSL state and verifier functions
      with_mock Verifier,
        get_persisted: fn _state, :module -> TestResource end,
        get_entities: fn
          _state, [:commanded, :events] ->
            [event]

          _state, [:attributes] ->
            [
              %{name: :id},
              %{name: :email},
              %{name: :name}
            ]
        end do
        result = ValidateEventFields.verify(%{})
        assert {:error, error} = result
        assert error.message =~ "Event `user_registered` has unknown fields"
        assert error.message =~ ":nonexistent_field"
      end
    end

    test "includes all events with invalid fields in the error message" do
      # Create multiple mock events with invalid fields
      event1 = %Event{
        name: :user_registered,
        fields: [:id, :email, :nonexistent_field1]
      }

      event2 = %Event{
        name: :user_updated,
        fields: [:id, :nonexistent_field2]
      }

      # Mock the DSL state and verifier functions
      with_mock Verifier,
        get_persisted: fn _state, :module -> TestResource end,
        get_entities: fn
          _state, [:commanded, :events] ->
            [event1, event2]

          _state, [:attributes] ->
            [
              %{name: :id},
              %{name: :email},
              %{name: :name}
            ]
        end do
        result = ValidateEventFields.verify(%{})
        assert {:error, error} = result
        assert error.message =~ "Event `user_registered` has unknown fields"
        assert error.message =~ ":nonexistent_field1"
        assert error.message =~ "Event `user_updated` has unknown fields"
        assert error.message =~ ":nonexistent_field2"
      end
    end
  end
end
