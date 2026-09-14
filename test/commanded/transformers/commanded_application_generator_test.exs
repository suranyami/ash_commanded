defmodule AshCommanded.Test.Commanded.Transformers.CommandedApplicationGeneratorTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias AshCommanded.Commanded.Transformers.GenerateCommandedApplication
  alias Spark.Dsl.Transformer

  # A placeholder module used only as an entity in the fake `:resources` section below —
  # `get_domain_resources/1` only checks whether the entities list is non-empty, so this
  # never needs to be a real Ash.Resource.
  defmodule TestResource do
    @moduledoc false
    defstruct []
  end

  # Builds a real Spark dsl_state — the plain map shape `Spark.Dsl.Transformer`/
  # `Spark.Dsl.Extension` actually operate on (see deps/spark/lib/spark/dsl/transformer.ex
  # `persist/3`, `get_entities/2`; deps/spark/lib/spark/dsl/extension.ex `get_opt/5`) —
  # rather than mocking Spark's own accessor functions with a fake struct.
  #
  # Before this rewrite, `dsl` was a custom `%TestDsl{}` struct with hand-rolled
  # `get_entities/2`/`get_persisted/2` clauses. Spark 2.7.2's `Spark.Dsl.Extension.get_entities/2`
  # does not dispatch to a struct's own functions the way that fixture assumed — for a
  # `%struct{}` value it calls `struct.entities(path)` (a real Spark.Dsl callback most
  # extension-having modules generate), which `TestDsl` never defined, raising
  # `ArgumentError: ... is not a Spark DSL module`. A plain map avoids this entirely: it hits
  # `Spark.Dsl.Extension.get_entities/2`'s `is_map(map)` clause, which reads the section data
  # straight out of the map — exactly what a real compiled resource's dsl_state contains.
  #
  # `app_opts` is the keyword list the `commanded do application do ... end end` section
  # would carry; pass `nil` to simulate no application configuration (the section key is
  # simply omitted, so `AshCommanded.Commanded.Dsl.application/1`'s `:otp_app` sentinel
  # lookup misses and returns `nil`, exactly like a domain with no `application` block).
  defp dsl_state(domain_module, app_opts) do
    base = %{
      [:resources] => %{entities: [TestResource]},
      persist: %{module: domain_module}
    }

    case app_opts do
      nil -> base
      opts -> Map.put(base, [:commanded, :application], %{opts: opts})
    end
  end

  describe "transform/1" do
    test "returns the dsl unchanged when there is no application config" do
      dsl = dsl_state(TestDomain, nil)

      assert {:ok, unchanged_dsl} = GenerateCommandedApplication.transform(dsl)
      assert unchanged_dsl == dsl
    end

    # These three tests mock `BaseTransformer.create_module/3` so `transform/1` never actually
    # invokes `Module.create/3` on the fake `TestDomain.Application` module name — doing so for
    # real would compile `router(TestDomain.Router)`, which needs
    # `TestDomain.Router.__registered_commands__/0` to already exist. That is exactly the
    # Domain/Resource compile-order defect quarantined for Phase 2 (see
    # `.planning/phases/01-build-integrity/deferred-items.md`); mocking `create_module/3` here
    # keeps this a pure unit test of `transform/1`'s own config-wiring logic, not a compile of
    # generated code.
    #
    # `:meck.new/2` links the mock's process to whichever process calls it. Registering the
    # matching `:meck.unload/1` via `on_exit` (which ExUnit always runs in a SEPARATE process,
    # after the test process has already exited) races that link: the mock's linked process may
    # already be gone by the time `on_exit` runs, and `:meck.unload/1` then raises
    # `{:not_mocked, module}` — empirically confirmed while rewriting this file, and the direct
    # cause of the four `:already_started` cascade failures this rewrite fixes (an earlier
    # crash-before-unload left one test's mock loaded, so the next test's own `:meck.new/2`
    # collided with it). `try/after` in the test body itself avoids this: `:meck.unload/1` then
    # runs synchronously, in the same process, before the test function returns.
    test "generates a module when application config is present" do
      app_config = [
        otp_app: :test_app,
        event_store: Commanded.EventStore.Adapters.InMemory,
        include_supervisor?: false
      ]

      dsl = dsl_state(TestDomain, app_config)

      :meck.new(AshCommanded.Commanded.Transformers.BaseTransformer, [:passthrough])

      try do
        :meck.expect(
          AshCommanded.Commanded.Transformers.BaseTransformer,
          :create_module,
          fn module, code, _env ->
            assert module == TestDomain.Application
            assert_app_module_code(code, app_config)
            :ok
          end
        )

        assert {:ok, updated_dsl} = GenerateCommandedApplication.transform(dsl)

        assert Transformer.get_persisted(updated_dsl, :commanded_application_module) ==
                 TestDomain.Application

        assert :meck.called(AshCommanded.Commanded.Transformers.BaseTransformer, :create_module, [
                 :_,
                 :_,
                 :_
               ])
      after
        :meck.unload(AshCommanded.Commanded.Transformers.BaseTransformer)
      end
    end

    test "generates a module with supervisor when include_supervisor? is true" do
      app_config = [
        otp_app: :test_app,
        event_store: Commanded.EventStore.Adapters.InMemory,
        include_supervisor?: true
      ]

      dsl = dsl_state(TestDomain, app_config)

      :meck.new(AshCommanded.Commanded.Transformers.BaseTransformer, [:passthrough])

      try do
        :meck.expect(
          AshCommanded.Commanded.Transformers.BaseTransformer,
          :create_module,
          fn _module, code, _env ->
            code_string = Macro.to_string(code)
            assert code_string =~ "def child_spec()"
            assert code_string =~ "Supervisor.child_spec"

            :ok
          end
        )

        assert {:ok, _updated_dsl} = GenerateCommandedApplication.transform(dsl)

        assert :meck.called(AshCommanded.Commanded.Transformers.BaseTransformer, :create_module, [
                 :_,
                 :_,
                 :_
               ])
      after
        :meck.unload(AshCommanded.Commanded.Transformers.BaseTransformer)
      end
    end

    test "uses prefix for module name when provided" do
      app_config = [
        otp_app: :test_app,
        event_store: Commanded.EventStore.Adapters.InMemory,
        prefix: "AcmeApp"
      ]

      dsl = dsl_state(TestDomain, app_config)

      :meck.new(AshCommanded.Commanded.Transformers.BaseTransformer, [:passthrough])

      try do
        :meck.expect(
          AshCommanded.Commanded.Transformers.BaseTransformer,
          :create_module,
          fn module, _code, _env ->
            assert module == AcmeApp.TestDomainApplication
            :ok
          end
        )

        assert {:ok, _updated_dsl} = GenerateCommandedApplication.transform(dsl)

        assert :meck.called(AshCommanded.Commanded.Transformers.BaseTransformer, :create_module, [
                 :_,
                 :_,
                 :_
               ])
      after
        :meck.unload(AshCommanded.Commanded.Transformers.BaseTransformer)
      end
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

  # Helper to assert the generated module code. `code` is the AST passed to
  # `BaseTransformer.create_module/3` — the module *body*, not a `defmodule ... do ... end`
  # wrapper (that wrapping happens inside `create_module/3` itself, via `Module.create/3`,
  # which this test mocks out — see the block comment above). Asserting for a literal
  # "defmodule TestDomain.Application do" substring here was always incorrect; it never ran
  # before this rewrite because the four-test cascade failure masked it.
  defp assert_app_module_code(code, _config) do
    code_string = Macro.to_string(code)
    assert code_string =~ "use Commanded.Application"
    assert code_string =~ "otp_app: :test_app"
    assert code_string =~ "event_store: [adapter: Commanded.EventStore.Adapters.InMemory]"
    assert code_string =~ "router(TestDomain.Router)"
  end
end
