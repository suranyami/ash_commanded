defmodule AshCommanded.Commanded.Transformers.GenerateCommandModules do
  @moduledoc """
  Generates command modules based on the commands defined in the DSL.

  For each command defined in a resource, this transformer will generate a corresponding module
  with the command name as a struct with the specified fields.

  This transformer should run before any other code generation transformers.

  ## Example

  Given a resource with the following command:

  ```elixir
  command :register_user do
    fields [:id, :email, :name]
    identity_field :id
  end
  ```

  This transformer will generate a module like:

  ```elixir
  defmodule MyApp.Commands.RegisterUser do
    @moduledoc "Command for registering a user"
    
    @type t :: %__MODULE__{
      id: String.t(),
      email: String.t(),
      name: String.t()
    }
    
    defstruct [:id, :email, :name]
  end
  ```
  """

  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer
  alias AshCommanded.Commanded.Transformers.BaseTransformer
  alias AshCommanded.Commanded.Transformers.GenerateEventModules

  @doc """
  Specifies that this transformer should run before the event module transformer.
  """
  @impl true
  def before?(GenerateEventModules), do: true
  def before?(_), do: false

  @doc """
  Transforms the DSL state to generate command modules.

  ## Examples

      iex> transform(dsl_state)
      updated_dsl_state
  """
  @impl true
  def transform(dsl_state) do
    resource_module = Transformer.get_persisted(dsl_state, :module)

    with commands when is_list(commands) and commands != [] <-
           Transformer.get_entities(dsl_state, [:commanded, :commands]) do
      resource_name = BaseTransformer.get_resource_name(resource_module)
      app_prefix = BaseTransformer.get_module_prefix(resource_module)

      final_state =
        Enum.reduce(commands, dsl_state, fn command, acc_dsl_state ->
          command_module = build_command_module(command, app_prefix)

          BaseTransformer.create_module(
            command_module,
            build_command_module_ast(command, resource_name),
            __ENV__
          )

          # Store the generated module in DSL state for potential use by other transformers
          command_modules = Transformer.get_persisted(acc_dsl_state, :command_modules, [])

          updated_dsl_state =
            Transformer.persist(acc_dsl_state, :command_modules, [
              {command.name, command_module} | command_modules
            ])

          updated_dsl_state
        end)

      {:ok, final_state}
    else
      _ -> {:ok, dsl_state}
    end
  end

  defp build_command_module(command, app_prefix) do
    command_name = command.command_name || command.name
    command_name_str = BaseTransformer.camelize_atom(command_name)

    Module.concat([app_prefix, "Commands", command_name_str])
  end

  defp build_command_module_ast(command, resource_name) do
    fields = command.fields
    command_name = command.command_name || command.name

    # Create a more descriptive moduledoc
    verb = humanize_verb(command_name)
    moduledoc = "Command for #{verb} a #{resource_name}"

    quote do
      @moduledoc unquote(moduledoc)

      @type t :: %__MODULE__{unquote_splicing(build_type_fields(fields))}

      defstruct unquote(fields)
    end
  end

  defp build_type_fields(fields) do
    Enum.map(fields, fn field ->
      {field, quote(do: any())}
    end)
  end

  defp humanize_verb(name) do
    name
    |> to_string()
    |> String.replace("_", " ")
  end
end
