defmodule AshCommanded.Commanded.Transformers.DomainRouterGeneratorTest do
  use ExUnit.Case, async: true

  alias AshCommanded.Commanded.Transformers.GenerateDomainRouterModule

  describe "domain router module generation helpers" do
    test "builds correct module names" do
      # Test module naming
      module_name = GenerateDomainRouterModule.build_domain_router_module(MyApp.Accounts)

      assert module_name == MyApp.Accounts.Router
    end
  end
end
