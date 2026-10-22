alias TranslinkDb.Query.Data

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
             %Edge{trip_id: trip_id, to_stop_id: to_stop_id, to_arrival: to_arrival}
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
          [prev.edge | acc]
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
          if stale |> MapSet.member?(popped_node) do
            pop(%NodePQ{
              map: map,
              queue: new_queue,
              stale: stale
            })
          else
            {popped_node,
             %NodePQ{
               map: map,
               queue: new_queue,
               stale: stale
             }}
          end
      end
    end
  end

  def find(
        # TODO: support querying by station
        {:stop, from_code},
        {:stop, to_code},
        # TODO: support querying by arrival time
        {:departure, departure} \\ {:departure, DateTime.now!("Canada/Pacific")}
      ) do
    # TODO: error handling
    {:ok, from_stop_id} = Data.stop_id_by_code(from_code)
    {:ok, to_stop_id} = Data.stop_id_by_code(to_code)

    {depature_date, depature_seconds} = TimeUtils.split(departure)
    # TODO: handle overnight trips. For now only the departure date counts.
    # (It'll miss overnight service from the previous day, or if
    # the departure is late at night, services on the next day.)
    date_services = Data.date_services(depature_date)

    current = %Node{
      best_arrival: depature_seconds,
      stop_id: from_stop_id,
      prev: nil
    }

    search = fn self, current, priority_queue ->
      if current.stop_id == to_stop_id do
        edges = Node.construct_path(current)

        if Enum.count(edges) == 0 do
          %{
            travel_time: "0s",
            route: [],
            arrival: TimeUtils.humanize(departure)
          }
        else
          departure = List.first(edges).from_departure
          arrival = List.last(edges).to_arrival

          %{
            travel_time: TimeUtils.humanize(arrival - departure),
            route: edges |> Enum.map(&Edge.display(&1, depature_date)),
            arrival: depature_date |> TimeUtils.join(arrival) |> TimeUtils.humanize()
          }
        end
      else
        current.stop_id
        |> edges(date_services, current.best_arrival)
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
            {next, next_pq} -> self.(self, next, next_pq)
            :empty -> "No path"
          end
        )
      end
    end

    search.(search, current, NodePQ.new())
  end

  @spec edges(Data.stop_id(), [Data.service_id()], Data.seconds()) :: [Edge.t()]
  defp edges(stop_id, services, seconds) do
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

    ride_edges =
      services
      |> Data.ride_edges(stop_id)
      |> Enum.map(&struct(Edge, &1))

    (walk_edges ++ ride_edges)
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

defmodule TimeUtils do
  @spec split(DateTime.t()) :: {Date.t(), Data.seconds()}
  def split(dt) do
    date =
      dt
      |> DateTime.shift_zone!("Canada/Pacific")
      |> DateTime.to_date()

    seconds = dt.hour * 3600 + dt.minute * 60 + dt.second
    {date, seconds}
  end

  @spec join(Date.t(), Data.seconds()) :: DateTime.t()
  def join(date, seconds) do
    date
    |> DateTime.new!(~T[00:00:00], "Canada/Pacific")
    |> DateTime.add(seconds, :second)
  end

  @spec humanize(Data.seconds()) :: String.t()
  def humanize(seconds) when is_integer(seconds) do
    minutes = Integer.floor_div(seconds, 60)
    seconds = seconds - minutes * 60
    hours = Integer.floor_div(minutes, 60)
    minutes = minutes - hours * 60

    hours = if(hours == 0, do: "", else: "#{hours}h ")
    minutes = if(minutes == 0, do: "", else: "#{minutes}m ")
    seconds = if(seconds == 0, do: "", else: "#{seconds}s")

    String.trim("#{hours}#{minutes}#{seconds}")
  end

  @spec humanize(DateTime.t()) :: String.t()
  def humanize(datetime) do
    datetime |> DateTime.to_naive() |> NaiveDateTime.to_string()
  end
end
