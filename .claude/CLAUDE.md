<!-- GSD:project-start source:PROJECT.md -->

## Project

**AshCommanded**

AshCommanded is an Elixir library that brings CQRS and Event Sourcing to the Ash Framework
declaratively. It is a Spark DSL extension: you describe commands, events, aggregate behaviour
and projections inside an Ash resource, and the library generates the Commanded modules —
command structs, event structs, aggregates, projectors, routers and the Commanded application —
that would otherwise be written by hand, one file at a time.

This project completes a library that was abandoned by its original author with structural pieces
missing, brings it to production quality, and then migrates the `core` application's entire
event-sourced codebase onto it. David is now a maintainer of the upstream repository
(`accountex-org/ash_commanded`) with rights to merge, triage issues and publish to hex.pm, so the
work lands upstream rather than in a private fork.

**Core Value:** `core`'s five event-sourced domains run in production on AshCommanded. No lesser proof counts —
a library for removing event-sourcing boilerplate is only credible if it carries a real
event-sourced system.

### Constraints

- **Tech stack**: Current Elixir/OTP, with the previous two minor Elixir releases supported and CI-tested.
  Presently declared `~> 1.14`; `core` runs `~> 1.18` on OTP 27. The declared floor tightens as part of this work.
- **Dependencies**: Ash ~> 3.0 (3.5.8), Spark ~> 2.3 (2.3.5), Commanded 1.4.8 — upper bounds move to current
  releases, but whatever is chosen must remain installable alongside `core`'s own resolved versions
- **Compatibility**: Must support every pattern `core` uses today, or `core` cannot migrate
- **Licence**: MIT, upstream `accountex-org/ash_commanded` — contributions must suit a public library
- **Genericity**: Examples and tests must be domain-neutral; no Accountex-specific concepts in the published library
- **Versioning**: Break freely on 0.x; 1.0 is cut only after `core` is fully migrated

<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->

## Technology Stack

## Languages

- Elixir 1.18.4 - Main implementation language for DSL extension
- Markdown - Documentation

## Runtime

- Erlang/OTP 27.3 - Runtime environment (implicit for Elixir)
- Mix 1.18.4 - Elixir package manager
- Lockfile: `mix.lock` (present)

## Frameworks

- Ash Framework 3.5.8 (~> 3.0) - Resource declaration and action framework that AshCommanded extends
- Spark 2.3.5 (~> 2.3) - DSL construction and transformation framework
- Commanded 1.4.8 - CQRS/Event Sourcing library (peer dependency, not in mix.exs but documented in CLAUDE.md)
- ExDoc 0.37.3 (~> 0.30) - Documentation generation from code comments
- Sourceror 1.10.0 (~> 1.8) - AST parsing and code generation (dev/test only)
- Igniter 0.6.30 (~> 0.5) - Code generation and modification framework (dev/test only)
- Mock 0.3.9 (~> 0.3.0) - Mocking library for unit tests (uses meck under the hood)

## Key Dependencies

- ash 3.5.8 - Core framework; defines resource DSL, actions, and transformations
- spark 2.3.5 - DSL extension framework; used to build the commanded DSL sections
- decimal 2.3.0 - Precise decimal arithmetic (required by Ash)
- ecto 3.12.5 - Database abstraction (transitive from Ash); used for transaction support via `Ecto.Multi`
- reactor 0.15.2 - Async computation framework for Ash (transitive)
- jason 1.4.4 - JSON encoding/decoding (required by Ash and Spark)
- telemetry 1.3.0 - Metrics and observability (transitive from Ash)
- splode 0.2.9 - Error handling utilities (transitive from Ash)

## Configuration

- Configured via `config/config.exs` (imported by `config_env()` conditions)
- Environment-specific configs: `config/dev.exs`, `config/test.exs`, `config/prod.exs`
- `.formatter.exs` - Code formatter configuration; uses Spark.Formatter plugin
- Formatter imports deps from: `:ash`, `:reactor`
- Spark formatter applies structured formatting to DSL sections
- Ash framework settings for resource handling (field access, page types, etc.)
- Spark formatter configuration with section ordering for `Ash.Resource` and `Ash.Domain`

## Platform Requirements

- Elixir 1.18.4
- Erlang/OTP 27.3
- macOS/Linux/Windows with Erlang runtime
- Elixir 1.14+ (minimum, project specifies `~> 1.14`)
- Erlang/OTP with standard libraries
- This is a library, not a standalone application; deployment depends on consuming application

