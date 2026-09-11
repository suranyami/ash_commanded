<!-- refreshed: 2026-09-11 -->
# Codebase Concerns

**Analysis Date:** 2026-09-11

## Tech Debt

### Missing Critical Dependencies

**Issue:** Commanded and EventStore libraries are not declared in `mix.exs`

- Files: `mix.exs`, `lib/commanded/transformers/generate_projector_modules.ex`, `lib/commanded/transformers/generate_main_router_module.ex`, `lib/commanded/transformers/generate_domain_router_module.ex`
- Impact: Generated code depends on Commanded but the dependency is not explicitly declared. This creates an implicit dependency on external configuration (user's project must add Commanded). Deployment or dependency resolution may fail if users forget to add Commanded.
- Fix approach: Add `:commanded` and `:event_store` as explicit dependencies in `mix.exs` with appropriate version constraints

### Logging via IO.puts/IO.inspect in Production Code

**Issue:** Debug logging statements left in production code paths

- Files:
  - `lib/commanded/snapshot_store.ex:111` - `IO.puts("Error retrieving snapshot: #{inspect(e)}")`
  - `lib/commanded/middleware/base_middleware.ex:18,25,31` - `IO.inspect` calls for command dispatch/result/failure logging
- Impact: Unstructured console output in production environments; should use proper logging infrastructure (Logger module); slows down Elixir process by synchronous I/O
- Fix approach: Replace `IO.puts`/`IO.inspect` with `Logger.error`, `Logger.info`, or `Logger.debug` calls; remove debug middleware logging or make it configurable

## Test Coverage Gaps

### Insufficient EventHandler Verifier Testing

**Issue:** Event handler verifiers have only existence tests, no logic validation

- Files: `test/commanded/verifiers/event_handler_tests.exs:1-20`
- Current test: Only checks that `ValidateEventHandlerEvents` and `ValidateEventHandlerActions` modules can be loaded and implement Spark.Dsl.Verifier behavior
- Missing: Tests for actual validation logic - invalid event references, invalid actions, duplicate handlers, etc.
- Risk: Broken verifiers could allow invalid DSL configurations that fail at runtime instead of compile-time
- Priority: High - verifiers are critical for catching configuration errors early

### Minimal Command Name Conflict Testing

**Issue:** No verifier or test for command names shadowing resource actions

- Files: All command verifier test files
- Current behavior: CLAUDE.md mentions "ValidateCommandNameConflict" verifier but it does not exist in codebase
- Missing: Verifier to prevent commands with the same name as existing Ash actions (would cause routing ambiguity)
- Risk: Command dispatch could accidentally invoke resource actions instead of command handlers
- Fix approach: Implement `ValidateCommandNameConflict` verifier and corresponding tests

## Large/Complex Modules

### GenerateAggregateModule - 861 lines

**Issue:** Single transformer module is extremely large and handles multiple responsibilities

- File: `lib/commanded/transformers/generate_aggregate_module.ex`
- Responsibilities: Command execution generation, event application generation, snapshot configuration, snapshot functions (create, restore, get, should_snapshot?)
- Complexity metrics: ~40 function definitions, nested case statements for command/event routing
- Risk: Changes to any aspect (commands, events, snapshots) affect entire module; difficult to test individual concerns
- Fragility: Snapshot logic mixed with aggregate state logic; difficult to maintain
- Fix approach: Extract snapshot generation to separate `GenerateSnapshotFunctions` transformer; separate command and event handler generation

### CommandActionMapper - 640 lines

**Issue:** Single module handles parameter transformation, validation, transaction coordination, and error mapping

- File: `lib/commanded/command_action_mapper.ex`
- Responsibilities: Command-to-action mapping, parameter transformation, validation, transaction coordination, error handling
- Complexity: ~100+ internal function definitions; deeply nested conditional logic for action type handling
- Risk: Parameter transformation bugs could silently pass invalid data; transaction logic is error-prone
- Fix approach: Extract transaction coordination to separate module; create dedicated `ParameterTransformer` for mapping logic

### Error Module - 514 lines

**Issue:** Centralized error handling with 500+ lines may hide composition opportunities

- File: `lib/commanded/error.ex`
- Current: Defines error type, helper functions for creating different error categories, formatting utilities
- Concern: Large module should consider whether helpers should be in separate protocol-based modules for extensibility
- Fix approach: Review if error helpers can be moved to protocol implementations or separate utility modules

## Architectural Concerns

### Projector Generation TODO

**Issue:** Incomplete projector discovery implementation

- File: `lib/commanded/transformers/generate_commanded_application.ex:115`
- Comment: `# TODO: Add dynamically discovered projectors here`
- Impact: Projectors may need to be manually registered in application module instead of auto-discovered
- Risk: Missing projectors won't process events, leading to stale read models
- Fix approach: Implement dynamic projector discovery using Spark's introspection capabilities

### Snapshot Store ETS Limitations

**Issue:** Default ETS-based snapshot store not suitable for distributed systems

- File: `lib/commanded/snapshot_store.ex`
- Current: Uses in-memory ETS table (`:ash_commanded_snapshots`) - lost on VM restart
- Impact: No persistence; multi-node systems need external snapshot store implementation
- Production implications: Users deploying to production must implement custom snapshot store or lose all snapshots on deployment
- Mitigation: Documentation exists for custom implementations, but default is not production-ready
- Fix approach: Consider providing pluggable backends (SQL, Redis) as separate packages

### Code Generation Via Quoted AST at Runtime

**Issue:** Modules generated at compile-time using `BaseTransformer.create_module` via quote

- Files: Multiple `Generate*Module` transformers
- Risk: Generated code bugs are hard to debug (stack traces point to generated code with unclear context); generated modules not visible in source
- Mitigation: Generated modules are placed in standard module namespace; test coverage should be comprehensive
- Concern: Large generated functions (e.g., aggregate execute/apply) may be difficult to troubleshoot when errors occur

## Security Considerations

### No Input Validation on Generated Command Structs

**Issue:** Generated command modules are plain structs with no built-in validation

- Files: `lib/commanded/transformers/generate_command_modules.ex`
- Current: Commands are struct + typespec only; validation happens through `ParameterValidator` middleware
- Risk: If middleware is skipped or improperly configured, invalid commands could be dispatched
- Fix approach: Consider adding built-in struct validation on command creation (custom `new/1` function with validation)

### Middleware Processing Can Be Bypassed

**Issue:** Command handlers can bypass middleware if dispatched directly

- Files: `lib/commanded/middleware/command_middleware_processor.ex`
- Current: Middleware pipeline is optional and configured per-command
- Risk: Commands dispatched without proper context propagation, validation, or transformation if middleware misconfigured
- Fix approach: Default to strict middleware application; allow explicit bypass only with documentation
- Mitigation: Add compiler warning if command has no middleware configured

## Known Fragile Areas

### Event Handler Module Generation

**Issue:** Event handler generation tightly coupled to projection generation

- Files: `lib/commanded/transformers/generate_event_handler_modules.ex`, `lib/commanded/transformers/generate_projector_modules.ex`
- Concern: Event handlers and projectors both use Commanded.Event.Handler trait; unclear separation of concerns
- Risk: Modifications to either generator could break the other
- Tight coupling: Projectors expect specific event handler naming conventions
- Fix approach: Document the contract between event handlers and projectors; consider unified generation if they're always used together

### Parameter Transformation Order Dependency

**Issue:** Parameter transforms applied in sequence without clear semantics

- File: `lib/commanded/command_action_mapper.ex` (lines ~150-200)
- Concern: Transform order matters but is not validated; no guarantees about idempotency
- Risk: Non-commutative transforms could produce different results based on order; no automatic ordering logic
- Fix approach: Document transform order semantics; consider topological sorting if dependencies exist

### Snapshot Restore Logic Without Validation

**Issue:** Aggregate state restoration from snapshots lacks validation

- File: `lib/commanded/transformers/generate_aggregate_module.ex` (snapshot restore sections)
- Concern: Restored state could be stale or corrupted without verification
- Risk: Business logic bugs if snapshot is from incompatible version
- Mitigation: Snapshot version checked but no semantic validation of restored state
- Fix approach: Add post-restore validation hook in generated aggregates

## Missing Critical Features

### No Snapshot Version Migration Strategy

**Issue:** Aggregate snapshot versions tracked but no migration framework provided

- File: `lib/commanded/snapshot.ex`, `lib/commanded/transformers/generate_aggregate_module.ex`
- Current: Snapshot version is configurable but there's no way to migrate snapshots between versions
- Impact: Changing aggregate structure requires manual snapshot deletion/recreation; no automatic version handling
- Risk: Deployment with snapshot version bump could fail if old snapshots not cleaned
- Fix approach: Provide migration hooks or transformer for snapshot version upgrades

### No Support for Command Correlation/Causation

**Issue:** Commands don't include correlation IDs or causation tracking

- Files: `lib/commanded/command.ex`, generated command modules
- Current: Commands are simple structs; no metadata about originating request/causation chain
- Impact: Difficult to trace command lineage for debugging; audit trail incomplete
- Standard: Commanded typically includes correlation and causation in metadata
- Fix approach: Add optional correlation/causation fields to command generation

### Limited Transaction Support Documentation

**Issue:** Transaction options are generated but usage patterns unclear

- Files: `lib/commanded/command.ex` (transaction_timeout, transaction_isolation_level fields)
- Current: Fields exist but no comprehensive guide on when/how to use them
- Risk: Users may misconfigure transactions, leading to performance issues
- Concern: Isolation level choices not validated against database capabilities
- Fix approach: Add transaction configuration guide to documentation

## Scaling Limits

### ETS Snapshot Table Unbounded Growth

**Issue:** ETS snapshot table has no size limits or cleanup strategy

- File: `lib/commanded/snapshot_store.ex` (ETS table created with `:set` type)
- Current: All snapshots inserted, none automatically removed
- Impact: Memory usage grows unbounded; production deployments will run out of memory
- Mitigation: `:public` table type allows external cleanup but no automatic mechanism
- Fix approach: Implement snapshot retention policy (e.g., keep N latest per aggregate or time-based TTL)

### Aggregate Version Field Unbounded

**Issue:** Aggregate version is integer with no rollover handling

- File: Generated aggregate modules
- Concern: Long-running aggregates eventually reach integer limits
- Impact: Version counter could overflow for aggregates with millions of events
- Elixir Limitation: Integers are arbitrary precision so no technical overflow, but version comparison logic could break
- Fix approach: Document version counter strategy; consider version partitioning for very high-event aggregates

## Dependencies at Risk

### No Explicit Commanded Version Constraint

**Issue:** Commanded library is not declared as dependency

- Current: Users must add Commanded to their project manually
- Risk: No version compatibility checking; users might add incompatible Commanded version
- Missing from mix.exs: `{:commanded, "~> X.Y"}`
- Fix approach: Add explicit Commanded dependency with tested version range

### EventStore Adapter Not Specified

**Issue:** EventStore configuration is delegated to user but no default provided

- File: `lib/commanded/transformers/generate_commanded_application.ex` (line 90: `event_store = Keyword.get(config, :event_store)`)
- Risk: Generated Commanded application will fail if event store not configured
- Current: Documentation indicates users must provide event store, but compile error could be clearer
- Fix approach: Require event store configuration during domain/application setup with clear error messaging

## Edge Cases Not Covered

### No End-to-End Command Dispatch Tests

**Issue:** Missing comprehensive tests for command -> event -> projection flow

- Test files: Multiple files but no integrated scenario tests
- Current: Individual transformer/verifier tests exist but not full CQRS workflow
- Gap: No tests verifying command dispatch -> aggregate execute -> event apply -> projector update sequence
- Risk: Integration bugs could be missed by unit tests
- Fix approach: Add integration test suite exercising full command lifecycle

### Snapshot Restore Edge Cases Not Tested

**Issue:** Limited test coverage for snapshot edge cases

- File: `test/commanded/snapshot_test.exs`
- Missing: Tests for snapshot version mismatches, corrupted snapshots, missing identity field
- Risk: Production snapshot failures would be discovered in production, not development
- Fix approach: Comprehensive snapshot edge case test suite (version conflicts, concurrent access, etc.)

### Parameter Validation Edge Cases

**Issue:** Parameter transformation/validation logic has limited edge case testing

- Files: `test/commanded/parameter_transformer_errors_test.exs`, `test/commanded/parameter_validator_test.exs`
- Current: ~120-150 lines each; likely covers happy path
- Missing: Complex scenarios with nested transforms, validation order dependencies, partial failures
- Fix approach: Add matrix-style tests for transform/validation combinations

---

**Concerns audit:** 2026-09-11
