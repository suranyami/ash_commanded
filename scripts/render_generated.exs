# Render a compiled module's Elixir source back from its BEAM debug_info.
#
# This is a throwaway prototype of what FOUND-07's `mix ash_commanded.dump` task would do
# from the other end. Two interception points exist for seeing generated code:
#
#   1. The AST, before Module.create/3  — highest fidelity, needs a hook in BaseTransformer.
#   2. BEAM debug_info, after compile   — no library change needed, works on any compiled
#                                          module, but post-macro-expansion.
#
# This script is (2), because it needs nothing added to the library. The difference matters:
# `use Commanded.Event.Handler` appears here as the functions it injected, not as the `use`
# line. For an aggregate that is fine — Commanded provides no aggregate `use` macro, so the
# generated body is all there is.
#
# Usage:  mix run render_generated.exs <Module.Name> [more modules...]

defmodule Render do
  def module(name) do
    mod = Module.concat([name])

    with {:module, _} <- Code.ensure_loaded(mod),
         path when is_list(path) <- :code.which(mod),
         {:ok, {_, [debug_info: {:debug_info_v1, :elixir_erl, {:elixir_v1, map, _}}]}} <-
           :beam_lib.chunks(path, [:debug_info]) do
      defs = Map.get(map, :definitions, [])

      header = """
      # ── #{name} ──
      # #{length(defs)} function(s) recovered from debug_info
      # source: #{path}
      """

      body =
        defs
        |> Enum.sort_by(fn {{fname, arity}, _kind, _meta, _clauses} -> {fname, arity} end)
        |> Enum.map_join("\n\n", &render_def/1)

      IO.puts(header)
      IO.puts(body)
      IO.puts("\n" <> String.duplicate("─", 78) <> "\n")
    else
      other -> IO.puts("could not render #{name}: #{inspect(other)}")
    end
  end

  defp render_def({{fname, arity}, kind, _meta, clauses}) do
    keyword = if kind == :def, do: "def", else: "defp"

    rendered =
      Enum.map_join(clauses, "\n\n", fn {_meta, args, guards, body} ->
        head =
          {fname, [], args}
          |> Macro.to_string()
          |> maybe_add_guards(guards)

        "#{keyword} #{head} do\n#{indent(Macro.to_string(body))}\nend"
      end)

    "# #{fname}/#{arity}\n#{safe_format(rendered)}"
  end

  defp maybe_add_guards(head, []), do: head

  defp maybe_add_guards(head, guards) do
    head <> " when " <> Enum.map_join(guards, " and ", &Macro.to_string/1)
  end

  defp indent(s), do: s |> String.split("\n") |> Enum.map_join("\n", &("  " <> &1))

  # The formatter can reject AST that round-trips imperfectly; fall back to the raw
  # rendering rather than losing the output entirely.
  defp safe_format(src) do
    try do
      src |> Code.format_string!() |> IO.iodata_to_binary()
    rescue
      _ -> src
    end
  end
end

case System.argv() do
  [] -> IO.puts("usage: mix run render_generated.exs <Module.Name> [...]")
  names -> Enum.each(names, &Render.module/1)
end
