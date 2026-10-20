defmodule AshCommanded.ParameterTransformerAtomCastTest do
  use ExUnit.Case, async: true

  alias AshCommanded.ParameterTransformer

  # Declared as a literal atom so it is guaranteed to exist before the test
  # runs, independently of which atoms happen to be loaded by other tests.
  @known_atom :ash_commanded_atom_cast_known_value

  # The dynamic suffix guarantees the atom is absent from the atom table on
  # every run. A literal could be created by some other test mentioning it
  # first, which would silently turn the negative assertions into no-ops.
  defp unknown_binary do
    "ash_commanded_atom_cast_unknown_#{System.unique_integer([:positive, :monotonic])}"
  end

  # `String.to_existing_atom/1` only resolves atoms that are already in the
  # atom table; it never creates one. If the atom is absent it raises
  # ArgumentError. This is the assertion that separates "rejected the value"
  # from "created the atom and then rejected the value".
  defp assert_unknown_to_runtime(binary) do
    assert_raise ArgumentError, fn -> String.to_existing_atom(binary) end
  end

  describe "cast_value/2 for the :atom type" do
    test "rejects a binary whose atom the runtime has never seen and creates no atom" do
      binary = unknown_binary()

      assert {:error, message} = ParameterTransformer.cast_value(binary, :atom)
      assert is_binary(message)

      assert_unknown_to_runtime(binary)
    end

    test "the rejection message does not echo the rejected binary" do
      binary = unknown_binary()

      assert {:error, message} = ParameterTransformer.cast_value(binary, :atom)

      refute String.contains?(message, binary)
    end

    test "accepts a binary whose atom already exists" do
      existing_binary = Atom.to_string(@known_atom)

      assert {:ok, @known_atom} = ParameterTransformer.cast_value(existing_binary, :atom)
    end

    test "passes an atom through unchanged" do
      assert {:ok, :already_an_atom} = ParameterTransformer.cast_value(:already_an_atom, :atom)
    end
  end

  describe "transform_params/2 with a {:cast, field, :atom} specification" do
    test "leaves an unrecognised binary in place and creates no atom" do
      binary = unknown_binary()

      result = ParameterTransformer.transform_params(%{role: binary}, [{:cast, :role, :atom}])

      assert result.role == binary
      assert_unknown_to_runtime(binary)
    end

    test "still converts the string form of an existing atom" do
      existing_binary = Atom.to_string(@known_atom)

      result =
        ParameterTransformer.transform_params(%{role: existing_binary}, [{:cast, :role, :atom}])

      assert result.role == @known_atom
    end
  end
end
