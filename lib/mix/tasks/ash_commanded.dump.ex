defmodule Mix.Tasks.AshCommanded.Dump do
  @shortdoc "Renders the Elixir source AshCommanded generated for a DSL module"

  @moduledoc """
  Renders the modules a Commanded DSL declaration generated.

  ## Usage

      mix ash_commanded.dump MyApp.Accounts.User
      mix ash_commanded.dump MyApp.Accounts.User --only MyApp.Commands.RegisterUser
      mix ash_commanded.dump MyApp.Accounts.User --beam
      mix ash_commanded.dump MyApp.Accounts.User --write

  Give it the resource (or domain) module that carries the `commanded do ... end` block. Every
  module under that resource's own namespace prefix that block's transformers generated is
  rendered, recovered from the AST captured immediately before `Module.create/3` ran. Narrow the
  output to one generated module with `--only`.

  ## Two views

  By default this shows the AST as the transformer wrote it, with `use X` still `use X` — this
  is FOUND-01/02/05's primary view. `--beam` shows the ground-truth post-compile view instead,
  recovered from the BEAM `debug_info` chunk (FOUND-03): `use X` there has already become the
  functions it injected. Concretely, `AshCommanded.TestSupport.Parity.Projectors.WidgetProjector`
  differs between the two: the default view shows `use Commanded.Event.Handler, ...` verbatim,
  while `--beam` shows the `child_spec/1`, `after_start/1` and other callbacks that macro
  injected.

  This forces a fresh, in-process recompile of the target module's own source file with AST
  capture enabled (see `AshCommanded.Resource.Transformers.BaseTransformer.create_module/3`).
  A normal `mix compile` or `mix test` never sets the capture flag, so it pays nothing (D-06).

  ## Regenerating goldens (FOUND-05)

  Golden renders under `test/golden/` are regenerated with exactly one command:

      mix ash_commanded.dump <Fixture> --write

  A bare invocation (no `--write`) diffs the fresh render against the committed golden when one
  exists, printing a per-line diff and the budget deltas and exiting non-zero on a difference; it
  prints the full render and exits zero when no golden exists yet (D-07). `--write` accepts the
  fresh render when every measured size shrank or held against the committed header, and
  **refuses** — writing nothing — when any size would grow, naming the budget key, its old and
  new value, and the golden file and header line to edit first (D-04, D-11). See
  `test/golden/README.md` for what the header and refusal mean.
  """

  use Mix.Task

  alias AshCommanded.Dump.Golden
  alias AshCommanded.Dump.Render

  @capture_table :ash_commanded_dump_capture

  @impl Mix.Task
  def run(argv) do
    {opts, args, invalid} =
      OptionParser.parse(argv, strict: [only: :string, beam: :boolean, write: :boolean])

    if invalid != [] do
      names = Enum.map_join(invalid, ", ", fn {flag, _value} -> flag end)
      Mix.raise("unrecognised flag(s): #{names}")
    end

    case args do
      [module_arg] ->
        dump(module_arg, opts)

      _ ->
        Mix.raise(
          "usage: mix ash_commanded.dump <DslModule> [--only <GeneratedModule>] [--beam] [--write]"
        )
    end
  end

  defp dump(module_arg, opts) do
    Mix.Task.run("compile")

    target = resolve_module!(module_arg)
    only = opts[:only] && resolve_module!(opts[:only])
    beam? = opts[:beam] == true

    cond do
      beam? and only ->
        render_beam(only)

      beam? ->
        target
        |> generated_module_names()
        |> raise_if_empty!(module_arg, nil)
        |> Enum.each(&render_beam/1)

      true ->
        source_path = source_path_for(target)

        entries =
          target
          |> capture_entries(only)
          |> raise_if_empty!(module_arg, only)

        run_ast(entries, source_path, write?: opts[:write] == true)
    end
  end

  defp raise_if_empty!([], module_arg, only) do
    Mix.raise(
      "no captured modules matched #{module_arg}" <>
        if(only, do: " --only #{inspect(only)}", else: "")
    )
  end

  defp raise_if_empty!(entries, _module_arg, _only), do: entries

  defp source_path_for(target) do
    target.__info__(:compile) |> Keyword.fetch!(:source) |> to_string()
  end

  defp generated_module_names(target) do
    target
    |> capture_entries(nil)
    |> Enum.map(fn {module_name, _ast} -> module_name end)
  end

  # ── Capture: the single source of truth for "every module this DSL generated" ──
  #
  # Both views resolve the target's generated modules the same way, so they cannot disagree
  # about what "every module the target DSL generated" means. The AST view uses the captured
  # bodies directly; the --beam view (without --only) discards the AST and keeps only the
  # names, since --beam reads its content straight from the already-compiled BEAM file instead.

  defp capture_entries(target, only) do
    ensure_capture_table()
    Code.compiler_options(ignore_module_conflict: true)
    Application.put_env(:ash_commanded, :capture_ast?, true)

    source_path = source_path_for(target)

    try do
      Code.compile_file(source_path)
    after
      Application.put_env(:ash_commanded, :capture_ast?, false)
    end

    result =
      :ets.tab2list(@capture_table)
      |> select_captured(target, only)
      |> Enum.sort_by(fn {module_name, _ast} -> Atom.to_string(module_name) end)

    restore_compiled_state!(target)

    result
  end

  # Code.compile_file/1 (used above so the pre-Module.create/3 AST can be captured) loads
  # modules in a way that leaves :code.which/1 unable to find their real, disk-backed .beam
  # file — breaking --beam's :beam_lib introspection for any of them for the rest of this VM
  # session. Purge the affected modules and force a genuine recompile so a later --beam call
  # (even within the same `mix` invocation, as the test suite does) sees real files again.
  defp restore_compiled_state!(target) do
    captured_names = :ets.tab2list(@capture_table) |> Enum.map(fn {name, _ast} -> name end)

    for module_name <- Enum.uniq([target | captured_names]) do
      :code.purge(module_name)
      :code.delete(module_name)
    end

    Code.compiler_options(ignore_module_conflict: false)
    Mix.Task.rerun("compile", ["--force"])
  end

  # "Under the target module's own namespace" (D-05): every captured module whose split name
  # starts with the resource/domain's own module prefix (its parent namespace — the same prefix
  # BaseTransformer.get_module_prefix/1 derives), or exactly the --only module when given.
  defp select_captured(captured, target, nil) do
    prefix = AshCommanded.Resource.Transformers.BaseTransformer.get_module_prefix(target)
    prefix_parts = Module.split(prefix)

    Enum.filter(captured, fn {module_name, _ast} ->
      List.starts_with?(Module.split(module_name), prefix_parts)
    end)
  end

  defp select_captured(captured, _target, only) do
    Enum.filter(captured, fn {module_name, _ast} -> module_name == only end)
  end

  defp resolve_module!(name) do
    module =
      try do
        Module.safe_concat([name])
      rescue
        ArgumentError ->
          Mix.raise("could not resolve module #{name}: no such module is currently loaded")
      end

    case Code.ensure_loaded(module) do
      {:module, ^module} -> module
      {:error, reason} -> Mix.raise("could not resolve module #{name}: #{inspect(reason)}")
    end
  end

  defp ensure_capture_table do
    case :ets.whereis(@capture_table) do
      :undefined -> :ets.new(@capture_table, [:named_table, :public, :set])
      _tid -> :ets.delete_all_objects(@capture_table)
    end
  end

  # ── Default view: pre-Module.create/3 AST, diffed against and written to goldens ──

  defp run_ast(entries, source_path, write?: write?) do
    fixture_dir = Path.basename(source_path, ".ex")

    results =
      Enum.map(entries, fn {module_name, ast} ->
        body = render_body(module_name, ast)
        golden = golden_path(fixture_dir, module_name)

        if write? do
          write_golden(golden, body)
        else
          diff_golden(golden, body)
        end
      end)

    if Enum.any?(results, &(&1 == :fail)) do
      Mix.raise("mix ash_commanded.dump: one or more goldens require attention (see above)")
    end
  end

  defp render_body(module_name, ast) do
    module_name
    |> Render.to_source(ast)
    |> Render.normalize_paths()
    |> ensure_trailing_newline()
  end

  defp ensure_trailing_newline(text) do
    if String.ends_with?(text, "\n"), do: text, else: text <> "\n"
  end

  @doc false
  # Test-support seam only (test/ash_commanded/golden_render_test.exs): renders exactly one
  # generated module through the identical pipeline `--write` uses, so the golden-render test
  # and the mix task cannot silently disagree about what a "fresh render" is.
  @spec render_module_for_test(module(), module()) :: String.t()
  def render_module_for_test(target, only) do
    Mix.Task.run("compile")

    case capture_entries(target, only) do
      [{^only, ast}] -> render_body(only, ast)
      [] -> raise "no captured module matched #{inspect(only)} under #{inspect(target)}"
    end
  end

  defp golden_path(fixture_dir, module_name) do
    name = module_name |> Module.split() |> Enum.join(".")
    Path.join(["test", "golden", fixture_dir, name <> ".golden"])
  end

  defp diff_golden(golden, body) do
    if File.exists?(golden) do
      {header_lines, old_body} = golden |> File.read!() |> Golden.split_header()

      if old_body == body do
        :ok
      else
        old_budget = Golden.parse_budget!(List.first(header_lines), golden)
        new_budget = Golden.measure(body)

        Mix.shell().info(budget_delta_lines(old_budget, new_budget))
        Mix.shell().info(diff_text(old_body, body))
        :fail
      end
    else
      Mix.shell().info(body)
      :ok
    end
  end

  defp write_golden(golden, body) do
    new_budget = Golden.measure(body)

    if File.exists?(golden) do
      write_existing_golden(golden, body, new_budget)
    else
      write_new_golden(golden, body, new_budget)
    end
  end

  defp write_existing_golden(golden, body, new_budget) do
    {header_lines, _old_body} = golden |> File.read!() |> Golden.split_header()
    old_budget = Golden.parse_budget!(List.first(header_lines), golden)
    staged_phase = Golden.staged_phase(header_lines)
    grown = growth(old_budget, new_budget)

    if grown == [] do
      do_write(golden, new_budget, staged_phase, body)
      Mix.shell().info("wrote #{golden}")
      :ok
    else
      report_refusal(golden, grown)
      :fail
    end
  end

  defp write_new_golden(golden, body, new_budget) do
    File.mkdir_p!(Path.dirname(golden))
    do_write(golden, new_budget, nil, body)
    Mix.shell().info("wrote #{golden}")
    :ok
  end

  defp report_refusal(golden, grown) do
    Enum.each(grown, &report_refusal_line(golden, &1))
  end

  defp report_refusal_line(golden, {key, old_v, new_v}) do
    Mix.shell().error(
      "#{golden}:1: refusing to write — #{key} would grow from #{old_v} to #{new_v}. " <>
        "Edit the `# gsd-budget:` header at line 1 to #{new_v} with a one-line reason " <>
        "if this growth is intentional, then retry."
    )
  end

  defp do_write(golden, budget, staged_phase, body) do
    header = Golden.format_header(budget, staged_phase)
    File.write!(golden, header <> "\n" <> body)
  end

  defp growth(old_budget, new_budget) do
    for key <- [:clause_max, :module_lines],
        old_v = Map.fetch!(old_budget, key),
        new_v = Map.fetch!(new_budget, key),
        new_v > old_v do
      {key, old_v, new_v}
    end
  end

  defp budget_delta_lines(old_budget, new_budget) do
    Enum.map_join([:clause_max, :module_lines], "\n", fn key ->
      "#{key} #{Map.fetch!(old_budget, key)} -> #{Map.fetch!(new_budget, key)}"
    end)
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

  # ── --beam view: post-compile debug_info (FOUND-03) ──

  defp render_beam(module_name) do
    with {:module, _} <- Code.ensure_loaded(module_name),
         path when is_list(path) <- :code.which(module_name),
         {:ok, {_, [debug_info: {:debug_info_v1, :elixir_erl, {:elixir_v1, map, _}}]}} <-
           :beam_lib.chunks(path, [:debug_info]) do
      defs = Map.get(map, :definitions, [])

      body =
        defs
        |> Enum.sort_by(fn {{fname, arity}, _kind, _meta, _clauses} -> {fname, arity} end)
        |> Enum.map_join("\n\n", &Render.render_beam_def/1)

      Mix.shell().info("# #{inspect(module_name)}\n#{body}")
    else
      other ->
        Mix.shell().info(
          "could not recover debug_info for #{inspect(module_name)}: #{inspect(other)}"
        )
    end
  end
end
