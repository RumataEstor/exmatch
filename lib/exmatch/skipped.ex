defmodule ExMatch.Skipped do
  defstruct [:num]

  def new(num) when is_integer(num) and num > 0,
    do: %__MODULE__{num: num}

  def list(num) when is_integer(num) do
    case num do
      0 -> []
      _ when num > 0 -> [%__MODULE__{num: num}]
    end
  end

  defimpl Inspect do
    alias ExMatch.Skipped

    def inspect(%Skipped{num: 1}, _opts) do
      ".."
    end

    def inspect(%Skipped{num: num}, _opts) do
      "..#{inspect(num)}.."
    end
  end
end
