<!-- refreshed: 2026-09-11 -->
# Codebase Structure

**Analysis Date:** 2026-09-11

## Directory Layout

```text
ash_commanded/
├── lib/                               # Source code
│   ├── ash_commanded.ex               # Top-level module (public API)
│   └── commanded/                     # Main package
│       ├── dsl.ex                     # Resource DSL extension (main entry point)
│       ├── domain_dsl.ex              # Domain DSL extension
│       ├── command.ex                 # Command data structure
│       ├── event.ex                   # Event data structure
│       ├── projection.ex              # Projection data structure
│       ├── event_handler.ex           # Event handler data structure
│       ├── error.ex                   # Standardized error struct and helpers
│       ├── command_action_mapper.ex   # Maps commands to Ash actions
│       ├── parameter_validator.ex     # Validates command parameters
│       ├── parameter_transformer.ex   # Transforms command parameters
│       ├── transaction.ex             # Transaction support for commands
│       ├── snapshot*.ex               # Snapshot-related modules
│       ├── middleware/                # Command processing middleware
│       │   ├── command_middleware.ex              # Base middleware class
│       │   ├── command_middleware_processor.ex    # Middleware chain processor
│       │   ├── validation_middleware.ex           # Parameter validation
│       │   ├── logging_middleware.ex              # Command logging
│       │   └── base_middleware.ex                 # Base middleware implementation
│       ├── sections/                  # DSL section definitions
│       │   ├── commands_section.ex                # Commands section schema
│       │   ├── events_section.ex                  # Events section schema
│       │   ├── projections_section.ex             # Projections section schema
│       │   ├── event_handlers_section.ex          # Event handlers section schema
│       │   └── application_section.ex             # Application config section schema
│       ├── transformers/              # Code generation transformers
│       │   ├── base_transformer.ex                # Base transformer utilities
│       │   ├── collect_parameter_transforms.ex   # Collect transform specs
│       │   ├── collect_parameter_validations.ex  # Collect validation specs
│       │   ├── collect_transaction_options.ex    # Collect transaction options
│       │   ├── generate_command_modules.ex       # Generate command structs
│       │   ├── generate_event_modules.ex         # Generate event structs
│       │   ├── generate_projection_modules.ex    # Generate projection modules
│       │   ├── generate_projector_modules.ex     # Generate event handlers for projections
│       │   ├── generate_event_handler_modules.ex # Generate event handlers for side effects
│       │   ├── generate_aggregate_module.ex      # Generate Commanded aggregate
│       │   ├── generate_domain_router_module.ex  # Generate domain router
│       │   ├── generate_main_router_module.ex    # Generate main app router
│       │   └── generate_commanded_application.ex # Generate Commanded.Application module
│       └── verifiers/                 # DSL validation
│           ├── validate_command_fields.ex        # Verify command fields exist
│           ├── validate_command_names.ex         # Verify unique command names
│           ├── validate_event_fields.ex          # Verify event fields exist
│           ├── validate_event_names.ex           # Verify unique event names
│           ├── validate_projection_events.ex     # Verify projections reference valid events
│           ├── validate_projection_actions.ex    # Verify projections reference valid actions
│           ├── validate_projection_changes.ex    # Verify projection changes reference valid attributes
│           ├── validate_event_handler_events.ex  # Verify handlers reference valid events
│           └── validate_event_handler_actions.ex # Verify handlers reference valid actions
├── test/                              # Test suite
│   ├── test_helper.exs                # Test configuration
│   └── commanded/                     # Tests organized by module
│       ├── middleware/
│       ├── sections/
│       ├── transformers/
│       ├── verifiers/
│       ├── dsl_test.exs               # Main DSL tests
│       ├── commands_dsl_test.exs      # Commands section tests
│       ├── events_dsl_test.exs        # Events section tests
│       ├── projections_dsl_test.exs   # Projections section tests
│       ├── event_handlers_dsl_test.exs # Event handlers section tests
│       └── [other tests]              # Feature/integration tests
├── config/                            # Configuration
│   ├── config.exs                     # Default configuration
│   ├── dev.exs                        # Development configuration
│   ├── test.exs                       # Test configuration
│   └── prod.exs                       # Production configuration
├── documentation/                     # API documentation (guides)
│   ├── commands.md                    # Commands guide
│   ├── events.md                      # Events guide
│   ├── projections.md                 # Projections guide
│   ├── event_handlers.md              # Event handlers guide
│   ├── routers.md                     # Routers guide
│   ├── application.md                 # Commanded application guide
│   ├── snapshotting.md                # Snapshots guide
│   ├── middleware.md                  # Middleware guide
│   ├── parameter_handling.md          # Parameter transformation/validation guide
│   ├── transactions.md                # Transactions guide
│   ├── context_propagation.md         # Context propagation guide
│   └── error_handling.md              # Error handling guide
├── cheatsheets/                       # DSL cheatsheets
│   └── AshCommanded.Commanded.Dsl.cheatmd
├── mix.exs                            # Project definition
├── mix.lock                           # Dependency lock file
├── README.md                          # Project README
├── LICENSE                            # MIT License
└── .formatter.exs                     # Code formatter config
```