## Package Metadata

- Package name: `ash_commanded`
- Version: 0.2.0
- Repository: `https://github.com/accountex-org/ash_commanded`
- License: MIT
- Maintainers: Accountex

<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->

## Conventions

## Naming Patterns

- Source files use snake_case with `.ex` extension
- Test files follow pattern `{name}_test.exs` matching the module they test
- Transformers: `generate_*.ex` (e.g., `generate_aggregate_module.ex`, `generate_command_modules.ex`)
- Verifiers: `validate_*.ex` (e.g., `validate_command_names.ex`, `validate_event_fields.ex`)
- Sections: `*_section.ex` (e.g., `commands_section.ex`, `events_section.ex`)
- Middleware components: placed in `lib/commanded/middleware/` subdirectory
- Follow CamelCase convention
- Organized hierarchically: `AshCommanded.Commanded.{Component}` (e.g., `AshCommanded.Commanded.Dsl`)
- Transformers: `AshCommanded.Commanded.Transformers.{TransformerName}`
- Verifiers: `AshCommanded.Commanded.Verifiers.{VerifierName}`
- Sections: `AshCommanded.Commanded.Sections.{SectionName}`
- Example paths: `AshCommanded.Commanded.Transformers.GenerateAggregateModule`, `AshCommanded.Commanded.Verifiers.ValidateCommandNames`
- Use snake_case for all function names
- Predicate functions end with `?` (e.g., `autogenerate_handler?`, `is_error?`)
- Private helper functions prefixed with underscore
- Generator functions named `build_*` (e.g., `build_aggregate_module_ast`)
- Validators named with `find_*` or `validate_*` prefix (e.g., `find_duplicates`, `validate_params`)
- Use snake_case for variable names
- Configuration maps use atom keys
- Frequently use tuple unpacking: `{:ok, value}` and `{:error, reason}`
- Struct fields use atom keys (e.g., `:name`, `:fields`, `:identity_field`)
- Module attributes use uppercase: `@type t :: ...`, `@moduledoc`, `@doc`
- Struct definition follows type specification: defstruct lists fields
- All public structs have `@type t` definition above (e.g., `AshCommanded.Commanded.Command` at `lib/commanded/command.ex`)
- Enum atoms are lowercase (e.g., `:create`, `:update`, `:destroy`, `:read`, `:custom`)

## Code Style

- Tool: Elixir built-in formatter with Spark.Formatter plugin
- Config: `.formatter.exs` specifies inputs, plugins, and import_deps
- Plugin imports: `[:ash, :reactor]` for proper DSL formatting
- Run with: `mix format` for all files, `mix format --check-formatted` to verify
- Line length: Elixir standard formatter (approximately 98 characters)
- Credo likely used (configured via `.credo.exs` if present)
- Spark DSL validation via transformers and verifiers
- Type checking via Dialyzer (configured in mix.exs)
- Each DSL section defines schema and entities
- Section modules follow pattern: `{Name}Section`
- Required fields have `required: true` in schema
- Schema uses type specifications: `:atom`, `:string`, `{:list, :atom}`, `{:or, [:type1, :type2]}`
- Example: `lib/commanded/sections/commands_section.ex` defines schema for `commands` section

## Import Organization

- Alias imports use full module paths with `as:` when helpful for clarity
- Example: `alias Spark.Dsl.Transformer` followed by `alias Spark.Dsl.Verifier`
- Group related module imports together

## Error Handling

- Use `{:ok, value}` and `{:error, reason}` tuples for operations that can fail
- Pattern match with `case` blocks to handle both branches
- Custom error type: `AshCommanded.Commanded.Error` (module at `lib/commanded/error.ex`)
- Error module provides specialized constructors:
- All error functions accept optional keyword list: `field:`, `value:`, `context:`, `path:`
- Use `Spark.Error.DslError` exception for DSL validation errors
- Pattern: `{:error, DslError.exception(message: msg, path: path)}`
- Path is a list like `[:commanded, :commands]` identifying where the error occurred
- Use `require Logger` at module top
- Log at appropriate levels (rarely used in current codebase, but infrastructure available)

## Comments

