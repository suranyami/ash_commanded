defmodule AshCommanded.Commanded.CommandActionMapperTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias AshCommanded.Commanded.CommandActionMapper
  alias AshCommanded.TestSupport.Widget

  # A plain command struct — map_to_action only needs field access via Map.from_struct/1,
  # not a DSL-generated command module, so a lightweight local struct is enough to drive it.
  defmodule TestCommand do
    @moduledoc false
    defstruct [:id, :name]
  end

  # Mirrors the real generated destroy_widget command shape (fields([:id]) only,
  # per test/support/widget.ex) — destroy actions accept no other input.
  defmodule DestroyCommand do
    @moduledoc false
    defstruct [:id]
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

  describe "map_to_action/4 against a real Ash resource" do
    # Not-found case first, per plan: a regression reintroducing an action-not-found
    # error must be distinguishable from an ordinary missing-record error.
    test "update against a non-existent id returns an error, not a raise" do
      missing_id = Ash.UUID.generate()
      command = %TestCommand{id: missing_id, name: "Anything"}

      assert {:error, error} =
               CommandActionMapper.map_to_action(command, Widget, :update,
                 action_type: :update,
                 identity_field: :id
               )

      refute is_struct(error, Ash.Error.Invalid.NoSuchAction)
      refute error |> inspect() |> String.contains?("NoSuchAction")
    end

    test "destroy against a non-existent id returns an error, not a raise" do
      missing_id = Ash.UUID.generate()
      command = %DestroyCommand{id: missing_id}

      assert {:error, error} =
               CommandActionMapper.map_to_action(command, Widget, :destroy,
                 action_type: :destroy,
                 identity_field: :id
               )

      refute is_struct(error, Ash.Error.Invalid.NoSuchAction)
      refute error |> inspect() |> String.contains?("NoSuchAction")
    end

    test "create persists a real Ash record, readable back through Ash.get!" do
      id = Ash.UUID.generate()
      command = %TestCommand{id: id, name: "Widget One"}

      assert {:ok, _result} =
               CommandActionMapper.map_to_action(command, Widget, :create, action_type: :create)

      assert Ash.get!(Widget, id).name == "Widget One"
    end

    test "update persists the new name on an existing record" do
      id = Ash.UUID.generate()

      {:ok, _} =
        CommandActionMapper.map_to_action(%TestCommand{id: id, name: "Original"}, Widget, :create,
          action_type: :create
        )

      update_command = %TestCommand{id: id, name: "Updated"}

      assert {:ok, _result} =
               CommandActionMapper.map_to_action(update_command, Widget, :update,
                 action_type: :update,
                 identity_field: :id
               )

      assert Ash.get!(Widget, id).name == "Updated"
    end

    test "destroy removes the record, so Ash.get afterwards returns a not-found error" do
      id = Ash.UUID.generate()

      {:ok, _} =
        CommandActionMapper.map_to_action(%TestCommand{id: id, name: "Temp"}, Widget, :create,
          action_type: :create
        )

      destroy_command = %DestroyCommand{id: id}

      assert {:ok, _result} =
               CommandActionMapper.map_to_action(destroy_command, Widget, :destroy,
                 action_type: :destroy,
                 identity_field: :id
               )

      assert {:error, %Ash.Error.Invalid{}} = Ash.get(Widget, id)
    end
  end
end
