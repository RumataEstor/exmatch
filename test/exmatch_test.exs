defmodule ExMatchTest.Dummy do
  defstruct [:a, :b, :c]

  def id(value), do: value
end

defmodule ExMatchTest.Dummy1 do
  defstruct [:a, :b, :c]
end

defmodule ExMatchTest do
  use ExUnit.Case

  require ExMatch

  doctest ExMatch

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

  defmacrop match_fails(expr, expected_message) do
    quote do
      result =
        try do
          unquote(expr)
          :ok
        rescue
          error in ExUnit.AssertionError ->
            error
        end

      if result == :ok do
        raise ExUnit.AssertionError, "expected to raise but returned successfully"
      end

      result_message =
        result
        |> Exception.message()
        |> String.replace_leading("\n\nmatch failed\n", "")

      assert unquote(expected_message) == result_message
    end
  end

  test "basic types" do
    ExMatch.match(1, 1)
    ExMatch.match(2.0, 2.0)
    ExMatch.match(:match, :match)
    ExMatch.match("test", "test")

    match_fails(
      ExMatch.match(1, 2),
      """
      left:  1
      right: 2
      """
    )

    match_fails(
      ExMatch.match("1", "2"),
      """
      left:  "1"
      right: "2"
      """
    )

    match_fails(
      ExMatch.match(1, "2"),
      """
      left:  1
      right: "2"
      """
    )

    match_fails(
      ExMatch.match(:test, 1),
      """
      left:  :test
      right: 1
      """
    )
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

    match_fails(
      ExMatch.match([1, 2, 4], [1, 2, 3]),
      """
      left:  [4]
      right: [3]
      """
    )

    match_fails(
      ExMatch.match([1, 2, 4], [2, 4]),
      """
      left:  [1, 2, 4]
      right: [2, 4]
      """
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

    match_fails(
      ExMatch.match({1, 2, 4}, {1, 2, 3}),
      """
      left:  {4}
      right: {3}
      """
    )

    match_fails(
      ExMatch.match({1, 2, 4}, {2, 4}),
      """
      left:  {1, 2, 4}
      right: {2, 4}
      """
    )

    match_fails(
      ExMatch.match({1, {2, 3}, 4}, {1, 2, 4}),
      """
      left:  {{2, 3}}
      right: {2}
      """
    )
  end

  test "map value" do
    map = %{a: 1, b: 2, c: 3, d: %{e: 11, f: 12}}
    eleven = 11
    two = 2

    ExMatch.match(%{a: id(1), b: b, c: c, d: %{e: ^eleven, f: eleven + 1}}, map)
    assert {2, 3} == {b, c}

    ExMatch.match(%{..., b: ExMatchTest.Dummy.id(two), c: b, d: %{..., f: a}}, map)
    assert a == 12
    assert b == 3

    match_fails(
      ExMatch.match(^map, 1),
      """
      left:  ^map = %{a: 1, b: 2, c: 3, d: %{e: 11, f: 12}}
      right: 1
      """
    )

    match_fails(
      ExMatch.match(^map, %{c: 3, a: 1}),
      """
      left:  ^map =~ %{b: 2, d: %{e: 11, f: 12}}
      right: %{}
      """
    )

    match_fails(
      ExMatch.match(%{a: 1, c: 2}, map),
      """
      left:  %{c: 2}
      right: %{b: 2, c: 3, d: %{e: 11, f: 12}}
      """
    )

    match_fails(
      ExMatch.match(%{..., a: 1, c: 2}, map),
      """
      left:  %{c: 2}
      right: %{c: 3}
      """
    )

    match_fails(
      ExMatch.match(
        %{a: 1, c: _c, x: _, y: 6, d: ExMatchTest.Dummy.id(eleven + two)},
        map
      ),
      """
      left:  %{x: _, y: 6, d: ExMatchTest.Dummy.id(eleven + two) = 13}
      right: %{b: 2, d: %{e: 11, f: 12}}
      """
    )
  end

  test "Struct" do
    alias ExMatchTest.Dummy
    ten = 10

    struct = %ExMatchTest.Dummy{a: 1, b: {1, 2, 3, 4}, c: 10}

    ExMatch.match(%Dummy{a: ten - 9, b: {1, 2, 3, 4}, c: ten - 0}, struct)
    ExMatch.match(%Dummy{..., a: 1, b: b}, struct)
    assert b == {1, 2, 3, 4}

    match_fails(
      ExMatch.match(%ExMatchTest.Dummy1{a: 1, b: ^b}, struct),
      """
      left:  %ExMatchTest.Dummy1{c: nil}
      right: %{__struct__: ExMatchTest.Dummy, c: 10}
      """
    )
  end

  test "DateTime" do
    # Timex keeps offsets in the DateTime unlike DateTime.parse
    datetime = Timex.parse!("2022-02-19 14:55:08.387165+09:45", "{ISO:Extended}")
    ExMatch.match("2022-02-19 14:55:08.387165+09:45", datetime)
    ExMatch.match("2022-02-19 05:10:08.387165Z", datetime)
    ExMatch.match(~U[2022-02-19 05:10:08.387165Z], datetime)
  end

  test "Decimal" do
    eleven = 11
    ExMatch.match(1, ~m(1.0))
    ExMatch.match(Decimal.mult("0.5", 2), 1)
    ExMatch.match(%{a: 1}, %{a: ~m(1.0)})
    ExMatch.match(%{a: 1}, %{a: Decimal.add("0.8", "0.2")})
    ExMatch.match(%Decimal{coef: 11, exp: -1, sign: 1}, ~m(1.1))
    ExMatch.match(%Decimal{..., coef: id(eleven)}, ~m(1.1))
    ExMatch.match(%Decimal{coef: 11, exp: 1 - 1, sign: 1}, Decimal.add(1, 10))

    match_fails(
      ExMatch.match(%Decimal{coef: 11, exp: -1, sign: 1}, ~m(11)),
      """
      left:  %Decimal{coef: 11, exp: -1, sign: 1}
      right: #Decimal<11>
      """
    )

    match_fails(
      ExMatch.match(%Decimal{coef: ^eleven, exp: 1 - 1, sign: 1}, Decimal.add(1, eleven)),
      """
      left:  %Decimal{coef: ^eleven = 11, exp: 1 - 1 = 0, sign: 1}
      right: #Decimal<12>
      """
    )
  end

  defp id(value), do: value
end
