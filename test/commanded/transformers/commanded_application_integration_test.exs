defmodule AshCommanded.Test.Commanded.Transformers.CommandedApplicationIntegrationTest do
  @moduledoc false
  use ExUnit.Case

  # Define a test domain with application configuration (DomainDsl adds the application section)
  defmodule TestDomain do
    use Ash.Domain,
      extensions: [AshCommanded.Commanded.DomainDsl],
      validate_config_inclusion?: false

    @doc false
    def app_path() do
      :ash_commanded
      |> :code.priv_dir()
      |> Path.join("tmp")
    end

    @doc false
    def create_app_path() do
      app_path()
      |> File.mkdir_p!()
    end

    resources do
      resource AshCommanded.Test.Commanded.Transformers.CommandedApplicationIntegrationTest.TestResource
    end

    if Code.ensure_loaded?(Commanded.Application) do
      # Only define this if Commanded is available (which it might not be in tests)
      commanded do
        application do
          otp_app(:ash_commanded)
          event_store(Commanded.EventStore.Adapters.InMemory)
          include_supervisor?(true)
        end
      end
    end
  end

  # A simple test resource with commands and events
  defmodule TestResource do
    use Ash.Resource,
      domain: TestDomain,
      extensions: [AshCommanded.Commanded.Dsl]

    if Code.ensure_loaded?(Commanded.Application) do
      commanded do
        commands do
          command :create_resource do
            fields([:id, :name])
            identity_field(:id)
          end
        end

        events do
          event :resource_created do
            fields([:id, :name])
          end
        end
      end
    end
  end

  @tag :skip_if_no_commanded
  setup do
    # Skip the test if Commanded is not available
    unless Code.ensure_loaded?(Commanded.Application) do
      :ok = ExUnit.configure(exclude: [skip_if_no_commanded: true])
      {:skip, "Commanded is not available, skipping test"}
    else
      :ok
    end
  end

  @tag :skip_if_no_commanded
  test "generates application module for domain" do
    # The test will pass if the module is created without errors
    assert Code.ensure_loaded?(TestDomain.Application)
  end

  @tag :skip_if_no_commanded
  test "generated application has correct configuration" do
    app_module = TestDomain.Application

    # Check that the module uses Commanded.Application
    assert function_exported?(app_module, :config, 0)

    # Check supervisor-related function if include_supervisor? was true
    assert function_exported?(app_module, :child_spec, 0)
  end

  # This test validates that our transformer is working correctly in the DSL flow
  # by checking that it runs after the router module is generated
  @tag :skip_if_no_commanded
  test "transformer order is correct" do
    # Load the transformer module
    alias AshCommanded.Commanded.Transformers.GenerateCommandedApplication

    # Check that it runs after the main router module
    assert GenerateCommandedApplication.after?(
             AshCommanded.Commanded.Transformers.GenerateMainRouterModule
           )
  end
end
