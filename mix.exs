defmodule AshCommanded.MixProject do
  use Mix.Project

  @version "0.2.0"
  @description "CQRS pattern implementation for Ash Framework resources using Commanded"
  @source_url "https://github.com/accountex-org/ash_commanded"

  def project do
    [
      app: :ash_commanded,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() == :prod,
      deps: deps(),

      # Hex
      description: @description,
      package: package(),

      # Docs
      name: "AshCommanded",
      docs: docs(),

      # Testing
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ash, "~> 3.0"},
      {:sourceror, "~> 1.8", only: [:dev, :test]},
      {:spark, "~> 2.3"},
      {:igniter, "~> 0.5", only: [:dev, :test]},
      {:mock, "~> 0.3.0", only: [:test]},

      # Documentation
      {:ex_doc, "~> 0.30", only: [:dev, :test], runtime: false}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp package do
    [
      maintainers: ["Accountex"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      },
      files: ~w(lib mix.exs README.md LICENSE .formatter.exs)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "LICENSE",
        "documentation/commands.md",
        "documentation/events.md",
        "documentation/projections.md",
        "documentation/event_handlers.md",
        "documentation/middleware.md",
        "documentation/parameter_handling.md",
        "documentation/transactions.md",
        "documentation/context_propagation.md",
        "documentation/error_handling.md",
        "documentation/routers.md",
        "documentation/application.md",
        "documentation/snapshotting.md",
        "cheatsheets/AshCommanded.Commanded.Dsl.cheatmd"
      ],
      groups_for_extras: [
        Guides: [
          "documentation/commands.md",
          "documentation/events.md",
          "documentation/projections.md",
          "documentation/event_handlers.md",
          "documentation/routers.md",
          "documentation/application.md",
          "documentation/snapshotting.md"
        ],
        "Advanced Features": [
          "documentation/middleware.md",
          "documentation/parameter_handling.md",
          "documentation/transactions.md",
          "documentation/context_propagation.md",
          "documentation/error_handling.md"
        ],
        Cheatsheets: [
          "cheatsheets/AshCommanded.Commanded.Dsl.cheatmd"
        ]
      ],
      groups_for_modules: [
        DSL: [
          AshCommanded.Commanded.Dsl,
          AshCommanded.Commanded.DomainDsl,
          ~r/AshCommanded.Commanded.Sections/
        ],
        Transformers: [
          ~r/AshCommanded.Commanded.Transformers/
        ],
        Verifiers: [
          ~r/AshCommanded.Commanded.Verifiers/
        ],
        Info: [
          AshCommanded.Commanded.Info
        ]
      ],
      before_closing_body_tag: &before_closing_body_tag/1,
      before_closing_head_tag: &before_closing_head_tag/1,
      formatters: ["html"]
    ]
  end

  defp before_closing_head_tag(:html) do
    """
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.13.11/dist/katex.min.css" integrity="sha384-Um5gpz1odJg5Z4HAmzPtgZKdTBHZdw8S29IecapCSB31ligYPhHQZMIlWLYQGVoc" crossorigin="anonymous">
    <script defer src="https://cdn.jsdelivr.net/npm/katex@0.13.11/dist/katex.min.js" integrity="sha384-YNHdsYkH6gMx9y3mRkmcJ2mFUjTd0qNQQvY9VYZgQd7DcN7env35GzlmFaZ23JGp" crossorigin="anonymous"></script>
    <script defer src="https://cdn.jsdelivr.net/npm/katex@0.13.11/dist/contrib/auto-render.min.js" integrity="sha384-vZTG03m+2yp6N6BNi5iM4rW4oIwk5DfcNdFfxkk9ZWpDriOkXX8voJBFrAO7MpVl" crossorigin="anonymous" onload="renderMathInElement(document.body);"></script>
    """
  end

  defp before_closing_body_tag(:html) do
    """
    <script src="https://cdn.jsdelivr.net/npm/mermaid@8.13.3/dist/mermaid.min.js"></script>
    <script>
      document.addEventListener("DOMContentLoaded", function () {
        mermaid.initialize({
          startOnLoad: false,
          theme: document.body.className.includes("dark") ? "dark" : "default"
        });
        let id = 0;
        for (const codeEl of document.querySelectorAll("pre code.mermaid")) {
          const preEl = codeEl.parentElement;
          const graphDefinition = codeEl.textContent;
          const graphEl = document.createElement("div");
          const graphId = "mermaid-graph-" + id++;
          mermaid.render(graphId, graphDefinition, function (svgSource, bindListeners) {
            graphEl.innerHTML = svgSource;
            bindListeners && bindListeners(graphEl);
            preEl.insertAdjacentElement("afterend", graphEl);
            preEl.remove();
          });
        }
      });
    </script>
    """
  end

  defp aliases do
    [
      docs: ["docs", &copy_images/1],
      "gen.docs": ["spark.cheat_sheets", "docs"],
      "spark.cheat_sheets": "spark.cheat_sheets --extensions AshCommanded.Commanded.Dsl"
    ]
  end

  # Copy images after docs are generated
  defp copy_images(_) do
    # Add any image copying logic here if needed
    :ok
  end
end
