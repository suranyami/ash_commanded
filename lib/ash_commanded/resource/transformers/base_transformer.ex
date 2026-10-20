defmodule AshCommanded.Resource.Transformers.BaseTransformer do
  @moduledoc """
  A base module for Commanded DSL transformers.

  This module provides common functionality for transformers that generate code
  based on the Commanded DSL configuration.
  """

  @doc """
  Gets the module prefix for generated modules.

  This extracts the base namespace from the resource module, which will be used
  as the prefix for all generated modules.

  ## Namespace-derivation exemption (rewrite rule 4/11, FOUND-10)

  `AshCommanded.CredoChecks.NoModuleNameSurgery` flags `Module.split/1` results reaching
  `Module.concat/1,2` as module-name surgery (rewrite rule 4: "Derive from
  `Transformer.get_persisted/2`, never by module-name surgery."). This function does exactly
  that shape, and is deliberately exempt via the `# ash_commanded:namespace-derivation` marker
  below.

  It is exempt rather than rewritten or phase-cited (D-01/D-02) because neither of those
  remedies applies here. Rewriting is impossible in the literal sense the rule asks for: a
  generated module's parent namespace has no source other than the DSL module's own name —
  Spark persists the resource module via `Transformer.get_persisted/2`, not a namespace prefix,
  so there is nothing to read back. And a phase-cited suppression is the wrong shape because
  D-02 requires the cited phase to be live and incomplete, whereas this site is permanent: no
  future phase's rewrite removes the need to derive a namespace prefix from a resource module's
  own name (`ash_oban` derives its own generated-module namespace exactly the same way,
  confirmed in this project's ARCHITECTURE.md research).

  The distinction is the one CONTEXT.md's D-04 already draws between a temporary suppression
  and a permanent, visible exemption: every OTHER call site that reconstructs an existing module
  reference by splitting and reconcatenating a name is a defect (the confirmed defects rewrite
  rule 4 targets), but deriving a *fresh* child namespace from a DSL module's own name — never
  reconstructing an existing reference — is the one legitimate use of this shape, and it lives
  behind this one named, documented, and counted (`AshCommanded.CredoChecks.Exemption`) utility
  rather than being open-ended.

  `get_resource_name/1` below needs no marker: it terminates in `List.last/1` with no
  concatenation, which both credo checks' own design already treats as a display string, not
  surgery.

  ## Examples

      iex> get_module_prefix(MyApp.Accounts.User)
      MyApp.Accounts
  """
  # ash_commanded:namespace-derivation
  @spec get_module_prefix(module()) :: module()
  def get_module_prefix(resource_module) do
    parts = Module.split(resource_module)

    case parts do
      [_single_module] -> resource_module
      multiple_parts -> multiple_parts |> Enum.drop(-1) |> Module.concat()
    end
  end

  @doc """
  Gets the resource name from the resource module.

  ## Examples
      
      iex> get_resource_name(MyApp.Accounts.User)
      "User"
  """
  @spec get_resource_name(module()) :: String.t()
  def get_resource_name(resource_module) do
    resource_module
    |> Module.split()
    |> List.last()
  end

  @doc """
  Converts an atom to CamelCase string.

  ## Examples
      
      iex> camelize_atom(:register_user)
      "RegisterUser"
  """
  @spec camelize_atom(atom()) :: String.t()
  def camelize_atom(atom) do
    atom
    |> to_string()
    |> Macro.camelize()
  end

  @doc """
  Creates a module with the given name and contents.

  This is a wrapper around Module.create/3 that handles the environment location.

  When `Application.get_env(:ash_commanded, :capture_ast?, false)` is true and the named,
  public ETS table `:ash_commanded_dump_capture` exists, the AST is recorded there (as
  `{module_name, ast}`) before the module is created. This is the seam `mix
  ash_commanded.dump` forces a recompile through to see what a transformer wrote before
  `Module.create/3` ran (D-06). A normal `mix compile`/`mix test` never sets the flag, so it
  pays one `Application.get_env/3` lookup and nothing else. A missing table cannot crash an
  ordinary compile (T-01-BI-02).

  Delegates to `create_module/4` with no explicit location, which falls back to
  `Macro.Env.location(env)` exactly as this function always has — every existing caller is
  unaffected.

  ## Examples

      iex> create_module(MyApp.Commands.RegisterUser, quoted_ast, __ENV__)
      :ok
  """
  @spec create_module(module(), Macro.t(), Macro.Env.t()) :: :ok
  def create_module(module_name, ast, env) do
    create_module(module_name, ast, env, [])
  end

  @doc """
  Same as `create_module/3`, but accepts an explicit `[file: ..., line: ...]` location that
  replaces `Macro.Env.location(env)` in the underlying `Module.create/3` call.

  This is FOUND-18: today, every generated module is compiled with the *transformer's* own
  file and line (`Macro.Env.location(env)`, `env` being the calling transformer's `__ENV__`),
  so a compile error inside generated code blames the transformer rather than the DSL
  declaration that produced it — never where the fault actually is. Pass an explicit
  location here to point a diagnostic at the file a developer can actually open and fix.

  The recommended source for that location is `Spark.Dsl.Transformer.get_persisted(dsl_state,
  :file)` — Spark automatically persists the DSL-using module's own file under `:file` for
  every extension (`@persist {:file, __ENV__.file}`, set once per DSL module at `use
  Ash.Resource`/`use Ash.Domain` time), so it is available to every transformer's `transform/1`
  without deriving anything. A transformer that wants a specific `:line` too can pair it with
  a line captured from the entity's own DSL declaration.

  When `location` is `[]` (the default from `create_module/3`), behaviour is identical to
  before this arity existed. `create_module/3`'s nine existing callers are unaffected; adopting
  the explicit location is left to the transformers that choose to pass one.

  ## Examples

      iex> create_module(MyApp.Commands.RegisterUser, quoted_ast, __ENV__,
      ...>   file: Spark.Dsl.Transformer.get_persisted(dsl_state, :file), line: 1)
      :ok
  """
  @spec create_module(module(), Macro.t(), Macro.Env.t(), keyword()) :: :ok
  def create_module(module_name, ast, env, location) do
    capture_ast(module_name, ast)

    resolved_location =
      case location do
        [] -> Macro.Env.location(env)
        _ -> location
      end

    Module.create(module_name, ast, resolved_location)
    :ok
  end

  @doc """
  Returns the location of the DSL module whose `transform/1` is currently running.

  The file comes from `Spark.Dsl.Transformer.get_persisted(dsl_state, :file)`, which Spark
  persists for every extension when the consumer writes `use Ash.Resource` or `use
  Ash.Domain`. Passing the result to `create_module/4` attributes every generated clause to
  the module a developer actually wrote, rather than to the transformer that generated it.

  An empty list means Spark persisted no file (or persisted something unusable). That is not
  a failure: `create_module/4` already documents `[]` as "fall back to
  `Macro.Env.location(env)`", so such a module degrades to the pre-FOUND-18 behaviour rather
  than handing `Module.create/3` a nil file.

  ## Examples

      iex> dsl_location(%{persist: %{file: "/app/lib/my_app/user.ex"}})
      [file: "/app/lib/my_app/user.ex", line: 1]

      iex> dsl_location(%{})
      []
  """
  @spec dsl_location(Spark.Dsl.t()) :: keyword()
  def dsl_location(dsl_state) do
    case Spark.Dsl.Transformer.get_persisted(dsl_state, :file) do
      file when is_binary(file) and file != "" ->
        [file: file, line: 1]

      file when is_list(file) ->
        case IO.chardata_to_string(file) do
          "" -> []
          path -> [file: path, line: 1]
        end

      _ ->
        []
    end
  end

  @doc """
  Returns the location of a single DSL declaration.

  The line comes from the entity's own Spark annotation (`Spark.Dsl.Entity.anno/1`), and the
  file from `dsl_location/1` — the two sources FOUND-18 asks for. Passing the result to
  `create_module/4` makes an error inside the generated module point at the declaration that
  produced it, which is the line a developer opens first.

  `anno/1` deliberately emits an `IO.warn` for entities whose struct has no
  `__spark_metadata__` field, so that call is guarded: this library must not emit that
  warning during an ordinary consumer compile. When the entity carries no usable annotation,
  the result falls back to `dsl_location/1`, so the file stays correct and only the line
  degrades.

  ## Examples

      iex> entity_location(%MyEntity{__spark_metadata__: %Spark.Dsl.Entity.Meta{
      ...>   anno: :erl_anno.set_line(:erl_anno.new(0), 33)
      ...> }}, %{persist: %{file: "/app/lib/my_app/user.ex"}})
      [file: "/app/lib/my_app/user.ex", line: 33]
  """
  @spec entity_location(Spark.Dsl.Entity.entity(), Spark.Dsl.t()) :: keyword()
  def entity_location(entity, dsl_state) do
    location = dsl_location(dsl_state)

    case {location, entity_line(entity)} do
      {[file: file, line: _], line} when is_integer(line) and line > 0 ->
        [file: file, line: line]

      {location, _line} ->
        location
    end
  end

  defp entity_line(entity) do
    if Map.has_key?(entity, :__spark_metadata__) do
      case Spark.Dsl.Entity.anno(entity) do
        nil -> nil
        anno -> :erl_anno.line(anno)
      end
    end
  end

  @capture_table :ash_commanded_dump_capture

  defp capture_ast(module_name, ast) do
    if Application.get_env(:ash_commanded, :capture_ast?, false) do
      try do
        :ets.insert(@capture_table, {module_name, ast})
      rescue
        ArgumentError -> :ok
      end
    end

    :ok
  end
end
