defmodule AshCommanded.Test.Commanded.Middleware.CommandMiddlewareTest do
  use ExUnit.Case
  require Logger

  alias AshCommanded.Commanded.Middleware.CommandMiddlewareProcessor
  alias AshCommanded.Commanded.Middleware.LoggingMiddleware
  alias AshCommanded.Commanded.Middleware.ValidationMiddleware

  # Create mock command modules for testing
  defmodule MockCommands.RegisterUser do
    defstruct [:id, :name, :email, :age, :middleware]
  end

  defmodule MockCommands.UpdateUser do
    defstruct [:id, :name, :email, :age, :middleware]
  end

  # Create test setup
  setup do
    # Suppress log output during tests
    Logger.configure(level: :none)

    # Set up middleware configurations
    register_middleware = [
      LoggingMiddleware,
      {ValidationMiddleware, required: [:name, :email]}
    ]

    update_middleware = [
      LoggingMiddleware,
      {ValidationMiddleware, format: [email: ~r/@/]}
    ]

    {:ok, register_middleware: register_middleware, update_middleware: update_middleware}
  end

  describe "middleware collection" do
    test "collects middleware from command", %{register_middleware: middleware} do
      # Create a command with middleware attached
      command = %MockCommands.RegisterUser{
        id: "test-id",
        name: "Test User",
        email: "test@example.com",
        age: 30,
        middleware: middleware
      }

      # Get middleware chain
      middleware_chain = CommandMiddlewareProcessor.get_middleware_chain(command, nil)

      # Should have both LoggingMiddleware and ValidationMiddleware
      assert Enum.count(middleware_chain) == 2
      assert LoggingMiddleware in middleware_chain
      assert ValidationMiddleware in middleware_chain
    end
  end

  describe "command validation" do
    test "passes valid command through middleware", %{register_middleware: middleware} do
      # Create a valid register_user command
      command = %MockCommands.RegisterUser{
        id: "test-id",
        name: "Test User",
        email: "test@example.com",
        age: 30,
        middleware: middleware
      }

      # Apply middleware with a final handler that returns success
      result =
        CommandMiddlewareProcessor.apply_middleware(
          command,
          nil,
          %{middleware_config: %{required: [:name, :email]}},
          fn _cmd, _ctx -> {:ok, :command_processed} end
        )

      # Middleware should allow the command to be processed
      assert result == {:ok, :command_processed}
    end

    test "rejects command with missing required fields", %{register_middleware: middleware} do
      # Create an invalid register_user command missing email
      command = %MockCommands.RegisterUser{
        id: "test-id",
        name: "Test User",
        # Missing email
        age: 30,
        middleware: middleware
      }

      # Apply middleware
      result =
        CommandMiddlewareProcessor.apply_middleware(
          command,
          nil,
          %{middleware_config: %{required: [:name, :email]}},
          fn _cmd, _ctx -> {:ok, :command_processed} end
        )

      # Middleware should reject the command
      assert {:error, {:validation_error, reason}} = result
      assert String.contains?(reason, "Missing required fields")
    end

    test "validates email format in update_user command", %{update_middleware: middleware} do
      # Create an update_user command with invalid email format
      command = %MockCommands.UpdateUser{
        id: "test-id",
        name: "Test User",
        # No @ symbol
        email: "invalid-email",
        age: 30,
        middleware: middleware
      }

      # Apply middleware
      result =
        CommandMiddlewareProcessor.apply_middleware(
          command,
          nil,
          %{middleware_config: %{format: [email: ~r/@/]}},
          fn _cmd, _ctx -> {:ok, :command_processed} end
        )

      # Middleware should reject the command
      assert {:error, {:validation_error, reason}} = result
      assert String.contains?(reason, "Invalid field formats")
    end

    test "applies custom validation function" do
      # Define middleware with custom validation
      middleware = [
        {ValidationMiddleware, validate: &validate_age/1}
      ]

      # Create an update_user command with age < 18
      command = %MockCommands.UpdateUser{
        id: "test-id",
        name: "Test User",
        email: "test@example.com",
        # Underage
        age: 17,
        middleware: middleware
      }

      # Apply middleware
      result =
        CommandMiddlewareProcessor.apply_middleware(
          command,
          nil,
          %{middleware_config: %{validate: &validate_age/1}},
          fn _cmd, _ctx -> {:ok, :command_processed} end
        )

      # Middleware should reject the command
      assert {:error, {:validation_error, "User must be at least 18 years old"}} = result
    end
  end

  # Custom validation function
  defp validate_age(command) do
    if command.age && command.age < 18 do
      {:error, "User must be at least 18 years old"}
    else
      :ok
    end
  end
end
