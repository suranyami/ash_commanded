# The Elixir minor series this repository's own toolchain runs, and the version every
# committed golden under test/golden/ is generated on. test/ash_commanded/golden_render_test.exs
# tags its text-diff comparison :canonical_version_only, excluded below on any other minor,
# because the render comes from Macro.to_string/1 + Code.format_string!/1 — both formatter-
# and version-sensitive, and can legitimately differ between Elixir minors with no change to
# our generator at all (D-12). This resolves the collision between FOUND-04 (goldens diffed in
# CI) and FOUND-16 (a three-version CI matrix). The size gates in
# test/ash_commanded/golden_budget_test.exs stay unconditional, because they count sizes rather
# than compare text, so they keep running on every matrix leg.
canonical_elixir_version = "1.18"

exclude_tags =
  if String.starts_with?(System.version(), canonical_elixir_version) do
    []
  else
    [:canonical_version_only]
  end

ExUnit.configure(exclude: exclude_tags)
ExUnit.start()
