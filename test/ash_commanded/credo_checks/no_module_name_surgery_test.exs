defmodule AshCommanded.CredoChecks.NoModuleNameSurgeryTest do
  use Credo.Test.Case

  alias AshCommanded.CredoChecks.Exemption
  alias AshCommanded.CredoChecks.NoModuleNameSurgery

  describe "shape 1 — Module.split/1 reaching Module.concat/1,2 in the same function" do
    test "the exact source at generate_aggregate_module.ex lines 242-247 produces an issue" do
      """
      defmodule CredoSampleModule do
        defp resource_module_from(command_module, resource_name) do
          # The command module only ever encodes the app_prefix (its own namespace minus
          # "Commands.<Name>"), never the resource name itself — so it cannot be split back
          # into the resource module at runtime. Compute the real resource module now, at
          # macro-generation time, and inline it as a literal instead.
          resource_module =
            command_module
            |> Module.split()
            |> Enum.drop(-2)
            |> Kernel.++([resource_name])
            |> Module.concat()

          resource_module
        end
      end
      """
      |> to_source_file("lib/ash_commanded_sample/aggregate.ex")
      |> run_check(NoModuleNameSurgery)
      |> assert_issue()
    end

    test "base_transformer.ex's real get_module_prefix/1 shape (a case-bound pipe chain) produces an issue when unmarked" do
      """
      defmodule CredoSampleModule do
        def get_module_prefix(resource_module) do
          parts = Module.split(resource_module)

          case parts do
            [_single_module] -> resource_module
            multiple_parts -> multiple_parts |> Enum.drop(-1) |> Module.concat()
          end
        end
      end
      """
      |> to_source_file("lib/ash_commanded_sample/base_transformer_unmarked.ex")
      |> run_check(NoModuleNameSurgery)
      |> assert_issue()
    end
  end

  describe "shape 2 — Module.concat/1,2 with a literal or interpolated string argument" do
    test "the exact source at generate_command_modules.ex line 99 produces an issue" do
      """
      defmodule CredoSampleModule do
        defp build_command_module(command, app_prefix) do
          command_name = command.command_name || command.name
          command_name_str = BaseTransformer.camelize_atom(command_name)

          Module.concat([app_prefix, "Commands", command_name_str])
        end
      end
      """
      |> to_source_file("lib/ash_commanded_sample/command_modules.ex")
      |> run_check(NoModuleNameSurgery)
      |> assert_issue()
    end

    test "the exact source at generate_commanded_application.ex lines 231-236 produces an issue" do
      """
      defmodule CredoSampleModule do
        defp application_module_name(domain_module, config) do
          prefix = Keyword.get(config, :prefix)
          domain_name = domain_module |> Module.split() |> List.last()

          if prefix do
            module_name = Module.concat([prefix, "\#{domain_name}Application"])

            if String.starts_with?(to_string(prefix), "Elixir.") do
              module_name
            else
              Module.concat(Elixir, module_name)
            end
          else
            Module.concat(domain_module, "Application")
          end
        end
      end
      """
      |> to_source_file("lib/ash_commanded_sample/commanded_application.ex")
      |> run_check(NoModuleNameSurgery)
      |> assert_issues()
    end
  end

  describe "must NOT flag — display strings and process naming" do
    test "the exact source at logging_middleware.ex line 37 (split terminating in List.last, no concat) produces no issue" do
      """
      defmodule CredoSampleModule do
        def before_dispatch(command, context, next) do
          config = Map.get(context, :middleware_config, %{})
          level = Map.get(config, :level, :info)

          command_type = command.__struct__ |> Module.split() |> List.last()
          command_id = extract_command_id(command)

          log(
            level,
            "[AshCommanded.Command] Dispatching \#{command_type}\#{command_id_str(command_id)} \#{inspect(command)}"
          )

          next.(command, context)
        end
      end
      """
      |> to_source_file("lib/ash_commanded_sample/logging_middleware.ex")
      |> run_check(NoModuleNameSurgery)
      |> refute_issues()
    end

    test "the exact source at generate_commanded_application.ex lines 130 and 135 (module-alias/variable-only concat) produces no issue" do
      """
      defmodule CredoSampleModule do
        defp build(app_module) do
          quote do
            def child_spec() do
              %{
                id: Module.concat(unquote(app_module), Supervisor),
                start:
                  {Supervisor, :start_link,
                   [
                     [],
                     [strategy: :one_for_one, name: Module.concat(unquote(app_module), Supervisor)]
                   ]},
                type: :supervisor
              }
            end
          end
        end
      end
      """
      |> to_source_file("lib/ash_commanded_sample/commanded_application_child_spec.ex")
      |> run_check(NoModuleNameSurgery)
      |> refute_issues()
    end
  end

  describe "the named exemption marker" do
    test "suppresses the issue for the one function it precedes, even though it contains the flagged shape" do
      """
      defmodule CredoSampleModule do
        # #{Exemption.marker()}
        def get_module_prefix(resource_module) do
          parts = Module.split(resource_module)

          case parts do
            [_single_module] -> resource_module
            multiple_parts -> multiple_parts |> Enum.drop(-1) |> Module.concat()
          end
        end
      end
      """
      |> to_source_file("lib/ash_commanded_sample/base_transformer_marked.ex")
      |> run_check(NoModuleNameSurgery)
      |> refute_issues()
    end
  end

  describe "the exemption marker's footprint in the real tree" do
    test "appears in exactly one function across all of lib/" do
      count =
        "lib"
        |> Path.join("**/*.ex")
        |> Path.wildcard()
        |> Enum.map(&File.read!/1)
        |> Enum.count(&String.contains?(&1, Exemption.marker()))

      assert count == 1
    end
  end
end
