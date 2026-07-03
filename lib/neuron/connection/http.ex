defmodule Neuron.Connection.Http do
  @moduledoc false
  @behaviour Neuron.Connection

  require Logger

  alias Neuron.{Config, ConfigUtils, JSONParseError, Response}

  @impl Neuron.Connection
  def call(query, options),
    do:
      query
      |> post(options)
      |> handle_response(options)

  def post(query, options),
    do:
      HTTPoison.post(
        options |> url() |> check_url(),
        query,
        build_headers(options),
        ConfigUtils.connection_options(options)
      )

  def handle_response(response, options) do
    json_library = ConfigUtils.json_library(options)
    parsed_options = ConfigUtils.parse_options(options)
    handle(response, json_library, parsed_options)
  end

  defp url(options), do: Keyword.get(options, :url) || Config.get(:url)

  defp check_url(nil), do: raise(ArgumentError, message: "you need to supply an url")
  defp check_url(url), do: url

  defp build_headers(options),
    do: Keyword.merge(["Content-Type": "application/json"], headers(options))

  defp headers(options), do: Keyword.get(options, :headers, Config.get(:headers) || [])

  defp handle(response, json_library, parse_options)

  defp handle({:ok, response}, json_library, parse_options) do
    case decode(json_library, response.body, parse_options) do
      {:ok, body} -> build_response_tuple(%{response | body: body})
      {:error, error} -> handle_unparsable(response, error)
      {:error, error, _} -> handle_unparsable(response, error)
    end
  end

  defp handle({:error, _} = response, _, _), do: response

  # Elixir's built-in JSON module (Elixir >= 1.18) has no decode/2 that
  # accepts parse options, so it gets a dedicated clause.
  defp decode(JSON, body, []), do: JSON.decode(body)

  defp decode(JSON, body, parse_options) do
    Logger.warning(
      "Neuron: parse_options #{inspect(parse_options)} are not supported by the built-in JSON module and will be ignored"
    )

    JSON.decode(body)
  end

  defp decode(json_library, body, parse_options), do: json_library.decode(body, parse_options)

  defp build_response_tuple(%{status_code: 200} = response) do
    {
      :ok,
      build_response(response)
    }
  end

  defp build_response_tuple(response) do
    {
      :error,
      build_response(response)
    }
  end

  defp build_response(response) do
    %Response{
      status_code: response.status_code,
      body: response.body,
      headers: response.headers
    }
  end

  defp handle_unparsable(response, error) do
    {
      :error,
      %JSONParseError{
        response: build_response(response),
        error: error
      }
    }
  end
end
