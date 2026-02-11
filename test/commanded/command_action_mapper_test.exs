defmodule AshCommanded.Commanded.CommandActionMapperTest do
  use ExUnit.Case

  alias AshCommanded.Commanded.CommandActionMapper

  # Define a sample command for testing
  defmodule TestCommand do
    defstruct [:id, :name, :email, :status, :metadata]
  end

  describe "infer_action_type/1" do
    test "infers create actions" do
      assert CommandActionMapper.infer_action_type(:create) == :create
      assert CommandActionMapper.infer_action_type(:create_user) == :create
      assert CommandActionMapper.infer_action_type(:create_new_account) == :create
    end

    test "infers update actions" do
      assert CommandActionMapper.infer_action_type(:update) == :update
      assert CommandActionMapper.infer_action_type(:update_email) == :update
      assert CommandActionMapper.infer_action_type(:update_user_profile) == :update
    end

    test "infers destroy actions" do
      assert CommandActionMapper.infer_action_type(:destroy) == :destroy
      assert CommandActionMapper.infer_action_type(:destroy_account) == :destroy
      assert CommandActionMapper.infer_action_type(:delete) == :destroy
      assert CommandActionMapper.infer_action_type(:delete_user) == :destroy
    end

    test "infers read actions" do
      assert CommandActionMapper.infer_action_type(:read) == :read
      assert CommandActionMapper.infer_action_type(:read_user) == :read
      assert CommandActionMapper.infer_action_type(:get) == :read
      assert CommandActionMapper.infer_action_type(:get_account) == :read
    end

    test "defaults to custom for other actions" do
      assert CommandActionMapper.infer_action_type(:activate) == :custom
      assert CommandActionMapper.infer_action_type(:send_notification) == :custom
      assert CommandActionMapper.infer_action_type(:process_payment) == :custom
    end
  end

  describe "map_to_action/4 with transform_params" do
    setup do
      command = %TestCommand{
        id: "123",
        name: "Test User",
        email: "test@example.com",
        status: :active,
        metadata: %{role: "admin"}
      }

      {:ok, command: command}
    end

    test "transforms params with default mapping", %{command: command} do
      # Mock resource module for testing
      resource_module = __MODULE__

      # Call the function directly
      result =
        CommandActionMapper.map_to_action(command, resource_module, :create,
          context: %{test: true}
        )

      # In our test helper, the result contains the params and action info
      assert {:ok, result_data} = result
      assert result_data.action == :create
      assert result_data.params.id == "123"
      assert result_data.params.name == "Test User"
      assert result_data.params.email == "test@example.com"
      assert result_data.params.status == :active
      assert result_data.params.metadata == %{role: "admin"}
      assert result_data.context == %{test: true}
    end

    test "transforms params with map param_mapping", %{command: command} do
      # Mock resource module for testing
      resource_module = __MODULE__

      # Define param mapping
      param_mapping = %{
        name: :full_name,
        email: :contact_email
      }

      # Call the function directly
      result =
        CommandActionMapper.map_to_action(command, resource_module, :create,
          param_mapping: param_mapping
        )

      # In our test helper, the result contains the params and action info
      assert {:ok, result_data} = result
      assert result_data.action == :create
      assert result_data.params.id == "123"
      assert result_data.params.full_name == "Test User"
      assert result_data.params.contact_email == "test@example.com"
      assert result_data.params.status == :active
      assert result_data.params.metadata == %{role: "admin"}
      refute Map.has_key?(result_data.params, :name)
      refute Map.has_key?(result_data.params, :email)
    end

    test "transforms params with function param_mapping", %{command: command} do
      # Mock resource module for testing
      resource_module = __MODULE__

      # Define param mapping function
      param_mapping = fn params ->
        params
        |> Map.put(:full_name, params.name)
        |> Map.put(:contact_email, params.email)
        |> Map.delete(:name)
        |> Map.delete(:email)
        |> Map.put(:created_at, "2023-01-01")
      end

      # Call the function directly
      result =
        CommandActionMapper.map_to_action(command, resource_module, :create,
          param_mapping: param_mapping
        )

      # In our test helper, the result contains the params and action info
      assert {:ok, result_data} = result
      assert result_data.action == :create
      assert result_data.params.id == "123"
      assert result_data.params.full_name == "Test User"
      assert result_data.params.contact_email == "test@example.com"
      assert result_data.params.status == :active
      assert result_data.params.metadata == %{role: "admin"}
      assert result_data.params.created_at == "2023-01-01"
      refute Map.has_key?(result_data.params, :name)
      refute Map.has_key?(result_data.params, :email)
    end
  end
end
