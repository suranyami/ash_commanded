defmodule AshCommanded.DisablePhaseCitationTest do
  @moduledoc """
  Enforces D-01/D-02: every `# credo:disable-for-this-file` suppression in `lib/`, and every
  `# gsd-staged-until-phase:` staged-golden marker under `test/golden/`, must cite a roadmap
  phase that both EXISTS in `.planning/ROADMAP.md` (appears as a `### Phase N:` heading) and is
  NOT already marked `Complete` in the Progress table's Status column.

  This is the mechanism that makes D-01's staging idiom honest. The pattern has already
  decayed once: before this plan, the fifteen disables already present in `lib/` all cited
  phase numbers from the archived thirteen-phase roadmap, which no longer exists — nothing
  detected that, because there was no structured, machine-parseable citation at all, only free
  prose. This test walks the real tree and fails loudly the moment a citation drifts again.

  One shared pair of functions (`extract_disable_violations/3` /
  `extract_staged_violations/3`) does the actual walking and validation for both `lib/`'s
  disables and `test/golden/`'s staged markers, both driven by the one roadmap parse
  (`parse_roadmap!/1`) — so the two suppression idioms cannot drift apart in how they are
  checked.
  """

  use ExUnit.Case, async: true

  @root File.cwd!()
  @roadmap_path Path.join(@root, ".planning/ROADMAP.md")

  @disable_regex ~r/^\s*#\s*credo:disable-for-this-file\b/
  @citation_regex ~r/^\s*#\s*gsd-disable-until-phase:\s*(\d+)/
  @staged_regex ~r/^\s*#\s*gsd-staged-until-phase:\s*(\d+)/
  @phase_heading_regex ~r/^###\s*Phase\s+(\d+):/
  @progress_row_regex ~r/^\|\s*(\d+)\.[^|]*\|[^|]*\|\s*([^|]+?)\s*\|/

  # How many lines after the last disable line in a consecutive group a structured citation
  # may appear on — matches the plan's own "within the following three lines" wording.
  @citation_window 3

  describe "the real repository (lib/ disables and test/golden/ staged markers)" do
    test "every credo:disable-for-this-file citation in lib/ names a live, incomplete roadmap phase" do
      {existing_phases, statuses} = parse_roadmap!(@roadmap_path)
      violations = extract_disable_violations(lib_files(), existing_phases, statuses)

      assert violations == [], format_violations(violations)
    end

    test "every staged golden marker in test/golden/ names a live, incomplete roadmap phase" do
      {existing_phases, statuses} = parse_roadmap!(@roadmap_path)
      violations = extract_staged_violations(golden_files(), existing_phases, statuses)

      assert violations == [], format_violations(violations)
    end

    test "the disable walk finds at least one disable to validate (a control that checks nothing is not a control)" do
      count =
        lib_files()
        |> Enum.map(&File.read!/1)
        |> Enum.flat_map(&disable_line_numbers/1)
        |> length()

      assert count > 0
    end

    test "the staged-golden walk finds at least one marker to validate" do
      count =
        golden_files()
        |> Enum.map(&File.read!/1)
        |> Enum.flat_map(&staged_line_numbers/1)
        |> length()

      assert count > 0
    end
  end

  describe "citation validation rules, exercised against synthetic fixtures so real-tree drift can't hide a broken rule" do
    test "a disable citing a phase absent from the roadmap fails, naming the file and the cited number" do
      existing_phases = MapSet.new([1, 2, 3])
      statuses = %{1 => "In Progress", 2 => "Not started", 3 => "Not started"}

      content = """
      # credo:disable-for-this-file Credo.Check.Refactor.Nesting
      # gsd-disable-until-phase: 99 — nothing owns phase 99
      defmodule Sample do
      end
      """

      [violation] =
        extract_disable_violations(
          [{"sample_absent_phase.ex", content}],
          existing_phases,
          statuses
        )

      assert violation.file == "sample_absent_phase.ex"
      assert violation.detail =~ "99"
    end

    test "a disable citing a phase already marked Complete fails, naming the file and the cited number" do
      existing_phases = MapSet.new([1, 2, 3])
      statuses = %{1 => "Complete", 2 => "Not started", 3 => "Not started"}

      content = """
      # credo:disable-for-this-file Credo.Check.Refactor.Nesting
      # gsd-disable-until-phase: 1 — phase 1 is already done
      defmodule Sample do
      end
      """

      [violation] =
        extract_disable_violations(
          [{"sample_complete_phase.ex", content}],
          existing_phases,
          statuses
        )

      assert violation.file == "sample_complete_phase.ex"
      assert violation.detail =~ "1"
    end

    test "a credo:disable-for-this-file line with no structured citation within 3 lines fails, naming the file" do
      existing_phases = MapSet.new([1])
      statuses = %{1 => "In Progress"}

      content = """
      # credo:disable-for-this-file Credo.Check.Refactor.Nesting
      #
      # Just prose, no structured gsd-disable-until-phase citation anywhere nearby.
      #
      defmodule Sample do
      end
      """

      [violation] =
        extract_disable_violations(
          [{"sample_no_citation.ex", content}],
          existing_phases,
          statuses
        )

      assert violation.file == "sample_no_citation.ex"
      assert violation.reason == :missing_citation
    end

    test "a disable citing a live, incomplete phase within the window passes with no violation" do
      existing_phases = MapSet.new([1, 2])
      statuses = %{1 => "In Progress", 2 => "Not started"}

      content = """
      # credo:disable-for-this-file Credo.Check.Refactor.Nesting
      # gsd-disable-until-phase: 2 — phase 2 owns this rewrite
      defmodule Sample do
      end
      """

      assert extract_disable_violations([{"sample_ok.ex", content}], existing_phases, statuses) ==
               []
    end

    test "a staged golden marker obeys the same absent/Complete phase rules as a disable citation" do
      existing_phases = MapSet.new([1, 2])
      statuses = %{1 => "Complete", 2 => "Not started"}

      absent =
        "# gsd-budget: clause_max=6 module_lines=48\n# gsd-staged-until-phase: 99\ndefmodule Sample do\nend\n"

      complete =
        "# gsd-budget: clause_max=6 module_lines=48\n# gsd-staged-until-phase: 1\ndefmodule Sample do\nend\n"

      ok =
        "# gsd-budget: clause_max=6 module_lines=48\n# gsd-staged-until-phase: 2\ndefmodule Sample do\nend\n"

      violations =
        extract_staged_violations(
          [
            {"absent.golden", absent},
            {"complete.golden", complete},
            {"ok.golden", ok}
          ],
          existing_phases,
          statuses
        )

      assert Enum.map(violations, & &1.file) |> Enum.sort() == [
               "absent.golden",
               "complete.golden"
             ]
    end
  end

  # -- Roadmap parsing (shared source of truth for both walks) -----------------------------

  @doc false
  def parse_roadmap!(path) do
    lines = path |> File.read!() |> String.split("\n")

    existing_phases =
      lines
      |> Enum.flat_map(fn line ->
        case Regex.run(@phase_heading_regex, line) do
          [_, n] -> [String.to_integer(n)]
          nil -> []
        end
      end)
      |> MapSet.new()

    statuses =
      lines
      |> Enum.flat_map(fn line ->
        case Regex.run(@progress_row_regex, line) do
          [_, n, status] -> [{String.to_integer(n), String.trim(status)}]
          nil -> []
        end
      end)
      |> Map.new()

    {existing_phases, statuses}
  end

  # -- Shared file discovery -----------------------------------------------------------------

  defp lib_files do
    [@root, "lib", "**", "*.ex"] |> Path.join() |> Path.wildcard() |> Enum.sort()
  end

  defp golden_files do
    [@root, "test", "golden", "**", "*.golden"] |> Path.join() |> Path.wildcard() |> Enum.sort()
  end

  defp disable_line_numbers(content) do
    content
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.filter(fn {line, _n} -> Regex.match?(@disable_regex, line) end)
    |> Enum.map(&elem(&1, 1))
  end

  defp staged_line_numbers(content) do
    content
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.filter(fn {line, _n} -> Regex.match?(@staged_regex, line) end)
    |> Enum.map(&elem(&1, 1))
  end

  # -- The shared walk + validate pair --------------------------------------------------------

  # Accepts either a real file path (String) or a {label, content} tuple, so synthetic
  # fixtures and real files share the exact same validation code path.
  defp extract_disable_violations(sources, existing_phases, statuses) do
    Enum.flat_map(sources, fn source ->
      {label, content} = read_source(source)
      violations_for_disables(label, content, existing_phases, statuses)
    end)
  end

  defp extract_staged_violations(sources, existing_phases, statuses) do
    Enum.flat_map(sources, fn source ->
      {label, content} = read_source(source)
      violations_for_staged(label, content, existing_phases, statuses)
    end)
  end

  defp read_source({label, content}), do: {label, content}

  defp read_source(path) when is_binary(path),
    do: {Path.relative_to(path, @root), File.read!(path)}

  defp violations_for_disables(label, content, existing_phases, statuses) do
    lines = content |> String.split("\n") |> List.to_tuple()

    content
    |> disable_line_numbers()
    |> group_consecutive()
    |> Enum.flat_map(&group_violation(label, &1, lines, existing_phases, statuses))
  end

  defp group_violation(label, group, lines, existing_phases, statuses) do
    last_idx = List.last(group)

    case find_citation_phase(lines, last_idx) do
      nil -> [missing_citation_violation(label, last_idx)]
      phase -> phase_violation(label, last_idx, phase, existing_phases, statuses)
    end
  end

  defp find_citation_phase(lines, last_idx) do
    line_count = tuple_size(lines)

    Enum.find_value(1..@citation_window, fn offset ->
      citation_phase_at(lines, line_count, last_idx + offset)
    end)
  end

  defp citation_phase_at(_lines, line_count, n) when n < 1 or n > line_count, do: nil

  defp citation_phase_at(lines, _line_count, n) do
    case Regex.run(@citation_regex, elem(lines, n - 1)) do
      [_, phase_str] -> String.to_integer(phase_str)
      nil -> nil
    end
  end

  defp missing_citation_violation(label, last_idx) do
    %{
      file: label,
      line: last_idx,
      reason: :missing_citation,
      detail: "no structured gsd-disable-until-phase citation within #{@citation_window} lines"
    }
  end

  defp violations_for_staged(label, content, existing_phases, statuses) do
    content
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, n} ->
      case Regex.run(@staged_regex, line) do
        [_, phase_str] ->
          phase_violation(label, n, String.to_integer(phase_str), existing_phases, statuses)

        nil ->
          []
      end
    end)
  end

  defp phase_violation(label, line, phase, existing_phases, statuses) do
    cond do
      not MapSet.member?(existing_phases, phase) ->
        [
          %{
            file: label,
            line: line,
            reason: :absent_phase,
            detail: "cites phase #{phase}, which does not exist in ROADMAP.md"
          }
        ]

      Map.get(statuses, phase) == "Complete" ->
        [
          %{
            file: label,
            line: line,
            reason: :complete_phase,
            detail: "cites phase #{phase}, which is already marked Complete in ROADMAP.md"
          }
        ]

      true ->
        []
    end
  end

  defp group_consecutive(idxs) do
    idxs
    |> Enum.reduce([], fn idx, acc ->
      case acc do
        [[prev | _] = run | rest] when idx == prev + 1 -> [[idx | run] | rest]
        _ -> [[idx] | acc]
      end
    end)
    |> Enum.map(&Enum.reverse/1)
    |> Enum.reverse()
  end

  defp format_violations(violations) do
    Enum.map_join(violations, "\n", fn v -> "#{v.file}:#{v.line} — #{v.detail}" end)
  end
end
