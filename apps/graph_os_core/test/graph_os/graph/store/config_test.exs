defmodule GraphOS.Graph.Store.ConfigTest do
  use ExUnit.Case, async: false
  @moduletag :code_graph
  
  alias GraphOS.Graph.Store.Config
  
  setup do
    # Start the Config GenServer
    {:ok, _pid} = start_supervised(Config)
    
    # Clean up after each test
    on_exit(fn ->
      # Reset the config to ensure tests are isolated
      Config.reset()
    end)
    
    :ok
  end
  
  describe "configuration management" do
    test "starts with default configuration" do
      {:ok, config} = Config.get()
      assert is_map(config)
      assert config.default_adapter == GraphOS.Graph.Store.ETS
    end
    
    test "can set configuration values" do
      # Set a configuration value
      :ok = Config.set(:test_key, "test_value")
      
      # Retrieve the updated configuration
      {:ok, config} = Config.get()
      assert config.test_key == "test_value"
    end
    
    test "can register a parent configuration" do
      # Register a parent configuration
      parent_config = %{
        adapter: GraphOS.Graph.Store.ETS,
        adapter_opts: [name: "parent_store"]
      }
      
      :ok = Config.register_parent("parent", parent_config)
      
      # Get the parent configuration
      {:ok, retrieved_config} = Config.get_parent("parent")
      assert retrieved_config.adapter == GraphOS.Graph.Store.ETS
      assert retrieved_config.adapter_opts[:name] == "parent_store"
    end
    
    test "can create configuration with inheritance" do
      # Register parent configuration
      parent_config = %{
        adapter: GraphOS.Graph.Store.ETS,
        adapter_opts: [name: "parent_store", option1: "parent_value", option2: "parent_only"]
      }
      
      :ok = Config.register_parent("parent", parent_config)
      
      # Create a child configuration that inherits and overrides some values
      child_opts = [
        inherit_from: "parent",
        override: %{
          adapter_opts: [name: "child_store", option1: "child_value"]
        }
      ]
      
      {:ok, child_config} = Config.create_child_config(child_opts)
      
      # Test inheritance and overrides
      assert child_config.adapter == GraphOS.Graph.Store.ETS
      assert child_config.adapter_opts[:name] == "child_store"     # Overridden
      assert child_config.adapter_opts[:option1] == "child_value"  # Overridden
      assert child_config.adapter_opts[:option2] == "parent_only"  # Inherited
    end
    
    test "resets configuration to defaults" do
      # Set a custom configuration
      :ok = Config.set(:custom_key, "custom_value")
      
      # Verify it's set
      {:ok, config_before} = Config.get()
      assert config_before.custom_key == "custom_value"
      
      # Reset the configuration
      :ok = Config.reset()
      
      # Verify it's back to defaults
      {:ok, config_after} = Config.get()
      refute Map.has_key?(config_after, :custom_key)
    end
  end
  
  describe "error handling" do
    test "returns error for non-existent parent" do
      result = Config.get_parent("non_existent")
      assert result == {:error, :parent_not_found}
    end
    
    test "returns error for invalid child configuration" do
      result = Config.create_child_config([inherit_from: "non_existent"])
      assert result == {:error, :parent_not_found}
    end
    
    test "handles deep merges correctly" do
      # Set up a parent with nested options
      parent_config = %{
        adapter: GraphOS.Graph.Store.ETS,
        adapter_opts: [
          name: "parent_store",
          nested: %{
            option1: "parent_nested",
            option2: "keep_this"
          }
        ]
      }
      
      :ok = Config.register_parent("nested_parent", parent_config)
      
      # Create child with partial override of nested structure
      child_opts = [
        inherit_from: "nested_parent",
        override: %{
          adapter_opts: [
            nested: %{
              option1: "child_nested"
              # option2 should be inherited
            }
          ]
        }
      ]
      
      {:ok, child_config} = Config.create_child_config(child_opts)
      
      # Check nested merging
      nested = Keyword.get(child_config.adapter_opts, :nested)
      assert nested.option1 == "child_nested"    # Overridden
      assert nested.option2 == "keep_this"       # Inherited
    end
  end
end
