# Router Generation

AshCommanded automatically generates [Commanded Routers](https://hexdocs.pm/commanded/commands.html) for dispatching commands to the appropriate handlers and aggregates based on your domain structure. The Commanded application module that uses these routers (e.g. `MyApp.Domain.Application`) is generated when you add `AshCommanded.Commanded.DomainDsl` to your Domain and define the `application` section.

## Domain-specific Routers

For each Ash.Domain containing resources with the AshCommanded.Commanded.Dsl extension, a domain-specific router is generated:

```elixir
defmodule ECommerce.Store.Router do
  use Commanded.Commands.Router

  # For each resource in the domain
  identify ECommerce.ProductAggregate, by: :id
  dispatch [ECommerce.Commands.CreateProduct, ECommerce.Commands.UpdateProduct], to: ECommerce.ProductAggregate
  
  identify ECommerce.CustomerAggregate, by: :id
  dispatch [ECommerce.Commands.RegisterCustomer, ECommerce.Commands.UpdateStatus], to: ECommerce.CustomerAggregate
end
```

These domain routers handle command routing within a specific domain context.

## Main Application Router

AshCommanded also generates a main application router at `AshCommanded.Router`. The behavior of this router depends on the domain structure:

### Single Domain Setup

For applications with a single domain, the main router directly routes commands to aggregates:

```elixir
defmodule AshCommanded.Router do
  use Commanded.Commands.Router

  # Direct command routing for all resources
  identify ECommerce.ProductAggregate, by: :id
  dispatch [ECommerce.Commands.CreateProduct, ECommerce.Commands.UpdateProduct], to: ECommerce.ProductAggregate
  
  identify ECommerce.CustomerAggregate, by: :id
  dispatch [ECommerce.Commands.RegisterCustomer, ECommerce.Commands.UpdateStatus], to: ECommerce.CustomerAggregate
end
```

### Multiple Domain Setup

For applications with multiple domains, the main router forwards commands to the appropriate domain router:

```elixir
defmodule AshCommanded.Router do
  use Commanded.Commands.Router

  # Forward to domain routers
  forward ECommerce.Store.Router
  forward ECommerce.Marketing.Router
  forward ECommerce.Shipping.Router
end
```

## Command Dispatching

With these routers in place, you can dispatch commands using the [dispatch/1](https://hexdocs.pm/commanded/Commanded.Commands.Router.html#dispatch/1) or [dispatch/2](https://hexdocs.pm/commanded/Commanded.Commands.Router.html#dispatch/2) functions:

```elixir
# Basic command dispatch
command = %ECommerce.Commands.CreateProduct{id: "123", name: "Premium Widget", price: 29.99}
AshCommanded.Router.dispatch(command)

# With options
command = %ECommerce.Commands.CreateProduct{id: "123", name: "Premium Widget", price: 29.99}
AshCommanded.Router.dispatch(command, correlation_id: UUID.uuid4(), metadata: %{user_id: "user-123"})
```

The command will be routed to the appropriate aggregate and handler based on the command type and the resource's identity.

## Identity Resolution

By default, the router uses the resource's primary identity key or the specified `identity_field` in the command definition.

```elixir
commanded do
  commands do
    command :create_product do
      fields([:id, :name, :price])
      identity_field(:id)  # Explicitly specify the identity field
    end
  end
end
```

If no identity field is specified, the router will try to use:
1. The first field from the resource's primary identity
2. The `:id` field as a fallback