# Commanded Application Configuration

The `application` section allows you to configure the [Commanded application](https://hexdocs.pm/commanded/application.html) that manages command dispatch, event publishing, and process management for your domain. The Commanded application is the core component that orchestrates the event-sourced domain.

AshCommanded uses two extensions: **resources** use `AshCommanded.Commanded.Dsl` (commands, events, projections, etc.), and **domains** use `AshCommanded.Commanded.DomainDsl` for the `application` section. Only the Domain extension generates the Commanded application module.

## Basic Usage

Add the **Domain extension** `AshCommanded.Commanded.DomainDsl` to your Domain and define the `application` section. The generated module will be named after your Domain (e.g. `MyApp.Domain.Application`):

```elixir
defmodule ECommerce.Store do
  use Ash.Domain, extensions: [AshCommanded.Commanded.DomainDsl]

  resources do
    resource ECommerce.Product
    resource ECommerce.Customer
    resource ECommerce.Order
  end

  commanded do
    application do
      otp_app :ecommerce
      event_store Commanded.EventStore.Adapters.EventStore
    end
  end
end
```

## Configuration Options

The following options can be configured in the `application` section:

| Option               | Type                 | Required | Default | Description                                                               |
|----------------------|----------------------|----------|---------|---------------------------------------------------------------------------|
| `otp_app`            | atom                 | Yes      | -       | The OTP application name to use for configuration                         |
| `event_store`        | atom or keyword list | Yes      | -       | The event store adapter to use (e.g., `Commanded.EventStore.Adapters.EventStore`) |
| `pubsub`             | atom                 | No       | `:local` | The pubsub adapter to use (`:local` or `:phoenix`)                      |
| `registry`           | atom                 | No       | `:local` | The registry adapter to use (`:local` or `:global`)                     |
| `snapshotting`       | keyword list         | No       | `[]`    | Configuration for aggregate snapshotting                                |
| `include_supervisor?` | boolean             | No       | `false` | Whether to include a supervisor for the application                      |
| `prefix`             | string               | No       | `nil`   | Application module prefix for generated code                             |

## Events Stores

AshCommanded supports all [Commanded event store adapters](https://hexdocs.pm/commanded/event-store.html):

* [`Commanded.EventStore.Adapters.EventStore`](https://hexdocs.pm/commanded_eventstore_adapter/) - The default PostgreSQL event store.
* [`Commanded.EventStore.Adapters.InMemory`](https://hexdocs.pm/commanded/Commanded.EventStore.Adapters.InMemory.html) - An in-memory event store useful for testing.

Example using the default EventStore adapter:

```elixir
commanded do
  application do
    otp_app :ecommerce
    event_store Commanded.EventStore.Adapters.EventStore
  end
end
```

Example using the InMemory adapter for testing:

```elixir
commanded do
  application do
    otp_app :ecommerce
    event_store Commanded.EventStore.Adapters.InMemory
  end
end
```

## Generated Application Module

The DSL will generate an application module using the configuration. This module extends the [Commanded.Application](https://hexdocs.pm/commanded/Commanded.Application.html) behavior:

```elixir
defmodule ECommerce.Store.Application do
  use Commanded.Application,
    otp_app: :ecommerce,
    event_store: Commanded.EventStore.Adapters.EventStore,
    pubsub: :local,
    registry: :local,
    router: ECommerce.Store.Router

  # Supervision for projectors (only included if include_supervisor? is true)
  def child_spec() do
    Supervisor.child_spec(
      {Supervisor, [
        strategy: :one_for_one,
        name: Module.concat(__MODULE__, Supervisor)
      ]},
      id: Module.concat(__MODULE__, Supervisor)
    )
  end
end
```

## Supervision

By default, Commanded applications are not supervised. To include a supervisor for your application, set `include_supervisor?` to `true`:

```elixir
commanded do
  application do
    otp_app :ecommerce
    event_store Commanded.EventStore.Adapters.EventStore
    include_supervisor? true
  end
end
```

This will generate a supervisor for your application that you can add to your supervision tree:

```elixir
defmodule ECommerce.Application do
  use Application

  def start(_type, _args) do
    children = [
      # ...other children
      ECommerce.Store.Application.child_spec()
    ]

    opts = [strategy: :one_for_one, name: ECommerce.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

## Multiple Applications

AshCommanded supports defining multiple Commanded applications across different domains. This is useful for separating different bounded contexts in your application:

```elixir
defmodule ECommerce.Customers do
  use Ash.Domain, extensions: [AshCommanded.Commanded.DomainDsl]

  resources do
    resource ECommerce.Customer
  end

  commanded do
    application do
      otp_app :ecommerce
      event_store Commanded.EventStore.Adapters.EventStore, schema: "customers"
    end
  end
end

defmodule ECommerce.Orders do
  use Ash.Domain, extensions: [AshCommanded.Commanded.DomainDsl]

  resources do
    resource ECommerce.Order
    resource ECommerce.OrderItem
  end

  commanded do
    application do
      otp_app :ecommerce
      event_store Commanded.EventStore.Adapters.EventStore, schema: "orders"
    end
  end
end
```

## Usage

Once the application is configured, you can dispatch commands through the domain's router:

```elixir
command = %ECommerce.Commands.RegisterCustomer{id: "123", email: "customer@example.com", name: "John Doe"}
ECommerce.Customers.Router.dispatch(command)
```

The router will automatically route the command to the appropriate aggregate and handle it according to your command handlers.