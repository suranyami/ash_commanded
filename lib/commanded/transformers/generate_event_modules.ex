defmodule AshCommanded.Commanded.Transformers.GenerateEventModules do
  @moduledoc """
  Generates event modules based on the events defined in the DSL.

  For each event defined in a resource, this transformer will generate a corresponding module
  with the event name as a struct with the specified fields.

  This transformer should run after command modules have been generated.

  ## Example

  Given a resource with the following event:

  ```elixir
  event :user_registered do
    fields [:id, :email, :name]
  end
  ```

  This transformer will generate a module like:

  ```elixir
  defmodule MyApp.Events.UserRegistered do
    @moduledoc "Event representing when a user was registered"
    
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
  alias AshCommanded.Commanded.Transformers.GenerateCommandModules

  @doc """
  Specifies that this transformer should run after the command module transformer.
  """
  @impl true
  def after?(GenerateCommandModules), do: true
  def after?(_), do: false

  @doc """
  Transforms the DSL state to generate event modules.

  ## Examples

      iex> transform(dsl_state)
      {:ok, updated_dsl_state}
  """
  @impl true
  def transform(dsl_state) do
    resource_module = Transformer.get_persisted(dsl_state, :module)

    with events when is_list(events) and events != [] <-
           Transformer.get_entities(dsl_state, [:commanded, :events]) do
      resource_name = BaseTransformer.get_resource_name(resource_module)
      app_prefix = BaseTransformer.get_module_prefix(resource_module)

      final_state =
        Enum.reduce(events, dsl_state, fn event, acc_dsl_state ->
          event_module = build_event_module(event, app_prefix)

          BaseTransformer.create_module(
            event_module,
            build_event_module_ast(event, resource_name),
            __ENV__
          )

          # Store the generated module in DSL state for potential use by other transformers
          event_modules = Transformer.get_persisted(acc_dsl_state, :event_modules, [])

          updated_dsl_state =
            Transformer.persist(acc_dsl_state, :event_modules, [
              {event.name, event_module} | event_modules
            ])

          updated_dsl_state
        end)

      {:ok, final_state}
    else
      _ -> {:ok, dsl_state}
    end
  end

  @doc """
  Builds the module name for an event.

  ## Examples

      iex> build_event_module(%Event{name: :user_registered}, MyApp)
      MyApp.Events.UserRegistered
      
      iex> build_event_module(%Event{name: :user_registered, event_name: :new_user}, MyApp)
      MyApp.Events.NewUser
  """
  def build_event_module(event, app_prefix) do
    event_name = event.event_name || event.name
    event_name_str = BaseTransformer.camelize_atom(event_name)

    Module.concat([app_prefix, "Events", event_name_str])
  end

  @doc """
  Builds the AST (Abstract Syntax Tree) for an event module.

  ## Examples

      iex> build_event_module_ast(%Event{name: :user_registered, fields: [:id]}, "User")
      {:__block__, [], [{:@, [...], [{:moduledoc, [...], [...]}]}, ...]}
  """
  def build_event_module_ast(event, resource_name) do
    fields = event.fields
    event_name = event.event_name || event.name

    # Create a more descriptive moduledoc
    event_description = humanize_event(event_name)
    moduledoc = "Event representing when a #{resource_name} #{event_description}"

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

  defp humanize_event(name) do
    name
    |> to_string()
    |> String.replace("_", " ")
  end
end
