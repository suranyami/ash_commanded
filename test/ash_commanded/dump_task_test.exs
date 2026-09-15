defmodule AshCommanded.DumpTaskTest do
  @moduledoc """
  Integration tests for `mix ash_commanded.dump` against the real parity fixture
  (`AshCommanded.TestSupport.Parity.Widget`).

  Covers both views the task exposes: the default pre-`Module.create/3` AST (FOUND-01/02/05)
  and the post-compile `--beam` `debug_info` view (FOUND-03), plus `--only` narrowing and
  strict flag parsing.

  `async: false`: the task mutates the global Mix shell (`Mix.shell/1`) and
  `Code.compiler_options/1`, both process-independent global state.
  """

  use ExUnit.Case, async: false

  @target "AshCommanded.TestSupport.Parity.Widget"
  @only_projector "AshCommanded.TestSupport.Parity.Projectors.WidgetProjector"
  @only_command "AshCommanded.TestSupport.Parity.Commands.CreateWidget"

  setup do
    original_shell = Mix.shell()
    Mix.shell(Mix.Shell.Process)

    on_exit(fn -> Mix.shell(original_shell) end)

    :ok
  end

  defp run_task!(args) do
    Mix.Task.rerun("ash_commanded.dump", args)
    collect_shell_messages()
  end

  defp collect_shell_messages(acc \\ []) do
    receive do
      {:mix_shell, :info, [msg]} -> collect_shell_messages([msg | acc])
      {:mix_shell, :error, [msg]} -> collect_shell_messages([msg | acc])
    after
      0 -> acc |> Enum.reverse() |> Enum.join("\n")
    end
  end

  test "--beam prints source recovered from debug_info, and it differs from the default view for a module that uses a macro" do
    default_output = run_task!([@target, "--only", @only_projector])
    beam_output = run_task!([@target, "--beam", "--only", @only_projector])

    assert beam_output =~ "def child_spec("
    assert beam_output != default_output
  end

  test "--beam on a module with no debug_info chunk prints a diagnostic naming the module rather than raising" do
    mod = compile_module_without_debug_info!()

    output = run_task!([@target, "--beam", "--only", inspect(mod)])

    assert output =~ inspect(mod)
    refute output =~ "** ("
  end

  test "--only narrows output to exactly one generated module; without it, every generated module is printed" do
    narrowed = run_task!([@target, "--only", @only_projector])
    assert narrowed =~ "defmodule AshCommanded.TestSupport.Parity.Projectors.WidgetProjector"
    refute narrowed =~ "defmodule #{@only_command}"

    everything = run_task!([@target])
    assert everything =~ "defmodule AshCommanded.TestSupport.Parity.Projectors.WidgetProjector"
    assert everything =~ "defmodule AshCommanded.TestSupport.Parity.WidgetAggregate"
  end

  test "an unrecognised flag is rejected rather than silently ignored" do
    assert_raise Mix.Error, fn ->
      Mix.Task.rerun("ash_commanded.dump", [@target, "--nonsense-flag"])
    end
  end

  test "both the default and --beam paths round-trip through the formatter fallback without losing output" do
    default_output = run_task!([@target, "--only", @only_projector])
    beam_output = run_task!([@target, "--beam", "--only", @only_projector])

    assert default_output =~ "defmodule"
    assert String.trim(default_output) != ""
    assert beam_output =~ "def "
    assert String.trim(beam_output) != ""
  end

  # Compiles a bare Erlang module with no :debug_info chunk (Elixir always injects one; a
  # hand-built Erlang form list compiled with no options does not), so `--beam` has a real,
  # loaded, BEAM-backed module to fail gracefully against.
  defp compile_module_without_debug_info! do
    suffix = System.unique_integer([:positive])
    mod = Module.concat(["AshCommanded", "Test", "NoDebugInfo#{suffix}"])

    forms = [
      {:attribute, 1, :module, mod},
      {:attribute, 1, :export, [{:value, 0}]},
      {:function, 1, :value, 0, [{:clause, 1, [], [], [{:atom, 1, :ok}]}]}
    ]

    {:ok, ^mod, binary} = :compile.forms(forms, [])

    beam_path = Path.join(System.tmp_dir!(), "#{mod}.beam")
    File.write!(beam_path, binary)

    {:module, ^mod} = :code.load_binary(mod, String.to_charlist(beam_path), binary)

    mod
  end
end
