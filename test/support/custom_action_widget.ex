defmodule AshCommanded.TestSupport.CustomActionDomain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource AshCommanded.TestSupport.CustomActionWidget
  end
end

defmodule AshCommanded.TestSupport.CustomActionWidget do
  # A minimal, dependency-free ETS-backed Ash resource carrying a generic
  # (non-CRUD) action, used solely to prove CommandActionMapper.execute_custom/4
  # really dispatches through Ash.ActionInput/Ash.run_action/1 against a real
  # Ash resource — a path that previously always returned a Mix.env() == :test
  # mock and had never actually executed.
  #
  # Ash.ActionInput.for_action/3 needs a resolvable domain (unlike
  # Ash.Changeset.for_action/3, `domain: nil` isn't enough for generic-action
  # dispatch), so this resource gets its own tiny domain rather than sharing
  # test/support/test_domain.ex.
  #
  # Not part of test/support/widget.ex because other plans in this wave also
  # read that fixture; this file exists purely to give the custom-action path
  # something real to dispatch against.
  @moduledoc false

  use Ash.Resource,
    domain: AshCommanded.TestSupport.CustomActionDomain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private? true
  end

  actions do
    defaults [:read, :destroy, create: [:id, :name], update: [:name]]

    action :rename_widget, :string do
      argument :new_name, :string, allow_nil?: false

      run fn input, _context ->
        {:ok, "renamed to #{input.arguments.new_name}"}
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
  end
end
