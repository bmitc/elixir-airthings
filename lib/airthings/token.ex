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
  def new(token_string, duration_s)
      when is_binary(token_string) and is_integer(duration_s) and duration_s >= 0 do
    %__MODULE__{
      token: token_string,
      duration_s: duration_s,
      created: DateTime.utc_now(:second)
    }
  end

  def new(token, duration_s) when is_binary(token) and is_binary(duration_s) do
    new(token, String.to_integer(duration_s))
  end

  @doc """
  Checks whether the token is about to expire or not. This is determined by
  if the elapsed time since the token's creation is greater than 90% of its
  duration. If so, then the token is considered as about to expire. At the
  time of writing, the token's duration is 3 hours = 10,800 seconds.
  """
  @spec about_to_expire?(__MODULE__.t()) :: boolean
  def about_to_expire?(token) do
    time_now = DateTime.utc_now(:second)

    time_elapsed_s = Time.diff(time_now, token.created, :second)
    time_elapsed_s >= token.duration_s * 0.9
  end
end
