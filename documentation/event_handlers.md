# Event Handlers

Event handlers define how to respond to domain events with side effects, integrations, notifications, or other operations that don't necessarily update the resource state directly. Unlike projections which are focused on updating read models, event handlers allow you to execute arbitrary code in response to events. In Commanded, [event handlers](https://hexdocs.pm/commanded/Commanded.Event.Handler.html) provide a flexible way to react to domain events.

## Introduction

In [CQRS](https://martinfowler.com/bliki/CQRS.html) and [Event Sourcing](https://martinfowler.com/eaaDev/EventSourcing.html) systems, events represent facts that have occurred in your domain. While projections use these events to maintain read models, there are often other operations you want to perform when events occur. This follows Commanded's [event handling approach](https://hexdocs.pm/commanded/events.html#handling-events):

- Sending notifications (emails, SMS, push notifications)
- Integrating with external systems
- Publishing events to message brokers
- Logging or analytics tracking
- Triggering downstream processes

AshCommanded provides the `event_handlers` section to define these behaviors declaratively.

## Usage

In the e-commerce example, we can define event handlers to send notifications when orders are placed or shipments are created:

```elixir
defmodule MyApp.Order do
  use Ash.Resource,
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id
    attribute :customer_id, :string
    attribute :total_amount, :decimal
    attribute :status, :atom, default: :pending
  end

  commanded do
    events do
      event :order_placed do
        fields [:id, :customer_id, :total_amount]
      end
      
      event :order_shipped do
        fields [:id, :tracking_number]
      end
    end
    
    event_handlers do
      # Send email notification when order is placed
      handler :order_confirmation do
        events [:order_placed]
        action fn event, _metadata ->
          MyApp.Notifications.send_order_confirmation(
            event.customer_id,
            event.id,
            event.total_amount
          )
          :ok
        end
      end
      
      # Integrate with shipping provider when order is shipped
      handler :shipping_notification do
        events [:order_shipped]
        action fn event, _metadata ->
          MyApp.ShippingProvider.notify_shipment(event.id, event.tracking_number)
          :ok
        end
      end
      
      # Publish events to a PubSub topic for other systems
      handler :event_broadcaster do
        events [:order_placed, :order_shipped]
        publish_to "order_events"
      end
    end
  end
end
```

## Handler Options

Event handlers are highly configurable:

| Option | Type | Description |
|--------|------|-------------|
| `events` | `list(atom)` | **Required**. List of event names this handler will respond to. |
| `action` | `atom` or `quoted` | Action to perform when handling events. Can be an Ash action name or a quoted function. |
| `handler_name` | `atom` | Override the auto-generated handler module name. |
| `publish_to` | `atom` or `string` or `list` | Specify PubSub topic(s) to publish the event to. |
| `idempotent` | `boolean` | Whether the handler is idempotent (safe to process the same event multiple times). Default: `false` |
| `autogenerate?` | `boolean` | Whether to autogenerate a handler module. Default: `true` |

## Action Types

There are three ways to specify the action a handler should take:

### 1. Function-Based Handlers

Using an anonymous function gives you full control over event handling:

```elixir
handler :notification_handler do
  events [:order_placed]
  action fn event, metadata ->
    # Access event data
    order_id = event.id
    customer_id = event.customer_id
    
    # Access metadata
    correlation_id = metadata.correlation_id
    
    # Call your notification service
    MyApp.Notifications.send_email(customer_id, order_id, correlation_id)
    
    # Return :ok to indicate success
    :ok
  end
end
```

### 2. Ash Action Handlers

You can reference an Ash action directly by its name:

```elixir
handler :sync_to_crm do
  events [:customer_registered]
  action :create_crm_contact
end
```

This assumes your resource has a corresponding action defined.

### 3. No-Op Handlers (Publishing Only)

If you just want to publish events to a topic without additional processing:

```elixir
handler :event_publisher do
  events [:order_placed, :order_shipped, :order_cancelled]
  publish_to "order_events"
end
```

## Differences from Projections

It's important to understand the distinction between projections and event handlers:

| Projections | Event Handlers |
|-------------|---------------|
| Focus on updating read models | Focus on side effects and integrations |
| Map events to resource changes | Execute arbitrary code in response to events |
| Always tied to create/update/delete operations | Can perform any operation, not just data changes |
| Primary purpose is maintaining consistent data views | Primary purpose is integration and notifications |
| Limited to data operations within your application | Can interact with external systems and services |

## Generated Modules

AshCommanded automatically generates event handler modules based on your DSL configuration. These follow the [Commanded.Event.Handler](https://hexdocs.pm/commanded/Commanded.Event.Handler.html) pattern:

```elixir
defmodule MyApp.EventHandlers.OrderOrderConfirmationHandler do
  @moduledoc "General purpose event handler for Order events (OrderConfirmation)"

  use Commanded.Event.Handler,
    application: MyApp.Domain.Application,  # Generated by AshCommanded.Commanded.DomainDsl on your Domain
    name: "MyApp.EventHandlers.OrderOrderConfirmationHandler"

  def handle(%MyApp.Events.OrderPlaced{} = event, metadata) do
    # Execute the function defined in the DSL
    send_order_confirmation(event.customer_id, event.id, event.total_amount)
    :ok
  end
  
  # Helper functions for action execution and response handling
  # ...
end
```

## Error Handling

Handler functions should return `:ok` on success or `{:error, reason}` on failure. When a handler fails:

1. The error is logged
2. The event might be retried, depending on your Commanded configuration
3. The failure is propagated to your application's error handling mechanism

For critical handlers, you may want to implement retry logic or fallback mechanisms.

## Best Practices

1. **Keep Handlers Focused**: Each handler should have a single responsibility.
2. **Make Handlers Idempotent**: Since events might be processed multiple times, design handlers to be idempotent.
3. **Separate Business Logic**: Put complex business logic in dedicated modules and have handlers call these functions.
4. **Handle Errors Gracefully**: Include proper error handling to ensure your system remains resilient.
5. **Consider Failure Domains**: Group handlers by failure domain - if one handler's failure shouldn't affect others, put them in different handler modules.
6. **Be Mindful of Performance**: Long-running handlers can block event processing; consider using background jobs for heavy operations.