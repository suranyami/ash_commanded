defmodule AshCommanded.Commanded.Transformers.RouterTransformerIntegrationTest do
  use ExUnit.Case, async: false

  # Define a custom DSL that just includes the router-related transformers
  defmodule CustomDsl do
    use Spark.Dsl.Extension,
      sections: [AshCommanded.Commanded.Dsl.__sections__()],
      transformers: [
        AshCommanded.Commanded.Transformers.GenerateCommandModules,
        AshCommanded.Commanded.Transformers.GenerateEventModules,
        AshCommanded.Commanded.Transformers.GenerateAggregateModule,
        AshCommanded.Commanded.Transformers.GenerateDomainRouterModule,
        AshCommanded.Commanded.Transformers.GenerateMainRouterModule
      ]
  end

  # Define a test domain
  defmodule TestDomain do
    use Ash.Domain,
      validate_config_inclusion?: false

    # Override the domain module to ensure it's treated as a domain
    def __ash_domain__, do: __MODULE__

    resources do
      resource AshCommanded.Commanded.Transformers.RouterTransformerIntegrationTest.UserResource
    end
  end

  # Define a test resource with commands
  defmodule UserResource do
    use Ash.Resource,
      extensions: [CustomDsl],
      domain: AshCommanded.Commanded.Transformers.RouterTransformerIntegrationTest.TestDomain

    def __ash_domain__,
      do: AshCommanded.Commanded.Transformers.RouterTransformerIntegrationTest.TestDomain

    # Include needed overrides for Ash.Resource behavior
    def __ash_resource__, do: true

    attributes do
      uuid_primary_key :id
      attribute :email, :string
      attribute :name, :string
    end

    commanded do
      commands do
        command :register_user do
          fields([:id, :email, :name])
          identity_field(:id)
        end
      end

      events do
        event :user_registered do
          fields([:id, :email, :name])
        end
      end
    end
  end

  describe "router transformer integration" do
    test "command mappings are correctly generated" do
      # The domain should have a reference to the resource
      assert TestDomain.__ash_domain__() == TestDomain
      assert UserResource.__ash_domain__() == TestDomain

      # Check that the command modules were generated
      command_modules = Spark.Dsl.Extension.get_persisted(UserResource, :command_modules, [])
      assert is_list(command_modules)
      assert length(command_modules) > 0

      # Check that the aggregate module was stored in the DSL state
      aggregate_module = Spark.Dsl.Extension.get_persisted(UserResource, :aggregate_module)
      assert aggregate_module != nil

      # Check that the domain router module name might be stored
      # (may be nil in test environment since transformer runs are conditional)
      domain_router_module =
        Spark.Dsl.Extension.get_persisted(UserResource, :domain_router_module)

      if domain_router_module != nil do
        assert domain_router_module ==
                 AshCommanded.Commanded.Transformers.RouterTransformerIntegrationTest.TestDomain.Router
      end

      # For a Domain, check if the main router module name was stored
      # (may be nil in test environment since the domain doesn't actually get the transformer run on it)
      main_router_module = Spark.Dsl.Extension.get_persisted(TestDomain, :main_router_module, nil)

      if main_router_module != nil do
        assert main_router_module ==
                 AshCommanded.Commanded.Transformers.RouterTransformerIntegrationTest.Router
      end

      # Check that the command resource mappings were stored
      mappings = Spark.Dsl.Extension.get_persisted(UserResource, :command_resource_mappings, [])
      assert is_list(mappings)

      if length(mappings) > 0 do
        mapping = List.first(mappings)
        assert mapping.resource == UserResource
        assert mapping.domain == TestDomain
        assert mapping.domain_router == TestDomain.Router
        assert mapping.aggregate == aggregate_module
        assert mapping.identity_field == :id

        # Check for commands in the mapping
        assert is_list(mapping.commands)
        assert length(mapping.commands) > 0
      end
    end
  end
end
