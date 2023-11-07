defmodule Airthings.Samples do
  @moduledoc """
  Datatype for an Airthings device's latest samples from all of its sensors
  """

  alias Airthings.Utilities

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
    |> Utilities.transform(:radonShortTermAvg, fn _ -> :radon end, &Function.identity/1)
    |> Utilities.transform(:temp, fn _ -> :temperature end, &Function.identity/1)
    |> Utilities.transform(:time, fn _ -> :datetime end, fn time ->
      {:ok, datetime} = DateTime.from_unix(time)
      datetime
    end)
    |> Utilities.to_struct(__MODULE__)
  end
end
