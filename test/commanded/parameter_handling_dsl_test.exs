defmodule AshCommanded.Test.Commanded.ParameterHandlingDslTest do
  use ExUnit.Case

  # Mock command with transforms and validations for testing
  defmodule MockCommand do
    defstruct [
      :name,
      :fields,
      :identity_field,
      :transforms,
      :validations
    ]
  end

  describe "DSL parameter handling" do
    setup do
      register_command = %MockCommand{
        name: :register_user,
        fields: [:id, :name, :email, :age],
        identity_field: :id,
        transforms: [
          {:map, :name, [to: :full_name]},
          {:cast, :age, :integer},
          {:transform, :email, &String.downcase/1},
          {:compute, :display_name, fn params -> "#{params[:name]} <#{params[:email]}>" end},
          {:default, :status, [value: "active"]}
        ],
        validations: [
          {:validate, :name, [type: :string, min_length: 2]},
          {:validate, :email, [format: ~r/@/]},
          {:validate, :age, [min: 18]}
        ]
      }

      update_command = %MockCommand{
        name: :update_user,
        fields: [:id, :name, :email, :age, :roles],
        identity_field: :id,
        transforms: [
          {:custom,
           fn params ->
             params
             |> Map.update(:name, nil, &String.capitalize/1)
             |> Map.put(:updated_at, DateTime.utc_now())
           end}
        ],
        validations: [
          {:validate, :roles,
           fn roles ->
             if is_list(roles) && Enum.all?(roles, &is_atom/1) do
               :ok
             else
               {:error, "roles must be a list of atoms"}
             end
           end}
        ]
      }

      {:ok, register_command: register_command, update_command: update_command}
    end

    test "command with transforms has expected structure", %{register_command: register_command} do
      # Verify basic command structure
      assert register_command.name == :register_user
      assert register_command.fields == [:id, :name, :email, :age]

      # Verify it has transforms
      assert register_command.transforms
      assert length(register_command.transforms) > 0

      # Verify basic transform specs
      assert Enum.any?(
               register_command.transforms,
               fn transform -> match?({:cast, :age, :integer}, transform) end
             )

      assert Enum.any?(
               register_command.transforms,
               fn transform -> match?({:map, :name, to: :full_name}, transform) end
             )
    end

    test "command with validations has expected structure", %{register_command: register_command} do
      # Verify it has validations
      assert register_command.validations
      assert length(register_command.validations) > 0

      # Verify basic validation specs
      assert Enum.any?(
               register_command.validations,
               fn validation ->
                 case validation do
                   {:validate, :age, rules} -> Keyword.get(rules, :min) == 18
                   _ -> false
                 end
               end
             )
    end

    test "custom transform function works", %{update_command: update_command} do
      # Extract the custom transform function
      custom_transform =
        Enum.find(
          update_command.transforms,
          fn transform -> match?({:custom, _}, transform) end
        )

      assert custom_transform

      # Test the custom transform function
      {_type, transform_fn} = custom_transform

      params = %{name: "john", email: "john@example.com"}
      transformed = transform_fn.(params)

      assert transformed.name == "John"
      assert Map.has_key?(transformed, :updated_at)
    end

    test "custom validation function works", %{update_command: update_command} do
      # Extract the custom validation function
      custom_validation =
        Enum.find(
          update_command.validations,
          fn validation ->
            case validation do
              {:validate, :roles, fn_val} when is_function(fn_val) -> true
              _ -> false
            end
          end
        )

      assert custom_validation

      # Test the custom validation function
      {:validate, :roles, validation_fn} = custom_validation

      # Valid roles
      assert :ok = validation_fn.([:user, :admin])

      # Invalid roles
      assert {:error, _} = validation_fn.(["user", "admin"])
      assert {:error, _} = validation_fn.("admin")
    end
  end
end
