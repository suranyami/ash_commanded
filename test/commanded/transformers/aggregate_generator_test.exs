defmodule AshCommanded.Commanded.Transformers.AggregateGeneratorTest do
  use ExUnit.Case, async: true
  
  alias AshCommanded.Commanded.Command
  alias AshCommanded.Commanded.Event
  alias AshCommanded.Commanded.Transformers.GenerateAggregateModule
  
  describe "aggregate module generation helpers" do
    test "builds correct module names" do
      # Test module naming
      module_name = invoke_private(
        GenerateAggregateModule,
        :build_aggregate_module,
        ["User", MyApp.Accounts]
      )
      
      assert module_name == MyApp.Accounts.UserAggregate
    end
    
    test "builds correct module AST" do
      # Set up test data
      attribute_names = [:id, :email, :name, :status]
      
      command = %Command{
        name: :register_user,
        fields: [:id, :email, :name],
        identity_field: :id
      }
      
      event = %Event{
        name: :user_registered,
        fields: [:id, :email, :name]
      }
      
      command_modules = %{
        register_user: MyApp.Commands.RegisterUser
      }
      
      event_modules = %{
        user_registered: MyApp.Events.UserRegistered
      }
      
      # Generate the AST
      ast = invoke_private(
        GenerateAggregateModule,
        :build_aggregate_module_ast,
        [
          "User",
          attribute_names,
          [command],
          [event],
          command_modules,
          event_modules
        ]
      )
      
      # The AST should be a block with expected elements
      ast_string = Macro.to_string(ast)
      
      # Check for expected components
      assert String.contains?(ast_string, "@moduledoc")
      assert String.contains?(ast_string, "defstruct")
      
      # Check for defstruct keyword and struct fields
      assert String.contains?(ast_string, "defstruct")
      
      # Test if struct looks like it contains our fields
      # Due to Macro.to_string formatting, we can't precisely check field format
      # But we can still check for presence of field keywords
      assert String.contains?(ast_string, "id:")
      assert String.contains?(ast_string, "email:")
      assert String.contains?(ast_string, "name:")
      
      # Check for execute function
      assert String.contains?(ast_string, "def execute")
      assert String.contains?(ast_string, "RegisterUser")
      
      # Check for apply function
      assert String.contains?(ast_string, "def apply")
      assert String.contains?(ast_string, "UserRegistered")
    end
    
    test "handles commands with no matching events" do
      # Set up test data with a command that has no matching event
      attribute_names = [:id, :email]
      
      command = %Command{
        name: :update_email,
        fields: [:id, :email],
        identity_field: :id
      }
      
      # No matching event for update_email
      event = %Event{
        name: :user_registered,
        fields: [:id, :email, :name]
      }
      
      command_modules = %{
        update_email: MyApp.Commands.UpdateEmail
      }
      
      event_modules = %{
        user_registered: MyApp.Events.UserRegistered
      }
      
      # Generate the AST
      ast = invoke_private(
        GenerateAggregateModule,
        :build_aggregate_module_ast,
        [
          "User",
          attribute_names,
          [command],
          [event],
          command_modules,
          event_modules
        ]
      )
      
      # Convert to string for easier inspection
      ast_string = Macro.to_string(ast)
      
      # Check that it includes warning about not implemented command
      assert String.contains?(ast_string, "Command not implemented")
      assert String.contains?(ast_string, "Error.aggregate_error")
      assert String.contains?(ast_string, "Logger.warning")
    end
  end
  
  # Helper to invoke private functions for testing
  defp invoke_private(module, function, args) do
    apply(module, function, args)
  catch
    :error, :undef -> {:error, "Private function #{function} not accessible"}
  end
end