## Directory Purposes

lib/

- Purpose: All source code; the main library
- Contains: DSL definitions, transformers, verifiers, data structures, utilities

lib/commanded/

- Purpose: Main package namespace; contains all AshCommanded-specific code
- Contains: DSL, sections, transformers, verifiers, data structures, middleware, utilities

lib/commanded/middleware/

- Purpose: Command processing middleware
- Contains: Middleware classes and processors for validating/transforming/logging commands

lib/commanded/sections/

- Purpose: Spark DSL section definitions
- Contains: Schema and entity definitions for each DSL section (commands, events, projections, etc.)

lib/commanded/transformers/

- Purpose: Code generation transformers that run during resource compilation
- Contains: Spark transformers that collect options, generate modules, verify correctness

lib/commanded/verifiers/

- Purpose: DSL validation/verification
- Contains: Spark verifiers that validate DSL usage and raise errors for incorrect configuration

test/

- Purpose: Test suite for the entire library
- Contains: Unit tests, integration tests, test helpers

test/commanded/

- Purpose: Tests organized by module/feature
- Contains: Tests for DSL, sections, transformers, verifiers, middleware, etc.

config/

- Purpose: Application configuration for different environments
- Contains: Environment-specific settings (dev, test, prod)

documentation/

- Purpose: API documentation and guides
- Contains: Markdown guides explaining how to use each feature

cheatsheets/

- Purpose: DSL quick reference
- Contains: Machine-readable cheatsheet for DSL (generated by Spark)

## Key File Locations

Entry Points:

- `lib/ash_commanded.ex` - Top-level module; public API facade
- `lib/commanded/dsl.ex` - Main resource DSL extension (users add to resources)
- `lib/commanded/domain_dsl.ex` - Domain-level DSL extension (users add to domains)

Data Structures:

- `lib/commanded/command.ex` - Command struct definition
- `lib/commanded/event.ex` - Event struct definition
- `lib/commanded/projection.ex` - Projection struct definition
- `lib/commanded/event_handler.ex` - Event handler struct definition

Core Logic:

- `lib/commanded/command_action_mapper.ex` - Maps commands to Ash actions; executes actions
- `lib/commanded/parameter_validator.ex` - Validates command parameters
- `lib/commanded/parameter_transformer.ex` - Transforms parameters using param_mapping
- `lib/commanded/transaction.ex` - Wraps command execution in transactions
- `lib/commanded/error.ex` - Standardized error handling

Code Generation:

- `lib/commanded/transformers/generate_command_modules.ex` - Generates command structs
- `lib/commanded/transformers/generate_event_modules.ex` - Generates event structs
- `lib/commanded/transformers/generate_projector_modules.ex` - Generates event handlers for projections
- `lib/commanded/transformers/generate_aggregate_module.ex` - Generates Commanded aggregates
- `lib/commanded/transformers/generate_commanded_application.ex` - Generates Commanded.Application module

Middleware:

