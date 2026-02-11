defmodule AshCommanded.Commanded.Transformers.ProjectorModulesIntegrationTest do
  use ExUnit.Case, async: false

  alias AshCommanded.Commanded.Transformers.GenerateProjectorModules

  describe "projector module generation" do
    test "transformer is properly configured" do
      # Verify the transformer implements the Spark.Dsl.Transformer behaviour
      assert Spark.implements_behaviour?(GenerateProjectorModules, Spark.Dsl.Transformer)
    end
  end
end
