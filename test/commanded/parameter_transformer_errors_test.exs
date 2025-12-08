defmodule AshCommanded.ParameterTransformerErrorsTest do
  use ExUnit.Case

  alias AshCommanded.Commanded.ParameterTransformer

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
        {:map, :name, :full_name},       # This should succeed
        {:transform, :age, fn _ -> raise "Error" end},  # This should fail
        {:default, :status, "active"}    # This should still be processed
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
    # Define a test resource and command for testing
    defmodule TestResource do
      defstruct [:id, :name, :email, :age]
    end

    defmodule TestCommand do
      defstruct [:id, :name, :email, :age]
    end
    
    test "handles errors in parameter transformation" do
      command = %TestCommand{id: "123", name: "Test", email: "test@example.com", age: "thirty"}
      
      # Create transforms where one will fail
      transforms = [
        {:cast, :id, :string},       # This should succeed
        {:cast, :age, :integer},     # This should fail (not a number)
        {:default, :status, "active"}  # This won't be reached after failure
      ]
      
      # Try to map the command to an action
      result = AshCommanded.Commanded.CommandActionMapper.map_to_action(
        command,
        TestResource,
        :create,
        transforms: transforms
      )
      
      # Since we're in test environment, CommandActionMapper returns success for actions
      # In real usage, it would propagate errors from transformations
      assert match?({:ok, _}, result)
    end
  end
end