- `lib/commanded/middleware/command_middleware_processor.ex` - Processes middleware chain
- `lib/commanded/middleware/validation_middleware.ex` - Validates command parameters
- `lib/commanded/middleware/logging_middleware.ex` - Logs command execution

Verification:

- `lib/commanded/verifiers/validate_command_fields.ex` - Verifies command fields
- `lib/commanded/verifiers/validate_command_names.ex` - Verifies command name uniqueness
- `lib/commanded/verifiers/validate_projection_actions.ex` - Verifies projections reference valid actions

DSL Sections:

- `lib/commanded/sections/commands_section.ex` - Commands section schema
- `lib/commanded/sections/events_section.ex` - Events section schema
- `lib/commanded/sections/projections_section.ex` - Projections section schema
- `lib/commanded/sections/event_handlers_section.ex` - Event handlers section schema
- `lib/commanded/sections/application_section.ex` - Application config section

Testing:

- `test/test_helper.exs` - Test setup and utilities
- `test/commanded/dsl_test.exs` - Main DSL tests
- `test/commanded/commands_dsl_test.exs` - Commands section tests
- `test/commanded/events_dsl_test.exs` - Events section tests

## Naming Conventions

Files:

- Transformer files: `generate_*.ex` (e.g., `generate_command_modules.ex`)
- Verifier files: `validate_*.ex` (e.g., `validate_command_names.ex`)
- Middleware files: `*_middleware.ex` (e.g., `validation_middleware.ex`)
- Section files: `*_section.ex` (e.g., `commands_section.ex`)
- Data structure files: `<singular>.ex` (e.g., `command.ex`, `event.ex`)

Modules:

- Transformers: `AshCommanded.Commanded.Transformers.<Name>`
- Verifiers: `AshCommanded.Commanded.Verifiers.<Name>`
- Middleware: `AshCommanded.Commanded.Middleware.<Name>`
- Sections: `AshCommanded.Commanded.Sections.<Name>`

Generated Modules:

- Command structs: `<AppPrefix>.Commands.<CommandName>` (e.g., `MyApp.Commands.RegisterUser`)
- Event structs: `<AppPrefix>.Events.<EventName>` (e.g., `MyApp.Events.UserRegistered`)
- Projectors: `<AppPrefix>.Projectors.<ResourceName>Projector` (e.g., `MyApp.Projectors.UserProjector`)
- Aggregates: `<AppPrefix>.<ResourceName>Aggregate` (e.g., `MyApp.UserAggregate`)
- Routers: `<DomainPrefix>.Router` or `<AppPrefix>.Router`
- Applications: `<DomainPrefix>.Application` or custom name via `:prefix` option

Functions:

- Transformers implement `transform/1` and optional `before?/1`, `after?/1` ordering predicates
- Verifiers implement `verify/1`
- Middleware implements `call/2` (command, next)
- Transformers/Verifiers use `Spark.Dsl.Transformer` helpers

Macros/DSL:

- User-facing macros: `command`, `event`, `projection`, `handler`, `application`
- Macro options: `fields`, `identity_field`, `action`, `changes`, etc.
- Nested blocks: `commands do ... end`, `events do ... end`, `projections do ... end`

## Where to Add New Code

New Feature (Commands, Events, Projections, Handlers):

- Definition: Update DSL section (`lib/commanded/sections/<feature>_section.ex`)
- Data Structure: Create `lib/commanded/<feature>.ex` if needed
- Code Generation: Create `lib/commanded/transformers/generate_<feature>_modules.ex`
- Verification: Create `lib/commanded/verifiers/validate_<feature>_*.ex` for each validation rule
- Tests: Add tests in `test/commanded/<feature>_test.exs` and `test/commanded/sections/<feature>_section_test.exs`

New Middleware:

- Implementation: `lib/commanded/middleware/<name>_middleware.ex`
- Base class: Extend `AshCommanded.Commanded.Middleware.BaseMiddleware`
- Tests: Add tests in `test/commanded/middleware/<name>_middleware_test.exs`

New Transformer:

