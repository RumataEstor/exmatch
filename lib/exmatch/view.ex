defprotocol ExMatch.View do
  @fallback_to_any true

  @spec inspect(t) :: iodata()
  def inspect(value)
end

defmodule ExMatch.View.Rendered do
  @moduledoc """
  Is used to displayed rendered view in diffs
  """

  @enforce_keys [:iodata]
  defstruct @enforce_keys

  @type t() :: %__MODULE__{iodata: iodata()}

  def new(iodata) do
    %__MODULE__{iodata: iodata}
  end

  defimpl Inspect do
    alias ExMatch.View.Rendered

    def inspect(%Rendered{iodata: iodata}, _opts) do
      IO.iodata_to_binary(iodata)
    end
  end

  defimpl ExMatch.View do
    alias ExMatch.View.Rendered

    def inspect(%Rendered{iodata: iodata}) do
      iodata
    end
  end
end

defimpl ExMatch.View, for: Any do
  def inspect(ast) do
    Macro.to_string(ast)
  end
end
