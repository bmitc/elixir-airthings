defmodule Airthings do
  @moduledoc """
  Airthings HTTP API client
  """

  alias Airthings.Location
  alias Airthings.Device
  alias Airthings.Samples

  use Tesla

  adapter(Tesla.Adapter.Hackney)

  plug(
    Tesla.Middleware.BaseUrl,
    "https://ext-api.airthings.com/v1"
  )

  plug(Tesla.Middleware.BasicAuth, username: @client_id, password: @client_secret)

  plug(Tesla.Middleware.JSON)

  ############################################################
  #### Types #################################################
  ############################################################

  ############################################################
  #### Public functions ######################################
  ############################################################

  @client_id ""
  @client_secret ""

  def new() do
    Tesla.client([
      {Tesla.Middleware.BearerAuth, token: get_token()}
    ])
  end

  def get_token() do
    with {:ok, %{status: 200} = response} <-
           post("https://accounts-api.airthings.com/v1/token", %{
             grant_type: "client_credentials",
             scope: ["read:device:current_values"]
           }) do
      response.body["access_token"]
    end
  end

  @spec get_devices(Tesla.Client.t()) :: {:ok, [Device.t()]} | {:error, any()} | any()
  def get_devices(client) do
    with {:ok, %{status: 200} = response} <- get(client, "/devices") do
      response.body["devices"]
      |> Enum.map(&Device.parse/1)
    else
      {:ok, error} -> {:error, error}
      error -> error
    end
  end

  @spec get_locations(Tesla.Client.t()) :: {:ok, [Location.t()]} | {:error, any()} | any()
  def get_locations(client) do
    with {:ok, %{status: 200} = response} <- get(client, "/locations") do
      response.body["locations"]
      |> Enum.map(&Location.parse/1)
    else
      {:ok, error} -> {:error, error}
      error -> error
    end
  end

  def get_latest_samples(client, %Device{id: id} = device) when is_map(device) do
    get_latest_samples(client, id)
  end

  def get_latest_samples(client, id) when is_integer(id) and id >= 0 do
    with {:ok, %{status: 200} = response} <- get(client, "/devices/#{id}/latest-samples") do
      response.body["data"]
      |> Samples.parse()
    else
      {:ok, error} -> {:error, error}
      error -> error
    end
  end

  ############################################################
  #### Private functions #####################################
  ############################################################
end
