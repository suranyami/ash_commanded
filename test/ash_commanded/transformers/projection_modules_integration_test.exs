defmodule AshCommanded.Transformers.ProjectionModulesIntegrationTest do
  use ExUnit.Case, async: false

  alias AshCommanded.Resource.Transformers.GenerateProjectionModules

  describe "projection module generation" do
    test "transformer is properly configured" do
      # Verify the transformer implements the Spark.Dsl.Transformer behaviour
      assert Spark.implements_behaviour?(GenerateProjectionModules, Spark.Dsl.Transformer)
    end
  end
end
