defmodule AshCommanded.Commanded.Middleware.BaseMiddleware do
  @moduledoc """
  Base module for implementing command middleware in AshCommanded.

  This module provides default implementations and helper functions
  for common middleware patterns. By using this module, you can implement
  only the callbacks you need while inheriting sensible defaults.

  ## Examples

  ```elixir
  defmodule MyApp.LoggingMiddleware do
    use AshCommanded.Commanded.Middleware.BaseMiddleware
    
    @impl true
    def before_dispatch(command, context, next) do
      # Log command being dispatched
      IO.inspect(command, label: "Dispatching command")
      next.(command, context)
    end
    
    @impl true
    def after_dispatch({:ok, result} = success, command, _context) do
      # Log successful execution
      IO.inspect(result, label: "Command succeeded")
      success
    end
    
    def after_dispatch({:error, reason} = error, command, _context) do
      # Log failed execution
      IO.inspect(reason, label: "Command failed")
      error
    end
  end
  ```

  ## Default Implementations

  By default, this module:
  - Passes the command and context unchanged to the next middleware
  - Returns the result from the command handler unchanged
  """

  alias AshCommanded.Commanded.Middleware.CommandMiddleware

  @doc """
  Using this module will implement the CommandMiddleware behavior.
  """
  defmacro __using__(_opts) do
    quote do
      @behaviour CommandMiddleware

      @impl CommandMiddleware
      def before_dispatch(command, context, next) do
        next.(command, context)
      end

      @impl CommandMiddleware
      def after_dispatch(result, _command, _context) do
        result
      end

      defoverridable before_dispatch: 3, after_dispatch: 3
    end
  end

  @doc """
  Helper to apply a list of middleware to a command.

  ## Parameters

  * `middleware` - List of middleware modules to apply
  * `command` - The command to process
  * `context` - The context for the command
  * `final_handler` - Function to call after all middleware has been applied

  ## Examples

  ```elixir
  apply_middleware(
    [LoggingMiddleware, ValidationMiddleware],
    %MyCommand{},
    %{},
    fn cmd, ctx -> {:ok, dispatch_command(cmd)} end
  )
  ```
  """
  @spec apply_middleware(
          middleware :: [module()],
          command :: struct(),
          context :: map(),
          final_handler :: (struct(), map() -> {:ok, any()} | {:error, any()})
        ) :: {:ok, any()} | {:error, any()}
  def apply_middleware(middleware, command, context, final_handler) do
    # Define the middleware chain, starting with the final handler
    middleware_chain =
      Enum.reduce(Enum.reverse(middleware), final_handler, fn middleware_module,
                                                              next_middleware ->
        fn cmd, ctx ->
          middleware_module.before_dispatch(cmd, ctx, next_middleware)
        end
      end)

    # Start the middleware chain
    result = middleware_chain.(command, context)

    # Apply after_dispatch callbacks in reverse order
    Enum.reduce(middleware, result, fn middleware_module, acc_result ->
      middleware_module.after_dispatch(acc_result, command, context)
    end)
  end
end
