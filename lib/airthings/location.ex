defmodule Airthings.Location do
  @enforce_keys [:id, :name]
  defstruct @enforce_keys

  @typedoc """
  Represents a location
  """
  @type t() :: %__MODULE__{
          id: String.t(),
          name: String.t()
        }

  @doc """
  Creates a new location
  """
  @spec new(String.t(), String.t()) :: __MODULE__.t()
  def new(id, name) do
    %__MODULE__{
      id: id,
      name: name
    }
  end

  @spec parse(map()) :: __MODULE__.t()
  def parse(location) do
    %__MODULE__{
      id: location["id"],
      name: location["name"]
    }
  end
end
