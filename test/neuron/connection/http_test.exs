defmodule Neuron.Connection.HttpTest do
  use ExUnit.Case

  alias Neuron.{
    Connection,
    JSONParseError,
    Response
  }

  @json_libraries [Jason, JSON]

  def build_response(status_code, body) do
    %{
      body: body,
      headers: [
        {"X-Powered-By", "Express"},
        {"Content-Type", "application/json; charset=utf-8"},
        {"Content-Length", "219"},
        {"ETag", "W/\"db-mvJgYYgL8rU//lf7M3zjvw\""},
        {"Date", "Sun, 28 May 2017 11:40:59 GMT"},
        {"Connection", "keep-alive"}
      ],
      status_code: status_code
    }
  end

  describe "post/2" do
    setup do
      Neuron.Config.set(nil)
      sham = Sham.start()

      %{
        sham: sham,
        url: "http://localhost:#{sham.port}/graph",
        query: ~s({"query": "{ users { name } }", "variables": {}})
      }
    end

    test "missing url raises", %{query: query} do
      assert_raise ArgumentError, "you need to supply an url", fn ->
        Connection.Http.post(query, url: nil, headers: [], connection_opts: [])
      end
    end

    test "sends the query with default and custom headers", %{
      sham: sham,
      url: url,
      query: query
    } do
      Sham.expect(sham, "POST", "/graph", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert body == query
        assert Plug.Conn.get_req_header(conn, "content-type") == ["application/json"]
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Basic dXNlcjpwYXNzd29yZA=="]
        Plug.Conn.resp(conn, 200, ~s({"data": {"users": []}}))
      end)

      headers = [Authorization: "Basic dXNlcjpwYXNzd29yZA=="]

      assert {:ok, %HTTPoison.Response{status_code: 200}} =
               Connection.Http.post(query, url: url, headers: headers, connection_opts: [])
    end

    test "passes custom connection options to the HTTP client", %{
      sham: sham,
      url: url,
      query: query
    } do
      # the :params option is applied by HTTPoison as the query string, so the
      # server observing it proves connection_opts reach the HTTP client
      Sham.expect(sham, "POST", "/graph", fn conn ->
        assert conn.query_string == "token=abc"
        Plug.Conn.resp(conn, 200, ~s({"data": null}))
      end)

      assert {:ok, %HTTPoison.Response{status_code: 200}} =
               Connection.Http.post(query,
                 url: url,
                 headers: [],
                 connection_opts: [params: [token: "abc"]]
               )
    end
  end

  describe "when successful response" do
    setup do
      %{
        response: build_response(200, ~s/{"data": {"users": []}}/)
      }
    end

    for json_library <- @json_libraries do
      test "returns the parsed Response struct using #{json_library}", %{response: response} do
        json_library = unquote(json_library)
        result = Connection.Http.handle_response({:ok, response}, json_library: json_library)

        expected_result = %Response{
          body: %{"data" => %{"users" => []}},
          headers: response.headers,
          status_code: response.status_code
        }

        assert result == {:ok, expected_result}
      end
    end

    # the built-in JSON module does not support parse options such as keys: :atoms
    for json_library <- [Jason] do
      test "returns the parsed Response struct with atom keys in the body map using #{json_library}",
           %{
             response: response
           } do
        json_library = unquote(json_library)

        result =
          Connection.Http.handle_response(
            {:ok, response},
            json_library: json_library,
            parse_options: [keys: :atoms]
          )

        expected_result = %Response{
          body: %{:data => %{:users => []}},
          headers: response.headers,
          status_code: response.status_code
        }

        assert result == {:ok, expected_result}
      end
    end
  end

  describe "when successful response but with errors in body" do
    setup do
      %{
        response: build_response(200, ~s/{"data": null, "errors": "stuff"}/)
      }
    end

    for json_library <- @json_libraries do
      test "returns the parsed Response struct using #{json_library}", %{
        response: response
      } do
        json_library = unquote(json_library)
        result = Connection.Http.handle_response({:ok, response}, json_library: json_library)

        expected_result = %Response{
          body: %{"data" => nil, "errors" => "stuff"},
          headers: response.headers,
          status_code: response.status_code
        }

        assert result == {:ok, expected_result}
      end
    end
  end

  describe "when response with != 200 status code" do
    setup do
      %{
        response:
          build_response(
            400,
            "{\"errors\":[{\"message\":\"Cannot query field \\\"nam\\\" on type \\\"User\\\". Did you mean \\\"name\\\"?\",\"locations\":[{\"line\":3,\"column\":11}]}]}"
          )
      }
    end

    for json_library <- @json_libraries do
      test "returns the parsed Response struct with errors using #{json_library}", %{
        response: response
      } do
        json_library = unquote(json_library)
        result = Connection.Http.handle_response({:ok, response}, json_library: json_library)

        expected_result = %Response{
          body: %{
            "errors" => [
              %{
                "locations" => [%{"column" => 11, "line" => 3}],
                "message" => "Cannot query field \"nam\" on type \"User\". Did you mean \"name\"?"
              }
            ]
          },
          headers: response.headers,
          status_code: response.status_code
        }

        assert result == {:error, expected_result}
      end
    end
  end

  describe "when error" do
    for json_library <- @json_libraries do
      test "returns the error using #{json_library}" do
        json_library = unquote(json_library)

        result =
          Connection.Http.handle_response({:error, "error message"}, json_library: json_library)

        assert result == {:error, "error message"}
      end
    end
  end

  describe "when response not json parsable" do
    for json_library <- @json_libraries do
      test "returns a JSONParseError using #{json_library}" do
        json_library = unquote(json_library)
        body = "<html><body>This is not the GraphQL URL</body></html>"
        raw_response = build_response(200, body)

        assert {:error, parse_error} =
                 Connection.Http.handle_response({:ok, raw_response}, json_library: json_library)

        assert is_map(parse_error)
        assert :maps.is_key(:__struct__, parse_error)
        assert :maps.get(:__struct__, parse_error) == JSONParseError

        assert %JSONParseError{error: error, response: response} = parse_error

        refute is_nil(error)
        assert is_map(response)
        assert :maps.is_key(:__struct__, response)
        assert :maps.get(:__struct__, response) == Response
      end
    end

    for json_library <- @json_libraries do
      test "includes a response struct for debugging using #{json_library}" do
        json_library = unquote(json_library)
        body = "<html><body>This is not the GraphQL URL</body></html>"
        raw_response = build_response(200, body)

        assert {_, %{response: %Response{} = response}} =
                 Connection.Http.handle_response({:ok, raw_response}, json_library: json_library)

        assert response.body == raw_response.body
        assert response.headers == raw_response.headers
      end
    end
  end
end
