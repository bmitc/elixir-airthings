defmodule Airthings.Samples do
  defstruct [
    :battery,
    :co2,
    :humidity,
    :pm1,
    :pm25,
    :pressure,
    :radon,
    :temperature,
    :datetime,
    :voc
  ]

  @typedoc """
  Represents a collection of samples for a single device
  """
  @type t() :: %__MODULE__{
          battery: non_neg_integer,
          co2: non_neg_integer,
          humidity: non_neg_integer,
          pm1: non_neg_integer,
          pm25: non_neg_integer,
          pressure: non_neg_integer,
          radon: non_neg_integer,
          temperature: non_neg_integer,
          datetime: DateTime.t(),
          voc: non_neg_integer
        }

  @spec parse(map()) :: __MODULE__.t()
  def parse(samples) do
    samples
    |> Map.new(fn {key, value} -> {String.to_atom(key), value} end)
    |> Map.delete(:relayDeviceType)
    |> transform(:radonShortTermAvg, fn _ -> :radon end, &Function.identity/1)
    |> transform(:temp, fn _ -> :temperature end, &Function.identity/1)
    |> transform(:time, fn _ -> :datetime end, fn time ->
      {:ok, datetime} = DateTime.from_unix(time)
      datetime
    end)
    |> to_struct(__MODULE__)
  end

  @spec transform(map, Map.key(), (any -> any), (any -> any)) :: map
  def transform(map, key, key_update_fn, value_update_fn) do
    if Map.has_key?(map, key) do
      new_value =
        map
        |> Map.get(key)
        |> value_update_fn.()

      new_key = key_update_fn.(key)

      map
      |> Map.delete(key)
      |> Map.put(new_key, new_value)
    else
      map
    end
  end

  def to_struct(map, module) do
    struct(module, map)
  end
end
