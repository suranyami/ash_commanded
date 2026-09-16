defmodule AshCommanded.TestSupport.Parity.Domain do
  @moduledoc """
  A domain-neutral `Ash.Domain` used only to prove SC2 (D-19): that
  `AshCommanded.Resource.Dsl`'s generated modules are identical under `MIX_ENV=dev` and
  `MIX_ENV=test`.

  This file, and `parity_widget.ex` beside it, are the ONLY resources in this repository that
  compile under `MIX_ENV=dev` (via `mix.exs`'s `elixirc_paths(:dev)`) — every other fixture lives
  under `test/support`, which is `:test`-only. They must reference nothing outside `:ash`,
  `:spark`, `:commanded` and this library's own `lib/` — no test framework, no test-only mocking
  library, no other `test/support` module — or `mix compile` (plain, no `MIX_ENV`) breaks for
  every contributor. See `scripts/compile_parity.sh` for the actual cross-environment check.
  """
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource AshCommanded.TestSupport.Parity.Widget
  end
end
