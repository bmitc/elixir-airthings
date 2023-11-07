defmodule Airthings do
  @moduledoc """
  An Airthings HTTP API client server. Retrieves data, such as devices, locations,
  latest samples for a device, etc. from the Airthings server for a specific API
  application. Automatically handles all internal token creation and authentication.
  """

  use GenServer

  alias Airthings.Client
  alias Airthings.Device
  alias Airthings.Location
  alias Airthings.Samples
  alias Airthings.Token

  @enforce_keys [:client_id, :client_secret, :token, :client]
  defstruct @enforce_keys

  # Represents the internal state of the Airthings GenServer
  @typep t() :: %__MODULE__{
           client_id: String.t(),
           client_secret: String.t(),
           token: Token.t(),
           client: Tesla.Client.t()
         }

  ############################################################
  #### Public API ############################################
  ############################################################

  @doc """
  Start an Airthings server. The server will automatically handle all token
  refreshing and authentication using the provided client ID and secret. Use
  the PID to call the request functions to retrieve data.
  """
  @spec start_link(String.t(), String.t()) :: GenServer.on_start()
  def start_link(client_id, client_secret) do
    GenServer.start_link(__MODULE__, [client_id, client_secret])
  end

  @doc """
  Gets all devices associated with the client ID
  """
  @spec get_devices(pid) :: {:ok, [Device.t()]} | {:error, any} | any
  def get_devices(pid) do
    GenServer.call(pid, :get_devices)
  end

  @doc """
  Gets all locations associated with the client ID
  """
  @spec get_locations(pid) :: {:ok, [Location.t()]} | {:error, any} | any
  def get_locations(pid) do
    GenServer.call(pid, :get_locations)
  end

  @doc """
  Gets latest samples for the given device or device ID
  """
  @spec get_latest_samples(pid, Device.t() | non_neg_integer) ::
          {:ok, Samples.t()} | {:error, any} | any
  def get_latest_samples(pid, %Device{id: id}) do
    GenServer.call(pid, {:get_latest_samples, id})
  end

  def get_latest_samples(pid, device_id) when is_integer(device_id) and device_id >= 0 do
    GenServer.call(pid, {:get_latest_samples, device_id})
  end

  @spec get_passthrough(pid, String.t()) :: {:ok, map} | {:error, any} | any
  def get_passthrough(pid, endpoint) when is_binary(endpoint) do
    GenServer.call(pid, {:get_passthrough, endpoint})
  end

  ############################################################
  #### GenServer callbacks ###################################
  ############################################################

  @impl GenServer
  def init([client_id, client_secret]) do
    {client, token} = Client.new(client_id, client_secret, return_token: true)

    state = %__MODULE__{
      client_id: client_id,
      client_secret: client_secret,
      token: token,
      client: client
    }

    # Schedule the periodic token check that will handle refreshing a token
    # outside of a request being made. All requests will also retry one time
    # after first refreshing the token if the token is expired.
    schedule_token_check()

    {:ok, state}
  end

  @impl GenServer
  def handle_info(:check_token, state) do
    schedule_token_check()
    {:noreply, check_token(state)}
  end

  @impl GenServer
  def handle_call(request, _from, state) do
    response = get_response(request, state)

    # If the request failed due to an expired token, the request is retried
    # one time after the token is refreshed.
    {state, response} =
      if should_retry?(response) do
        # Refresh the token by getting a new one
        state = refresh_token(state)

        # Retry the request
        response = get_response(request, state)
        {state, response}
      else
        {state, response}
      end

    {:reply, response, state}
  end

  ############################################################
  #### Private functions #####################################
  ############################################################

  # Handles getting the response for the given request. This allows the `handle_call`
  # function to be made completely generic and independent of the specific request
  # and its specific response.
  @spec get_response(request :: any, __MODULE__.t()) :: any
  defp get_response(:get_devices, state), do: Client.get_devices(state.client)
  defp get_response(:get_locations, state), do: Client.get_locations(state.client)

  defp get_response({:get_latest_samples, device_id}, state),
    do: Client.get_latest_samples(state.client, device_id)

  defp get_response({:get_passthrough, endpoint}, state),
    do: Client.get_passthrough(state.client, endpoint)

  # Determines if the request should be retried due to the token
  # being expired, which is determined by receive an status response
  # code of 401. Although the token is periodically checked, this hedges
  # against the case where the periodic check has failed or hasn't run
  # yet after the token expired, which is possible if the token's duration
  # is close to the period of the check token check.
  @spec should_retry?({:error, Tesla.Env.result()}) :: boolean
  defp should_retry?({:error, %{status: 401}}), do: true
  defp should_retry?(_), do: false

  # Refreshes the internal token by creating a fresh client, which internally
  # fetches a new token
  @spec refresh_token(__MODULE__.t()) :: __MODULE__.t()
  defp refresh_token(state) do
    {new_client, new_token} =
      Client.new(state.client_id, state.client_secret, return_token: true)

    %__MODULE__{state | token: new_token, client: new_client}
  end

  # Checks the internal token's state by comparing its duration to when it
  # was created. If it is close to expiring, refresh the token.
  @spec check_token(__MODULE__.t()) :: __MODULE__.t()
  defp check_token(state) do
    if Token.about_to_expire?(state.token) do
      refresh_token(state)
    else
      state
    end
  end

  # Schedules an internal process message to check on the token's state
  # every 1 minute. The period could be calculated based upon the token's
  # duration, but instead, we just check every minute. If the token expires
  # within that minute, then there is a retry mechanism. At the time of
  # writing, the token's duration is 3 hours = 10,800 seconds.
  @spec schedule_token_check() :: reference
  defp schedule_token_check() do
    Process.send_after(self(), :check_token, :timer.minutes(1))
  end
end
