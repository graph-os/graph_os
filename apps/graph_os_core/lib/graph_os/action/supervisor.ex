defmodule GraphOS.Action.Supervisor do
  @moduledoc """
  A DynamicSupervisor responsible for starting and managing GraphOS.Action.Runner processes.
  """
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    # Start with a temporary strategy, restart runners if they crash
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts a new Action Runner process for a given execution.
  """
  def start_runner(opts) do
    # opts should include :execution_id, :caller_actor_id, :component_module, :action_name, :args
    spec = {GraphOS.Action.Runner, opts}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  @doc """
  Terminates an Action Runner process.
  """
  def stop_runner(execution_id) do
    # Find the child PID using the registered name
    case Registry.lookup(Registry.GraphOSActionRunner, execution_id) do
      {:ok, pid} ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)
      :error ->
        # Already stopped or never started
        :ok
    end
  end
end
