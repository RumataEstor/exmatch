defmodule ExMatchTest.Dummy do
  defstruct [:a, :b, :c]

  def id(value), do: value
end

defmodule ExMatchTest.Dummy1 do
  defstruct [:a, :b, :c]
end

defmodule Order do
  use Ecto.Schema
  schema "orders" do
    field :price, :decimal
    timestamps type: :utc_datetime_usec
  end
end
