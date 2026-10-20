# Parameter Transformation and Validation

AshCommanded provides parameter transformation and validation for command handling through two
public runtime modules:

- `AshCommanded.ParameterTransformer` — transforms a parameter map before it reaches an Ash action
- `AshCommanded.ParameterValidator` — validates a parameter map against a list of rules

> **There is no `transform_params` or `validate_params` DSL surface.** The `command` entity
> declares no nested entities, so a `command` block containing either of those blocks does not
> compile. Everything on this page is called directly from your command-handling code, with the
> spec lists shown. The same is true of the nested `transaction` block: transaction configuration
> is available only through the flat command options (`in_transaction?`, `repo`,
> `transaction_timeout`, `transaction_isolation_level`), which the DSL does declare and honour.

## Parameter Transformation

`AshCommanded.ParameterTransformer.transform_params/2` applies a list of transformation specs to
a parameter map and returns the transformed map. It is useful for:

- Renaming fields to match action expectations
- Type conversion (for example, string to integer)
- Computing new fields
- Setting default values
- Applying arbitrary transformations

### Basic Usage

```elixir
params = %{name: "John Doe", email: "John@Example.com", birthdate: "1990-01-01"}

transformed =
  AshCommanded.ParameterTransformer.transform_params(params, [
    {:map, :name, to: :full_name},
    {:cast, :birthdate, :date},
    {:transform, :email, &String.downcase/1},
    {:default, :status, [value: "active"]}
  ])
```

### Transformation Types

| Spec | Description | Example |
| ------ | ------------- | --------- |
| `{:map, from, to}` | Renames a field | `{:map, :name, to: :full_name}` |
| `{:cast, field, type}` | Converts a field to a specific type | `{:cast, :age, :integer}` |
| `{:compute, field, fun}` | Creates a new field using a function of the whole map | `{:compute, :display_name, fn p -> p.name end}` |
| `{:transform, field, fun}` | Applies a function to a field's value | `{:transform, :email, &String.downcase/1}` |
| `{:default, field, value}` | Sets a value when the field is nil | `{:default, :status, "active"}` |
| `{:custom, fun}` | Applies a function to the entire params map | `{:custom, fn p -> Map.put(p, :key, "value") end}` |

The `:default` spec also accepts `[value: value]` and `[fn: zero_arity_fun]`. The `:compute` spec
accepts a one-arity function directly, or a keyword list with `:using` or `:fn`.

### Type Casting

AshCommanded supports casting fields to the following types:

- `:string`
- `:integer`
- `:float`
- `:boolean`
- `:date`
- `:datetime`
- `:atom`
- `:list`
- `:map`

For example:

```elixir
AshCommanded.ParameterTransformer.transform_params(params, [
  {:cast, :age, :integer},
  {:cast, :created_at, :datetime},
  {:cast, :active, :boolean}
])
```

Casting to `:atom` accepts only atoms the runtime already knows. Atoms are never reclaimed on the
BEAM, so converting arbitrary input into atoms with `String.to_atom/1` would be an atom-table
exhaustion denial-of-service primitive; a value whose atom does not already exist leaves the
original value in place.

## Parameter Validation

`AshCommanded.ParameterValidator.validate_params/2` validates a parameter map against a list of
validation rules and returns `:ok` or `{:error, errors}`, where `errors` is a list of
`AshCommanded.Error` structs.

### Basic Usage

```elixir
case AshCommanded.ParameterValidator.validate_params(params, [
       {:validate, :name, [type: :string, min_length: 2]},
       {:validate, :email, [format: ~r/@/]},
       {:validate, :age, [type: :integer, min: 18]}
     ]) do
  :ok -> :valid
  {:error, errors} -> {:invalid, errors}
end
```

### Validation Types

| Rule | Description | Example |
| ------ | ------------- | --------- |
| `type` | Checks the field's type | `{:validate, :age, [type: :integer]}` |
| `format` | Validates against a regular expression | `{:validate, :email, [format: ~r/@/]}` |
| `min`/`max` | Checks a numeric range | `{:validate, :age, [min: 18, max: 120]}` |
| `min_length`/`max_length` | Checks string length | `{:validate, :name, [min_length: 2]}` |
| `min_items`/`max_items` | Checks list item count | `{:validate, :tags, [min_items: 1]}` |
| `one_of` | Checks a value against a list | `{:validate, :role, [one_of: [:user, :admin]]}` |
| `subset_of` | For lists, checks every value | `{:validate, :roles, [subset_of: [:user, :admin]]}` |
| Custom function | Applies arbitrary validation logic | `{:validate, :field, fn value -> :ok end}` |

A custom function must return `:ok` or `{:error, message}`.

### Combining Multiple Validations

A single field can carry multiple rules in one spec:

```elixir
{:validate, :password,
 [
   min_length: 8,
   format: ~r/[A-Z]/,
   format: ~r/[a-z]/,
   format: ~r/[0-9]/,
   format: ~r/[^A-Za-z0-9]/
 ]}
```

## Integration with Command Middleware

Parameter validation can also be configured as command middleware. The built-in
`AshCommanded.Middleware.ValidationMiddleware` accepts the same kinds of checks through its
middleware options:

```elixir
defmodule MyApp.User do
  use Ash.Resource,
    extensions: [AshCommanded.Resource.Dsl]

  commanded do
    commands do
      command :register_user do
        fields [:id, :name, :email, :age]

        middleware [
          {AshCommanded.Middleware.ValidationMiddleware,
           required: [:name, :email, :age],
           format: [email: ~r/@/],
           validate: fn command ->
             if command.age < 18 do
               {:error, "User must be at least 18 years old"}
             else
               :ok
             end
           end}
        ]
      end
    end
  end
end
```

## Benefits Over Basic Mapping

The parameter transformation and validation modules provide several advantages over basic field
mapping:

1. **Type Safety**: Automatic type conversion ensures values match expected types
2. **Data Normalization**: Fields can be consistently transformed (for example, lowercased emails)
3. **Computation**: Derived fields can be calculated based on input parameters
4. **Validation**: Problems are caught early in the command lifecycle
5. **Security**: Input can be sanitized and validated before processing
6. **Default Values**: Missing or nil values can be automatically populated
7. **Contextual Processing**: Command parameters can be transformed based on other parameters

By using these functions, you can create a more robust integration between your commands and Ash
actions, with clear validation rules and transformation logic.
