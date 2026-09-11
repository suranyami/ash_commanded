# Coding Conventions

**Analysis Date:** 2026-09-11

## Naming Patterns

**Files:**

- Source files use snake_case with `.ex` extension
- Test files follow pattern `{name}_test.exs` matching the module they test
- Transformers: `generate_*.ex` (e.g., `generate_aggregate_module.ex`, `generate_command_modules.ex`)
- Verifiers: `validate_*.ex` (e.g., `validate_command_names.ex`, `validate_event_fields.ex`)
- Sections: `*_section.ex` (e.g., `commands_section.ex`, `events_section.ex`)
- Middleware components: placed in `lib/commanded/middleware/` subdirectory

**Modules:**

- Follow CamelCase convention
- Organized hierarchically: `AshCommanded.Commanded.{Component}` (e.g., `AshCommanded.Commanded.Dsl`)
- Transformers: `AshCommanded.Commanded.Transformers.{TransformerName}`
- Verifiers: `AshCommanded.Commanded.Verifiers.{VerifierName}`
- Sections: `AshCommanded.Commanded.Sections.{SectionName}`
- Example paths: `AshCommanded.Commanded.Transformers.GenerateAggregateModule`, `AshCommanded.Commanded.Verifiers.ValidateCommandNames`

**Functions:**

- Use snake_case for all function names
- Predicate functions end with `?` (e.g., `autogenerate_handler?`, `is_error?`)
- Private helper functions prefixed with underscore
- Generator functions named `build_*` (e.g., `build_aggregate_module_ast`)
- Validators named with `find_*` or `validate_*` prefix (e.g., `find_duplicates`, `validate_params`)

**Variables:**

- Use snake_case for variable names
- Configuration maps use atom keys
- Frequently use tuple unpacking: `{:ok, value}` and `{:error, reason}`
- Struct fields use atom keys (e.g., `:name`, `:fields`, `:identity_field`)

**Types and Structs:**

- Module attributes use uppercase: `@type t :: ...`, `@moduledoc`, `@doc`
- Struct definition follows type specification: defstruct lists fields
- All public structs have `@type t` definition above (e.g., `AshCommanded.Commanded.Command` at `lib/commanded/command.ex`)
- Enum atoms are lowercase (e.g., `:create`, `:update`, `:destroy`, `:read`, `:custom`)

## Code Style

**Formatting:**

- Tool: Elixir built-in formatter with Spark.Formatter plugin
- Config: `.formatter.exs` specifies inputs, plugins, and import_deps
- Plugin imports: `[:ash, :reactor]` for proper DSL formatting
- Run with: `mix format` for all files, `mix format --check-formatted` to verify
- Line length: Elixir standard formatter (approximately 98 characters)

**Linting:**

- Credo likely used (configured via `.credo.exs` if present)
- Spark DSL validation via transformers and verifiers
- Type checking via Dialyzer (configured in mix.exs)

**Spark DSL Sections:**

- Each DSL section defines schema and entities
- Section modules follow pattern: `{Name}Section`
- Required fields have `required: true` in schema
- Schema uses type specifications: `:atom`, `:string`, `{:list, :atom}`, `{:or, [:type1, :type2]}`
- Example: `lib/commanded/sections/commands_section.ex` defines schema for `commands` section

## Import Organization

**Order:**

1. Elixir/Erlang standard library imports (rarely used directly)
2. External library imports (Spark, Ash, Sourceror, etc.)
3. Local module aliases for AshCommanded components
4. Require statements for Logger, Spark.Dsl.Transformer, etc.

**Path Aliases:**

- Alias imports use full module paths with `as:` when helpful for clarity
- Example: `alias Spark.Dsl.Transformer` followed by `alias Spark.Dsl.Verifier`
- Group related module imports together

**Example structure from `lib/commanded/dsl.ex`:**

```elixir
require Logger
alias AshCommanded.Commanded.Sections.CommandsSection
alias AshCommanded.Commanded.Sections.EventsSection
```

## Error Handling

**Pattern:**

- Use `{:ok, value}` and `{:error, reason}` tuples for operations that can fail
- Pattern match with `case` blocks to handle both branches
- Custom error type: `AshCommanded.Commanded.Error` (module at `lib/commanded/error.ex`)

