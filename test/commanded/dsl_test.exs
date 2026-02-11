defmodule AshCommanded.Commanded.DslTest do
  use ExUnit.Case, async: true

  defmodule TestResource do
    use Ash.Resource,
      extensions: [AshCommanded.Commanded.Dsl],
      domain: nil

    commanded do
    end
  end

  defmodule RegularResource do
    use Ash.Resource,
      domain: nil
  end

  defmodule ResourceWithCommanded do
    use Ash.Resource,
      extensions: [AshCommanded.Commanded.Dsl],
      domain: nil

    commanded do
      commands do
      end

      events do
      end

      projections do
      end
    end
  end

  describe "extension?/1" do
    test "returns true for resources using the extension" do
      assert AshCommanded.Commanded.Dsl.extension?(TestResource)
    end

    test "returns false for resources not using the extension" do
      refute AshCommanded.Commanded.Dsl.extension?(RegularResource)
    end
  end

  describe "DSL sections" do
    test "resource can define commanded sections" do
      # Just checking that the module compiles successfully
      assert Code.ensure_loaded?(ResourceWithCommanded)
    end
  end
end
