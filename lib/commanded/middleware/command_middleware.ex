defmodule AshCommanded.Commanded.Middleware.CommandMiddleware do
  @moduledoc """
  Protocol defining the behavior for command middleware in AshCommanded.

  Command middleware allow you to intercept, modify, or enhance commands
  before they're processed. This is useful for cross-cutting concerns like:

  - Validation
  - Logging
  - Authorization
  - Rate limiting
  - Auditing
  - Parameter transformation
  - Error handling

  Middleware is applied in the order it's defined, with each middleware able to:
  1. Modify the command
  2. Pass it to the next middleware
  3. Short-circuit the chain by returning an error

  ## Implementing Middleware

  To create custom middleware, implement this protocol:

  ```elixir
  defmodule MyApp.MyMiddleware do
    @behaviour AshCommanded.Commanded.Middleware.CommandMiddleware
    
    @impl true
    def before_dispatch(%{} = command, context, next) do
      # Modify command or context here
      modified_command = update_in(command.metadata, &Map.put(&1, :traced, true))
      modified_context = Map.put(context, :middleware_timestamp, DateTime.utc_now())
      
      # Call the next middleware in the chain
      next.(modified_command, modified_context)
    end
    
    @impl true
    def after_dispatch({:ok, result} = success, _command, _context) do
      # Handle successful result
      success
    end
    
    def after_dispatch({:error, _reason} = error, _command, _context) do
      # Handle errors
      error
    end
  end
  ```

  ## Using Middleware

  Middleware can be specified globally for all commands, per resource, or per command:

  ```elixir
  # Global middleware in application config
  config :ash_commanded, :global_middleware, [
    MyApp.LoggingMiddleware,
    MyApp.AuditingMiddleware
  ]

  # Resource-level middleware
  defmodule MyApp.User do
    use Ash.Resource,
      extensions: [AshCommanded.Commanded.Dsl]
      
    commanded do
      middleware [
        MyApp.AuthorizationMiddleware,
        MyApp.ValidationMiddleware
      ]
      
      commands do
        # Command-specific middleware
        command :register_user do
          fields [:id, :email, :name]
          middleware [MyApp.RegistrationMiddleware]
        end
      end
    end
  end
  ```
  """

  @doc """
  Called before a command is dispatched.

  ## Parameters

  * `command` - The command to be dispatched
  * `context` - The context for this command dispatch
  * `next` - Function to call the next middleware in the chain

  ## Returns

  The result of the last middleware or command handler in the chain.
  """
  @callback before_dispatch(command :: struct(), context :: map(), next :: function()) ::
              {:ok, any()} | {:error, any()}

  @doc """
  Called after a command is dispatched.

  ## Parameters

  * `result` - The result of the command handler
  * `command` - The original command that was dispatched
  * `context` - The context for this command dispatch

  ## Returns

  The potentially modified result.
  """
  @callback after_dispatch(result :: any(), command :: struct(), context :: map()) ::
              {:ok, any()} | {:error, any()}
end
