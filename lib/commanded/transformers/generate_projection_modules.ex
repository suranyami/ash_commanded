# credo:disable-for-this-file AshCommanded.CredoChecks.NoModuleNameSurgery
# gsd-disable-until-phase: 5 — `build_projection_module/2`'s
# `event_module |> Module.split() |> ...` reconstructs a projection module's parent namespace
# from the event module name itself, the confirmed defect FOUND-10/rewrite-rule-4 targets.
# ROADMAP.md Phase 5 ("Projections, Event Handlers and Process Managers") owns the projection
# generator rewrite and is where this is replaced with `Transformer.get_persisted/2`, per D-01.
defmodule AshCommanded.Commanded.Transformers.GenerateProjectionModules do
  @moduledoc """
  Generates projection modules based on the projections defined in the DSL.

  For each projection defined in a resource, this transformer will generate a corresponding module
  that handles the transformation of events into resource updates.

  This transformer should run after the event module transformer.

  ## Example

  Given a resource with the following projection:

  ```elixir
  projection :user_registered do
    action :create
    changes(%{status: :active})
  end
  ```

  This transformer will generate a module like:

  ```elixir
  defmodule MyApp.Projections.UserRegistered do
    @moduledoc "Projection that handles user_registered events"
    
    def apply(event, resource) do
      # Apply changes to the resource based on the event
      changes = %{status: :active}
      Ash.Changeset.for_action(resource, event, :create, changes)
    end
  end
  ```
  """

  use Spark.Dsl.Transformer
  alias AshCommanded.Commanded.Transformers.BaseTransformer
  alias AshCommanded.Commanded.Transformers.GenerateEventModules
  alias Spark.Dsl.Transformer

  @doc """
  Specifies that this transformer should run after the event module transformer.
  """
  @impl true
  def after?(GenerateEventModules), do: true
  def after?(_), do: false

  @doc """
  Transforms the DSL state to generate projection modules.

  ## Examples

      iex> transform(dsl_state)
      {:ok, updated_dsl_state}
  """
  @impl true
  def transform(dsl_state) do
    resource_module = Transformer.get_persisted(dsl_state, :module)

    case Transformer.get_entities(dsl_state, [:commanded, :projections]) do
      [] ->
        {:ok, dsl_state}

      projections ->
        resource_name = BaseTransformer.get_resource_name(resource_module)
        app_prefix = BaseTransformer.get_module_prefix(resource_module)

        final_state =
          Enum.reduce(projections, dsl_state, fn projection, acc_dsl_state ->
            projection_module = build_projection_module(projection, app_prefix)

            BaseTransformer.create_module(
              projection_module,
              build_projection_module_ast(projection, resource_name),
              __ENV__
            )

            # Store the generated module in DSL state for potential use by other transformers
            projection_modules = Transformer.get_persisted(acc_dsl_state, :projection_modules, [])

            updated_dsl_state =
              Transformer.persist(acc_dsl_state, :projection_modules, [
                {projection.name, projection_module} | projection_modules
              ])

            updated_dsl_state
          end)

        {:ok, final_state}
    end
  end

  @doc """
  Builds the module name for a projection.

  ## Examples

      iex> build_projection_module(%Projection{name: :user_registered}, MyApp)
      MyApp.Projections.UserRegistered
  """
  def build_projection_module(projection, app_prefix) do
    projection_name_str = BaseTransformer.camelize_atom(projection.name)

    Module.concat([app_prefix, "Projections", projection_name_str])
  end

  @doc """
  Builds the AST (Abstract Syntax Tree) for a projection module.

  ## Examples

      iex> build_projection_module_ast(%Projection{name: :user_registered, action: :create, changes: %{status: :active}}, "User")
      {:__block__, [], [{:@, [...], [{:moduledoc, [...], [...]}]}, ...]}
  """
  def build_projection_module_ast(projection, resource_name) do
    event_name = projection.event_name || projection.name

    # Create a more descriptive moduledoc
    moduledoc = "Projection that handles #{event_name} events for #{resource_name} resources"

    # Generate the appropriate apply function based on the changes type
    changes_ast = generate_changes_ast(projection.changes)

    quote do
      @moduledoc unquote(moduledoc)

      @doc """
      Applies the projection to the resource based on the received event.

      ## Parameters

      - `event` - The event that triggered this projection
      - `resource` - The resource to apply changes to

      ## Returns

      An Ash changeset ready to be applied
      """
      def apply(event, resource) do
        changes = unquote(changes_ast)

        Ash.Changeset.new(resource)
        |> Ash.Changeset.for_action(unquote(projection.action), changes)
        |> Ash.Changeset.set_context(%{event: event})
      end

      @doc """
      Returns the action that should be performed on the resource.

      ## Returns

      The atom representing the Ash action to perform
      """
      def action, do: unquote(projection.action)
    end
  end

  # Generate AST for static map changes
  defp generate_changes_ast(changes) when is_map(changes) do
    # Handle maps with function values
    changes_with_handled_functions =
      Enum.map(changes, fn {k, v} ->
        {k, handle_function_value(v)}
      end)
      |> Enum.into(%{})

    Macro.escape(changes_with_handled_functions)
  end

  # Generate AST for function reference in DSL.
  #
  # In practice `projection.changes` is never the raw `{:fn, _, _}` AST this clause's name
  # suggests — Spark's `:quoted` schema type evaluates a `changes(fn event -> ... end)` DSL
  # entry into a real, compiled anonymous function at DSL-processing time, before this
  # transformer ever runs. Kept for robustness in case some other DSL entry point ever supplies
  # literal unevaluated AST here; the function-value clauses below are what actually fires today.
  defp generate_changes_ast({:fn, _, _} = fn_ast) do
    quote do
      changes_fn = unquote(fn_ast)
      changes_fn.(event)
    end
  end

  # A `changes(fn event -> ... end)` DSL entry (one argument: the triggering event).
  #
  # Found while exercising a real generated projector's `handle/2` for the first time (Plan
  # 01-06, TEST-03): the previous version of this clause just re-embedded the function value
  # itself via `Macro.escape/1` without ever calling it, so `apply/2` assigned the raw function
  # to `changes` and passed it straight to `Ash.Changeset.for_action/3`, which requires a map or
  # keyword list — crashing with `Protocol.UndefinedError` ("protocol Enumerable not implemented
  # for type Function") the moment a real event flowed through. `is_function(email_proj.changes,
  # 1)` in `projections_dsl_test.exs` only ever asserted that the DSL *parsed* the function; no
  # test called the generated code with a real event, so this was never observed until now.
  defp generate_changes_ast(other) when is_function(other, 1) do
    quote do
      unquote(Macro.escape(other)).(event)
    end
  end

  # A `changes(&SomeModule.compute/0)`-style zero-arity function reference (e.g. the
  # `registered_at: &DateTime.utc_now/0` shape used as a *map value* elsewhere is handled by
  # `handle_function_value/1` below; this clause is for `changes` itself being a bare zero-arity
  # function, not one taking the event).
  defp generate_changes_ast(other) when is_function(other, 0) do
    quote do
      unquote(Macro.escape(other)).()
    end
  end

  # Handle function reference passed in a map value
  defp handle_function_value(value) when is_function(value) do
    # For function values, we'll just reference them directly
    # This will be escaped by Macro.escape in the parent function
    value
  end

  # Handle non-function values
  defp handle_function_value(value) do
    value
  end
end
