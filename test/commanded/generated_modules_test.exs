defmodule AshCommanded.GeneratedModules.DirectCallsTest do
  @moduledoc """
  Calls the generated projector and event-handler modules directly, as plain functions — no
  Commanded application, no subscription, no process. Per RESEARCH.md's "Pattern 3": `handle/2`
  is generated as an ordinary function; `Commanded.Aggregates.Aggregate`/`Commanded.Event.Handler`
  wrap it at runtime dispatch, but nothing prevents calling it directly in a test.

  Covers the two generated module kinds `aggregate_end_to_end_test.exs` (Plan 01-02's tracer)
  does not: the projector and the event handler. The router is covered separately in
  `AshCommanded.GeneratedModules.RouterDispatchTest` below, in this same file.
  """
  use ExUnit.Case, async: true

  alias AshCommanded.TestSupport.Widget
  alias AshCommanded.TestSupport.Events.WidgetUpdated
  alias AshCommanded.TestSupport.Events.WidgetCreated
  alias AshCommanded.TestSupport.Projectors.WidgetProjector
  alias AshCommanded.TestSupport.EventHandlers.WidgetWidgetNotifierHandler

  describe "generated projector" do
    test "handle/2 writes a real Ash record, readable back through Ash.get" do
      assert Code.ensure_loaded?(WidgetProjector)

      widget =
        Widget
        |> Ash.Changeset.for_create(:create, %{id: Ash.UUID.generate(), name: "Before"})
        |> Ash.create!()

      event = struct(WidgetUpdated, id: widget.id, name: "After Direct-Call Projection")

      assert {:ok, %Widget{} = updated} = WidgetProjector.handle(event, %{})
      assert updated.id == widget.id
      assert updated.name == "After Direct-Call Projection"

      persisted = Ash.get!(Widget, widget.id)
      assert persisted.name == "After Direct-Call Projection"
    end
  end

  describe "generated event handler" do
    test "handle/2 runs its declared side effect and returns the documented success value" do
      assert Code.ensure_loaded?(WidgetWidgetNotifierHandler)

      id = Ash.UUID.generate()
      event = struct(WidgetCreated, id: id, name: "Notify Me")

      assert :ok = WidgetWidgetNotifierHandler.handle(event, %{})
      assert_received {:widget_notified, ^id}
    end
  end
end

defmodule AshCommanded.GeneratedModules.RouterDispatchTest do
  @moduledoc """
  Dispatches a command through a real `Commanded.Application`, started under a name unique to
  each test (`AshCommanded.TestSupport.CommandedAppCase`, D-15), and asserts the resulting
  aggregate state — proving per-test Commanded application isolation (TEST-06) against a real
  dispatch path.

  ## Why this dispatches through `AshCommanded.TestSupport.WidgetRouter`, not "the generated
  main/domain router"

  This plan's Task 3 originally called for dispatching through the DSL's own auto-generated
  router. That router does not exist to dispatch through: confirmed by a live probe (recorded in
  `.planning/phases/01-build-integrity/deferred-items.md`, "From Plan 01-06"), under the current
  `AshCommanded.Commanded.Dsl` (resource) / `AshCommanded.Commanded.DomainDsl` (domain) split,
  `GenerateMainRouterModule` and `GenerateDomainRouterModule` never actually produce a router
  module for any domain — both only run while a resource compiles, and check whether the
  resource *is* the domain, which is never true. This is part of the same Domain/Resource
  compile-order defect family already quarantined for Phase 2 as FOUND-03/FOUND-04, and fixing it
  is a structural transformer-wiring change, out of this plan's scope.

  `AshCommanded.TestSupport.WidgetRouter` (defined in `test/support/commanded_app_case.ex`) is a
  hand-written `Commanded.Commands.Router`, wired directly to the DSL's real generated
  `Commands.CreateWidget` and `WidgetAggregate` modules, substituting for the router that would
  exist if the defect above were fixed. It proves the same underlying claim this task cares
  about — real dispatch through Commanded, with genuine per-test isolation — using the DSL's
  real generated command and aggregate modules, without depending on a router the library does
  not currently produce.

  ## Why these tests assert on `returning: :aggregate_state`, not `Ash.get!/2`

  `AshCommanded.TestSupport.Widget` uses `ets do private? true end`, which scopes its ETS table
  to the CALLING PROCESS (`Ash.DataLayer.Ets`'s own documented behaviour). Dispatching through a
  real `Commanded.Application` runs the aggregate's `execute/2` inside the aggregate's own
  registered process — a different process than the test — so a write made there is invisible to
  a later `Ash.get!/2` call from the test process (also confirmed by probe; see
  deferred-items.md). `dispatch(..., returning: :aggregate_state)` sidesteps this: Commanded
  returns the post-`apply/2` aggregate struct synchronously to the caller regardless of which
  process executed the command, so it proves the dispatch produced a real, correctly-populated
  aggregate without needing cross-process ETS visibility.
  """
  use AshCommanded.TestSupport.CommandedAppCase, async: true

  alias AshCommanded.TestSupport.Commands.CreateWidget
  alias AshCommanded.TestSupport.WidgetAggregate
  alias AshCommanded.TestSupport.WidgetRouter

  test "the router implements the Commanded router behaviour and is not a pass-through stub" do
    assert Code.ensure_loaded?(WidgetRouter)
    assert function_exported?(WidgetRouter, :dispatch, 1)
    assert function_exported?(WidgetRouter, :dispatch, 2)

    # A pass-through stub (a module whose `dispatch/1` just hands the argument back) would not
    # have a real registered-commands table at all; a genuine `Commanded.Commands.Router` builds
    # one at compile time from its `dispatch(...)` declarations.
    assert WidgetRouter.__registered_commands__() == [CreateWidget]
  end

  # Both of the following two tests dispatch the SAME fixed identity — deliberately, not a
  # fresh UUID each time. If two tests shared one Commanded application/event store, the second
  # dispatch of this identity would either collide with the first test's stream or silently
  # observe its prior state (a duplicate-registration/version-conflict error, or a stale
  # aggregate). Because `CommandedAppCase` starts an independently-named application per test,
  # each succeeds exactly as if it were the only dispatch ever made against this id — that is
  # the TEST-06 claim, stated as a test rather than as a hope.
  @shared_identity "11111111-1111-1111-1111-111111111111"

  test "dispatching a command against a per-test application produces a real aggregate", %{
    commanded_application: app
  } do
    command = struct(CreateWidget, id: @shared_identity, name: "Router Widget")

    assert {:ok, %WidgetAggregate{} = aggregate} =
             AshCommanded.TestSupport.CommandedApplication.dispatch(command,
               application: app,
               returning: :aggregate_state
             )

    assert aggregate.id == @shared_identity
    assert aggregate.name == "Router Widget"
  end

  test "a second test reusing the same identity, under its own per-test application, does not collide",
       %{commanded_application: app} do
    command = struct(CreateWidget, id: @shared_identity, name: "Isolated Router Widget")

    assert {:ok, %WidgetAggregate{} = aggregate} =
             AshCommanded.TestSupport.CommandedApplication.dispatch(command,
               application: app,
               returning: :aggregate_state
             )

    assert aggregate.id == @shared_identity
    assert aggregate.name == "Isolated Router Widget"
  end
end
