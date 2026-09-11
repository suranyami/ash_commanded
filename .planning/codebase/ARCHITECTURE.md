<!-- refreshed: 2026-09-11 -->
# Architecture

**Analysis Date:** 2026-09-11

## System Overview

AshCommanded is a Spark-based DSL extension for the Ash Framework that implements CQRS (Command Query Responsibility Segregation) and Event Sourcing patterns using the Commanded library. It enables declarative definition of commands, events, and projections within Ash resources, with automatic code generation for modules and Commanded routers.

```text
┌──────────────────────────────────────────────────────────────┐
│                    User Layer                                 │
│   Ash.Resource + AshCommanded DSL / Ash.Domain               │
│  `lib/ash_commanded.ex` + User-defined resources             │
└────────┬──────────────────────────────────────────────────────┘
         │
┌────────▼──────────────────────────────────────────────────────┐
│              DSL Parsing & Sections Layer                      │
│      (Spark.Dsl.Extension + CommandsSection, Events, etc.)    │
│  `lib/commanded/dsl.ex` + `lib/commanded/sections/*.ex`       │
└────────┬──────────────────────────────────────────────────────┘
         │
┌────────▼──────────────────────────────────────────────────────┐
│           Transformation & Verification Layer                  │
│  Transformers: Collect options, Generate modules, Optimize    │
│  Verifiers: Validate DSL correctness                          │
│  `lib/commanded/transformers/*.ex`                            │
│  `lib/commanded/verifiers/*.ex`                               │
└────────┬──────────────────────────────────────────────────────┘
         │
┌────────▼──────────────────────────────────────────────────────┐
│         Code Generation Output (Generated Modules)             │
│  Commands, Events, Projectors, Routers, Aggregates, Handlers  │
│  (Compiled into module bytecode)                              │
└────────┬──────────────────────────────────────────────────────┘
         │
┌────────▼──────────────────────────────────────────────────────┐
│           Execution Layer (Runtime)                            │
│  Middleware Chain → Command Mapper → Ash Actions              │
│  Event Processing → Projectors → Event Handlers              │
│  `lib/commanded/middleware/*.ex`                              │
│  `lib/commanded/command_action_mapper.ex`                     │
│  `lib/commanded/transaction.ex`                               │
└────────┬──────────────────────────────────────────────────────┘
         │
┌────────▼──────────────────────────────────────────────────────┐
│              Integration Layer                                 │
│  Ash Resources, Actions, Changesets                            │
│  Commanded EventStore, Routers, Aggregates                    │
└──────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
| ----------- | ---------------- | ------ |
| **Dsl** | Main resource extension; defines 5 DSL sections and coordinates transformers/verifiers | `lib/commanded/dsl.ex` |
| **DomainDsl** | Domain-level extension; imports Dsl and runs application generation | `lib/commanded/domain_dsl.ex` |
| **CommandsSection** | Schema for command definitions with fields, identity, action mapping | `lib/commanded/sections/commands_section.ex` |
| **EventsSection** | Schema for event definitions with fields | `lib/commanded/sections/events_section.ex` |
| **ProjectionsSection** | Schema for projection definitions; maps events to resource updates | `lib/commanded/sections/projections_section.ex` |
| **EventHandlersSection** | Schema for general-purpose event handler definitions | `lib/commanded/sections/event_handlers_section.ex` |
| **ApplicationSection** | Schema for Commanded application config (event store, pubsub, etc.) | `lib/commanded/sections/application_section.ex` |
| **Command** | Data structure representing a command with fields, action, middleware | `lib/commanded/command.ex` |
| **Event** | Data structure representing an event with fields | `lib/commanded/event.ex` |
| **Projection** | Data structure representing a projection; maps event to action | `lib/commanded/projection.ex` |
| **EventHandler** | Data structure representing a side-effect handler | `lib/commanded/event_handler.ex` |
| **GenerateCommandModules** | Generates command struct modules from DSL definitions | `lib/commanded/transformers/generate_command_modules.ex` |
| **GenerateEventModules** | Generates event struct modules from DSL definitions | `lib/commanded/transformers/generate_event_modules.ex` |
| **GenerateProjectionModules** | Generates projection modules for event-to-action mapping | `lib/commanded/transformers/generate_projection_modules.ex` |
| **GenerateProjectorModules** | Generates Commanded event handler modules for projections | `lib/commanded/transformers/generate_projector_modules.ex` |
| **GenerateEventHandlerModules** | Generates event handler modules for side effects | `lib/commanded/transformers/generate_event_handler_modules.ex` |
| **GenerateAggregateModule** | Generates Commanded aggregate module (applies events to state) | `lib/commanded/transformers/generate_aggregate_module.ex` |
| **GenerateDomainRouterModule** | Generates domain-specific command router | `lib/commanded/transformers/generate_domain_router_module.ex` |
| **GenerateMainRouterModule** | Generates main application-level command router | `lib/commanded/transformers/generate_main_router_module.ex` |
| **GenerateCommandedApplication** | Generates Commanded.Application module with supervision | `lib/commanded/transformers/generate_commanded_application.ex` |
| **CommandActionMapper** | Maps command structs to Ash action parameters; executes Ash actions | `lib/commanded/command_action_mapper.ex` |
| **ParameterValidator** | Validates command parameters against constraints | `lib/commanded/parameter_validator.ex` |
| **ParameterTransformer** | Transforms command parameters before action execution | `lib/commanded/parameter_transformer.ex` |
| **Transaction** | Wraps command execution in database transactions | `lib/commanded/transaction.ex` |
| **Error** | Standardized error struct and helpers; converts Ash/Commanded errors | `lib/commanded/error.ex` |
| **CommandMiddleware** | Base class for command processing middleware | `lib/commanded/middleware/command_middleware.ex` |
| **ValidationMiddleware** | Middleware that validates command parameters | `lib/commanded/middleware/validation_middleware.ex` |
| **LoggingMiddleware** | Middleware that logs command execution | `lib/commanded/middleware/logging_middleware.ex` |
| **CommandMiddlewareProcessor** | Processes middleware chain for commands | `lib/commanded/middleware/command_middleware_processor.ex` |
| **SnapshotConfiguration** | Configuration for aggregate snapshotting | `lib/commanded/snapshot_configuration.ex` |
| **SnapshotStore** | Stores and retrieves aggregate snapshots | `lib/commanded/snapshot_store.ex` |
| **SnapshotAdapter** | Adapts snapshot store to Commanded interface | `lib/commanded/snapshot_adapter.ex` |
| **ValidateCommandFields** | Verifies command fields exist in resource attributes | `lib/commanded/verifiers/validate_command_fields.ex` |
| **ValidateCommandNames** | Verifies command names are unique within resource | `lib/commanded/verifiers/validate_command_names.ex` |
| **ValidateEventFields** | Verifies event fields exist in resource attributes | `lib/commanded/verifiers/validate_event_fields.ex` |
| **ValidateEventNames** | Verifies event names are unique within resource | `lib/commanded/verifiers/validate_event_names.ex` |
| **ValidateProjectionEvents** | Verifies projections reference valid events | `lib/commanded/verifiers/validate_projection_events.ex` |
| **ValidateProjectionActions** | Verifies projections reference valid resource actions | `lib/commanded/verifiers/validate_projection_actions.ex` |
| **ValidateProjectionChanges** | Verifies projections only update known resource attributes | `lib/commanded/verifiers/validate_projection_changes.ex` |
| **ValidateEventHandlerEvents** | Verifies event handlers reference valid events | `lib/commanded/verifiers/validate_event_handler_events.ex` |
| **ValidateEventHandlerActions** | Verifies event handlers reference valid actions | `lib/commanded/verifiers/validate_event_handler_actions.ex` |

## Pattern Overview

**Overall:** Spark DSL Extension Pattern with Multi-Stage Code Generation

**Key Characteristics:**

- **Declarative DSL**: Users declare commands, events, projections via `commanded do ... end` blocks
- **Multi-stage transformation**: Collect options → Verify → Generate code → Compile modules
- **Generated module architecture**: All command/event/router code is auto-generated at compile time
- **Middleware pipeline**: Commands flow through middleware chain before action execution
- **Event sourcing**: Commands emit events; events update projections; handlers respond to events
- **Ash integration**: Generated code calls Ash actions; uses Ash resources as data models
- **Commanded integration**: Generated routers dispatch to Commanded; aggregates apply events

## Layers

**DSL Layer:**

- Purpose: Accept declarative configuration from user
- Location: `lib/commanded/dsl.ex` + `lib/commanded/sections/*.ex`
- Contains: Spark DSL extension definition, section schemas, entity types
- Depends on: Spark (DSL framework)
- Used by: Transformation layer reads DSL state

**Data Structure Layer:**

- Purpose: Represent parsed DSL entities as structs
- Location: `lib/commanded/command.ex`, `event.ex`, `projection.ex`, `event_handler.ex`
- Contains: Data structures with metadata for DSL entities
- Depends on: None (pure data)
- Used by: Transformers read and process these structs

**Transformation Layer:**

- Purpose: Collect options and generate Elixir modules from DSL
- Location: `lib/commanded/transformers/*.ex`
- Contains: Transformers that run in sequence; generates command modules, events, routers, etc.
- Depends on: Data structures, Spark.Dsl.Transformer, code generation utilities (Sourceror, Igniter)
- Used by: Spark calls transformers during resource compilation

**Verification Layer:**

- Purpose: Validate DSL correctness before code generation
- Location: `lib/commanded/verifiers/*.ex`
- Contains: Verifiers that check field references, action references, name uniqueness
- Depends on: Data structures, Ash resource metadata
- Used by: Spark calls verifiers after transformation to ensure correctness

**Execution Layer (Runtime):**

- Purpose: Process commands and events at runtime
- Location: `lib/commanded/middleware/*.ex`, `command_action_mapper.ex`, `parameter_*.ex`, `transaction.ex`
- Contains: Middleware chain, action mapping, validation, parameter transformation
- Depends on: Ash framework, generated modules
- Used by: User code or Commanded routers dispatch commands through this layer

**Integration Layer:**

- Purpose: Bridge AshCommanded to Ash and Commanded ecosystems
- Location: Implicit; uses Ash resources and Commanded routers
- Contains: Generated routers, aggregates, event handlers that interface with Ash/Commanded
- Depends on: Ash, Commanded libraries
- Used by: Runtime system executes Ash actions and Commanded routers

## Data Flow

### Primary Command Execution Path

1. **User creates command** (`lib/commanded/command.ex` struct)

   ```elixir
   command = %MyApp.Commands.RegisterUser{id: "123", email: "user@example.com", name: "John"}
   ```

2. **Dispatch through router** (generated by `GenerateDomainRouterModule` or `GenerateMainRouterModule`)

   ```elixir
   MyApp.Domain.Router.dispatch(command)
   ```

3. **Middleware processing** (`lib/commanded/middleware/command_middleware_processor.ex`)
   - Each middleware in the command's `middleware` list processes the command
   - `ValidationMiddleware` validates parameters via `ParameterValidator`
   - Custom middleware can transform or validate

4. **Parameter transformation** (`lib/commanded/parameter_transformer.ex`)
   - Applies param_mapping from command definition
   - Transforms command fields to action parameters

5. **Command → Action mapping** (`lib/commanded/command_action_mapper.ex`)
   - Maps command to corresponding Ash action
   - Resolves action name from command config
   - Prepares action parameters

6. **Transaction wrapping** (`lib/commanded/transaction.ex`)
   - If command configured with `in_transaction?: true`
   - Wraps action execution in repository transaction
   - Handles rollback on error

7. **Ash action execution**
   - Calls Ash resource action with parameters
   - Returns result or error

8. **Context propagation**
   - Enriches action context with:
     - Command metadata (if `include_command?: true`)
     - Aggregate state (if `include_aggregate?: true`)
     - Request metadata (if `include_metadata?: true`)

9. **Result returned to user**
   - Success: Returns action result
   - Error: Returns standardized error via `Error` module

### Event Processing Path

1. **Command emits event** (Ash action creates/updates resource, triggering event)
   - Event stored in event store (Commanded integration)

2. **Projector subscribes** (generated by `GenerateProjectorModules`)
   - Commanded event handler receives event
   - Matches event type to projection definitions

3. **Projection applied** (`lib/commanded/projection.ex`)
   - Retrieves changes from projection definition
   - Can be static map or dynamic function
   - Maps event data to resource fields

4. **Ash action executed** (usually `:create` or `:update`)
   - Projector calls Ash action with projection changes
   - Updates read model in resource table

5. **Side-effect handlers invoked**
   - Event handlers (generated by `GenerateEventHandlerModules`) receive event
   - Execute custom logic (send email, update external system, etc.)
   - Can trigger additional commands/events

### DSL Compilation Flow

1. **User defines Ash resource with DSL**

   ```elixir
   defmodule MyApp.User do
     use Ash.Resource, extensions: [AshCommanded.Commanded.Dsl]
     commanded do
       commands do ... end
       events do ... end
       projections do ... end
     end
   end
   ```

2. **Spark parses DSL** → Creates DSL state with entities

3. **Collect transformers run** (CollectParameterTransforms, CollectParameterValidations, etc.)
   - Extract metadata from DSL
   - Store in DSL state for later transformers

4. **Generate transformers run in sequence**
   - `GenerateCommandModules` → Creates `MyApp.Commands.RegisterUser` struct module
   - `GenerateEventModules` → Creates `MyApp.Events.UserRegistered` struct module
   - `GenerateProjectionModules` → Records projection definitions
   - `GenerateProjectorModules` → Creates `MyApp.Projectors.UserProjector` handler
   - `GenerateEventHandlerModules` → Creates handler modules
   - `GenerateAggregateModule` → Creates `MyApp.UserAggregate` for Commanded
   - `GenerateDomainRouterModule` → Creates domain router (if in Ash.Domain)
   - `GenerateMainRouterModule` → Creates main app router
   - `GenerateCommandedApplication` → Creates app module (on domain with DomainDsl)

5. **Verifiers run** to ensure correctness
   - ValidateCommandFields, ValidateCommandNames, etc.
   - All commands/events/projections/handlers validated

6. **Compiled modules available** at runtime
   - Generated modules now callable
   - Routers dispatch commands
   - Projectors handle events
   - Handlers execute side effects

## Key Abstractions

**Command:**

- Purpose: Represents an action to be performed; mapped to Ash action
- Examples: `MyApp.Commands.RegisterUser`, `MyApp.Commands.UpdateEmail`
- Pattern: Struct with fields; middleware chain; param mapping; context config
- Implementation: `lib/commanded/command.ex` + `GenerateCommandModules`

**Event:**

- Purpose: Represents a fact that occurred; emitted by commands
- Examples: `MyApp.Events.UserRegistered`, `MyApp.Events.EmailUpdated`
- Pattern: Struct with fields matching domain facts
- Implementation: `lib/commanded/event.ex` + `GenerateEventModules`

**Projection:**

- Purpose: Maps event to resource update; applied to read model
- Examples: Create user when `UserRegistered` event, Update email when `EmailUpdated` event
- Pattern: Event → Action + Changes
- Implementation: `lib/commanded/projection.ex` + `GenerateProjectorModules`

**Event Handler:**

- Purpose: Executes side effects in response to events (not updating resource)
- Examples: Send email on registration, Log event, Notify external system
- Pattern: Events → Custom action/function
- Implementation: `lib/commanded/event_handler.ex` + `GenerateEventHandlerModules`

**Router:**

- Purpose: Dispatches commands to handlers; integrates with Commanded
- Examples: `MyApp.Domain.Router`, `MyApp.Router`
- Pattern: Command struct → Middleware → Action → Result
- Implementation: Generated by `GenerateDomainRouterModule` + `GenerateMainRouterModule`

**Aggregate:**

- Purpose: Applies events to state; maintains consistency in event sourcing
- Examples: `MyApp.UserAggregate`
- Pattern: Immutable state → Event application
- Implementation: Generated by `GenerateAggregateModule`

## Entry Points

**Resource DSL Entry:**

- Location: User's Ash resource file
- Triggers: `use Ash.Resource, extensions: [AshCommanded.Commanded.Dsl]`
- Responsibilities: Parse `commanded do ... end` block; run transformers/verifiers

**Domain DSL Entry:**

- Location: User's Ash domain file (optional)
- Triggers: `use Ash.Domain, extensions: [AshCommanded.Commanded.DomainDsl]`
- Responsibilities: Import resource DSL; run application generation transformer

**Command Dispatch Entry (Runtime):**

- Location: User code or API handler
- Triggers: `MyApp.Domain.Router.dispatch(command)` or `MyApp.Router.dispatch(command)`
- Responsibilities: Route command through middleware → mapper → Ash action

## Architectural Constraints

- **Compile-time code generation**: All command/event/router modules generated during resource compilation; no runtime code generation
- **Single resource focus**: Each resource extension generates modules for that resource only; domain router aggregates domain resources; main router aggregates domains
- **Synchronous command dispatch**: Commands execute synchronously through Ash actions; events are stored then projectors process asynchronously (if event store is async)
- **Transaction boundaries**: Commands can be wrapped in transactions; projections are applied within Ash changeset context
- **Module namespace**: Generated modules follow convention: `<ResourceModule>.Commands.<CommandName>`, etc. Uses module prefix from resource module
- **Action type inference**: Action type (create/update/destroy/read/custom) can be inferred from action name or explicitly specified
- **Event identity**: Events must have corresponding event name; field mapping must match resource attributes
- **Middleware order**: Middleware processes in declaration order; each can transform/validate/reject command
- **Verifier execution**: All verifiers run in parallel after all transformers complete; early verification of DSL correctness

## Anti-Patterns

### Conditional DSL Definition

**What happens:** Trying to use `if` or conditionals in DSL blocks to define commands/events based on runtime state

```elixir
commanded do
  commands do
    if feature_enabled?(:new_command) do  # WRONG
      command :new_action do ... end
    end
  end
end
```

**Why it's wrong:** DSL is evaluated at compile time, not runtime; conditionals execute once during compilation; feature flags don't apply
**Do this instead:** Use separate resources or modules for feature-gated functionality; enable at compile time via Mix env or config:

```elixir
commanded do
  commands do
    command :standard_action do ... end
    if Mix.env() == :prod do  # OK - compile-time evaluation
      command :premium_action do ... end
    end
  end
end
```

### Mutable Command State

**What happens:** Storing mutable references in command structs; modifying command during middleware processing

```elixir
defp my_middleware(command) do
  command.context = add_data(command.context)  # WRONG - struct immutability
  command
end
```

**Why it's wrong:** Elixir structs are immutable; this pattern breaks the immutability guarantees; middleware should return new command with updated context
**Do this instead:** Use immutable update syntax:

```elixir
defp my_middleware(command) do
  new_context = Map.merge(command.context_prefix || %{}, added_data)
  %{command | static_context: new_context}  # OK - creates new struct
end
```

### Projection Changes as Hardcoded String Keys

**What happens:** Using string keys in projection changes instead of atom keys matching resource attributes

```elixir
projection :event_received do
  action(:create)
  changes(%{"name" => "John"})  # WRONG - should be atom keys
end
```

**Why it's wrong:** Resource attributes are atoms; string keys won't match; validator checks atom keys only
**Do this instead:** Use atom keys matching resource attributes:

```elixir
projection :event_received do
  action(:create)
  changes(%{name: "John"})  # OK - atom keys
end
```

### Circular Command Dependencies

**What happens:** Command A triggers event that projects to action that dispatches Command B which triggers event that projects back to Command A

```text
Command :register_user → Event :user_registered → Projection :create_profile 
→ Action :create_profile_action (async dispatch) → Command :send_welcome_email
→ Event :email_sent → ... ← [CYCLE BACK]
```

**Why it's wrong:** Can cause infinite loops; event sourcing expects forward-only event chains; projections should update read models, not dispatch new commands
**Do this instead:** Use event handlers for side effects instead of projections:

```elixir
event_handlers do
  handler :send_welcome_email do
    events [:user_registered]
    action fn event, _metadata ->
      Notifications.send_email(event.email)
    end
  end
end
```

## Error Handling

**Strategy:** Standardized error struct with typed error categories; conversions from Ash and Commanded errors to common format

**Patterns:**

- **Explicit error creation**: Use `Error.validation_error/2`, `Error.command_error/2`, etc. for specific error types
- **Ash error conversion**: Catch Ash errors via `Error.from_ash_error/1`; returns normalized error
- **Commanded error conversion**: Catch Commanded errors via `Error.from_commanded_error/1`; returns normalized error
- **Error context**: Store contextual info (field, value, path) for debugging
- **Error propagation**: Middleware can return `{:error, error}` to reject command early
- **Transaction rollback**: Transaction failures automatically converted to `dispatch_error`

Error type taxonomy:

- `:validation_error` - Parameter or field validation failed
- `:command_error` - Command itself is malformed (missing fields, bad type)
- `:transformation_error` - Parameter transformation failed
- `:aggregate_error` - Aggregate not found or state inconsistency
- `:dispatch_error` - Router/Commanded dispatch failed
- `:action_error` - Ash action execution failed
- `:projection_error` - Projection application failed

## Cross-Cutting Concerns

**Logging:**

- `LoggingMiddleware` logs command dispatch, parameters, and results
- Transformers log module generation (via Logger)
- Can be disabled or customized per command

**Validation:**

- `ValidationMiddleware` validates command parameters
- `ParameterValidator` checks field constraints
- Verifiers check DSL correctness at compile time

**Authentication:**

- Not handled by AshCommanded; use Ash policy layer or middleware
- Middleware can check `context.actor` from Ash context

---

Architecture analysis: 2026-09-11
