defmodule AshCommanded.Commanded.Middleware.LoggingMiddleware do
  @moduledoc """
  Middleware that logs command dispatch and results.

  This middleware logs information about commands being dispatched
  and their results. It's useful for debugging and auditing.

  ## Configuration

  The logging level can be configured with the `:level` option:

  ```elixir
  middleware AshCommanded.Commanded.Middleware.LoggingMiddleware, level: :debug
  ```

  Available levels: `:debug`, `:info`, `:warn`, `:error`

  ## Log Format

  The middleware logs the following information:

  * Before dispatch: Command type, command ID, and fields
  * After successful dispatch: Command type, command ID, and result
  * After failed dispatch: Command type, command ID, and error reason
  """

  use AshCommanded.Commanded.Middleware.BaseMiddleware
  require Logger

  @impl true
  def before_dispatch(command, context, next) do
    # Extract configuration from context or use defaults
    config = Map.get(context, :middleware_config, %{})
    level = Map.get(config, :level, :info)

    # Extract command information
    command_type = command.__struct__ |> Module.split() |> List.last()
    command_id = extract_command_id(command)

    # Log the command being dispatched
    log(
      level,
      "[AshCommanded.Command] Dispatching #{command_type}#{command_id_str(command_id)} #{inspect(command)}"
    )

    # Call the next middleware
    next.(command, context)
  end

  @impl true
  def after_dispatch({:ok, result} = success, command, context) do
    # Extract configuration from context or use defaults
    config = Map.get(context, :middleware_config, %{})
    level = Map.get(config, :level, :info)

    # Extract command information
    command_type = command.__struct__ |> Module.split() |> List.last()
    command_id = extract_command_id(command)

    # Log the successful result
    log(
      level,
      "[AshCommanded.Command] #{command_type}#{command_id_str(command_id)} succeeded with result: #{inspect(result)}"
    )

    success
  end

  def after_dispatch({:error, reason} = error, command, context) do
    # Extract configuration from context or use defaults
    config = Map.get(context, :middleware_config, %{})
    level = Map.get(config, :error_level, :error)

    # Extract command information
    command_type = command.__struct__ |> Module.split() |> List.last()
    command_id = extract_command_id(command)

    # Log the error
    log(
      level,
      "[AshCommanded.Command] #{command_type}#{command_id_str(command_id)} failed with reason: #{inspect(reason)}"
    )

    error
  end

  # Helper to extract command ID if available
  defp extract_command_id(command) do
    cond do
      Map.has_key?(command, :id) -> Map.get(command, :id)
      Map.has_key?(command, :uuid) -> Map.get(command, :uuid)
      Map.has_key?(command, :command_id) -> Map.get(command, :command_id)
      true -> nil
    end
  end

  # Helper to format command ID string
  defp command_id_str(nil), do: ""
  defp command_id_str(id), do: " [#{id}]"

  # Helper to log at appropriate level
  defp log(:debug, message), do: Logger.debug(message)
  defp log(:info, message), do: Logger.info(message)
  defp log(:warn, message), do: Logger.warning(message)
  defp log(:error, message), do: Logger.error(message)
end
