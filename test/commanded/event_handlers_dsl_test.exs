defmodule AshCommanded.Commanded.EventHandlersDslTest do
  @moduledoc false
  use ExUnit.Case

  defmodule TestDomain do
    @moduledoc false
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource AshCommanded.Commanded.EventHandlersDslTest.TestResource
    end
  end

  defmodule TestResource do
    @moduledoc false
    use Ash.Resource,
      domain: TestDomain,
      extensions: [AshCommanded.Commanded.Dsl]

    attributes do
      uuid_primary_key :id
      attribute :name, :string
      attribute :email, :string
      attribute :status, :atom, default: :pending
    end

    commanded do
      events do
        event :test_registered do
          fields([:id, :name, :email])
        end

        event :test_updated do
          fields([:id, :email])
        end
      end

      event_handlers do
        handler :notification_handler do
          events([:test_registered])

          action(fn event, _metadata ->
            # Simple function that would send an email
            send(self(), {:notification_sent, event})
            :ok
          end)
        end

        handler :integration_handler do
          events([:test_registered, :test_updated])
          publish_to("integration_topic")
          idempotent(true)
          # Testing custom handler name
          handler_name(:external_system_sync)
        end
      end
    end
  end

  test "can define event handlers in the DSL" do
    handlers = Spark.Dsl.Extension.get_entities(TestResource, [:commanded, :event_handlers])

    assert length(handlers) == 2

    [notification_handler, integration_handler] = handlers

    # Check notification handler
    assert notification_handler.name == :notification_handler
    assert notification_handler.events == [:test_registered]
    assert is_function(extract_function_from_quoted(notification_handler.action), 2)

    # Check integration handler
    assert integration_handler.name == :integration_handler
    assert integration_handler.events == [:test_registered, :test_updated]
    assert integration_handler.publish_to == "integration_topic"
    assert integration_handler.idempotent == true
    assert integration_handler.handler_name == :external_system_sync
  end

  test "event handler DSL is processed correctly" do
    # Verify that the extension is registered
    extensions = Spark.extensions(TestResource)
    assert AshCommanded.Commanded.Dsl in extensions

    # Verify that we get the event handlers we defined
    handlers = Spark.Dsl.Extension.get_entities(TestResource, [:commanded, :event_handlers])
    assert length(handlers) == 2

    # Just verify our transformer module exists - we can't directly test if it's run
    assert Code.ensure_loaded?(AshCommanded.Commanded.Transformers.GenerateEventHandlerModules)
  end

  # Helper to extract a function from quoted code for testing
  defp extract_function_from_quoted(quoted) do
    {func, _} = Code.eval_quoted(quoted)
    func
  end
end