- Complex algorithm explanation (required)
- Non-obvious business logic (required)
- Workarounds for bugs or limitations (required with explanation)
- DSL examples in @moduledoc and @doc (extensively used)
- TODO/FIXME/HACK comments in implementation (rare in current code)
- Elixir uses `@moduledoc` for module documentation
- All public modules must have `@moduledoc` with description
- Functions have `@doc` with examples showing parameter types and usage
- `@spec` provides type specifications for function arguments and return values
- Example from `lib/commanded/error.ex`:

## Parameters

## Examples

## Function Design

- Typical functions 10-40 lines
- Larger functions like `build_aggregate_module_ast` may exceed 100 lines due to AST construction complexity
- Transformers and code generators are naturally longer (150-300+ lines for complex generation)
- Private helper functions split complex logic (e.g., `find_duplicates`, `build_error_message`)
- Functions often take DSL state as first parameter in transformers/verifiers
- Pattern: `@impl true def transform(dsl_state)` or `@impl true def verify(dsl_state)`
- Second parameter commonly holds options/metadata
- Use keyword lists for optional parameters
- Transformers: `{:ok, updated_dsl_state}` or `{:error, exception}`
- Verifiers: `:ok` on success, `{:error, exception}` on failure
- Builders/generators: Return bare values (AST, module name, etc.)
- Validators: Return filtered lists or validation results

## Module Design

- All public functions documented with @doc
- Private functions prefixed with `_` (e.g., `_build_module_ast`, `_find_duplicates`)
- Module attributes (@moduledoc, @doc, @spec) on every public definition
- Spark DSL components (@impl true for transformer/verifier callbacks)
- No barrel files observed in current structure
- Each module has clear single responsibility
- Import aliases used explicitly where needed
- Spark.Dsl.Transformer — Base class for code-generating transformers
- Spark.Dsl.Verifier — Base class for validation verifiers
- Defstruct modules for data representation (Command, Event, Error, etc.)
- Exception modules for error types (DslError from Spark)
- `lib/commanded/transformers/generate_aggregate_module.ex` — Implements Spark.Dsl.Transformer with @impl callbacks
- `lib/commanded/verifiers/validate_command_names.ex` — Implements Spark.Dsl.Verifier with @impl callbacks
- `lib/commanded/command.ex` — Pure data struct with @type definition
- `lib/commanded/error.ex` — Error module with specialized constructor functions

<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->

## Architecture

## System Overview

