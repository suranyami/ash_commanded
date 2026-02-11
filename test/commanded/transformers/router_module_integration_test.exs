defmodule AshCommanded.Commanded.Transformers.RouterModuleIntegrationTest do
  use ExUnit.Case, async: false

  alias AshCommanded.Commanded.Transformers.GenerateDomainRouterModule
  alias AshCommanded.Commanded.Transformers.GenerateMainRouterModule

  describe "router module generation" do
    test "domain router transformer is properly configured" do
      # Verify the transformer implements the Spark.Dsl.Transformer behaviour
      assert Spark.implements_behaviour?(GenerateDomainRouterModule, Spark.Dsl.Transformer)
    end

    test "main router transformer is properly configured" do
      # Verify the transformer implements the Spark.Dsl.Transformer behaviour
      assert Spark.implements_behaviour?(GenerateMainRouterModule, Spark.Dsl.Transformer)
    end
  end
end
