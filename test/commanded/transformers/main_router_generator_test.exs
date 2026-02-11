defmodule AshCommanded.Commanded.Transformers.MainRouterGeneratorTest do
  use ExUnit.Case, async: true

  alias AshCommanded.Commanded.Transformers.GenerateMainRouterModule

  describe "main router module generation helpers" do
    test "builds correct module names" do
      # Test module naming
      module_name = GenerateMainRouterModule.build_main_router_module(MyApp)

      assert module_name == MyApp.Router
    end
  end
end
