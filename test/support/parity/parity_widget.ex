defmodule AshCommanded.TestSupport.Parity.Widget do
  @moduledoc """
  A domain-neutral, dependency-free `Ash.Resource` used only to prove SC2 (D-19): that
  `AshCommanded.Resource.Dsl`'s generated modules are identical under `MIX_ENV=dev` and
  `MIX_ENV=test`. See `AshCommanded.TestSupport.Parity.Domain`'s moduledoc and
  `scripts/compile_parity.sh`.

  Deliberately has no data layer (defaults to `Ash.DataLayer.Simple`, per
  `Ash.Resource`'s own default) — this resource exists to be *compiled*, not written to, and a
  real data layer is one more thing that could differ between environments.
  """
  use Ash.Resource,
    domain: AshCommanded.TestSupport.Parity.Domain,
    extensions: [AshCommanded.Resource.Dsl]

  commanded do
    commands do
      command :create_widget do
        fields([:id, :label])
        identity_field(:id)
        action :create
        event :widget_created
      end
    end

    events do
      event :widget_created do
        fields([:id, :label])
      end
    end

    projections do
      projection :widget_created do
        action :create
        changes(%{})
      end
    end

    event_handlers do
      handler :notifier do
        events([:widget_created])
        action :create
      end
    end
  end

  actions do
    defaults [:read, create: [:id, :label]]
  end

  attributes do
    # `uuid_primary_key/1` hides every option but `:name` and defaults `writable?` to false, so
    # it cannot accept a client-supplied id — declare it explicitly instead, writable, so
    # `create: [:id, :label]` above can actually accept it (mirrors
    # `test/support/widget.ex`'s identical need).
    attribute :id, :uuid do
      primary_key? true
      allow_nil? false
      writable? true
      public? true
      default &Ash.UUID.generate/0
    end

    attribute :label, :string, public?: true
  end
end
