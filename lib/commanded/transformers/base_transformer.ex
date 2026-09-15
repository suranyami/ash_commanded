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

  ## Examples

      iex> create_module(MyApp.Commands.RegisterUser, quoted_ast, __ENV__)
      :ok
  """
  @spec create_module(module(), Macro.t(), Macro.Env.t()) :: :ok
  def create_module(module_name, ast, env) do
    capture_ast(module_name, ast)
    Module.create(module_name, ast, Macro.Env.location(env))
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
