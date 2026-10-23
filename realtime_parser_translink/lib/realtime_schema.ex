defmodule TranslinkSchema do
  use Protox.Define,
    enums: [],
    messages: [
      %Protox.Message{
        name: TransitRealtime.FeedMessage,
        syntax: :proto2,
        fields: [
          Protox.Field.new!(tag: 1, label: :required, name: :header, kind: {:scalar, nil}, type: {:message, TransitRealtime.FeedHeader}),
          Protox.Field.new!(tag: 2, label: :repeated, name: :entity, kind: :unpacked, type: {:message, TransitRealtime.FeedEntity})
        ]
      },
      %Protox.Message{
        name: TransitRealtime.FeedHeader,
        syntax: :proto2,
        fields: [
          Protox.Field.new!(tag: 1, label: :required, name: :gtfs_realtime_version, kind: {:scalar, ""}, type: :string),
          Protox.Field.new!(tag: 3, label: :optional, name: :timestamp, kind: {:scalar, nil}, type: :uint64)
        ]
      },
      %Protox.Message{
        name: TransitRealtime.FeedEntity,
        syntax: :proto2,
        fields: [
          Protox.Field.new!(tag: 1, label: :required, name: :id, kind: {:scalar, ""}, type: :string),
          Protox.Field.new!(tag: 3, label: :optional, name: :trip_update, kind: {:scalar, nil}, type: {:message, TransitRealtime.TripUpdate})
        ]
      },
      %Protox.Message{
        name: TransitRealtime.TripUpdate,
        syntax: :proto2,
        fields: [
          Protox.Field.new!(tag: 1, label: :required, name: :trip, kind: {:scalar, nil}, type: {:message, TransitRealtime.TripDescriptor}),
          Protox.Field.new!(tag: 2, label: :repeated, name: :stop_time_update, kind: :unpacked, type: {:message, TransitRealtime.StopTimeUpdate}),
          Protox.Field.new!(tag: 3, label: :optional, name: :vehicle, kind: {:scalar, nil}, type: {:message, TransitRealtime.VehicleDescriptor})
        ]
      },
      %Protox.Message{
        name: TransitRealtime.TripDescriptor,
        syntax: :proto2,
        fields: [
          Protox.Field.new!(tag: 1, label: :optional, name: :trip_id, kind: {:scalar, nil}, type: :string),
          Protox.Field.new!(tag: 2, label: :optional, name: :start_time, kind: {:scalar, nil}, type: :string),
          Protox.Field.new!(tag: 3, label: :optional, name: :start_date, kind: {:scalar, nil}, type: :string),
          Protox.Field.new!(tag: 5, label: :optional, name: :route_id, kind: {:scalar, nil}, type: :string)
        ]
      },
      %Protox.Message{
        name: TransitRealtime.VehicleDescriptor,
        syntax: :proto2,
        fields: [
          Protox.Field.new!(tag: 1, label: :optional, name: :id, kind: {:scalar, nil}, type: :string),
          Protox.Field.new!(tag: 2, label: :optional, name: :label, kind: {:scalar, nil}, type: :string)
        ]
      },
      %Protox.Message{
        name: TransitRealtime.StopTimeUpdate,
        syntax: :proto2,
        fields: [
          Protox.Field.new!(tag: 1, label: :optional, name: :stop_sequence, kind: {:scalar, nil}, type: :uint32),
          Protox.Field.new!(tag: 2, label: :optional, name: :arrival, kind: {:scalar, nil}, type: {:message, TransitRealtime.StopTimeEvent}),
          Protox.Field.new!(tag: 3, label: :optional, name: :departure, kind: {:scalar, nil}, type: {:message, TransitRealtime.StopTimeEvent}),
          Protox.Field.new!(tag: 4, label: :optional, name: :stop_id, kind: {:scalar, nil}, type: :string)
        ]
      },
      %Protox.Message{
        name: TransitRealtime.StopTimeEvent,
        syntax: :proto2,
        fields: [
          Protox.Field.new!(tag: 1, label: :optional, name: :delay, kind: {:scalar, nil}, type: :int32),
          Protox.Field.new!(tag: 2, label: :optional, name: :time, kind: {:scalar, nil}, type: :int64)
        ]
      }
    ]
end