**Error Creation:**

- Error module provides specialized constructors:
  - `Error.new(type, message, opts)` — General error creation
  - `Error.validation_error(message, opts)` — Validation failures
  - `Error.command_error(message, opts)` — Command-specific errors
  - `Error.dispatch_error(message, opts)` — Command dispatch failures
  - `Error.transformation_error(message, opts)` — Parameter transformation failures
  - `Error.aggregate_error(message, opts)` — Aggregate state errors
  - `Error.action_error(message, opts)` — Ash action execution errors
- All error functions accept optional keyword list: `field:`, `value:`, `context:`, `path:`

**Verifier Errors:**

- Use `Spark.Error.DslError` exception for DSL validation errors
- Pattern: `{:error, DslError.exception(message: msg, path: path)}`
- Path is a list like `[:commanded, :commands]` identifying where the error occurred

**Logging:**

- Use `require Logger` at module top
- Log at appropriate levels (rarely used in current codebase, but infrastructure available)

## Comments

**When to Comment:**

- Complex algorithm explanation (required)
- Non-obvious business logic (required)
- Workarounds for bugs or limitations (required with explanation)
- DSL examples in @moduledoc and @doc (extensively used)
- TODO/FIXME/HACK comments in implementation (rare in current code)

**JSDoc/TSDoc:**

- Elixir uses `@moduledoc` for module documentation
- All public modules must have `@moduledoc` with description
- Functions have `@doc` with examples showing parameter types and usage
- `@spec` provides type specifications for function arguments and return values
- Example from `lib/commanded/error.ex`:

```elixir
@doc """
Creates a new error with the specified type and message.

## Parameters
  * `type` - The type of error
  * `message` - The error message
  * `opts` - Additional options

## Examples

    iex> Error.new(:validation_error, "Field required")
    %Error{type: :validation_error, message: "Field required"}
"""
@spec new(error_type(), String.t(), keyword()) :: t()
```

## Function Design

**Size:**

- Typical functions 10-40 lines
- Larger functions like `build_aggregate_module_ast` may exceed 100 lines due to AST construction complexity
- Transformers and code generators are naturally longer (150-300+ lines for complex generation)
- Private helper functions split complex logic (e.g., `find_duplicates`, `build_error_message`)

**Parameters:**

- Functions often take DSL state as first parameter in transformers/verifiers
- Pattern: `@impl true def transform(dsl_state)` or `@impl true def verify(dsl_state)`
- Second parameter commonly holds options/metadata
- Use keyword lists for optional parameters

**Return Values:**

- Transformers: `{:ok, updated_dsl_state}` or `{:error, exception}`
- Verifiers: `:ok` on success, `{:error, exception}` on failure
- Builders/generators: Return bare values (AST, module name, etc.)
- Validators: Return filtered lists or validation results

## Module Design

**Exports:**

- All public functions documented with @doc
- Private functions prefixed with `_` (e.g., `_build_module_ast`, `_find_duplicates`)
- Module attributes (@moduledoc, @doc, @spec) on every public definition
- Spark DSL components (@impl true for transformer/verifier callbacks)

**Barrel Files:**

- No barrel files observed in current structure
- Each module has clear single responsibility
- Import aliases used explicitly where needed

**Module Patterns:**

- Spark.Dsl.Transformer — Base class for code-generating transformers
- Spark.Dsl.Verifier — Base class for validation verifiers
- Defstruct modules for data representation (Command, Event, Error, etc.)
- Exception modules for error types (DslError from Spark)

**Typical Module Structure:**

1. Module declaration with @moduledoc
2. @type definitions if needed
3. require/import/alias blocks
4. Public functions with @doc/@spec
5. Private helper functions with leading _
6. Callback implementations (@impl true for Spark behaviors)

**Examples:**

- `lib/commanded/transformers/generate_aggregate_module.ex` — Implements Spark.Dsl.Transformer with @impl callbacks
- `lib/commanded/verifiers/validate_command_names.ex` — Implements Spark.Dsl.Verifier with @impl callbacks
- `lib/commanded/command.ex` — Pure data struct with @type definition
- `lib/commanded/error.ex` — Error module with specialized constructor functions

---

*Convention analysis: 2026-09-11*
