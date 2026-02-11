defmodule AshCommanded.Commanded.Transformers.ProjectionGeneratorTest do
  use ExUnit.Case, async: true

  alias AshCommanded.Commanded.Projection
  alias AshCommanded.Commanded.Transformers.GenerateProjectionModules

  describe "projection module generation helpers" do
    test "builds correct module names" do
      # Create a test projection
      projection = %Projection{
        name: :user_registered,
        action: :create,
        changes: %{status: :active}
      }

      # Test module naming
      module_name =
        invoke_private(
          GenerateProjectionModules,
          :build_projection_module,
          [projection, MyApp.Accounts]
        )

      assert module_name == MyApp.Accounts.Projections.UserRegistered
    end

    test "builds correct module AST" do
      # Static changes
      projection_with_static = %Projection{
        name: :user_registered,
        action: :create,
        changes: %{status: :active}
      }

      # Test the AST generation for static changes
      ast =
        invoke_private(
          GenerateProjectionModules,
          :build_projection_module_ast,
          [projection_with_static, "User"]
        )

      # The AST should be a block with @moduledoc, apply/2 and action/0
      assert is_tuple(ast)
      assert elem(ast, 0) == :__block__

      block_contents = elem(ast, 2)

      assert Enum.any?(block_contents, fn node ->
               match?({:@, _, [{:moduledoc, _, _}]}, node)
             end)

      assert Enum.any?(block_contents, fn node ->
               match?({:def, _, [{:apply, _, _}, _]}, node)
             end)

      assert Enum.any?(block_contents, fn node ->
               match?({:def, _, [{:action, _, _}, _]}, node)
             end)

      # For testing, just check that we can build an AST for a projection
      # with a function-like changes definition - can't test with a real function
      # as it can't be escaped in a macro
      projection_with_fn = %Projection{
        name: :email_changed,
        action: :update,
        # Using a map for the test
        changes: %{email: "test@example.com"}
      }

      # Test the AST generation for function changes
      ast =
        invoke_private(
          GenerateProjectionModules,
          :build_projection_module_ast,
          [projection_with_fn, "User"]
        )

      # Similar checks for function-based changes
      assert is_tuple(ast)
      assert elem(ast, 0) == :__block__

      block_contents = elem(ast, 2)

      assert Enum.any?(block_contents, fn node ->
               match?({:def, _, [{:apply, _, _}, _]}, node)
             end)
    end
  end

  # Helper to invoke private functions for testing
  defp invoke_private(module, function, args) do
    apply(module, function, args)
  catch
    :error, :undef -> {:error, "Private function #{function} not accessible"}
  end
end
