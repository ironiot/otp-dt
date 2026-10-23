alias TranslinkDb.Query.{Data, TimeUtils}

defmodule TranslinkDb.Query.BestRoute do
  defmodule Edge do
    defstruct [:from_stop_id, :to_stop_id, :from_departure, :to_arrival, :trip_id]

    @type t :: %Edge{
            from_stop_id: Data.stop_id(),
            to_stop_id: Data.stop_id(),
            from_departure: Data.seconds(),
            to_arrival: Data.seconds(),
            # nil == walking
            trip_id: Data.trip_id() | nil
          }

    def display(
          %Edge{
            from_stop_id: from_stop_id,
            to_stop_id: to_stop_id,
            from_departure: from_departure,
            to_arrival: to_arrival,
            trip_id: trip_id
          },
          date
        ) do
      %{
        from: Data.stop_name(from_stop_id),
        to: Data.stop_name(to_stop_id),
        departure: date |> TimeUtils.join(from_departure) |> TimeUtils.humanize(),
        duration: TimeUtils.humanize(to_arrival - from_departure),
        via:
          case trip_id do
            nil -> "Walking"
            id -> Data.trip_headsign(id)
          end
      }
    end

    def display(msg, _) when is_binary(msg), do: msg
  end

  defmodule Node do
    defstruct [:best_arrival, :stop_id, :prev]

    @type t :: %Node{
            best_arrival: Data.seconds(),
            stop_id: Data.stop_id(),
            prev: %{node: t(), edge: Edge.t()} | nil
          }

    @spec construct_path(t()) :: [Edge.t()]
    def construct_path(node) do
      construct_path(node, [])
    end

    defp construct_path(%Node{prev: nil}, acc) do
      acc
    end

    defp construct_path(%Node{prev: prev}, []) do
      construct_path(prev.node, [prev.edge])
    end

    defp construct_path(
           %Node{prev: prev},
           acc = [
             %Edge{
               trip_id: trip_id,
               to_stop_id: to_stop_id,
               from_departure: from_departure,
               to_arrival: to_arrival
             }
             | rest
           ]
         ) do
      construct_path(
        prev.node,
        if trip_id == prev.edge.trip_id do
          # same trip, combine
          [
            %Edge{
              trip_id: trip_id,
              from_stop_id: prev.edge.from_stop_id,
              to_stop_id: to_stop_id,
              from_departure: prev.edge.from_departure,
              to_arrival: to_arrival
            }
            | rest
          ]
        else
          case from_departure - prev.edge.to_arrival do
            0 ->
              [prev.edge | acc]

            seconds ->
              [
                prev.edge,
                "Wait #{TimeUtils.humanize(seconds)}"
                | acc
              ]
          end
        end
      )
    end
  end

  defmodule NodePQ do
    defstruct [
      # for loop up by id
      :map,
      # for fast min removal
      :queue,
      # there's no fast way to remove from a PQ,
      # so changing priority means inserting a new entry
      # and marking the old one as stale
      :stale
    ]

    @type t :: %NodePQ{
            map: %{Data.stop_id() => Node.t()},
            queue: PriorityQueue.t(),
            stale: MapSet.t()
          }

    @spec new() :: t()
    def new() do
      %NodePQ{
        map: Map.new(),
        queue: PriorityQueue.new(),
        stale: MapSet.new()
      }
    end

    @spec update(Node.t(), t()) :: t()
    def update(
          node = %Node{stop_id: stop_id, best_arrival: best_arrival},
          priority_queue = %NodePQ{map: map, queue: queue, stale: stale}
        ) do
      case Map.fetch(map, stop_id) do
        :error ->
          %NodePQ{
            map: map |> Map.put(stop_id, node),
            queue: queue |> PriorityQueue.put(best_arrival, node),
            stale: stale
          }

        {:ok, old_node} ->
          if best_arrival < old_node.best_arrival do
            %NodePQ{
              map: map |> Map.put(stop_id, node),
              queue: queue |> PriorityQueue.put(best_arrival, node),
              stale: stale |> MapSet.put(old_node)
            }
          else
            priority_queue
          end
      end
    end

    @spec pop(t()) :: {Node.t(), t()} | :empty
    def pop(%NodePQ{map: map, queue: queue, stale: stale}) do
      case PriorityQueue.pop(queue) do
        {{nil, nil}, _} ->
          :empty

        {{_best_arrival, popped_node}, new_queue} ->
          new_priority_queue = %NodePQ{map: map, queue: new_queue, stale: stale}

          if MapSet.member?(stale, popped_node) do
            pop(new_priority_queue)
          else
            {popped_node, new_priority_queue}
          end
      end
    end
  end

  def find(from, to, time \\ {:departure, DateTime.now!("Canada/Pacific")})

  def find(from, to, {:departure, departure}) do
    with {:ok, from_stop_ids} <- resolve_stop_id(from),
         {:ok, to_stop_ids} <- resolve_stop_id(to) do
      {depature_date, depature_seconds} = TimeUtils.split(departure)
      # TODO: handle overnight trips. For now only the departure date counts.
      # (It'll miss overnight service from the previous day, or if
      # the departure is late at night, services on the next day.)
      date_services = Data.date_services(depature_date)

      current = %Node{
        stop_id: List.first!(from_stop_ids),
        best_arrival: depature_seconds,
        prev: nil
      }

      priority_queue =
        from_stop_ids
        |> Enum.map(
          &%Node{
            stop_id: &1,
            best_arrival: depature_seconds,
            prev: nil
          }
        )
        |> Enum.reduce(NodePQ.new(), &NodePQ.update/2)

      case search(current, priority_queue, to_stop_ids, date_services) do
        :no_path ->
          "No path"

        [] ->
          %{
            travel_time: "0s",
            route: [],
            arrival: TimeUtils.humanize(departure)
          }

        edges ->
          departure = List.first!(edges).from_departure
          arrival = List.last!(edges).to_arrival

          %{
            travel_time: TimeUtils.humanize(arrival - departure),
            arrival: depature_date |> TimeUtils.join(arrival) |> TimeUtils.humanize(),
            itinerary: edges |> Enum.map(&Edge.display(&1, depature_date))
          }
      end
    end
  end

  def find(_from, _to, {:arrival, _arrival}) do
    {:error, "TODO: support querying by arrival time"}
  end

  defp search(
         current = %Node{stop_id: stop_id, best_arrival: best_arrival},
         priority_queue,
         to_stop_ids,
         date_services
       ) do
    if stop_id in to_stop_ids do
      Node.construct_path(current)
    else
      stop_id
      |> edges(date_services, best_arrival)
      |> Enum.map(
        &%Node{
          best_arrival: &1.to_arrival,
          stop_id: &1.to_stop_id,
          prev: %{node: current, edge: &1}
        }
      )
      |> Enum.reduce(priority_queue, &NodePQ.update/2)
      |> NodePQ.pop()
      |> then(
        &case &1 do
          {next, next_pq} -> search(next, next_pq, to_stop_ids, date_services)
          :empty -> :no_path
        end
      )
    end
  end

  @spec resolve_stop_id(integer() | String.t()) :: {:ok, [Data.stop_id()]} | {:error, String.t()}

  defp resolve_stop_id(code) when is_integer(code) do
    case Data.stop_id_by_code(code) do
      nil -> {:error, "Stop code #{code} does not exist"}
      stop_id -> {:ok, [stop_id]}
    end
  end

  defp resolve_stop_id(name) when is_binary(name) do
    case Data.stop_ids_by_name(name) do
      [] -> {:error, "Unknown stop name #{name}"}
      stop_ids -> {:ok, stop_ids}
    end
  end

  @spec edges(Data.stop_id(), [Data.service_id()], Data.seconds()) :: [Edge.t()]
  defp edges(stop_id, services, seconds) do
    ride_edges =
      services
      |> Data.ride_edges(stop_id)
      |> Enum.map(&struct(Edge, &1))

    walk_edges =
      stop_id
      |> Data.walk_edges()
      |> Enum.map(
        &%Edge{
          from_stop_id: &1.from_stop_id,
          to_stop_id: &1.to_stop_id,
          from_departure: seconds,
          to_arrival: seconds + &1.distance
        }
      )

    (ride_edges ++ walk_edges)
    |> Enum.group_by(& &1.to_stop_id)
    |> Map.new(fn {to_stop_id, rides} ->
      {to_stop_id,
       rides
       |> Enum.filter(&(&1.from_departure >= seconds))
       |> Enum.min_by(& &1.to_arrival, fn -> nil end)}
    end)
    |> Map.values()
    |> Enum.filter(&(&1 != nil))
  end
end
