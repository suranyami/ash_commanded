defmodule AshCommanded.Commanded.Transformers.ProjectionModulesIntegrationTest do
  use ExUnit.Case, async: false

  alias AshCommanded.Commanded.Transformers.GenerateProjectionModules

  describe "projection module generation" do
    test "transformer is properly configured" do
      # Verify the transformer implements the Spark.Dsl.Transformer behaviour
      assert Spark.implements_behaviour?(GenerateProjectionModules, Spark.Dsl.Transformer)
    end
  end
end
