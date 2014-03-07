defmodule RedisPool.Supervisor do
  use Supervisor.Behaviour

  def start_link do
    case :application.get_env(:redis_pool, :pools) do
      {:ok, p} ->
        pools = p
      _ ->
        pools = [{:redis_pool, [{:size, 10}, {:max_overflow, 10}]}]
    end
    case :application.get_env(:redis_pool, :global_or_local) do
      {:ok, g} ->
        global_or_local = g
      _ ->
        global_or_local = :global
    end
    start_link(pools, global_or_local)
  end

  def start_link(pools, global_or_local) do
    :supervisor.start_link({:local, __MODULE__}, __MODULE__, [pools, global_or_local])
  end

  def create_pool(pool_name, size, options) do
    args = [
      {:name, {:global, pool_name}},
      {:worker_module, :eredis},
      {:size, size},
      {:max_overflow, 10}] ++ options
    pool_spec = :poolboy.child_spec(pool_name, args)
    :supervisor.start_child(__MODULE__, pool_spec)
  end

  def delete_pool(pool_name) do
    :supervisor.terminate_child(__MODULE__, pool_name)
    :supervisor.delete_child(__MODULE__, pool_name)
  end

  def init([pools, global_or_local]) do
    spec_fun = fn({pool_name, pool_config}) ->
      args = [{:name, {global_or_local, pool_name}}, {:worker_module, :eredis}] ++ pool_config
      :poolboy.child_spec(pool_name, args)
    end
    pool_specs = Enum.map(pools, spec_fun)

    supervise(pool_specs, strategy: :one_for_one)
  end

end