defmodule AshCommanded.Commanded.Transformers.EventModulesIntegrationTest do
  use ExUnit.Case, async: false

  alias AshCommanded.Commanded.Transformers.GenerateEventModules

  describe "event module generation" do
    test "transformer is properly configured" do
      # Verify the transformer implements the Spark.Dsl.Transformer behaviour
      assert Spark.implements_behaviour?(GenerateEventModules, Spark.Dsl.Transformer)
    end
  end
end
