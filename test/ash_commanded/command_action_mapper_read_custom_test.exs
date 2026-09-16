defmodule AshCommanded.CommandActionMapperReadCustomTest do
  # Plan 01-04 removed the last two Mix.env() == :test branches from
  # CommandActionMapper (the read and custom paths). Neither path had ever
  # actually executed before this plan — proven here rather than assumed,
  # against the real Ash fixtures, exactly as Plan 01-02 proved create/update/
  # destroy in command_action_mapper_test.exs.
  @moduledoc false
  use ExUnit.Case, async: true

  alias AshCommanded.CommandActionMapper
  alias AshCommanded.TestSupport.CustomActionWidget
  alias AshCommanded.TestSupport.Widget

  defmodule CreateCommand do
    @moduledoc false
    defstruct [:id, :name]
  end

  defmodule ReadCommand do
    @moduledoc false
    defstruct [:id]
  end

  defmodule RenameCommand do
    @moduledoc false
    defstruct [:new_name]
  end

  describe "execute_read/4 against a real Ash resource" do
    test "returns the real persisted record, not the parameters it was handed" do
      id = Ash.UUID.generate()

      {:ok, _} =
        CommandActionMapper.map_to_action(
          %CreateCommand{id: id, name: "Readable"},
          Widget,
          :create,
          action_type: :create
        )

      assert {:ok, record} =
               CommandActionMapper.map_to_action(%ReadCommand{id: id}, Widget, :read,
                 action_type: :read,
                 identity_field: :id
               )

      # The old mock returned %{action: action_name, identity: ..., context: ...}.
      # A real Ash record has neither :action nor :identity keys, and it carries
      # the persisted :name — proof this came from Ash, not an echo.
      assert record.id == id
      assert record.name == "Readable"
      refute Map.has_key?(record, :action)
      refute Map.has_key?(record, :identity)
    end

    test "returns a not-found error for a record that was never created" do
      missing_id = Ash.UUID.generate()

      assert {:error, error} =
               CommandActionMapper.map_to_action(%ReadCommand{id: missing_id}, Widget, :read,
                 action_type: :read,
                 identity_field: :id
               )

      assert error.message == "Record not found"
    end
  end

  describe "execute_custom/4 against a real Ash resource" do
    test "invokes the resource's declared generic action through Ash.run_action" do
      assert {:ok, "renamed to Widget Two"} =
               CommandActionMapper.map_to_action(
                 %RenameCommand{new_name: "Widget Two"},
                 CustomActionWidget,
                 :rename_widget,
                 action_type: :custom
               )
    end
  end
end
