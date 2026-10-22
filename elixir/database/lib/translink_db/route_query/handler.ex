alias TranslinkDb.Query.Data

defmodule TranslinkDb.Query.Handler do
  defmodule Edge do
    defstruct [:from_stop_id, :to_stop_id, :from_departure, :to_arrival, :trip_id]

    @type t :: %Edge{
            from_stop_id: Data.stop_id(),
            to_stop_id: Data.stop_id(),
            from_departure: Data.seconds(),
            to_arrival: Data.seconds(),
            # nil == walk edge
            trip_id: Data.trip_id() | nil
          }
  end

  defmodule Node do
    defstruct [:best_arrival, :stop_id, :prev]

    @type t :: %Node{
            best_arrival: Data.seconds() | :infinity,
            stop_id: Data.stop_id(),
            prev:
              %{node: t(), edge: Edge.t()}
              | nil
          }

    def resolve(node), do: resolve(node, [])

    defp resolve(%Node{best_arrival: _, stop_id: _, prev: nil}, acc) do
      acc
    end

    defp resolve(%Node{best_arrival: _, stop_id: _, prev: prev}, acc) do
      resolve(prev.node, [prev.edge | acc])
    end
  end

  defmodule NodeQueue do
    defstruct [
      # for loop up by id
      :map,
      # for fast min removal
      :queue,
      # there's no fast way to directly remove from a PQ,
      # so changing priority means inserting a new entry
      # and marking the old one as removed
      :removed
    ]

    @type t :: %NodeQueue{
            map: %{Data.stop_id() => Node.t()},
            queue: PriorityQueue.t(),
            removed: MapSet.t()
          }

    @spec new() :: t()
    def new() do
      %NodeQueue{
        map: Map.new(),
        queue: PriorityQueue.new(),
        removed: MapSet.new()
      }
    end

    @spec upsert(Node.t(), t()) :: t()
    def upsert(node, %NodeQueue{map: map, queue: queue, removed: removed}) do
      removed =
        case Map.fetch(map, node.stop_id) do
          {:ok, old_node} -> removed |> MapSet.put(old_node)
          _ -> removed
        end

      %NodeQueue{
        map: map |> Map.put(node.stop_id, node),
        queue: queue |> PriorityQueue.put(node.best_arrival, node),
        removed: removed
      }
    end

    @spec fetch(t(), Data.stop_id()) :: {:ok, Node.t()} | :error
    def fetch(node_queue, stop_id) do
      Map.fetch(node_queue.map, stop_id)
    end

    @spec pop_min(t()) :: {Node.t(), t()} | :empty
    def pop_min(%NodeQueue{map: map, queue: queue, removed: removed}) do
      case PriorityQueue.pop(queue) do
        {{nil, nil}, _} ->
          :empty

        {{_best_arrival, popped_node}, new_queue} ->
          if removed |> MapSet.member?(popped_node) do
            pop_min(%NodeQueue{
              map: map,
              queue: new_queue,
              removed: removed
            })
          else
            {popped_node,
             %NodeQueue{
               map: map,
               queue: new_queue,
               removed: removed |> MapSet.put(popped_node)
             }}
          end
      end
    end
  end

  def best_route(
        from_stop_id,
        to_stop_id,
        # TODO: support querying by arrival time
        {:departure, dt} \\ {:departure, DateTime.now!("Canada/Pacific")}
      ) do
    {date, seconds} = normalize_datetime(dt)

    current = %Node{
      best_arrival: seconds,
      stop_id: from_stop_id,
      prev: nil
    }

    relax = fn edge, current, queue ->
      with {:ok, neighbor} <- NodeQueue.fetch(queue, edge.to_stop_id),
           false <- edge.to_arrival < neighbor.best_arrival do
        nil
      else
        _ ->
          %Node{
            best_arrival: edge.to_arrival,
            stop_id: edge.to_stop_id,
            prev: %{node: current, edge: edge}
          }
      end
    end

    search = fn self, current, queue ->
      if current.stop_id == to_stop_id do
        Node.resolve(current)
      else
        case current.stop_id
             |> edges(date, current.best_arrival)
             |> Enum.map(&relax.(&1, current, queue))
             |> Enum.filter(&(&1 != nil))
             |> Enum.reduce(queue, &NodeQueue.upsert/2)
             |> NodeQueue.pop_min() do
          {next, next_queue} -> self.(self, next, next_queue)
          :empty -> :no_path
        end
      end
    end

    search |> search.(current, NodeQueue.new())
  end

  @spec edges(Data.stop_id(), Date.t(), Data.seconds()) :: [Edge.t()]
  defp edges(stop_id, date, seconds) do
    walk_edges =
      Data.walk_edges(stop_id)
      |> Enum.map(
        &%Edge{
          from_stop_id: &1.from_stop_id,
          to_stop_id: &1.to_stop_id,
          from_departure: seconds,
          to_arrival: seconds + &1.distance
        }
      )

    ride_edges =
      Data.service_ids(date)
      |> Data.ride_edges(stop_id)
      |> Enum.group_by(& &1.to_stop_id)
      |> Map.new(fn {to_stop_id, rides} ->
        {to_stop_id,
         rides
         |> Enum.filter(&(&1.from_departure > seconds))
         |> Enum.min_by(& &1.to_arrival, fn -> nil end)}
      end)
      |> Map.values()
      |> Enum.filter(&(&1 != nil))
      |> Enum.map(&struct(Edge, &1))

    walk_edges ++ ride_edges
  end

  defp normalize_datetime(%DateTime{} = dt) do
    date = DateTime.to_date(dt)
    seconds = dt.hour * 3600 + dt.minute * 60 + dt.second
    {date, seconds}
  end
end
