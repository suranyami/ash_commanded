defmodule AshCommanded.Commanded.Transformers.EventGeneratorTest do
  use ExUnit.Case, async: true

  alias AshCommanded.Commanded.Event
  alias AshCommanded.Commanded.Transformers.GenerateEventModules

  describe "event module generation helpers" do
    test "builds correct module names" do
      # Access the private function for testing
      event = %Event{
        name: :user_registered,
        fields: [:id, :email, :name],
        event_name: nil
      }

      # Test module naming
      module_name =
        invoke_private(
          GenerateEventModules,
          :build_event_module,
          [event, MyApp.Accounts]
        )

      assert module_name == MyApp.Accounts.Events.UserRegistered

      # Test with custom event name
      event_with_custom_name = %Event{
        name: :user_registered,
        fields: [:id, :email, :name],
        event_name: :new_user_created
      }

      module_name =
        invoke_private(
          GenerateEventModules,
          :build_event_module,
          [event_with_custom_name, MyApp.Accounts]
        )

      assert module_name == MyApp.Accounts.Events.NewUserCreated
    end

    test "builds correct module AST" do
      event = %Event{
        name: :user_registered,
        fields: [:id, :email, :name],
        event_name: nil
      }

      # Test the AST generation
      ast =
        invoke_private(
          GenerateEventModules,
          :build_event_module_ast,
          [event, "User"]
        )

      # The AST should be a block with @moduledoc, @type, and defstruct
      assert is_tuple(ast)
      assert elem(ast, 0) == :__block__

      block_contents = elem(ast, 2)

      assert Enum.any?(block_contents, fn node ->
               match?({:@, _, [{:moduledoc, _, _}]}, node)
             end)

      assert Enum.any?(block_contents, fn node ->
               match?({:@, _, [{:type, _, _}]}, node)
             end)

      assert Enum.any?(block_contents, fn node ->
               match?({:defstruct, _, _}, node)
             end)
    end
  end

  # Helper to invoke private functions for testing
  defp invoke_private(module, function, args) do
    apply(module, function, args)
  catch
    :error, :undef -> {:error, "Private function #{function} not accessible"}
  end
end
