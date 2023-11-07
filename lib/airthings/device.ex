defmodule Airthings.Device do
  @moduledoc """
  Datatype for an Airthings device
  """

  alias Airthings.Location

  @enforce_keys [:type, :id, :location, :product_name, :sensors]
  defstruct @enforce_keys

  @typedoc """
  Represents a device
  """
  @type t() :: %__MODULE__{
          type: String.t(),
          id: non_neg_integer,
          location: Location.t(),
          product_name: String.t(),
          sensors: [String.t()]
        }

  @spec parse(map()) :: __MODULE__.t()
  def parse(device) do
    %__MODULE__{
      type: device["deviceType"],
      id: String.to_integer(device["id"]),
      location: Location.parse(device["location"]),
      product_name: device["productName"],
      sensors: device["sensors"]
    }
  end
end
