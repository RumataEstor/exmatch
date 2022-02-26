defmodule ExMatchTest do
  use ExUnit.Case
  require ExMatch

  # doctest ExMatch
  defmacrop sigil_m({:<<>>, _, [string]}, []) do
    decimal =
      string
      |> String.replace("_", "")
      |> Decimal.new()
      |> Macro.escape()

    quote do
      unquote(decimal)
    end
  end

  test "basic types" do
    ExMatch.match(1, 1)
    ExMatch.match(2.0, 2.0)
    ExMatch.match(:match, :match)
    ExMatch.match("test", "test")

    assert_raise(ExUnit.AssertionError, fn -> ExMatch.match(1, 2) end)
    assert_raise(ExUnit.AssertionError, fn -> ExMatch.match("1", "2") end)
    assert_raise(ExUnit.AssertionError, fn -> ExMatch.match(1, "2") end)
    assert_raise(ExUnit.AssertionError, fn -> ExMatch.match(:test, 1) end)
  end

  test "basic var" do
    ExMatch.match(v, 1)
    assert 1 == v
  end

  test "list" do
    ExMatch.match([], [])
    ExMatch.match([1], [1])
    ExMatch.match([1, 2], [1, 2])
    ExMatch.match([1, 2, 3], [1, 2, 3])
    ExMatch.match([1, 2, 3, 4], [1, 2, 3, 4])
    ExMatch.match([a, 2, 3, b], [1, 2, 3, 4])
    assert {a, b} == {1, 4}

    assert_raise(
      ExUnit.AssertionError,
      "\n\nmatch failed\nleft:  [4]\nright: [3]\n",
      fn -> ExMatch.match([1, 2, 4], [1, 2, 3]) end
    )

    assert_raise(
      ExUnit.AssertionError,
      "\n\nmatch failed\nleft:  [1, 2, 4]\nright: [2, 4]\n",
      fn -> ExMatch.match([1, 2, 4], [2, 4]) end
    )
  end

  test "tuple" do
    ExMatch.match({}, {})
    ExMatch.match({1}, {1})
    ExMatch.match({1, 2}, {1, 2})
    ExMatch.match({1, 2, 3}, {1, 2, 3})
    ExMatch.match({1, 2, 3, 4}, {1, 2, 3, 4})
    ExMatch.match({a, 2, 3, b}, {1, 2, 3, 4})
    assert {a, b} == {1, 4}

    assert_raise(
      ExUnit.AssertionError,
      "\n\nmatch failed\nleft:  {4}\nright: {3}\n",
      fn -> ExMatch.match({1, 2, 4}, {1, 2, 3}) end
    )

    assert_raise(
      ExUnit.AssertionError,
      "\n\nmatch failed\nleft:  {1, 2, 4}\nright: {2, 4}\n",
      fn -> ExMatch.match({1, 2, 4}, {2, 4}) end
    )
  end

  test "map value" do
    map = %{a: 1, b: 2, c: 3, d: %{e: 11, f: 12}}
    eleven = 11
    two = 2

    ExMatch.match(%{a: id(1), b: b, c: c, d: %{e: ^eleven, f: (eleven + 1)}}, map)
    assert {2, 3} == {b, c}

    ExMatch.match(%{..., b: ExMatchTest.RemoteModule.id(two), c: b, d: %{..., f: a}}, map)
    assert a == 12
    assert b == 3

    assert_raise(
      ExUnit.AssertionError,
      "\n\nmatch failed\nleft:  %{c: 2}\nright: %{b: 2, c: 3, d: %{e: 11, f: 12}}\n",
      fn -> ExMatch.match(%{a: 1, c: 2}, map) end
    )

    assert_raise(
      ExUnit.AssertionError,
      "\n\nmatch failed\nleft:  %{x: %ExMatch.Var{}, y: 6}\nright: %{b: 2, c: 3, d: %{e: 11, f: 12}}\n",
      fn -> ExMatch.match(%{a: 1, x: _x, y: 6}, map) end
    )
  end

  test "datetime" do
    datetime = Timex.parse!("2022-02-19 14:55:08.387165+09:45", "{ISO:Extended}")
    ExMatch.match("2022-02-19 14:55:08.387165+09:45", datetime)
    ExMatch.match("2022-02-19 05:10:08.387165Z", datetime)
    ExMatch.match(~U[2022-02-19 05:10:08.387165Z], datetime)
  end

  test "map keys" do
    map = %{~m(1) => 1}
  end

  defp id(value), do: value
end

defmodule ExMatchTest.RemoteModule do
  def id(value), do: value
end
