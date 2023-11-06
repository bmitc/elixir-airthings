defmodule Airthings.Client do
  @moduledoc """
  Airthings HTTP API client
  """

  use Tesla

  alias Airthings.Device
  alias Airthings.Location
  alias Airthings.Samples
  alias Airthings.Token

  adapter(Tesla.Adapter.Hackney)

  plug(Tesla.Middleware.BaseUrl, "https://ext-api.airthings.com/v1")
  plug(Tesla.Middleware.JSON)

  ############################################################
  #### Public functions ######################################
  ############################################################

  @doc """
  Creates a new client to use for calling Airthings HTTP API client functions. Retrieves
  an authorization token using the given client ID and secret.
  """
  @spec new(String.t(), String.t()) :: Tesla.Client.t()
  def new(client_id, client_secret) do
    {client, _token} = new(client_id, client_secret, return_token: true)
    client
  end

  def new(client_id, client_secret, return_token: true) do
    {:ok, token} = get_token(client_id, client_secret)

    client =
      Tesla.client([
        {Tesla.Middleware.BearerAuth, token: token.token}
      ])

    {client, token}
  end

  @spec get_token(String.t(), String.t()) :: {:ok, Token.t()} | {:error, any} | any
  def get_token(client_id, client_secret) do
    with {:ok, %{status: 200} = response} <-
           post("https://accounts-api.airthings.com/v1/token", %{
             grant_type: "client_credentials",
             scope: ["read:device:current_values"],
             client_id: client_id,
             client_secret: client_secret
           }) do
      {:ok, Token.new(response.body["access_token"], response.body["expires_in"])}
    else
      {:ok, error} -> {:error, error}
      error -> error
    end
  end

  @spec get_devices(Tesla.Client.t()) :: {:ok, [Device.t()]} | {:error, any} | any
  def get_devices(client) do
    with {:ok, %{status: 200} = response} <- get(client, "/devices") do
      {:ok, Enum.map(response.body["devices"], &Device.parse/1)}
    else
      {:ok, error} -> {:error, error}
      error -> error
    end
  end

  @spec get_locations(Tesla.Client.t()) :: {:ok, [Location.t()]} | {:error, any} | any
  def get_locations(client) do
    with {:ok, %{status: 200} = response} <- get(client, "/locations") do
      {:ok, Enum.map(response.body["locations"], &Location.parse/1)}
    else
      {:ok, error} -> {:error, error}
      error -> error
    end
  end

  @spec get_latest_samples(Tesla.Client.t(), Device.t() | non_neg_integer) ::
          {:ok, Samples.t()} | {:error, any} | any
  def get_latest_samples(client, %Device{id: id} = device) when is_map(device) do
    get_latest_samples(client, id)
  end

  def get_latest_samples(client, id) when is_integer(id) and id >= 0 do
    with {:ok, %{status: 200} = response} <- get(client, "/devices/#{id}/latest-samples") do
      {:ok, Samples.parse(response.body["data"])}
    else
      {:ok, error} -> {:error, error}
      error -> error
    end
  end

  @doc """
  This get function is just a simple passthrough of the response for the given endpoint. This is useful
  for when there's an endpoint that doesn't have a bespoke function created for it or if a user wants
  to see the entire response returned.
  """
  @spec get_passthrough(Tesla.Client.t(), String.t()) ::
          {:ok, Tesla.Env.t()} | {:error, any} | any
  def get_passthrough(client, endpoint) when is_binary(endpoint) do
    with {:ok, %{status: 200} = response} <- get(client, endpoint) do
      {:ok, response}
    else
      {:ok, error} -> {:error, error}
      error -> error
    end
  end
end
