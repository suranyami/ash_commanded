# Transformer Execution Order in AshCommanded

This document explains the order of execution for transformers in the AshCommanded extension.

## Current Transformers

1. `GenerateCommandModules` - Generates command modules based on command definitions
2. `GenerateEventModules` - Generates event modules based on event definitions

## Controlling Transformer Order

Spark provides two mechanisms to control the order of transformers:

1. **Explicit Order in Extension Definition**: Transformers are listed in order in the extension definition.
2. **Dependency Callbacks**: Using `before?/1` and `after?/1` callbacks to define dependencies.

## Current Order Implementation

Our current implementation specifies transformer order through the extension definition:

```elixir
use Spark.Dsl.Extension,
  sections: [@commanded_section],
  transformers: [
    AshCommanded.Resource.Transformers.GenerateCommandModules,
    AshCommanded.Resource.Transformers.GenerateEventModules
  ],
  verifiers: [
    # verifiers...
  ]
```

This ensures that command modules are generated before event modules.

## Improving Transformer Order with Dependencies

For more complex dependencies between transformers, we should implement the dependency callbacks:

```elixir
# In GenerateEventModules
def after?(AshCommanded.Resource.Transformers.GenerateCommandModules), do: true
def after?(_), do: false
```

This explicitly states that event modules should be generated after command modules.

## Future Transformers and Order Dependencies

As we add more transformers, we should consider these dependencies:

1. **Command Modules**: Should run first
2. **Event Modules**: Should run after command modules
3. **Aggregate Modules**: Should run after command and event modules
4. **Command Handler Modules**: Should run after command and aggregate modules
5. **Projection Modules**: Should run after event modules
6. **Router Modules**: Should run last, after all other modules are generated

## Implementation Plan

For each new transformer, we should:

1. Document its dependencies
2. Implement appropriate `before?/1` and `after?/1` callbacks
3. Test that it runs in the correct order

## Testing Transformer Order

We can test transformer order through integration tests that verify:

1. Transformers are called in the expected order
2. Later transformers can access resources created by earlier transformers

For example, we should verify that when both command and event modules are generated, 
command modules are available before event module generation begins.