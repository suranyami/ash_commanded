defmodule AshCommanded.Test.Commanded.Transformers.CommandedApplicationGeneratorTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias AshCommanded.Commanded.Transformers.GenerateCommandedApplication
  alias Spark.Dsl.Transformer

  # Required to persist :module (domain module) in test DSL when simulating Domain context
  defmodule TestDsl do
    defstruct [:persist_fn]

    def persist(%__MODULE__{} = dsl, key, value) do
      %{dsl | persist_fn: {key, value}}
    end

    def get_persisted(%__MODULE__{persist_fn: {persisted_key, value}}, requested_key)
        when persisted_key == requested_key,
        do: value

    def get_persisted(%__MODULE__{}, :module), do: TestDomain
    def get_persisted(%__MODULE__{}, _), do: nil

    def get_entities(%__MODULE__{}, [:resources]), do: {:ok, [TestResource]}
  end

  # Simple resource for testing
  defmodule TestResource do
    defstruct []
  end

  describe "transform/1" do
    @tag :skip_if_no_commanded
    test "returns the dsl unchanged when there is no application config" do
      dsl = %TestDsl{persist_fn: {:module, TestDomain}}

      # Mock the application function to return nil (no config)
      :meck.new(AshCommanded.Commanded.Dsl, [:passthrough])
      :meck.expect(AshCommanded.Commanded.Dsl, :application, fn _ -> nil end)

      assert {:ok, unchanged_dsl} = GenerateCommandedApplication.transform(dsl)
      assert unchanged_dsl == dsl

      :meck.unload(AshCommanded.Commanded.Dsl)
    end

    @tag :skip_if_no_commanded
    test "generates a module when application config is present" do
      dsl = %TestDsl{persist_fn: {:module, TestDomain}}

      # Mock application to return a config
      app_config = [
        otp_app: :test_app,
        event_store: Commanded.EventStore.Adapters.InMemory,
        include_supervisor?: false
      ]

      :meck.new(AshCommanded.Commanded.Dsl, [:passthrough])
      :meck.expect(AshCommanded.Commanded.Dsl, :application, fn _ -> app_config end)

      # Mock create_module to capture the generated code
      :meck.new(AshCommanded.Commanded.Transformers.BaseTransformer, [:passthrough])

      :meck.expect(AshCommanded.Commanded.Transformers.BaseTransformer, :create_module, fn module,
                                                                                           code,
                                                                                           _env ->
        assert module == TestDomain.Application
        assert_app_module_code(code, app_config)
        :ok
      end)

      # Mock persist to verify we're storing the module
      :meck.new(Transformer, [:passthrough])

      :meck.expect(Transformer, :persist, fn _dsl, :commanded_application_module, module ->
        assert module == TestDomain.Application
        dsl
      end)

      {:ok, _updated_dsl} = GenerateCommandedApplication.transform(dsl)

      assert :meck.called(AshCommanded.Commanded.Transformers.BaseTransformer, :create_module, [
               :_,
               :_,
               :_
             ])

      assert :meck.called(Transformer, :persist, [:_, :commanded_application_module, :_])

      :meck.unload(AshCommanded.Commanded.Dsl)
      :meck.unload(Transformer)
      :meck.unload(AshCommanded.Commanded.Transformers.BaseTransformer)
    end

    @tag :skip_if_no_commanded
    test "generates a module with supervisor when include_supervisor? is true" do
      dsl = %TestDsl{persist_fn: {:module, TestDomain}}

      # Mock application to return a config with supervisor
      app_config = [
        otp_app: :test_app,
        event_store: Commanded.EventStore.Adapters.InMemory,
        include_supervisor?: true
      ]

      :meck.new(AshCommanded.Commanded.Dsl, [:passthrough])
      :meck.expect(AshCommanded.Commanded.Dsl, :application, fn _ -> app_config end)

      # Mock create_module to capture the generated code
      :meck.new(AshCommanded.Commanded.Transformers.BaseTransformer, [:passthrough])

      :meck.expect(
        AshCommanded.Commanded.Transformers.BaseTransformer,
        :create_module,
        fn _module, code, _env ->
          # Should have child_spec function for supervisor
          code_string = Macro.to_string(code)
          assert code_string =~ "def child_spec()"
          assert code_string =~ "Supervisor.child_spec"

          :ok
        end
      )

      # Mock persist
      :meck.new(Transformer, [:passthrough])
      :meck.expect(Transformer, :persist, fn dsl, _key, _value -> dsl end)

      {:ok, _updated_dsl} = GenerateCommandedApplication.transform(dsl)

      assert :meck.called(AshCommanded.Commanded.Transformers.BaseTransformer, :create_module, [
               :_,
               :_,
               :_
             ])

      :meck.unload(AshCommanded.Commanded.Dsl)
      :meck.unload(Transformer)
      :meck.unload(AshCommanded.Commanded.Transformers.BaseTransformer)
    end

    @tag :skip_if_no_commanded
    test "uses prefix for module name when provided" do
      dsl = %TestDsl{persist_fn: {:module, TestDomain}}

      # Mock application to return a config with prefix
      app_config = [
        otp_app: :test_app,
        event_store: Commanded.EventStore.Adapters.InMemory,
        prefix: "AcmeApp"
      ]

      :meck.new(AshCommanded.Commanded.Dsl, [:passthrough])
      :meck.expect(AshCommanded.Commanded.Dsl, :application, fn _ -> app_config end)

      # Mock create_module to capture the generated code
      :meck.new(AshCommanded.Commanded.Transformers.BaseTransformer, [:passthrough])

      :meck.expect(AshCommanded.Commanded.Transformers.BaseTransformer, :create_module, fn module,
                                                                                           code,
                                                                                           _env ->
        # Should use prefix in module name
        assert module == AcmeApp.TestDomainApplication
        code_string = Macro.to_string(code)
        assert code_string =~ "defmodule AcmeApp.TestDomainApplication"

        :ok
      end)

      # Mock persist
      :meck.new(Transformer, [:passthrough])
      :meck.expect(Transformer, :persist, fn dsl, _key, _value -> dsl end)

      {:ok, _updated_dsl} = GenerateCommandedApplication.transform(dsl)

      assert :meck.called(AshCommanded.Commanded.Transformers.BaseTransformer, :create_module, [
               :_,
               :_,
               :_
             ])

      :meck.unload(AshCommanded.Commanded.Dsl)
      :meck.unload(Transformer)
      :meck.unload(AshCommanded.Commanded.Transformers.BaseTransformer)
    end
  end

  describe "after?/1" do
    test "should run after GenerateMainRouterModule" do
      assert GenerateCommandedApplication.after?(
               AshCommanded.Commanded.Transformers.GenerateMainRouterModule
             ) == true
    end

    test "should not run after other transformers" do
      assert GenerateCommandedApplication.after?(
               AshCommanded.Commanded.Transformers.GenerateCommandModules
             ) == false
    end
  end

  # Helper to assert the generated module code
  defp assert_app_module_code(code, _config) do
    code_string = Macro.to_string(code)
    assert code_string =~ "defmodule TestDomain.Application do"
    assert code_string =~ "use Commanded.Application"
    assert code_string =~ "otp_app: :test_app"
    assert code_string =~ "event_store: Commanded.EventStore.Adapters.InMemory"
  end
end
