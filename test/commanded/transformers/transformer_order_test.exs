defmodule AshCommanded.Commanded.Transformers.TransformerOrderTest do
  use ExUnit.Case, async: true

  alias AshCommanded.Commanded.Transformers.GenerateCommandModules
  alias AshCommanded.Commanded.Transformers.GenerateEventModules
  alias AshCommanded.Commanded.Transformers.GenerateMainRouterModule
  alias AshCommanded.Commanded.Transformers.GenerateCommandedApplication

  describe "transformer ordering" do
    test "event module transformer runs after command module transformer" do
      # Check that the event module transformer is configured to run after command module transformer
      assert GenerateEventModules.after?(GenerateCommandModules)

      # Command module transformer should not be configured to run after event module transformer
      refute GenerateCommandModules.after?(GenerateEventModules)

      # Command module transformer should be configured to run before event module transformer
      assert GenerateCommandModules.before?(GenerateEventModules)

      # Event module transformer might not have before? implemented, so catch if it fails
      try do
        refute GenerateEventModules.before?(GenerateCommandModules)
      rescue
        UndefinedFunctionError -> :ok
      end

      # For completeness, check that transformers don't need to run after themselves
      refute GenerateCommandModules.after?(GenerateCommandModules)
      refute GenerateEventModules.after?(GenerateEventModules)
    end

    test "commanded application transformer runs after main router transformer" do
      # Check that the application transformer is configured to run after main router transformer
      assert GenerateCommandedApplication.after?(GenerateMainRouterModule)

      # Main router transformer should not be configured to run after application transformer
      refute GenerateMainRouterModule.after?(GenerateCommandedApplication)

      # For completeness, check that transformers don't need to run after themselves
      refute GenerateCommandedApplication.after?(GenerateCommandedApplication)
    end
  end
end