- Implementation: `lib/commanded/transformers/generate_<name>_module.ex`
- Base class: Extend `Spark.Dsl.Transformer`
- Register: Add to transformers list in `lib/commanded/dsl.ex`
- Tests: Add tests in `test/commanded/transformers/<name>_test.exs`

New Verifier:

- Implementation: `lib/commanded/verifiers/validate_<rule>.ex`
- Base class: Extend `Spark.Dsl.Verifier`
- Register: Add to verifiers list in `lib/commanded/dsl.ex`
- Tests: Add tests in `test/commanded/verifiers/<rule>_test.exs`

Bug Fix:

- Locate: Use file paths from error messages or find via grep
- Fix: Modify relevant module (transformer, verifier, or core logic)
- Test: Add test case to `test/commanded/` matching the bug scenario
- Verify: Run `mix test` to ensure fix works and doesn't break existing tests

Documentation:

- New guides: Add `.md` file to `documentation/` directory
- Register: Update `mix.exs` docs config to include new file
- Regenerate: Run `mix gen.docs` to rebuild documentation

## Special Directories

_build/

- Purpose: Build artifacts
- Generated: Yes (via `mix compile`)
- Committed: No (in .gitignore)
- Notes: Contains compiled .beam files, dependencies, etc.

doc/

- Purpose: Generated API documentation
- Generated: Yes (via `mix docs`)
- Committed: No (in .gitignore)
- Notes: HTML documentation; recreate via `mix docs`

.cursor/

- Purpose: IDE-specific metadata (likely Cursor editor state)
- Generated: Yes
- Committed: No (in .gitignore)
- Notes: Can be safely deleted

deps/

- Purpose: Project dependencies
- Generated: Yes (via `mix deps.get`)
- Committed: No (in .gitignore)
- Notes: Downloaded from hex.pm and git repos

## Module Organization Pattern

Each major feature follows this pattern:

1. **Data Structure** (`lib/commanded/<feature>.ex`)
   - Struct definition with fields and types
   - Documented via @moduledoc and @type

2. **DSL Section** (`lib/commanded/sections/<feature>_section.ex`)
   - Schema definition for DSL options
   - Entity definitions for DSL entities
   - Functions: `schema/0`, `entities/0`

3. **Transformer** (`lib/commanded/transformers/generate_<feature>_modules.ex`)
   - Code generation for feature
   - Implements `transform/1` (required)
   - Implements ordering predicates if needed
   - Uses BaseTransformer utilities for common tasks

4. **Verifiers** (`lib/commanded/verifiers/validate_<feature>_*.ex`)
   - One verifier per validation rule (e.g., field existence, name uniqueness)
   - Implements `verify/1`
   - Raises descriptive errors for violations

5. **Tests** (`test/commanded/<feature>_*_test.exs`)
   - Test DSL parsing (section tests)
   - Test code generation (transformer tests)
   - Test validation (verifier tests)
   - Test integration (feature tests)

## Code Generation Flow

```text
User writes Ash resource with commanded DSL
    ↓
Spark parses DSL → Creates DSL state
    ↓
CollectParameterTransforms runs → Extracts transform specs
    ↓
CollectParameterValidations runs → Extracts validation specs
    ↓
CollectTransactionOptions runs → Extracts transaction options
    ↓
GenerateCommandModules runs → Creates command struct modules
    ↓
GenerateEventModules runs → Creates event struct modules
    ↓
GenerateProjectionModules runs → Creates projection records
    ↓
GenerateProjectorModules runs → Creates event handler modules
    ↓
GenerateEventHandlerModules runs → Creates side-effect handlers
    ↓
GenerateAggregateModule runs → Creates Commanded aggregate
    ↓
GenerateDomainRouterModule runs → Creates domain router
    ↓
GenerateMainRouterModule runs → Creates main app router
    ↓
GenerateCommandedApplication runs → Creates Commanded.Application
    ↓
All Verifiers run in parallel → Validate correctness
    ↓
Resource compiled → All generated modules available at runtime
```

Each transformer reads DSL entities via `Spark.Dsl.Transformer.get_entities/2` and persists state for downstream transformers via `Spark.Dsl.Transformer.persist/3`.

Architecture analysis: 2026-09-11
