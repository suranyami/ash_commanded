defmodule AshCommanded.Commanded.Verifiers.IntegrationTest do
  use ExUnit.Case, async: false

  describe "verifiers integration" do
    test "verifiers are properly loaded" do
      # Check that the verifier modules are loaded
      assert Code.ensure_loaded?(AshCommanded.Commanded.Verifiers.ValidateCommandFields)
      assert Code.ensure_loaded?(AshCommanded.Commanded.Verifiers.ValidateCommandNames)
      assert Code.ensure_loaded?(AshCommanded.Commanded.Verifiers.ValidateEventFields)
      assert Code.ensure_loaded?(AshCommanded.Commanded.Verifiers.ValidateEventNames)
      assert Code.ensure_loaded?(AshCommanded.Commanded.Verifiers.ValidateProjectionEvents)
      assert Code.ensure_loaded?(AshCommanded.Commanded.Verifiers.ValidateProjectionActions)
      assert Code.ensure_loaded?(AshCommanded.Commanded.Verifiers.ValidateProjectionChanges)
      assert Code.ensure_loaded?(AshCommanded.Commanded.Verifiers.ValidateEventHandlerEvents)
      assert Code.ensure_loaded?(AshCommanded.Commanded.Verifiers.ValidateEventHandlerActions)

      # Check that the verifier modules implement the Spark.Dsl.Verifier behaviour
      assert Spark.implements_behaviour?(
               AshCommanded.Commanded.Verifiers.ValidateCommandFields,
               Spark.Dsl.Verifier
             )

      assert Spark.implements_behaviour?(
               AshCommanded.Commanded.Verifiers.ValidateCommandNames,
               Spark.Dsl.Verifier
             )

      assert Spark.implements_behaviour?(
               AshCommanded.Commanded.Verifiers.ValidateEventFields,
               Spark.Dsl.Verifier
             )

      assert Spark.implements_behaviour?(
               AshCommanded.Commanded.Verifiers.ValidateEventNames,
               Spark.Dsl.Verifier
             )

      assert Spark.implements_behaviour?(
               AshCommanded.Commanded.Verifiers.ValidateProjectionEvents,
               Spark.Dsl.Verifier
             )

      assert Spark.implements_behaviour?(
               AshCommanded.Commanded.Verifiers.ValidateProjectionActions,
               Spark.Dsl.Verifier
             )

      assert Spark.implements_behaviour?(
               AshCommanded.Commanded.Verifiers.ValidateProjectionChanges,
               Spark.Dsl.Verifier
             )

      assert Spark.implements_behaviour?(
               AshCommanded.Commanded.Verifiers.ValidateEventHandlerEvents,
               Spark.Dsl.Verifier
             )

      assert Spark.implements_behaviour?(
               AshCommanded.Commanded.Verifiers.ValidateEventHandlerActions,
               Spark.Dsl.Verifier
             )
    end
  end
end
