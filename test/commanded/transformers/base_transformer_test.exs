defmodule AshCommanded.Commanded.Transformers.BaseTransformerTest do
  use ExUnit.Case, async: true

  alias AshCommanded.Commanded.Transformers.BaseTransformer

  describe "get_module_prefix/1" do
    test "extracts module prefix correctly" do
      assert BaseTransformer.get_module_prefix(MyApp.Accounts.User) == MyApp.Accounts
      assert BaseTransformer.get_module_prefix(SingleModule) == SingleModule
      assert BaseTransformer.get_module_prefix(A.B.C.D.Resource) == A.B.C.D
    end
  end

  describe "get_resource_name/1" do
    test "extracts resource name correctly" do
      assert BaseTransformer.get_resource_name(MyApp.Accounts.User) == "User"
      assert BaseTransformer.get_resource_name(SingleModule) == "SingleModule"
      assert BaseTransformer.get_resource_name(A.B.C.D.Resource) == "Resource"
    end
  end

  describe "camelize_atom/1" do
    test "converts atom to camelcase string" do
      assert BaseTransformer.camelize_atom(:register_user) == "RegisterUser"
      assert BaseTransformer.camelize_atom(:update_email) == "UpdateEmail"
      assert BaseTransformer.camelize_atom(:single_word) == "SingleWord"
      assert BaseTransformer.camelize_atom(:already_camel_case) == "AlreadyCamelCase"
    end
  end

  describe "create_module/3" do
    test "creates a module with the given AST" do
      module_name = Module.concat(["AshCommanded", "Test", "GeneratedModule"])

      ast =
        quote do
          @moduledoc "A test module"
          def test_function, do: :it_works
        end

      assert BaseTransformer.create_module(module_name, ast, __ENV__) == :ok
      assert Code.ensure_loaded?(module_name)
      assert module_name.test_function() == :it_works
    end
  end
end
