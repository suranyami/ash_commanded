defmodule AshCommanded.Commanded.Transformers.AggregateModuleIntegrationTest do
  use ExUnit.Case, async: false

  alias AshCommanded.Commanded.Transformers.GenerateAggregateModule

  describe "aggregate module generation" do
    test "transformer is properly configured" do
      # Verify the transformer implements the Spark.Dsl.Transformer behaviour
      assert Spark.implements_behaviour?(GenerateAggregateModule, Spark.Dsl.Transformer)
    end
  end
end
