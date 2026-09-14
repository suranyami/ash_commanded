defmodule AshCommanded.TestSupport.ContextDomain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource AshCommanded.TestSupport.ContextWidget
  end
end

defmodule AshCommanded.TestSupport.ContextWidget do
  # A minimal, dependency-free ETS-backed Ash resource whose sole purpose is to
  # make the :context option CommandActionMapper.map_to_action/4 sets on the
  # real Ash changeset (via Ash.Changeset.set_context/2) observable from
  # outside — CommandActionMapper's public API returns only {:ok, record} or
  # {:error, _}, so context can only be proven to have "really landed" via a
  # change that copies it onto a persisted attribute.
  #
  # Not part of test/support/widget.ex because other plans in this wave also
  # read that fixture, and it has no such change attached; adding one there
  # would be an unrelated change to a shared fixture.
  @moduledoc false

  use Ash.Resource,
    domain: AshCommanded.TestSupport.ContextDomain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private? true
  end

  actions do
    defaults [:read, :destroy, update: [:name]]

    create :create do
      accept [:id, :name]

      change fn changeset, _context ->
        captured = inspect(changeset.context)
        Ash.Changeset.force_change_attribute(changeset, :context_probe, captured)
      end
    end
  end

  attributes do
    attribute :id, :uuid do
      primary_key? true
      allow_nil? false
      writable? true
      public? true
      default &Ash.UUID.generate/0
    end

    attribute :name, :string, public?: true
    attribute :context_probe, :string, public?: true
  end
end
