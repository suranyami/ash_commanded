defmodule AshCommanded.ContextBuilderTest do
  use ExUnit.Case, async: false

  # Simple context building module for testing
  defmodule ContextBuilder do
    @doc """
    Builds a context map based on configuration
    """
    def build_context(aggregate, command, opts \\ []) do
      %{}
      |> maybe_put_aggregate(aggregate, opts)
      |> maybe_put_command(command, opts)
      |> maybe_put_metadata(command, opts)
      |> maybe_merge_static_context(opts)
    end

    defp maybe_put_aggregate(context, aggregate, opts) do
      if Keyword.get(opts, :include_aggregate?, true) do
        Map.put(context, prefixed_key(opts, :aggregate), aggregate)
      else
        context
      end
    end

    defp maybe_put_command(context, command, opts) do
      if Keyword.get(opts, :include_command?, true) do
        Map.put(context, prefixed_key(opts, :command), command)
      else
        context
      end
    end

    defp maybe_put_metadata(context, command, opts) do
      if Keyword.get(opts, :include_metadata?, true) && Map.has_key?(command, :metadata) do
        metadata = Map.get(command, :metadata, %{})
        Map.put(context, prefixed_key(opts, :metadata), metadata)
      else
        context
      end
    end

    defp maybe_merge_static_context(context, opts) do
      static_context = Keyword.get(opts, :static_context, %{})

      if is_map(static_context) && map_size(static_context) > 0 do
        Map.merge(context, static_context)
      else
        context
      end
    end

    defp prefixed_key(opts, key) do
      case Keyword.get(opts, :context_prefix, nil) do
        nil -> key
        prefix -> :"#{prefix}.#{key}"
      end
    end
  end

  describe "context building" do
    test "includes aggregate, command and metadata by default" do
      # Create test aggregate and command
      aggregate = %{id: "123", name: "Test User"}
      command = %{id: "123", email: "test@example.com", metadata: %{user_id: "admin"}}

      # Build context with default options
      context = ContextBuilder.build_context(aggregate, command)

      # Verify context has expected keys
      assert Map.has_key?(context, :aggregate)
      assert Map.has_key?(context, :command)
      assert Map.has_key?(context, :metadata)

      # Verify context has expected values
      assert context.aggregate == aggregate
      assert context.command == command
      assert context.metadata == %{user_id: "admin"}
    end

    test "can exclude specific context items" do
      # Create test aggregate and command
      aggregate = %{id: "123", name: "Test User"}
      command = %{id: "123", email: "test@example.com", metadata: %{user_id: "admin"}}

      # Build context excluding aggregate
      context = ContextBuilder.build_context(aggregate, command, include_aggregate?: false)

      # Verify aggregate is not in the context, but other items are
      refute Map.has_key?(context, :aggregate)
      assert Map.has_key?(context, :command)
      assert Map.has_key?(context, :metadata)
    end

    test "supports context key prefixing" do
      # Create test aggregate and command
      aggregate = %{id: "123", name: "Test User"}
      command = %{id: "123", email: "test@example.com", metadata: %{user_id: "admin"}}

      # Build context with prefix
      context = ContextBuilder.build_context(aggregate, command, context_prefix: :cmd)

      # Verify context has prefixed keys
      assert Map.has_key?(context, :"cmd.aggregate")
      assert Map.has_key?(context, :"cmd.command")
      assert Map.has_key?(context, :"cmd.metadata")

      # Verify context has expected values
      assert Map.get(context, :"cmd.aggregate") == aggregate
      assert Map.get(context, :"cmd.command") == command
      assert Map.get(context, :"cmd.metadata") == %{user_id: "admin"}
    end

    test "includes static context" do
      # Create test aggregate and command
      aggregate = %{id: "123", name: "Test User"}
      command = %{id: "123", email: "test@example.com"}

      # Static context to include
      static_context = %{
        app_version: "1.0.0",
        environment: :test
      }

      # Build context with static context
      context = ContextBuilder.build_context(aggregate, command, static_context: static_context)

      # Verify context includes static context values
      assert context.aggregate == aggregate
      assert context.command == command
      assert context.app_version == "1.0.0"
      assert context.environment == :test
    end

    test "handles missing metadata gracefully" do
      # Create test aggregate and command without metadata
      aggregate = %{id: "123", name: "Test User"}
      command = %{id: "123", email: "test@example.com"}

      # Build context
      context = ContextBuilder.build_context(aggregate, command)

      # Verify context does not have metadata key
      assert Map.has_key?(context, :aggregate)
      assert Map.has_key?(context, :command)
      refute Map.has_key?(context, :metadata)
    end
  end
end
