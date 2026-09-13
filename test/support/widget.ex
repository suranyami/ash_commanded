defmodule AshCommanded.TestSupport.Widget do
  @moduledoc false
  use Ash.Resource,
    domain: AshCommanded.TestSupport.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshCommanded.Commanded.Dsl]

  ets do
    private? true
  end

  commanded do
    commands do
      command :create_widget do
        fields([:id, :name])
        identity_field(:id)
        action :create
        event :widget_created
      end
    end

    events do
      event :widget_created do
        fields([:id, :name])
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: [:id, :name], update: [:name]]
  end

  attributes do
    # `uuid_primary_key/1` hides every option but `:name` and defaults `writable?` to
    # false, so it cannot accept a client-supplied id (needed here: the aggregate's
    # identity comes from the dispatched command, not from Ash). Declare it explicitly
    # instead, writable, so `create: [:id, :name]` below can actually accept it.
    attribute :id, :uuid do
      primary_key? true
      allow_nil? false
      writable? true
      public? true
      default &Ash.UUID.generate/0
    end

    attribute :name, :string, public?: true
  end
end
