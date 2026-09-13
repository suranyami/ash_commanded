defmodule AshCommanded.TestSupport.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource AshCommanded.TestSupport.Widget
  end
end