```text

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

- **Declarative DSL**: Users declare commands, events, projections via `commanded do ... end` blocks
- **Multi-stage transformation**: Collect options → Verify → Generate code → Compile modules
- **Generated module architecture**: All command/event/router code is auto-generated at compile time
- **Middleware pipeline**: Commands flow through middleware chain before action execution
- **Event sourcing**: Commands emit events; events update projections; handlers respond to events
- **Ash integration**: Generated code calls Ash actions; uses Ash resources as data models
- **Commanded integration**: Generated routers dispatch to Commanded; aggregates apply events

## Layers

- Purpose: Accept declarative configuration from user
- Location: `lib/commanded/dsl.ex` + `lib/commanded/sections/*.ex`
- Contains: Spark DSL extension definition, section schemas, entity types
- Depends on: Spark (DSL framework)
- Used by: Transformation layer reads DSL state
- Purpose: Represent parsed DSL entities as structs
- Location: `lib/commanded/command.ex`, `event.ex`, `projection.ex`, `event_handler.ex`
- Contains: Data structures with metadata for DSL entities
- Depends on: None (pure data)
- Used by: Transformers read and process these structs
- Purpose: Collect options and generate Elixir modules from DSL
- Location: `lib/commanded/transformers/*.ex`
- Contains: Transformers that run in sequence; generates command modules, events, routers, etc.
- Depends on: Data structures, Spark.Dsl.Transformer, code generation utilities (Sourceror, Igniter)
- Used by: Spark calls transformers during resource compilation
- Purpose: Validate DSL correctness before code generation
- Location: `lib/commanded/verifiers/*.ex`
- Contains: Verifiers that check field references, action references, name uniqueness
- Depends on: Data structures, Ash resource metadata
- Used by: Spark calls verifiers after transformation to ensure correctness
- Purpose: Process commands and events at runtime
- Location: `lib/commanded/middleware/*.ex`, `command_action_mapper.ex`, `parameter_*.ex`, `transaction.ex`
- Contains: Middleware chain, action mapping, validation, parameter transformation
- Depends on: Ash framework, generated modules
- Used by: User code or Commanded routers dispatch commands through this layer
- Purpose: Bridge AshCommanded to Ash and Commanded ecosystems
- Location: Implicit; uses Ash resources and Commanded routers
- Contains: Generated routers, aggregates, event handlers that interface with Ash/Commanded
- Depends on: Ash, Commanded libraries
- Used by: Runtime system executes Ash actions and Commanded routers

## Data Flow

### Primary Command Execution Path

### Event Processing Path

### DSL Compilation Flow

## Key Abstractions

- Purpose: Represents an action to be performed; mapped to Ash action
- Examples: `MyApp.Commands.RegisterUser`, `MyApp.Commands.UpdateEmail`
- Pattern: Struct with fields; middleware chain; param mapping; context config
- Implementation: `lib/commanded/command.ex` + `GenerateCommandModules`
- Purpose: Represents a fact that occurred; emitted by commands
- Examples: `MyApp.Events.UserRegistered`, `MyApp.Events.EmailUpdated`
- Pattern: Struct with fields matching domain facts
- Implementation: `lib/commanded/event.ex` + `GenerateEventModules`
- Purpose: Maps event to resource update; applied to read model
- Examples: Create user when `UserRegistered` event, Update email when `EmailUpdated` event
- Pattern: Event → Action + Changes
- Implementation: `lib/commanded/projection.ex` + `GenerateProjectorModules`
- Purpose: Executes side effects in response to events (not updating resource)
- Examples: Send email on registration, Log event, Notify external system
- Pattern: Events → Custom action/function
- Implementation: `lib/commanded/event_handler.ex` + `GenerateEventHandlerModules`
- Purpose: Dispatches commands to handlers; integrates with Commanded
- Examples: `MyApp.Domain.Router`, `MyApp.Router`
- Pattern: Command struct → Middleware → Action → Result
- Implementation: Generated by `GenerateDomainRouterModule` + `GenerateMainRouterModule`
- Purpose: Applies events to state; maintains consistency in event sourcing
- Examples: `MyApp.UserAggregate`
- Pattern: Immutable state → Event application
- Implementation: Generated by `GenerateAggregateModule`

## Entry Points

- Location: User's Ash resource file
- Triggers: `use Ash.Resource, extensions: [AshCommanded.Commanded.Dsl]`
- Responsibilities: Parse `commanded do ... end` block; run transformers/verifiers
- Location: User's Ash domain file (optional)
- Triggers: `use Ash.Domain, extensions: [AshCommanded.Commanded.DomainDsl]`
- Responsibilities: Import resource DSL; run application generation transformer
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

```elixir

```

```elixir

```

### Mutable Command State

```elixir

```

```elixir

```

### Projection Changes as Hardcoded String Keys

```elixir

```

```elixir

```

### Circular Command Dependencies

```text

```

```elixir

```

## Error Handling

- **Explicit error creation**: Use `Error.validation_error/2`, `Error.command_error/2`, etc. for specific error types
- **Ash error conversion**: Catch Ash errors via `Error.from_ash_error/1`; returns normalized error
- **Commanded error conversion**: Catch Commanded errors via `Error.from_commanded_error/1`; returns normalized error
- **Error context**: Store contextual info (field, value, path) for debugging
- **Error propagation**: Middleware can return `{:error, error}` to reject command early
- **Transaction rollback**: Transaction failures automatically converted to `dispatch_error`
- `:validation_error` - Parameter or field validation failed
- `:command_error` - Command itself is malformed (missing fields, bad type)
- `:transformation_error` - Parameter transformation failed
- `:aggregate_error` - Aggregate not found or state inconsistency
- `:dispatch_error` - Router/Commanded dispatch failed
- `:action_error` - Ash action execution failed
- `:projection_error` - Projection application failed

## Cross-Cutting Concerns

- `LoggingMiddleware` logs command dispatch, parameters, and results
- Transformers log module generation (via Logger)
- Can be disabled or customized per command
- `ValidationMiddleware` validates command parameters
- `ParameterValidator` checks field constraints
- Verifiers check DSL correctness at compile time
- Not handled by AshCommanded; use Ash policy layer or middleware
- Middleware can check `context.actor` from Ash context

<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->

## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->

## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:

- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->

## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
