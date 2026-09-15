defmodule AshCommanded.GoldenRenderTest do
  @moduledoc """
  Proves every committed golden under `test/golden/` still matches a fresh render, byte for
  byte (FOUND-04). Uses the identical rendering pipeline `mix ash_commanded.dump --write`
  itself uses (`Mix.Tasks.AshCommanded.Dump.render_module_for_test/2`), so this test and the
  mix task cannot silently disagree about what "the fresh render" is.

  Tagged `:canonical_version_only` (D-12): the render comes from `Macro.to_string/1` +
  `Code.format_string!/1`, both formatter- and version-sensitive, so a golden generated on one
  Elixir minor can legitimately differ on another with no change to our generator at all. See
  `test/test_helper.exs` for the exclusion this tag drives on any non-canonical minor, and
  `test/ash_commanded/golden_budget_test.exs` for the size gates that stay unconditional
  instead.

  One test is generated per discovered golden file, matching `golden_budget_test.exs`'s
  pattern: a `test/golden/**/*.golden` glob that finds nothing here generates zero tests,
  which is itself the failure signal that this gate compared nothing.
  """

  use ExUnit.Case, async: false

  @moduletag :canonical_version_only

  # Maps a golden's fixture directory (`test/golden/<fixture_dir>/...`) back to the resource
  # module whose `commanded do ... end` block generated it. Grows only if a new fixture
  # directory is introduced — today there is exactly one, `test/support/parity/parity_widget.ex`.
  @fixture_targets %{
    "parity_widget" => AshCommanded.TestSupport.Parity.Widget
  }

  golden_files =
    [File.cwd!(), "test", "golden", "**", "*.golden"]
    |> Path.join()
    |> Path.wildcard()
    |> Enum.sort()

  for golden_path <- golden_files do
    @golden_path golden_path
    relative_path = Path.relative_to_cwd(golden_path)

    test "matches a fresh render for #{relative_path}" do
      AshCommanded.GoldenRenderTest.assert_matches_fresh_render!(@golden_path)
    end
  end

  @doc false
  def assert_matches_fresh_render!(golden_path) do
    fixture_dir = golden_path |> Path.dirname() |> Path.basename()

    target =
      Map.get(@fixture_targets, fixture_dir) ||
        flunk(
          "#{golden_path}: no fixture target registered for fixture dir #{fixture_dir} " <>
            "in AshCommanded.GoldenRenderTest.@fixture_targets"
        )

    module_name =
      golden_path
      |> Path.basename(".golden")
      |> then(&Module.concat([&1]))

    {_header_lines, committed_body} =
      golden_path |> File.read!() |> AshCommanded.Dump.Golden.split_header()

    fresh_body = Mix.Tasks.AshCommanded.Dump.render_module_for_test(target, module_name)

    assert fresh_body == committed_body, """
    #{golden_path}: fresh render no longer matches the committed golden.
    #{diff_text(committed_body, fresh_body)}
    """
  end

  defp diff_text(old_body, new_body) do
    old_lines = String.split(old_body, "\n")
    new_lines = String.split(new_body, "\n")

    List.myers_difference(old_lines, new_lines)
    |> Enum.flat_map(fn
      {:eq, _} -> []
      {:del, lines} -> Enum.map(lines, &"- #{&1}")
      {:ins, lines} -> Enum.map(lines, &"+ #{&1}")
    end)
    |> Enum.join("\n")
  end
end
