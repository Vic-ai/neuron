defmodule NeuronTest do
  use ExUnit.Case

  import Mox

  setup :verify_on_exit!

  setup do
    url = "www.example.com/graph"
    Neuron.Config.set(nil)
    Neuron.Config.set(url: url)
    %{url: url}
  end

  describe "json_library/0" do
    test "Test that the default JSON library is Jason" do
      assert Neuron.ConfigUtils.json_library() == Jason
    end
  end

  describe "query/1" do
    for json_library <- [Jason, JSON] do
      test "calls the connection with correct query string using #{json_library}" do
        json_library = unquote(json_library)
        Neuron.Config.set(json_library: json_library)
        Neuron.Config.set(connection_module: Neuron.ConnectionMock)

        expected_body = json_library.encode!(%{query: "{ users { name } }", variables: %{}})

        expect(Neuron.ConnectionMock, :call, fn body, options ->
          assert body == expected_body
          assert options == []
          {:ok, %Neuron.Response{body: %{"data" => %{"users" => []}}, status_code: 200}}
        end)

        assert {:ok, %Neuron.Response{}} = Neuron.query("{ users { name } }")
      end
    end
  end

  describe "query/2" do
    for json_library <- [Jason, JSON] do
      test "it takes all configs as arguments using #{json_library}" do
        json_library = unquote(json_library)
        url = "www.example.com/another/graph"
        headers = ["X-test-header": "my_header"]
        connection_opts = [timeout: 50_000]

        expected_body = json_library.encode!(%{query: "{ users { name } }", variables: %{}})

        expected_options = [
          url: url,
          headers: headers,
          connection_opts: connection_opts,
          json_library: json_library,
          connection_module: Neuron.ConnectionMock
        ]

        expect(Neuron.ConnectionMock, :call, fn body, options ->
          assert body == expected_body
          assert options == expected_options
          {:ok, %Neuron.Response{body: %{"data" => %{"users" => []}}, status_code: 200}}
        end)

        assert {:ok, %Neuron.Response{}} =
                 Neuron.query("{ users { name } }", %{}, expected_options)
      end
    end
  end
end
