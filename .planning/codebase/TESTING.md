# Testing Patterns

**Analysis Date:** 2026-09-11

## Test Framework

**Runner:**

- ExUnit (Elixir's built-in test framework)
- Version: Latest stable (available with Elixir runtime)
- Config: `mix.exs` specifies test configuration via aliases
- No separate test runner config file (ExUnit integrated into Mix)

**Assertion Library:**

- ExUnit assertions (built-in via `assert`, `refute`, `assert_raise`, etc.)
- No external assertion library used

**Run Commands:**

```bash
mix test                                  # Run all tests once
mix test test/path/to/file.exs           # Run specific test file
mix test test/path/to/file.exs:42        # Run specific test by line number
mix test --failed                        # Re-run previously failed tests (if configured)
mix test --trace                         # Show detailed output for each test
mix test --async false                   # Run tests sequentially (default is async where enabled)
```

## Test File Organization

**Location:**

- Tests co-located with source code under `test/` mirror structure
- `test/commanded/` mirrors `lib/commanded/` structure
- Test subdirectories: `test/commanded/middleware/`, `test/commanded/sections/`, `test/commanded/transformers/`, `test/commanded/verifiers/`
- Total: 50 test files (`.exs` extension)

**Naming:**

- File pattern: `{tested_module_name}_test.exs`
- Examples: `commands_dsl_test.exs`, `error_handling_test.exs`, `generate_aggregate_module_test.exs`
- Test module names: `{TestedModule}Test` or `{TestedModule}#{Feature}Test`
- Example: `AshCommanded.Commanded.CommandsDslTest` in `test/commanded/commands_dsl_test.exs`

**Structure:**

```text
test/
├── test_helper.exs                      # Global test setup
├── commanded/
│   ├── commands_dsl_test.exs
│   ├── events_dsl_test.exs
│   ├── projections_dsl_test.exs
│   ├── error_handling_test.exs
│   ├── parameter_handling_test.exs
│   ├── context_test.exs
│   ├── snapshot_test.exs
│   ├── middleware/
│   │   └── *_test.exs
│   ├── sections/
│   │   └── *_test.exs
│   ├── transformers/
│   │   └── *_test.exs
│   └── verifiers/
│       └── *_test.exs
```

## Test Structure

**Suite Organization:**

```elixir
defmodule AshCommanded.Commanded.CommandsDslTest do
  use ExUnit.Case, async: true

  # Test module definitions (inner defmodule blocks)
  defmodule ResourceWithCommands do
    use Ash.Resource,
      extensions: [AshCommanded.Commanded.Dsl],
      domain: nil

    attributes do
      uuid_primary_key :id
      attribute :email, :string
      attribute :name, :string
      attribute :status, :atom, default: :inactive
    end

    commanded do
      # DSL block being tested
    end
  end

  # Test cases organized by describe blocks
  describe "commands DSL" do
    test "resource can define commands" do
      # Test implementation
    end

    test "property with different values" do
      # Another test
    end
  end

  describe "another feature" do
    test "test name" do
      # Another test
    end
  end
end
```

**Patterns:**

- Async tests: `use ExUnit.Case, async: true` when tests are isolated
- Non-async tests: `use ExUnit.Case` (no async flag) when tests share state
- Setup blocks: `setup do` or `setup :tag` for test initialization (not observed in current tests)
- Teardown: Typically implicit via Ash's transaction isolation
- Assertion pattern: `assert condition`, `assert expected == actual`, `assert_raise`

## Mocking

**Framework:**

- Mock library (`{:mock, "~> 0.3.0"}` in mix.exs, test-only dependency)
- Minimal mocking observed in tests (tests prefer real execution with in-memory databases)

**Patterns:**

```elixir
# Mock usage (when needed):
test "with mocked function" do
  with_mock Ash, [create: fn _resource, _params -> {:ok, record} end] do
    # Test code that calls the mocked function
  end
end
```

**What to Mock:**

- External service calls (if any)
- Commanded event store operations (for unit tests that don't need event persistence)
- File I/O operations
- Time-dependent operations (use mocked DateTime where appropriate)

**What NOT to Mock:**

- Ash resource operations (use real in-memory implementation)
- DSL parsing and compilation (tests verify actual generated code)
- Spark transformers/verifiers (test complete compilation path)
- Internal module behavior (verify full integration)

## Fixtures and Factories

**Test Data:**

- Inline defmodule blocks within test files define test resources
- Example from `commands_dsl_test.exs`:

```elixir
defmodule ResourceWithCommands do
  use Ash.Resource,
    extensions: [AshCommanded.Commanded.Dsl],
    domain: nil

  attributes do
    uuid_primary_key :id
    attribute :email, :string
    attribute :name, :string
  end

  commanded do
    commands do
      command :register_user do
        fields([:id, :email, :name])
        identity_field(:id)
      end
    end
  end
end
```

**Location:**

- Fixtures defined at top level within test modules (not in separate fixture files)
- Test helpers in `test/test_helper.exs`
- No ExMachina factory usage observed in AshCommanded tests (unlike work/core which uses Core.Factory)

**Pattern for Setup:**

```elixir
defmodule MyTest do
  use ExUnit.Case

  # Define test resource inline
  defmodule TestResource do
    use Ash.Resource,
      extensions: [AshCommanded.Commanded.Dsl],
      domain: nil
    # ... resource definition
  end

  describe "feature" do
    test "uses inline resource" do
      commands = Spark.Dsl.Extension.get_entities(TestResource, [:commanded, :commands])
      # Verify
    end
  end
end
```

## Coverage

**Requirements:**

- No explicit coverage requirement configured
- Coverage tools available (ExCoveralls can be added)
- No coverage enforcement in CI/CD observed

**View Coverage:**

```bash
mix test --cover          # Generate coverage report (if configured)
```

## Test Types

**Unit Tests:**

- Scope: Individual DSL sections, transformers, verifiers
- Approach: Test that DSL parses correctly and generates expected structures
- Pattern: Create test resource with DSL block, verify entities extracted
- Examples:
  - `commands_dsl_test.exs` — Verifies command DSL parsing
  - `events_dsl_test.exs` — Verifies event DSL parsing
  - `error_handling_test.exs` — Verifies Error module functions

**Integration Tests:**

- Scope: Full DSL compilation, cross-module generation
- Approach: Compile entire resource with all sections, verify generated code
- Examples:
  - `dsl_test.exs` — Tests full DSL compilation
  - `parameter_handling_test.exs` — Tests parameter transformation integration
  - `context_test.exs` — Tests context propagation across modules

**E2E Tests:**

- Framework: Not implemented (use mix test for all integration coverage)
- Scope: Would test full command→event→projection→read model flow
- Not applicable to this library (E2E would be in applications using AshCommanded)

## Common Patterns

**Async Testing:**

```elixir
# Async tests when resources don't share state
use ExUnit.Case, async: true

test "isolated test" do
  # Test code
end
```

**Error Testing:**

```elixir
test "creates a validation error" do
  error = Error.validation_error("Value must be positive", field: :age, value: -5)

  assert error.type == :validation_error
  assert error.message == "Value must be positive"
  assert error.field == :age
  assert error.value == -5
end

# For testing error raising
test "raises exception" do
  assert_raise ArgumentError, fn ->
    # Code that should raise
  end
end
```

**DSL Verification Pattern:**

```elixir
test "resource can define commands" do
  # Just checking that the module compiles successfully
  assert Code.ensure_loaded?(ResourceWithCommands)

  # Access the command DSL configuration
  commands = Spark.Dsl.Extension.get_entities(ResourceWithCommands, [:commanded, :commands])

  # Check that we have the correct number of commands
  assert length(commands) == 3

  # Find commands by name and check their properties
  register_cmd = Enum.find(commands, &(&1.name == :register_user))
  assert register_cmd.fields == [:id, :email, :name]
  assert register_cmd.identity_field == :id
  assert register_cmd.autogenerate_handler? == true
end
```

**Describe Block Organization:**

```elixir
describe "commands DSL" do
  test "resource can define commands" do
    # Test
  end

  test "validates command fields" do
    # Test
  end
end

describe "error handling" do
  test "raises on invalid fields" do
    # Test
  end
end
```

## Test Environment Configuration

**Test Mode Setup:**

- `config/test.exs` — Minimal configuration (imports Config, generally empty beyond that)
- `test/test_helper.exs` — Initializes ExUnit with:

  ```elixir
  # Check if Commanded is available (optional dependency)
  exclude_tags =
    if Code.ensure_loaded?(Commanded.Application) do
      [:skip]
    else
      [:skip_if_no_commanded]
    end

  ExUnit.configure(
    exclude: exclude_tags,
    trace: false,
    seed: 0
  )

  ExUnit.start()
  ```

## Test Coverage Targets

**Well-Tested Areas:**

- DSL parsing (commands, events, projections, event handlers)
- Error creation and formatting
- Parameter transformation and validation
- Context propagation
- Module generation (aggregate, router, projector)

**Less-Tested Areas:**

- Middleware execution (partially tested)
- Snapshot functionality (basic tests present)
- Transaction handling (basic tests present)

## Best Practices

1. **Test Isolation**: Use `async: true` when resources are independent
2. **Test Names**: Use descriptive names that explain what is being tested
3. **Arrange-Act-Assert**: Structure tests with clear setup, action, verification
4. **One Assertion Focus**: Keep tests focused on single behavior
5. **Test Resources Inline**: Define test resources within test files for clarity
6. **Use describe/1**: Group related tests with `describe` blocks
7. **Verify DSL Compilation**: Always check `Code.ensure_loaded?(Module)` for compilation tests
8. **Extract Entities**: Use `Spark.Dsl.Extension.get_entities` to verify DSL configuration

---

## Analysis Date

Testing analysis: 2026-09-11
