defmodule AshCommanded.Commanded.Middleware.CommandMiddlewareProcessor do
  @moduledoc """
  Processes command middleware for AshCommanded.

  This module is responsible for:
  1. Collecting middleware from configuration, resources, and commands
  2. Building the middleware chain
  3. Applying middleware to commands

  It's used internally by command handlers to ensure consistent
  middleware application across the system.
  """

  alias AshCommanded.Commanded.Middleware.BaseMiddleware

  @doc """
  Apply all applicable middleware to a command.

  ## Parameters

  * `command` - The command to process
  * `resource` - The resource the command belongs to
  * `context` - The context for the command dispatch
  * `final_handler` - Function to call after all middleware has been applied

  ## Examples

  ```elixir
  apply_middleware(
    %MyApp.Commands.RegisterUser{},
    MyApp.User,
    %{},
    fn cmd, ctx -> {:ok, process_command(cmd)} end
  )
  ```
  """
  @spec apply_middleware(
          command :: struct(),
          resource :: module(),
          context :: map(),
          final_handler :: (struct(), map() -> {:ok, any()} | {:error, any()})
        ) :: {:ok, any()} | {:error, any()}
  def apply_middleware(command, resource, context, final_handler) do
    # Get middleware for this command
    middleware = get_middleware_chain(command, resource)

    # Apply the middleware chain
    BaseMiddleware.apply_middleware(middleware, command, context, final_handler)
  end

  @doc """
  Get the complete middleware chain for a command.

  This collects middleware from:
  1. Global application config
  2. Resource-level middleware
  3. Command-specific middleware

  ## Parameters

  * `command` - The command struct
  * `resource` - The resource module

  ## Returns

  A list of middleware modules with their configuration.
  """
  @spec get_middleware_chain(struct(), module()) :: [module()]
  def get_middleware_chain(command, resource) do
    # Get global middleware from application config
    global_middleware = get_global_middleware()

    # Get resource middleware
    resource_middleware = get_resource_middleware(resource)

    # Get command middleware
    command_middleware = get_command_middleware(command)

    # Combine all middleware, with proper precedence
    middleware_with_config =
      (global_middleware ++ resource_middleware ++ command_middleware)
      |> Enum.map(&normalize_middleware/1)

    # Extract just the modules
    Enum.map(middleware_with_config, fn {module, _config} -> module end)
  end

  # Get global middleware from application config
  defp get_global_middleware do
    Application.get_env(:ash_commanded, :global_middleware, [])
  end

  # Get middleware defined at the resource level
  defp get_resource_middleware(resource) do
    if is_atom(resource) && !is_nil(resource) &&
         function_exported?(Spark.Dsl.Extension, :get_opt, 3) do
      try do
        Spark.Dsl.Extension.get_opt(resource, [:commanded, :commands], :middleware, [])
      rescue
        # Safely handle the case when resource is not a Spark DSL module
        _ -> []
      end
    else
      []
    end
  end

  # Get middleware defined at the command level
  defp get_command_middleware(command) do
    command_module = command.__struct__

    # Check if this is an AshCommanded command with middleware
    if is_map(command) && Map.has_key?(command, :middleware) do
      command.middleware
    else
      # Try to get middleware from the command module if available
      if function_exported?(command_module, :middleware, 0) do
        command_module.middleware()
      else
        []
      end
    end
  end

  # Normalize middleware to a {module, config} tuple
  defp normalize_middleware(middleware) do
    case middleware do
      {module, config} when is_atom(module) and is_map(config) ->
        {module, config}

      {module, config} when is_atom(module) ->
        {module, %{options: config}}

      module when is_atom(module) ->
        {module, %{}}

      other ->
        raise ArgumentError, "Invalid middleware specification: #{inspect(other)}"
    end
  end
end
