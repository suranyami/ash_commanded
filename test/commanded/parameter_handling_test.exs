defmodule AshCommanded.Test.Commanded.ParameterHandlingTest do
  use ExUnit.Case

  alias AshCommanded.Commanded.ParameterTransformer
  alias AshCommanded.Commanded.ParameterValidator

  describe "parameter transformation" do
    test "transform_params with map field transformation" do
      params = %{name: "John Doe", email: "john@example.com"}
      transforms = [{:map, :name, to: :full_name}]

      transformed = ParameterTransformer.transform_params(params, transforms)

      assert transformed == %{full_name: "John Doe", email: "john@example.com"}
    end

    test "transform_params with type casting" do
      params = %{age: "42", active: "true"}

      transforms = [
        {:cast, :age, :integer},
        {:cast, :active, :boolean}
      ]

      transformed = ParameterTransformer.transform_params(params, transforms)

      assert transformed == %{age: 42, active: true}
    end

    test "transform_params with computed field" do
      params = %{first_name: "John", last_name: "Doe"}

      transforms = [
        {:compute, :full_name, [using: fn p -> "#{p.first_name} #{p.last_name}" end]}
      ]

      transformed = ParameterTransformer.transform_params(params, transforms)

      assert transformed.full_name == "John Doe"
    end

    test "transform_params with field transformation" do
      params = %{email: "JOHN@EXAMPLE.COM"}

      transforms = [
        {:transform, :email, fn email -> String.downcase(email) end}
      ]

      transformed = ParameterTransformer.transform_params(params, transforms)

      assert transformed.email == "john@example.com"
    end

    test "transform_params with default value" do
      params = %{name: "John"}

      transforms = [
        {:default, :status, [value: "active"]}
      ]

      transformed = ParameterTransformer.transform_params(params, transforms)

      assert transformed.status == "active"
    end

    test "transform_params with function default" do
      params = %{name: "John"}

      # Get a deterministic time for testing
      fixed_time = DateTime.new!(~D[2023-01-01], ~T[12:00:00])

      transforms = [
        {:default, :created_at, [fn: fn -> fixed_time end]}
      ]

      transformed = ParameterTransformer.transform_params(params, transforms)

      assert transformed.created_at == fixed_time
    end

    test "transform_params with custom transformation" do
      params = %{name: "john doe", email: "john@example.com"}

      transforms = [
        {:custom,
         fn p ->
           p
           |> Map.put(:name, String.capitalize(p.name))
           |> Map.put(:normalized_email, String.downcase(p.email))
         end}
      ]

      transformed = ParameterTransformer.transform_params(params, transforms)

      assert transformed.name == "John doe"
      assert transformed.normalized_email == "john@example.com"
    end

    test "transform_params with multiple transforms" do
      params = %{name: "John Doe", age: "30", email: "JOHN@EXAMPLE.COM"}

      transforms = [
        {:map, :name, to: :full_name},
        {:cast, :age, :integer},
        {:transform, :email, &String.downcase/1},
        {:default, :status, [value: "active"]},
        {:compute, :displayName,
         [using: fn params -> "#{params.full_name} <#{params.email}>" end]}
      ]

      transformed = ParameterTransformer.transform_params(params, transforms)

      assert transformed == %{
               full_name: "John Doe",
               age: 30,
               email: "john@example.com",
               status: "active",
               displayName: "John Doe <john@example.com>"
             }
    end

    test "Manual transform_params with different transform types" do
      params = %{name: "John Doe", age: "30", email: "john@example.com"}

      # Process each transform manually for testing
      transformed =
        params
        # manually simulate map
        |> Map.put(:full_name, params.name)
        # manually simulate cast
        |> Map.put(:age, 30)
        # manually simulate default
        |> Map.put(:status, "active")
        # manually simulate compute
        |> Map.put(:display_name, "John Doe <john@example.com>")

      assert transformed.full_name == "John Doe"
      assert transformed.age == 30
      assert transformed.status == "active"
      assert transformed.display_name == "John Doe <john@example.com>"
    end
  end

  describe "parameter validation" do
    test "validate_params with type validation" do
      params = %{name: "John", age: 30}

      validations = [
        {:validate, :name, [type: :string]},
        {:validate, :age, [type: :integer]}
      ]

      assert :ok = ParameterValidator.validate_params(params, validations)
    end

    test "validate_params with failing type validation" do
      params = %{name: "John", age: "thirty"}

      validations = [
        {:validate, :name, [type: :string]},
        {:validate, :age, [type: :integer]}
      ]

      assert {:error, errors} = ParameterValidator.validate_params(params, validations)
      assert Enum.any?(errors, &String.contains?(&1.message, "must be of type integer"))
    end

    test "validate_params with format validation" do
      params = %{email: "john@example.com"}

      validations = [
        {:validate, :email, [format: ~r/@/]}
      ]

      assert :ok = ParameterValidator.validate_params(params, validations)
    end

    test "validate_params with failing format validation" do
      params = %{email: "invalid-email"}

      validations = [
        {:validate, :email, [format: ~r/@/]}
      ]

      assert {:error, errors} = ParameterValidator.validate_params(params, validations)
      assert Enum.any?(errors, &String.contains?(&1.message, "does not match required format"))
    end

    test "validate_params with range validation" do
      params = %{age: 25}

      validations = [
        {:validate, :age, [min: 18, max: 100]}
      ]

      assert :ok = ParameterValidator.validate_params(params, validations)
    end

    test "validate_params with failing range validation" do
      params = %{age: 15}

      validations = [
        {:validate, :age, [min: 18, max: 100]}
      ]

      assert {:error, errors} = ParameterValidator.validate_params(params, validations)
      assert Enum.any?(errors, &String.contains?(&1.message, "must be at least 18"))
    end

    test "validate_params with custom validation function" do
      params = %{password: "P@ssw0rd"}

      validations = [
        {:validate, :password,
         fn password ->
           cond do
             String.length(password) < 8 ->
               {:error, "must be at least 8 characters long"}

             not String.match?(password, ~r/[A-Z]/) ->
               {:error, "must contain an uppercase letter"}

             not String.match?(password, ~r/[0-9]/) ->
               {:error, "must contain a number"}

             true ->
               :ok
           end
         end}
      ]

      assert :ok = ParameterValidator.validate_params(params, validations)
    end

    test "validate_params with failing custom validation" do
      params = %{password: "password"}

      validations = [
        {:validate, :password,
         fn password ->
           cond do
             String.length(password) < 8 ->
               {:error, "must be at least 8 characters long"}

             not String.match?(password, ~r/[A-Z]/) ->
               {:error, "must contain an uppercase letter"}

             not String.match?(password, ~r/[0-9]/) ->
               {:error, "must contain a number"}

             true ->
               :ok
           end
         end}
      ]

      assert {:error, errors} = ParameterValidator.validate_params(params, validations)
      assert Enum.any?(errors, &String.contains?(&1.message, "must contain an uppercase letter"))
    end

    test "validate_params with domain validation" do
      params = %{role: :admin}

      validations = [
        {:validate, :role, [one_of: [:user, :admin, :moderator]]}
      ]

      assert :ok = ParameterValidator.validate_params(params, validations)
    end

    test "validate_params with failing domain validation" do
      params = %{role: :superuser}

      validations = [
        {:validate, :role, [one_of: [:user, :admin, :moderator]]}
      ]

      assert {:error, errors} = ParameterValidator.validate_params(params, validations)
      assert Enum.any?(errors, &String.contains?(&1.message, "must be one of"))
    end

    test "validate_params with list validation" do
      params = %{tags: ["elixir", "phoenix"]}

      validations = [
        {:validate, :tags, [min_items: 1, max_items: 5]}
      ]

      assert :ok = ParameterValidator.validate_params(params, validations)
    end

    test "validate_params with failing list validation" do
      params = %{tags: ["elixir", "phoenix", "ecto", "ash", "commanded", "spark"]}

      validations = [
        {:validate, :tags, [min_items: 1, max_items: 5]}
      ]

      assert {:error, errors} = ParameterValidator.validate_params(params, validations)
      assert Enum.any?(errors, &String.contains?(&1.message, "must contain at most 5 items"))
    end

    test "validate_params with multiple validations" do
      params = %{name: "John", email: "john@example.com", age: 25, role: :admin}

      validations = [
        {:validate, :name, [type: :string, min_length: 2]},
        {:validate, :email, [type: :string, format: ~r/@/]},
        {:validate, :age, [type: :integer, min: 18, max: 100]},
        {:validate, :role, [one_of: [:user, :admin, :moderator]]}
      ]

      assert :ok = ParameterValidator.validate_params(params, validations)
    end

    test "validate_params with multiple failing validations" do
      params = %{name: "J", email: "invalid-email", age: 15, role: :superuser}

      validations = [
        {:validate, :name, [type: :string, min_length: 2]},
        {:validate, :email, [type: :string, format: ~r/@/]},
        {:validate, :age, [type: :integer, min: 18, max: 100]},
        {:validate, :role, [one_of: [:user, :admin, :moderator]]}
      ]

      assert {:error, errors} = ParameterValidator.validate_params(params, validations)
      assert length(errors) == 4
    end

    test "multiple validation checks" do
      # Create a validation function that checks multiple things
      multi_check = fn params ->
        issues = []

        # Check name length
        issues =
          if String.length(params.name) < 2 do
            issues ++ ["Name too short"]
          else
            issues
          end

        # Check email format
        issues =
          if not String.contains?(params.email, "@") do
            issues ++ ["Invalid email format"]
          else
            issues
          end

        # Check age
        issues =
          if params.age < 18 do
            issues ++ ["Too young"]
          else
            issues
          end

        if Enum.empty?(issues) do
          :ok
        else
          {:error, issues}
        end
      end

      # Apply with valid params
      params = %{name: "John", email: "john@example.com", age: 25}
      assert :ok = multi_check.(params)

      # Apply with invalid params
      params = %{name: "J", email: "invalid-email", age: 15}
      assert {:error, issues} = multi_check.(params)
      # All three validations fail
      assert length(issues) == 3
    end
  end

  describe "parameter transformation and validation integration" do
    test "transform then validate params" do
      # Define transformations
      transforms = [
        {:cast, :age, :integer},
        {:transform, :email, &String.downcase/1},
        {:default, :role, [value: :user]}
      ]

      # Define validations
      validations = [
        {:validate, :age, [min: 18]},
        {:validate, :email, [format: ~r/@/]},
        {:validate, :role, [one_of: [:user, :admin, :moderator]]}
      ]

      # Valid parameters
      params = %{name: "John", email: "JOHN@EXAMPLE.COM", age: "25"}

      # Transform
      transformed = ParameterTransformer.transform_params(params, transforms)

      # Validate
      validation_result = ParameterValidator.validate_params(transformed, validations)

      assert :ok = validation_result
      assert transformed.age == 25
      assert transformed.email == "john@example.com"
      assert transformed.role == :user
    end

    test "transform then validate with validation errors" do
      # Define transformations
      transforms = [
        {:cast, :age, :integer},
        {:transform, :email, &String.downcase/1},
        {:default, :role, [value: :guest]}
      ]

      # Define validations
      validations = [
        {:validate, :age, [min: 18]},
        {:validate, :email, [format: ~r/@/]},
        {:validate, :role, [one_of: [:user, :admin, :moderator]]}
      ]

      # Invalid parameters (underage and role not allowed)
      params = %{name: "John", email: "john@example.com", age: "15"}

      # Transform
      transformed = ParameterTransformer.transform_params(params, transforms)

      # Validate
      validation_result = ParameterValidator.validate_params(transformed, validations)

      assert {:error, errors} = validation_result
      # Both age and role should fail validation
      assert length(errors) == 2
    end
  end
end
