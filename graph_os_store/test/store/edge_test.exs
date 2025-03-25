defmodule GraphOS.Entity.EdgeTypeRestrictionsTest do
  use ExUnit.Case, async: true

  alias GraphOS.Store

  # Define test modules for testing type restrictions
  defmodule TestGraph do
    use GraphOS.Entity.Graph, temp: true
  end

  defmodule Person do
    use GraphOS.Entity.Node, graph: TestGraph
  end

  defmodule Company do
    use GraphOS.Entity.Node, graph: TestGraph
  end

  defmodule City do
    use GraphOS.Entity.Node, graph: TestGraph
  end

  # Edge type that only allows Person -> Company connections
  defmodule WorksAt do
    use GraphOS.Entity.Edge,
      graph: TestGraph,
      source: GraphOS.Entity.EdgeTypeRestrictionsTest.Person,
      target: GraphOS.Entity.EdgeTypeRestrictionsTest.Company
  end

  # Edge type that allows Person or Company as source, but not Company as target
  defmodule LivesIn do
    use GraphOS.Entity.Edge,
      graph: TestGraph,
      source: [GraphOS.Entity.EdgeTypeRestrictionsTest.Person, GraphOS.Entity.EdgeTypeRestrictionsTest.Company],
      target_not: GraphOS.Entity.EdgeTypeRestrictionsTest.Company
  end

  # Edge type with no restrictions
  defmodule ConnectsTo do
    use GraphOS.Entity.Edge,
      graph: TestGraph
  end

  setup do
    # Initialize a new store for each test
    {:ok, store_name} = Store.init(name: :"test_store_#{:erlang.unique_integer([:positive])}")
    on_exit(fn -> Store.stop(store_name) end)
    %{store: store_name}
  end

  describe "Edge with source/target restrictions" do
    test "creates an edge with valid source and target", %{store: store} do
      # Create nodes with ids that include the type name
      {:ok, person} = Store.insert(Person, %{id: "person_1", data: %{name: "Alice"}}, store: store)
      {:ok, company} = Store.insert(Company, %{id: "company_1", data: %{name: "Acme Inc."}}, store: store)

      # Create a valid edge
      edge_data = %{source: person.id, target: company.id}
      assert {:ok, edge} = Store.insert(WorksAt, edge_data, store: store)
      assert edge.source == person.id
      assert edge.target == company.id
    end

    test "rejects an edge with invalid source", %{store: store} do
      # Create nodes
      {:ok, company} = Store.insert(Company, %{id: "company_2", data: %{name: "Acme Inc."}}, store: store)
      {:ok, city} = Store.insert(City, %{id: "city_1", data: %{name: "New York"}}, store: store)

      # Try to create an invalid edge (company -> city, but WorksAt requires Person -> Company)
      edge_data = %{source: company.id, target: city.id}
      assert {:error, reason} = Store.insert(WorksAt, edge_data, store: store)
      assert String.contains?(reason, "invalid source type")
    end

    test "rejects an edge with invalid target", %{store: store} do
      # Create nodes
      {:ok, person} = Store.insert(Person, %{id: "person_2", data: %{name: "Bob"}}, store: store)
      {:ok, city} = Store.insert(City, %{id: "city_2", data: %{name: "Chicago"}}, store: store)

      # Try to create an invalid edge (person -> city, but WorksAt requires Person -> Company)
      edge_data = %{source: person.id, target: city.id}
      assert {:error, reason} = Store.insert(WorksAt, edge_data, store: store)
      assert String.contains?(reason, "invalid target type")
    end
  end

  describe "Edge with multiple allowed source types" do
    test "creates an edge with either allowed source type", %{store: store} do
      # Create nodes of different types
      {:ok, person} = Store.insert(Person, %{id: "person_3", data: %{name: "Charlie"}}, store: store)
      {:ok, company} = Store.insert(Company, %{id: "company_3", data: %{name: "BigCorp"}}, store: store)
      {:ok, city} = Store.insert(City, %{id: "city_3", data: %{name: "San Francisco"}}, store: store)

      # LivesIn allows Person or Company as source (but not City)
      # Create a valid edge with Person source
      person_edge_data = %{source: person.id, target: city.id}
      assert {:ok, person_edge} = Store.insert(LivesIn, person_edge_data, store: store)
      assert person_edge.source == person.id
      assert person_edge.target == city.id

      # Create a valid edge with Company source
      company_edge_data = %{source: company.id, target: city.id}
      assert {:ok, company_edge} = Store.insert(LivesIn, company_edge_data, store: store)
      assert company_edge.source == company.id
      assert company_edge.target == city.id
    end

    test "rejects an edge with excluded target type", %{store: store} do
      # Create nodes
      {:ok, person} = Store.insert(Person, %{id: "person_4", data: %{name: "Dave"}}, store: store)
      {:ok, company} = Store.insert(Company, %{id: "company_4", data: %{name: "SmallCorp"}}, store: store)

      # LivesIn has target_not: Company, so this should fail
      edge_data = %{source: person.id, target: company.id}
      assert {:error, reason} = Store.insert(LivesIn, edge_data, store: store)
      assert String.contains?(reason, "excluded target type")
    end
  end

  describe "Edge without restrictions" do
    test "allows any source and target types", %{store: store} do
      # Create nodes of different types
      {:ok, person} = Store.insert(Person, %{id: "person_5", data: %{name: "Eve"}}, store: store)
      {:ok, company} = Store.insert(Company, %{id: "company_5", data: %{name: "TechCorp"}}, store: store)
      {:ok, city} = Store.insert(City, %{id: "city_5", data: %{name: "London"}}, store: store)

      # ConnectsTo has no restrictions, so all combinations should work
      assert {:ok, _} = Store.insert(ConnectsTo, %{source: person.id, target: company.id}, store: store)
      assert {:ok, _} = Store.insert(ConnectsTo, %{source: company.id, target: city.id}, store: store)
      assert {:ok, _} = Store.insert(ConnectsTo, %{source: city.id, target: person.id}, store: store)
      assert {:ok, _} = Store.insert(ConnectsTo, %{source: person.id, target: city.id}, store: store)
    end
  end
end
