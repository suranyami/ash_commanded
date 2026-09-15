defmodule Mix.Tasks.AshCommanded.Dump do
  @shortdoc "Renders the Elixir source AshCommanded generated for a DSL module"

  @moduledoc """
  Renders the modules a Commanded DSL declaration generated, as the transformer wrote them —
  before `Module.create/3`, and before any later macro expansion.

  ## Usage

      mix ash_commanded.dump MyApp.Accounts.User
      mix ash_commanded.dump MyApp.Accounts.User --only MyApp.Commands.RegisterUser

  Give it the resource (or domain) module that carries the `commanded do ... end` block. Every
  module under that resource's own namespace prefix that block's transformers generated is
  rendered as formatted Elixir source, recovered from the AST captured immediately before
  `Module.create/3` ran. Narrow the output to one generated module with `--only`.

  This forces a fresh, in-process recompile of the target module's own source file with AST
  capture enabled (see `AshCommanded.Commanded.Transformers.BaseTransformer.create_module/3`).
  A normal `mix compile` or `mix test` never sets the capture flag, so it pays nothing (D-06).

  This is FOUND-01/02/05's default, pre-`Module.create/3` view. It is deliberately not the same
  as `scripts/render_generated.exs`'s post-compile `:beam_lib` view (FOUND-03), which shows code
  after macro expansion — `use X` there appears as the functions it injected. That is a separate,
  later flag on this same task.
  """

  use Mix.Task

  @capture_table :ash_commanded_dump_capture

  @impl Mix.Task
  def run(argv) do
    {opts, args, _invalid} = OptionParser.parse(argv, strict: [only: :string])

    case args do
      [module_arg] ->
        dump(module_arg, opts[:only])

      _ ->
        Mix.raise("usage: mix ash_commanded.dump <DslModule> [--only <GeneratedModule>]")
    end
  end

  defp dump(module_arg, only_arg) do
    # Ordinary incremental compile first, so Ash/Spark/Commanded and every other module load
    # through the fast, cached path — only the target's own file is recompiled below.
    Mix.Task.run("compile")

    target = resolve_module!(module_arg)
    only = only_arg && resolve_module!(only_arg)

    source_path =
      target.__info__(:compile)
      |> Keyword.fetch!(:source)
      |> to_string()

    ensure_capture_table()
    Code.compiler_options(ignore_module_conflict: true)
    Application.put_env(:ash_commanded, :capture_ast?, true)

    try do
      Code.compile_file(source_path)
    after
      Application.put_env(:ash_commanded, :capture_ast?, false)
    end

    captured = :ets.tab2list(@capture_table)
    entries = select_captured(captured, target, only)

    if entries == [] do
      Mix.raise(
        "no captured modules matched #{module_arg}" <>
          if(only, do: " --only #{inspect(only)}", else: "")
      )
    end

    entries
    |> Enum.sort_by(fn {module_name, _ast} -> Atom.to_string(module_name) end)
    |> Enum.each(fn {module_name, ast} ->
      Mix.shell().info(render(module_name, ast))
    end)
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

  # "Under the target module's own namespace" (D-05): every captured module whose split name
  # starts with the resource/domain's own module prefix (its parent namespace — the same prefix
  # BaseTransformer.get_module_prefix/1 derives), or exactly the --only module when given.
  defp select_captured(captured, target, nil) do
    prefix = AshCommanded.Commanded.Transformers.BaseTransformer.get_module_prefix(target)
    prefix_parts = Module.split(prefix)

    Enum.filter(captured, fn {module_name, _ast} ->
      List.starts_with?(Module.split(module_name), prefix_parts)
    end)
  end

  defp select_captured(captured, _target, only) do
    Enum.filter(captured, fn {module_name, _ast} -> module_name == only end)
  end

  defp render(module_name, ast) do
    wrapped =
      quote do
        defmodule unquote(module_name) do
          unquote(ast)
        end
      end

    wrapped
    |> Macro.to_string()
    |> safe_format()
  end

  # Reused verbatim from scripts/render_generated.exs's safe_format/1: the formatter can
  # reject AST that round-trips imperfectly; fall back to the raw rendering rather than
  # losing the output entirely.
  defp safe_format(src) do
    try do
      src |> Code.format_string!() |> IO.iodata_to_binary()
    rescue
      _ -> src
    end
  end
end
