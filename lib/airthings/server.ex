defmodule Airthings.Server do
  use GenServer

  alias Airthings.Token

  @enforce_keys [:client_id, :client_secret, :token, :client]
  defstruct @enforce_keys

  @type t() :: %__MODULE__{
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

  ############################################################
  #### GenServer callbacks ###################################
  ############################################################

  @impl GenServer
  def init([client_id, client_secret]) do
    {client, token} = Airthings.new(client_id, client_secret, return_token: true)

    state = %__MODULE__{
      client_id: client_id,
      client_secret: client_secret,
      token: token,
      client: client
    }

    schedule_token_check()

    {:ok, state}
  end

  @impl GenServer
  def handle_info(:check_token, state) do
    IO.inspect(state.token, label: "Checking token")
    schedule_token_check()
    {:noreply, check_token(state)}
  end

  @impl GenServer
  def handle_call(:get_devices, _from, state) do
    response = Airthings.get_devices(state.client)

    {state, response} =
      if should_retry?(response) do
        state = refresh_token(state)
        response = Airthings.get_devices(state.client)
        {state, response}
      else
        {state, response}
      end

    {:reply, response, state}
  end

  ############################################################
  #### Private functions #####################################
  ############################################################

  # Determines if the request should be retried due to the token
  # being expired, which is determined by receive an status response
  # code of 401. Although the token is periodically checked, this hedges
  # against the case where the periodic check has failed or hasn't run
  # yet after the token expired, which is possible if the token's duration
  # is close to the period of the check token check.
  defp should_retry?({:error, %{status: 401}}), do: true
  defp should_retry?(_), do: false

  # Refreshes the internal token by creating a fresh client
  @spec refresh_token(__MODULE__.t()) :: __MODULE__.t()
  defp refresh_token(state) do
    {new_client, new_token} =
      Airthings.new(state.client_id, state.client_secret, return_token: true)

    %__MODULE__{state | token: new_token, client: new_client}
  end

  # Checks the internal token's state by comparing it's duration to when it
  # was created. If it is close to expiring, refresh the token.
  @spec check_token(__MODULE__.t()) :: __MODULE__.t()
  defp check_token(state) do
    token_duration_s = state.token.duration_s
    token_created = state.token.created
    time_now = DateTime.utc_now(:second)

    time_elapsed_s = Time.diff(time_now, token_created, :second)
    token_about_to_expire? = time_elapsed_s >= token_duration_s * 0.9

    if token_about_to_expire? do
      refresh_token(state)
    else
      state
    end
  end

  # Schedules an internal process message to check on the token's state
  # every 1 minute
  defp schedule_token_check() do
    Process.send_after(self(), :check_token, :timer.minutes(1))
  end
end
