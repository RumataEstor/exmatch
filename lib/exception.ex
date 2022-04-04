defmodule ExMatch.Exception do
  defstruct [:class, :error, :stacktrace]

  def new(class, error, stacktrace) do
    %__MODULE__{class: class, error: error, stacktrace: stacktrace}
  end

  defimpl Inspect do
    alias ExMatch.Exception, as: Self

    def inspect(%Self{} = self, _opts) do
      Exception.format(self.class, self.error, self.stacktrace)
      |> String.trim()
    end
  end
end
