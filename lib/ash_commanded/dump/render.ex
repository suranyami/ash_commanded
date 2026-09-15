defmodule AshCommanded.Dump.Render do
  @moduledoc """
  Pure rendering helpers shared by `Mix.Tasks.AshCommanded.Dump`'s two views: the default
  pre-`Module.create/3` AST (FOUND-01/02/05) and the post-compile `--beam` `debug_info` view
  (FOUND-03). Kept dependency-free from `Mix` so every function here is directly unit-testable
  without `Mix.Task.rerun/2`.
  """

  @doc """
  Wraps a captured `defmodule` body AST in its own module name and renders it as formatted
  Elixir source.

  ## Examples

      iex> AshCommanded.Dump.Render.to_source(Foo.Bar, quote(do: def(baz, do: :ok)))
      "defmodule Foo.Bar do\\n  def(baz, do: :ok)\\nend\\n"
  """
  @spec to_source(module(), Macro.t()) :: String.t()
  def to_source(module_name, ast) do
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

  @doc """
  Renders one `def`/`defp` clause recovered from BEAM `debug_info` (the shape
  `:beam_lib.chunks/2` returns per definition) as formatted Elixir source.

  ## Examples

      iex> AshCommanded.Dump.Render.render_beam_def({{:value, 0}, :def, [], [{[], [], [], {:atom, [], :ok}}]})
      "# value/0\\ndef(value()) do\\n  :ok\\nend\\n"
  """
  @spec render_beam_def({{atom(), non_neg_integer()}, :def | :defp, keyword(), [tuple()]}) ::
          String.t()
  def render_beam_def({{fname, arity}, kind, _meta, clauses}) do
    keyword = if kind == :def, do: "def", else: "defp"

    rendered =
      Enum.map_join(clauses, "\n\n", fn {_meta, args, guards, body} ->
        head =
          {fname, [], args}
          |> Macro.to_string()
          |> maybe_add_guards(guards)

        "#{keyword} #{head} do\n#{indent(Macro.to_string(body))}\nend"
      end)

    "# #{fname}/#{arity}\n" <> safe_format(rendered)
  end

  defp maybe_add_guards(head, []), do: head

  defp maybe_add_guards(head, guards) do
    head <> " when " <> Enum.map_join(guards, " and ", &Macro.to_string/1)
  end

  defp indent(s), do: s |> String.split("\n") |> Enum.map_join("\n", &("  " <> &1))

  @doc """
  Formats source text, falling back to the unformatted string when the AST does not round-trip
  through `Code.format_string!/1` cleanly. A partial, unformatted render is more useful than a
  raised exception losing the output entirely.

  ## Examples

      iex> AshCommanded.Dump.Render.safe_format("def foo, do: :ok")
      "def(foo, do: :ok)\\n"
  """
  @spec safe_format(String.t()) :: String.t()
  def safe_format(src) do
    src |> Code.format_string!() |> IO.iodata_to_binary()
  rescue
    _ -> src
  end

  @doc """
  Normalises any absolute path rooted at the current working directory to a repository-relative
  one (T-01-ID). Rendered output can otherwise carry a developer's own machine path into a
  committed golden, leaking local filesystem structure and making the CI text diff permanently
  red on every other machine.

  ## Examples

      iex> AshCommanded.Dump.Render.normalize_paths("#{File.cwd!()}/lib/foo.ex")
      "lib/foo.ex"
  """
  @spec normalize_paths(String.t()) :: String.t()
  def normalize_paths(text) do
    String.replace(text, File.cwd!() <> "/", "")
  end
end
