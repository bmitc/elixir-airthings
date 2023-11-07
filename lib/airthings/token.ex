defmodule Airthings.Token do
  @moduledoc """
  Datatype for an authentication token
  """

  @enforce_keys [:token, :duration_s, :created]
  defstruct @enforce_keys

  @typedoc """
  Represents a token
  """
  @type t() :: %__MODULE__{
          token: String.t(),
          duration_s: non_neg_integer,
          created: DateTime.t()
        }

  @doc """
  Creates a new token
  """
  @spec new(String.t(), non_neg_integer | String.t()) :: __MODULE__.t()
  def new(token, duration_s)
      when is_binary(token) and is_integer(duration_s) and duration_s >= 0 do
    %__MODULE__{
      token: token,
      duration_s: duration_s,
      created: DateTime.utc_now(:second)
    }
  end

  def new(token, duration_s) when is_binary(token) and is_binary(duration_s) do
    new(token, String.to_integer(duration_s))
  end
end
