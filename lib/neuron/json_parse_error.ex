defmodule Neuron.JSONParseError do
  @moduledoc """
  Struct representation of a JSON parse error.
  """

  alias Neuron.Response

  # The error shape depends on the configured json_library: Jason returns an
  # exception struct, the built-in JSON module returns a tuple such as
  # {:invalid_byte, 0, 60}.
  @type t :: %Neuron.JSONParseError{error: term(), response: Response.t()}

  defstruct response: %Response{},
            error: nil
end
