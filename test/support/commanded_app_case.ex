defmodule AshCommanded.TestSupport.WidgetRouter do
  @moduledoc """
  A hand-written `Commanded.Commands.Router` used only by
  `AshCommanded.TestSupport.CommandedAppCase`-based tests to prove real dispatch through
  Commanded, against the DSL's own generated `Widget` command and aggregate modules.

  This is deliberately NOT the DSL's own auto-generated main/domain router
  (`AshCommanded.Resource.Transformers.GenerateMainRouterModule` /
  `GenerateDomainRouterModule`). Confirmed via a live probe while writing this file: under the
  current `AshCommanded.Resource.Dsl` (resource) / `AshCommanded.Domain.Dsl` (domain)
  split, those two transformers never actually produce a router module. Both check
  `Spark.Dsl.Transformer.get_persisted(dsl_state, :module)` against the module *currently being
  compiled* — but they are declared only in `AshCommanded.Resource.Dsl`'s (resource-level)
  transformer list, so that check always sees the resource, never the domain, and
  `GenerateMainRouterModule`'s domain branch can never fire. `AshCommanded.Domain.Dsl`
  does not list either transformer itself. Net effect: no `<Domain>.Router` or `<Prefix>.Router`
  module is ever generated, for any domain, under the current architecture — verified directly:
  a real `Ash.Domain` using `DomainDsl` with a resource carrying commands compiles its command,
  event and aggregate modules correctly, but `Code.ensure_loaded?/1` is `false` for both
  candidate router module names.

  This is the same Domain/Resource compile-order defect family already quarantined for Phase 2
  as FOUND-03/FOUND-04 (see
  `.planning/phases/01-build-integrity/deferred-items.md`) — fixing the transformer wiring is a
  structural change out of this plan's scope, not a mechanical test fix. This router substitutes
  a hand-written `dispatch/3` wired directly against the real generated `Commands.CreateWidget`
  and `WidgetAggregate` modules, so the per-test Commanded-application isolation this case
  template exists to prove (TEST-06) can still be demonstrated against a real dispatch path.
  """
  use Commanded.Commands.Router

  alias AshCommanded.TestSupport.Commands.CreateWidget
  alias AshCommanded.TestSupport.WidgetAggregate

  dispatch(CreateWidget, to: WidgetAggregate, identity: :id)
end

defmodule AshCommanded.TestSupport.CommandedApplication do
  @moduledoc """
  A fixed, compile-time `Commanded.Application` used by
  `AshCommanded.TestSupport.CommandedAppCase`. Each test starts its own ISOLATED instance of
  this application via `start_link(name: unique_atom)` (Commanded's own documented mechanism for
  running the same application multiple times with independent event stores — see
  `Commanded.Application`'s "Dynamic named applications" moduledoc section) rather than starting
  this module's default (unnamed) instance directly.
  """
  use Commanded.Application,
    otp_app: :ash_commanded,
    event_store: [adapter: Commanded.EventStore.Adapters.InMemory]

  router(AshCommanded.TestSupport.WidgetRouter)
end

defmodule AshCommanded.TestSupport.CommandedAppCase do
  @moduledoc """
  An `ExUnit.CaseTemplate` that starts a uniquely-named `Commanded.Application` before each
  test and stops it in `on_exit` (D-15).

  Each test gets its OWN application name — derived from `System.unique_integer([:positive])`,
  never from the test file or module — and therefore its own isolated event store process:
  Commanded derives the `InMemory` adapter's registered process name from the *runtime* name the
  application is started under (`Commanded.EventStore.Adapters.InMemory`'s `parse_config/2`
  builds it as `Module.concat([application, EventStore])`, where `application` is the name
  passed to `start_link/1`, not the compile-time module) — so two tests started under different
  names can never observe each other's dispatched events, even under `async: true`.

  ## Example

      defmodule MyDispatchTest do
        use AshCommanded.TestSupport.CommandedAppCase, async: true

        test "dispatches a command", %{commanded_application: app} do
          command = struct(AshCommanded.TestSupport.Commands.CreateWidget, id: Ash.UUID.generate(), name: "x")
          assert :ok = AshCommanded.TestSupport.CommandedApplication.dispatch(command, application: app)
        end
      end
  """
  use ExUnit.CaseTemplate

  using do
    quote do
      alias AshCommanded.TestSupport.CommandedApplication
    end
  end

  setup do
    app_name =
      Module.concat([
        AshCommanded.TestSupport.CommandedApplication,
        :"Test#{System.unique_integer([:positive])}"
      ])

    {:ok, pid} = AshCommanded.TestSupport.CommandedApplication.start_link(name: app_name)

    on_exit(fn ->
      # `start_link/1` links the supervisor to the calling (test) process, so when that
      # process exits — which always happens before `on_exit` runs, since `on_exit` runs
      # afterward, in its own process (ExUnit.OnExitHandler) — the linked supervisor is
      # usually already gone by the time this callback fires. `Process.alive?/1` closes most
      # of that race but not all of it (the supervisor can still be mid-shutdown), so treat
      # "already stopped" as success rather than a test failure.
      if Process.alive?(pid) do
        try do
          AshCommanded.TestSupport.CommandedApplication.stop(pid)
        catch
          :exit, _ -> :ok
        end
      end
    end)

    {:ok, commanded_application: app_name}
  end
end
