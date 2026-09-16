defmodule AshCommanded.ParameterTransformerErrorsTest do
  use ExUnit.Case, async: true

  alias AshCommanded.ParameterTransformer
  alias AshCommanded.TestSupport.Widget

  describe "Parameter transformer error handling" do
    test "safely handles errors in map transforms" do
      # Create a transform that will cause an error
      transform = {:map, nil, :name}
      params = %{name: "Test"}

      # Process params through transforms - this should safely handle the error
      result = ParameterTransformer.transform_params(params, [transform])

      # Map should still contain the original data
      assert result.name == "Test"
    end

    test "safely handles errors in cast transforms" do
      # Create a cast transform with invalid value
      transform = {:cast, :age, :integer}
      params = %{age: "not-a-number"}

      # Process params through transforms
      result = ParameterTransformer.transform_params(params, [transform])

      # Age should remain unchanged
      assert result.age == "not-a-number"
    end

    test "safely handles errors in compute transforms" do
      # Create a compute transform that will raise an error
      bad_compute_fn = fn _params -> raise "Computation error" end
      transform = {:compute, :computed_value, bad_compute_fn}
      params = %{name: "Test"}

      # Process params through transforms
      result = ParameterTransformer.transform_params(params, [transform])

      # Original params should remain unchanged
      assert result.name == "Test"
      # Computed field should not be added
      refute Map.has_key?(result, :computed_value)
    end

    test "safely handles errors in transform transforms" do
      # Create a transform that will raise an error
      bad_transform_fn = fn _value -> raise "Transform error" end
      transform = {:transform, :name, bad_transform_fn}
      params = %{name: "Test"}

      # Process params through transforms
      result = ParameterTransformer.transform_params(params, [transform])

      # Name should remain unchanged
      assert result.name == "Test"
    end

    test "continues processing after encountering an error" do
      # Create multiple transforms where one will fail
      transforms = [
        # This should succeed
        {:map, :name, :full_name},
        # This should fail
        {:transform, :age, fn _ -> raise "Error" end},
        # This should still be processed
        {:default, :status, "active"}
      ]

      params = %{name: "Test", age: 30}

      # Process params through transforms
      result = ParameterTransformer.transform_params(params, transforms)

      # Check that successful transforms were applied
      assert result.full_name == "Test"
      assert result.status == "active"
      # Original value should remain for failed transform
      assert result.age == 30
    end
  end

  describe "Command action mapper with parameter transformer" do
    # Scoped to Widget's own fields plus :age, an attribute Widget's create
    # action does not accept — the vehicle for proving the negative assertion
    # below.
    defmodule TransformerTestCommand do
      @moduledoc false
      defstruct [:id, :name, :age]
    end

    test "a cast that fails to convert leaves the real action to reject the command, writing nothing" do
      id = Ash.UUID.generate()
      command = %TransformerTestCommand{id: id, name: "Test", age: "thirty"}

      # Create transforms where one will fail
      transforms = [
        # This should succeed
        {:cast, :id, :string},
        # ParameterTransformer.transform_params/2 is deliberately safe: a
        # failed cast leaves the original value in place rather than raising
        # or returning an error tuple (see the "safely handles..." tests
        # above). That means :age survives, unchanged, as "thirty" — a value
        # Widget's create action does not accept at all. The real Ash action
        # is what actually rejects the command now; the mock this test used
        # to hit always returned {:ok, _} regardless, so this negative path
        # could never be observed before.
        {:cast, :age, :integer},
        {:default, :status, "active"}
      ]

      # Try to map the command to a real Ash action
      result =
        AshCommanded.CommandActionMapper.map_to_action(
          command,
          Widget,
          :create,
          transforms: transforms
        )

      assert {:error, _error} = result

      # The whole point of this test: prove no record was written, by reading
      # back through Ash.get and expecting not-found.
      assert {:error, %Ash.Error.Invalid{}} = Ash.get(Widget, id)
    end
  end
end
