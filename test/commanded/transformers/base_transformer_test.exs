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

    test "does not capture AST into ETS when :capture_ast? is unset (D-06)" do
      table = :ash_commanded_dump_capture
      :ets.new(table, [:named_table, :public, :set])
      on_exit(fn -> safe_delete_table(table) end)

      module_name = Module.concat(["AshCommanded", "Test", "NoCaptureModule"])

      ast =
        quote do
          def value, do: :no_capture
        end

      assert BaseTransformer.create_module(module_name, ast, __ENV__) == :ok
      assert :ets.lookup(table, module_name) == []
    end

    test "captures the module name and AST into the named ETS table when :capture_ast? is true (D-06)" do
      table = :ash_commanded_dump_capture
      :ets.new(table, [:named_table, :public, :set])
      Application.put_env(:ash_commanded, :capture_ast?, true)

      on_exit(fn ->
        Application.delete_env(:ash_commanded, :capture_ast?)
        safe_delete_table(table)
      end)

      module_name = Module.concat(["AshCommanded", "Test", "CapturedModule"])

      ast =
        quote do
          def value, do: :captured
        end

      assert BaseTransformer.create_module(module_name, ast, __ENV__) == :ok
      assert [{^module_name, captured_ast}] = :ets.lookup(table, module_name)
      assert captured_ast == ast
    end

    test "capturing with the flag true does not crash when the named ETS table is missing (T-01-BI-02)" do
      safe_delete_table(:ash_commanded_dump_capture)
      Application.put_env(:ash_commanded, :capture_ast?, true)
      on_exit(fn -> Application.delete_env(:ash_commanded, :capture_ast?) end)

      module_name = Module.concat(["AshCommanded", "Test", "MissingTableModule"])

      ast =
        quote do
          def value, do: :missing_table
        end

      assert BaseTransformer.create_module(module_name, ast, __ENV__) == :ok
      assert module_name.value() == :missing_table
    end

    test "create_module/4 with an explicit location sets the module's own compile source (FOUND-18)" do
      module_name = Module.concat(["AshCommanded", "Test", "ExplicitLocationModule"])

      ast =
        quote do
          def value, do: :explicit_location
        end

      location = [file: "test/support/parity/parity_widget.ex", line: 12]

      assert BaseTransformer.create_module(module_name, ast, __ENV__, location) == :ok

      source = module_name.__info__(:compile) |> Keyword.fetch!(:source) |> to_string()
      # The compiler resolves a relative :file to an absolute path, so assert the supplied
      # location is what was named rather than requiring byte-identical strings.
      assert String.ends_with?(source, location[:file])
      refute source == __ENV__.file
    end

    test "create_module/3 keeps falling back to Macro.Env.location(env) unchanged (FOUND-18)" do
      module_name = Module.concat(["AshCommanded", "Test", "FallbackLocationModule"])

      ast =
        quote do
          def value, do: :fallback_location
        end

      assert BaseTransformer.create_module(module_name, ast, __ENV__) == :ok

      assert module_name.__info__(:compile) |> Keyword.fetch!(:source) |> to_string() ==
               __ENV__.file
    end

    test "a compile error in the generated AST names the supplied location, not the transformer's own file (FOUND-18)" do
      module_name = Module.concat(["AshCommanded", "Test", "CompileErrorModule"])

      ast =
        quote do
          def broken(^undefined_pin_variable), do: :ok
        end

      location = [file: "fake/dsl_declaration.ex", line: 3]

      error =
        assert_raise CompileError, fn ->
          BaseTransformer.create_module(module_name, ast, __ENV__, location)
        end

      assert to_string(error.file) == location[:file]
    end
  end

  defp safe_delete_table(table) do
    :ets.delete(table)
  rescue
    ArgumentError -> :ok
  end
end
