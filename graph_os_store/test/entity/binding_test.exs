defmodule GraphOS.Entity.BindingTest do
  use ExUnit.Case, async: true

  alias GraphOS.Entity.Binding

  # Define test modules
  defmodule ModuleA do
  end

  defmodule ModuleB do
  end

  defmodule ModuleC do
  end

  describe "new/1" do
    test "creates a binding with include list" do
      binding = Binding.new(%{include: [ModuleA, ModuleB]})
      assert binding.include == [ModuleA, ModuleB]
      assert binding.exclude == []
    end

    test "creates a binding with exclude list" do
      binding = Binding.new(%{exclude: [ModuleC]})
      assert binding.include == []
      assert binding.exclude == [ModuleC]
    end

    test "creates a binding with both include and exclude" do
      binding = Binding.new(%{include: ModuleA, exclude: ModuleC})
      assert binding.include == [ModuleA]
      assert binding.exclude == [ModuleC]
    end

    test "normalizes single module to list" do
      binding = Binding.new(%{include: ModuleA})
      assert binding.include == [ModuleA]
    end
  end

  describe "normalize_modules/1" do
    test "converts single module to list" do
      assert Binding.normalize_modules(ModuleA) == [ModuleA]
    end

    test "keeps list as is" do
      assert Binding.normalize_modules([ModuleA, ModuleB]) == [ModuleA, ModuleB]
    end

    test "converts nil to empty list" do
      assert Binding.normalize_modules(nil) == []
    end
  end

  describe "allowed?/2" do
    test "when include is specified, only included modules are allowed" do
      binding = Binding.new(%{include: [ModuleA, ModuleB]})
      assert Binding.allowed?(binding, ModuleA) == true
      assert Binding.allowed?(binding, ModuleB) == true
      assert Binding.allowed?(binding, ModuleC) == false
    end

    test "when exclude is specified, all modules except excluded are allowed" do
      binding = Binding.new(%{exclude: [ModuleC]})
      assert Binding.allowed?(binding, ModuleA) == true
      assert Binding.allowed?(binding, ModuleB) == true
      assert Binding.allowed?(binding, ModuleC) == false
    end

    test "when both include and exclude are specified" do
      binding = Binding.new(%{include: [ModuleA, ModuleB, ModuleC], exclude: [ModuleC]})
      assert Binding.allowed?(binding, ModuleA) == true
      assert Binding.allowed?(binding, ModuleB) == true
      assert Binding.allowed?(binding, ModuleC) == false
    end

    test "when neither include nor exclude are specified, all modules are allowed" do
      binding = Binding.new(%{})
      assert Binding.allowed?(binding, ModuleA) == true
      assert Binding.allowed?(binding, ModuleB) == true
      assert Binding.allowed?(binding, ModuleC) == true
    end
  end
end
