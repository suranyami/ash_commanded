defmodule AshCommanded.Test.Commanded.Transformers.CommandedApplicationGeneratorTest do
  @moduledoc """
  Exercises `GenerateCommandedApplication.transform/1` for real — no `:meck`, no mocking of
  `BaseTransformer.create_module/3` — against a real, compiled application module.

  ## Why this file used to mock `BaseTransformer.create_module/3`, and why it no longer does

  The previous version of this file mocked `create_module/3` so `transform/1` would never
  actually call `Module.create/3` on the generated application module. That was a workaround
  for a real defect: the generated application code calls `router(unquote(router_module))`,
  and `Commanded.Commands.CompositeRouter`'s `router/1` macro reads
  `router_module.__registered_commands__/0` at compile time. Under the current Domain/Resource
  DSL split, `AshCommanded.Resource.Dsl`'s own router-generation transformers
  (`GenerateDomainRouterModule`/`GenerateMainRouterModule`) never actually produce a router
  module for any domain (see `.planning/phases/01-build-integrity/deferred-items.md`, "From Plan
  01-06") — so a real domain compiled with an `application` section always crashes exactly like
  the quarantined `commanded_application_integration_test.exs.phase2-blocked` file, regardless
  of where the fixture lives. Confirmed again this session: moving an equivalent fixture into
  `test/support/` (compiled ahead of test files, in dependency order) produces the identical
  `function ...Router.__registered_commands__/0 is undefined` crash — this is not a compile
  *ordering* problem fixable by file placement, it is that the router is never generated at all.

  Mocking `create_module/3` sidestepped that crash by never actually compiling anything — but it
  meant this file only ever asserted on what the transformer's generated AST *would* look like
  as a string, never on real compiled behavior. It also made this file the last `:meck` user in
  the suite, and `:meck`'s own defensive bookkeeping around Erlang's `:cover` tool caused a real,
  intermittent full-suite failure: `:meck.new/2` asks `:cover` to back up the original module's
  cover state before replacing it, and `:cover.call/1` *starts* the cover server on demand if it
  isn't running. Since this file is `async: true`, two concurrent `:meck.new/2` calls (this file
  racing itself, or racing whichever other async file happened to run at the same instant) could
  both try to start `:cover` at once; the loser got `{:error, {:already_started, pid}}` against a
  success-only match inside `meck_proc.erl`, crashing that one test — reproduced by running the
  full suite 5 times in a row (2 failures, always the same test) even though single-seed and
  single-file runs never showed it, because a seed only reorders tests, it does not change
  whether two async files' `:meck.new/2` calls land in the same instant.

  ## The fix: hand-supply the ONE prerequisite the broken transformer would have supplied

  `create_empty_router!/1` below defines a real, compiled, empty `Commanded.Commands.Router`
  named exactly `<domain_module>.Router` — the module name `GenerateCommandedApplication`'s
  `router(...)` call expects. This is not working around the same defect the quarantined file
  exists for: it isolates `GenerateCommandedApplication.transform/1`'s OWN behavior (module
  naming, prefix handling, config assembly, supervisor inclusion) from the SEPARATE,
  already-documented router-generation defect, by supplying the one piece that defect would have
  supplied. `transform/1` then runs for real, with no mocking, and every assertion below is
  against the real compiled application module's actual runtime behavior (`app_module.config()`,
  `function_exported?/3`, `app_module.__registered_commands__/0`) rather than a string match
  against generated AST.

  Each test uses its OWN uniquely-named domain (`System.unique_integer/1`), so `async: true` is
  completely safe — there is no shared, mutable, out-of-band state (no meck, no global registry)
  for two tests to race over.
  """
  use ExUnit.Case, async: true

  alias AshCommanded.Domain.Transformers.GenerateCommandedApplication
  alias AshCommanded.Resource.Transformers.BaseTransformer
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
  # `app_opts` is the keyword list the `commanded do application do ... end end` section
  # would carry; pass `nil` to simulate no application configuration (the section key is
  # simply omitted, so `AshCommanded.Resource.Dsl.application/1`'s `:otp_app` sentinel
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

  # Defines a real, empty Commanded.Commands.Router named `<domain_module>.Router` — see the
  # moduledoc above for why this is necessary and why it is not a workaround for the same defect
  # the quarantined integration test exists for.
  defp create_empty_router!(router_module) do
    :ok =
      BaseTransformer.create_module(
        router_module,
        quote(do: use(Commanded.Commands.Router)),
        __ENV__
      )
  end

  # A domain module name unique to this test (never shared across tests, never derived from the
  # test file/module name) — every test that creates a real application module needs its own
  # domain, so two async tests can never collide on the same generated module name.
  defp unique_domain_module(tag) do
    Module.concat([
      :"CommandedApplicationGeneratorTest#{tag}#{System.unique_integer([:positive])}"
    ])
  end

  describe "transform/1" do
    test "returns the dsl unchanged when there is no application config" do
      domain_module = unique_domain_module("NoConfig")
      dsl = dsl_state(domain_module, nil)

      assert {:ok, unchanged_dsl} = GenerateCommandedApplication.transform(dsl)
      assert unchanged_dsl == dsl
    end

    test "generates a real, compiled application module when application config is present" do
      domain_module = unique_domain_module("Basic")
      create_empty_router!(Module.concat(domain_module, "Router"))

      app_config = [
        otp_app: :test_app,
        event_store: Commanded.EventStore.Adapters.InMemory,
        include_supervisor?: false
      ]

      dsl = dsl_state(domain_module, app_config)

      assert {:ok, updated_dsl} = GenerateCommandedApplication.transform(dsl)

      app_module = Transformer.get_persisted(updated_dsl, :commanded_application_module)
      assert app_module == Module.concat(domain_module, "Application")
      assert Code.ensure_loaded?(app_module)

      config = app_module.config()
      assert Keyword.get(config, :otp_app) == :test_app

      assert Keyword.get(config, :event_store) == [
               adapter: Commanded.EventStore.Adapters.InMemory
             ]

      # include_supervisor? was false: no arity-0 child_spec (the library's own, distinct from
      # Commanded.Application's own always-present arity-1 child_spec/1).
      refute function_exported?(app_module, :child_spec, 0)
    end

    test "generates a module with an arity-0 child_spec when include_supervisor? is true" do
      domain_module = unique_domain_module("Supervisor")
      create_empty_router!(Module.concat(domain_module, "Router"))

      app_config = [
        otp_app: :test_app,
        event_store: Commanded.EventStore.Adapters.InMemory,
        include_supervisor?: true
      ]

      dsl = dsl_state(domain_module, app_config)

      assert {:ok, updated_dsl} = GenerateCommandedApplication.transform(dsl)

      app_module = Transformer.get_persisted(updated_dsl, :commanded_application_module)
      assert Code.ensure_loaded?(app_module)
      assert function_exported?(app_module, :child_spec, 0)

      # Found while writing this test (never previously exercised — see
      # generate_commanded_application.ex's own comment): the generated `child_spec/0` used to
      # call `Supervisor.child_spec({Supervisor, opts}, ...)`, which requires the first element
      # to implement `child_spec/1` itself — bare `Supervisor` doesn't, so this raised
      # `ArgumentError` the instant it was actually called. Fixed to build the child spec map
      # directly; this assertion is what proves the fix.
      assert %{id: _, start: {Supervisor, :start_link, [[], supervisor_opts]}, type: :supervisor} =
               app_module.child_spec()

      assert Keyword.get(supervisor_opts, :strategy) == :one_for_one
    end

    test "uses prefix for module name when provided" do
      domain_module = unique_domain_module("Prefixed")
      create_empty_router!(Module.concat(domain_module, "Router"))

      app_config = [
        otp_app: :test_app,
        event_store: Commanded.EventStore.Adapters.InMemory,
        prefix: "AcmeApp"
      ]

      dsl = dsl_state(domain_module, app_config)

      assert {:ok, updated_dsl} = GenerateCommandedApplication.transform(dsl)

      domain_name = domain_module |> Module.split() |> List.last()
      expected_app_module = Module.concat(["AcmeApp", "#{domain_name}Application"])

      app_module = Transformer.get_persisted(updated_dsl, :commanded_application_module)
      assert app_module == expected_app_module
      assert Code.ensure_loaded?(app_module)
      assert Keyword.get(app_module.config(), :otp_app) == :test_app
    end

    test "the generated module really is wired to the router it was given" do
      domain_module = unique_domain_module("RouterWiring")
      router_module = Module.concat(domain_module, "Router")
      create_empty_router!(router_module)

      app_config = [
        otp_app: :test_app,
        event_store: Commanded.EventStore.Adapters.InMemory
      ]

      dsl = dsl_state(domain_module, app_config)
      assert {:ok, updated_dsl} = GenerateCommandedApplication.transform(dsl)

      app_module = Transformer.get_persisted(updated_dsl, :commanded_application_module)

      # A pass-through/no-op application would not delegate to the router at all; a real
      # Commanded.Application composite-routes to it, so its own registered-commands list
      # mirrors the router's (empty here, since the fixture router has no dispatch/2 clauses).
      assert app_module.__registered_commands__() == router_module.__registered_commands__()
    end
  end

  describe "after?/1" do
    test "should run after GenerateMainRouterModule" do
      assert GenerateCommandedApplication.after?(
               AshCommanded.Resource.Transformers.GenerateMainRouterModule
             ) == true
    end

    test "should not run after other transformers" do
      assert GenerateCommandedApplication.after?(
               AshCommanded.Resource.Transformers.GenerateCommandModules
             ) == false
    end
  end
end
