defmodule GraphOS.Entity.BindingTest do
  use ExUnit.Case

  alias GraphOS.Entity.Binding

  # Define some test modules for use with bindings
  defmodule TestModuleA do
  end

  defmodule TestModuleB do
  end

  defmodule TestModuleC do
  end

  # Test Edge module with binding
  defmodule TestEdge do
    def entity do
      %{
        source: GraphOS.Entity.Binding.new(include: [TestModuleA]),
        target: GraphOS.Entity.Binding.new(exclude: [TestModuleC])
      }
    end
  end

  describe "Binding creation" do
    test "new/1 with keyword list" do
      binding = Binding.new(include: [TestModuleA], exclude: [TestModuleB])

      assert binding.include == [TestModuleA]
      assert binding.exclude == [TestModuleB]
    end

    test "new/1 with map" do
      binding = Binding.new(%{include: [TestModuleA], exclude: [TestModuleB]})

      assert binding.include == [TestModuleA]
      assert binding.exclude == [TestModuleB]
    end

    test "new/1 with single module (not in list)" do
      binding = Binding.new(include: TestModuleA, exclude: TestModuleB)

      assert binding.include == [TestModuleA]
      assert binding.exclude == [TestModuleB]
    end

    test "new/1 with empty options" do
      binding = Binding.new([])

      assert binding.include == []
      assert binding.exclude == []
    end

    test "new/1 with nil values" do
      binding = Binding.new(include: nil, exclude: nil)

      assert binding.include == []
      assert binding.exclude == []
    end
  end

  describe "Module normalization" do
    test "normalize_modules/1 with a list" do
      modules = [TestModuleA, TestModuleB]
      normalized = Binding.normalize_modules(modules)

      assert normalized == modules
    end

    test "normalize_modules/1 with a single module" do
      normalized = Binding.normalize_modules(TestModuleA)

      assert normalized == [TestModuleA]
    end

    test "normalize_modules/1 with nil" do
      normalized = Binding.normalize_modules(nil)

      assert normalized == []
    end
  end

  describe "Binding validation" do
    test "validate!/1 with valid modules" do
      binding = Binding.new(include: [TestModuleA], exclude: [TestModuleB])

      # Should not raise an error
      assert binding == Binding.validate!(binding)
    end

    test "validate!/1 with invalid modules" do
      # Use an atom that doesn't look like a module name (no dot)
      binding = %Binding{include: [:not_a_module], exclude: []}

      assert_raise ArgumentError, fn ->
        Binding.validate!(binding)
      end
    end
  end

  describe "Include and exclude checks" do
    test "included?/2 with empty include list" do
      binding = Binding.new([])

      # When include is empty, all modules are considered included
      assert Binding.included?(binding, TestModuleA) == true
      assert Binding.included?(binding, TestModuleB) == true
    end

    test "included?/2 with specific modules" do
      binding = Binding.new(include: [TestModuleA, TestModuleB])

      assert Binding.included?(binding, TestModuleA) == true
      assert Binding.included?(binding, TestModuleB) == true
      assert Binding.included?(binding, TestModuleC) == false
    end

    test "excluded?/2 with empty exclude list" do
      binding = Binding.new([])

      # When exclude is empty, no modules are considered excluded
      assert Binding.excluded?(binding, TestModuleA) == false
      assert Binding.excluded?(binding, TestModuleB) == false
    end

    test "excluded?/2 with specific modules" do
      binding = Binding.new(exclude: [TestModuleA, TestModuleB])

      assert Binding.excluded?(binding, TestModuleA) == true
      assert Binding.excluded?(binding, TestModuleB) == true
      assert Binding.excluded?(binding, TestModuleC) == false
    end
  end

  describe "allowed?/2 function" do
    test "allowed?/2 with empty binding" do
      binding = Binding.new([])

      # With no include/exclude, all modules are allowed
      assert Binding.allowed?(binding, TestModuleA) == true
      assert Binding.allowed?(binding, TestModuleB) == true
      assert Binding.allowed?(binding, TestModuleC) == true
    end

    test "allowed?/2 with only include list" do
      binding = Binding.new(include: [TestModuleA, TestModuleB])

      # Only modules in the include list are allowed
      assert Binding.allowed?(binding, TestModuleA) == true
      assert Binding.allowed?(binding, TestModuleB) == true
      assert Binding.allowed?(binding, TestModuleC) == false
    end

    test "allowed?/2 with only exclude list" do
      binding = Binding.new(exclude: [TestModuleC])

      # All modules not in the exclude list are allowed
      assert Binding.allowed?(binding, TestModuleA) == true
      assert Binding.allowed?(binding, TestModuleB) == true
      assert Binding.allowed?(binding, TestModuleC) == false
    end

    test "allowed?/2 with both include and exclude lists" do
      binding = Binding.new(include: [TestModuleA, TestModuleB, TestModuleC], exclude: [TestModuleC])

      # Module must be in include AND not in exclude to be allowed
      assert Binding.allowed?(binding, TestModuleA) == true
      assert Binding.allowed?(binding, TestModuleB) == true
      assert Binding.allowed?(binding, TestModuleC) == false
    end

    test "allowed?/2 with entity module" do
      # TestEdge has source binding that includes TestModuleA
      # and target binding that excludes TestModuleC

      # TestModuleA is allowed as source
      assert Binding.allowed?(TestEdge, TestModuleA) == true

      # TestModuleB is allowed as target (not excluded)
      assert Binding.allowed?(TestEdge, TestModuleB) == true

      # TestModuleC is not allowed as target (explicitly excluded)
      # It's also not included in source, so overall it's not allowed
      assert Binding.allowed?(TestEdge, TestModuleC) == false

      # Create an entity with source and target both excluding TestModuleC
      defmodule StrictBindingEdge do
        def entity do
          %{
            source: GraphOS.Entity.Binding.new(exclude: [GraphOS.Entity.BindingTest.TestModuleC]),
            target: GraphOS.Entity.Binding.new(exclude: [GraphOS.Entity.BindingTest.TestModuleC])
          }
        end
      end

      # TestModuleA and TestModuleB are allowed
      assert Binding.allowed?(StrictBindingEdge, TestModuleA) == true
      assert Binding.allowed?(StrictBindingEdge, TestModuleB) == true

      # TestModuleC is not allowed anywhere
      assert Binding.allowed?(StrictBindingEdge, TestModuleC) == false
    end
  end
end
