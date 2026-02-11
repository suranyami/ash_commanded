defmodule AshCommanded.Commanded.Verifiers.EventHandlerTests do
  @moduledoc false
  use ExUnit.Case

  alias AshCommanded.Commanded.Verifiers.ValidateEventHandlerEvents
  alias AshCommanded.Commanded.Verifiers.ValidateEventHandlerActions

  # Test the basic functionality of the modules
  describe "event handler verifiers" do
    test "event handler verifiers are properly loaded" do
      # Check that they exist
      assert Code.ensure_loaded?(ValidateEventHandlerEvents)
      assert Code.ensure_loaded?(ValidateEventHandlerActions)

      # Check that they implement the Spark.Dsl.Verifier behaviour
      assert Spark.implements_behaviour?(ValidateEventHandlerEvents, Spark.Dsl.Verifier)
      assert Spark.implements_behaviour?(ValidateEventHandlerActions, Spark.Dsl.Verifier)
    end
  end
end
