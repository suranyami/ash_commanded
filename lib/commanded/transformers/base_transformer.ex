defmodule AshCommanded.Commanded.Transformers.BaseTransformer do
  @moduledoc """
  A base module for Commanded DSL transformers.

  This module provides common functionality for transformers that generate code
  based on the Commanded DSL configuration.
  """

  @doc """
  Gets the module prefix for generated modules.

  This extracts the base namespace from the resource module, which will be used
  as the prefix for all generated modules.

  ## Examples
      
      iex> get_module_prefix(MyApp.Accounts.User)
      MyApp.Accounts
  """
  @spec get_module_prefix(module()) :: module()
  def get_module_prefix(resource_module) do
    parts = Module.split(resource_module)

    case parts do
      [_single_module] -> resource_module
      multiple_parts -> multiple_parts |> Enum.drop(-1) |> Module.concat()
    end
  end

  @doc """
  Gets the resource name from the resource module.

  ## Examples
      
      iex> get_resource_name(MyApp.Accounts.User)
      "User"
  """
  @spec get_resource_name(module()) :: String.t()
  def get_resource_name(resource_module) do
    resource_module
    |> Module.split()
    |> List.last()
  end

  @doc """
  Converts an atom to CamelCase string.

  ## Examples
      
      iex> camelize_atom(:register_user)
      "RegisterUser"
  """
  @spec camelize_atom(atom()) :: String.t()
  def camelize_atom(atom) do
    atom
    |> to_string()
    |> Macro.camelize()
  end

  @doc """
  Creates a module with the given name and contents.

  This is a wrapper around Module.create/3 that handles the environment location.

  When `Application.get_env(:ash_commanded, :capture_ast?, false)` is true and the named,
  public ETS table `:ash_commanded_dump_capture` exists, the AST is recorded there (as
  `{module_name, ast}`) before the module is created. This is the seam `mix
  ash_commanded.dump` forces a recompile through to see what a transformer wrote before
  `Module.create/3` ran (D-06). A normal `mix compile`/`mix test` never sets the flag, so it
  pays one `Application.get_env/3` lookup and nothing else. A missing table cannot crash an
  ordinary compile (T-01-BI-02).

  Delegates to `create_module/4` with no explicit location, which falls back to
  `Macro.Env.location(env)` exactly as this function always has — every existing caller is
  unaffected.

  ## Examples

      iex> create_module(MyApp.Commands.RegisterUser, quoted_ast, __ENV__)
      :ok
  """
  @spec create_module(module(), Macro.t(), Macro.Env.t()) :: :ok
  def create_module(module_name, ast, env) do
    create_module(module_name, ast, env, [])
  end

  @doc """
  Same as `create_module/3`, but accepts an explicit `[file: ..., line: ...]` location that
  replaces `Macro.Env.location(env)` in the underlying `Module.create/3` call.

  This is FOUND-18: today, every generated module is compiled with the *transformer's* own
  file and line (`Macro.Env.location(env)`, `env` being the calling transformer's `__ENV__`),
  so a compile error inside generated code blames the transformer rather than the DSL
  declaration that produced it — never where the fault actually is. Pass an explicit
  location here to point a diagnostic at the file a developer can actually open and fix.

  The recommended source for that location is `Spark.Dsl.Transformer.get_persisted(dsl_state,
  :file)` — Spark automatically persists the DSL-using module's own file under `:file` for
  every extension (`@persist {:file, __ENV__.file}`, set once per DSL module at `use
  Ash.Resource`/`use Ash.Domain` time), so it is available to every transformer's `transform/1`
  without deriving anything. A transformer that wants a specific `:line` too can pair it with
  a line captured from the entity's own DSL declaration.

  When `location` is `[]` (the default from `create_module/3`), behaviour is identical to
  before this arity existed. `create_module/3`'s nine existing callers are unaffected; adopting
  the explicit location is left to the transformers that choose to pass one.

  ## Examples

      iex> create_module(MyApp.Commands.RegisterUser, quoted_ast, __ENV__,
      ...>   file: Spark.Dsl.Transformer.get_persisted(dsl_state, :file), line: 1)
      :ok
  """
  @spec create_module(module(), Macro.t(), Macro.Env.t(), keyword()) :: :ok
  def create_module(module_name, ast, env, location) do
    capture_ast(module_name, ast)

    resolved_location =
      case location do
        [] -> Macro.Env.location(env)
        _ -> location
      end

    Module.create(module_name, ast, resolved_location)
    :ok
  end

  @capture_table :ash_commanded_dump_capture

  defp capture_ast(module_name, ast) do
    if Application.get_env(:ash_commanded, :capture_ast?, false) do
      try do
        :ets.insert(@capture_table, {module_name, ast})
      rescue
        ArgumentError -> :ok
      end
    end

    :ok
  end
end
