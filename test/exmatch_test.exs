defmodule ExMatchTest do
  @external_resource "README.md"

  use ExMatchTest.TestCase

  doctest ExMatch

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

  test "var with condition" do
    ExMatch.match(a when not is_nil(a), 1)
    assert 1 == a

    match_fails(
      ExMatch.match(b when b + a == 0, 1),
      """
      left:  b = 1 when b + a == 0 = false
      right: 1
      """
    )

    ExMatch.match(%{a: _x, b: y when a < y}, %{b: 2, a: 1})
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
      left:  [..2.., 4]
      right: [..2.., 3]
      """
    )

    match_fails(
      ExMatch.match([1, 2, 4], [2, 4]),
      """
      left:  [1, 2, 4]
      right: [2, 4]
      """
    )

    match_fails(
      ExMatch.match([1, 2], [1, 2, 3, 4]),
      """
      left:  [..2..]
      right: [..2.., 3, 4]
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
      left:  {..2.., 4}
      right: {..2.., 3}
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
      left:  {.., {2, 3}, ..}
      right: {.., 2, ..}
      """
    )

    match_fails(
      ExMatch.match({_, 2}, {1, 2, 3, 4}),
      """
      left:  {..2..}
      right: {..2.., 3, 4}
      """
    )

    match_fails(
      ExMatch.match({1, 2}, {1, 2, 3, 4}),
      """
      left:  {..2..}
      right: {..2.., 3, 4}
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
      ExMatch.match(%{b: ^two}, map),
      """
      left:  %{}
      right: %{a: 1, c: 3, d: %{e: 11, f: 12}}
      """
    )

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
      right: %{c: 3, b: 2, d: %{e: 11, f: 12}}
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
      left:  %{d: ExMatchTest.Dummy.id(eleven + two) = 13, x: _, y: 6}
      right: %{d: %{e: 11, f: 12}, b: 2}
      """
    )
  end

  test "struct" do
    alias ExMatchTest.Dummy
    ten = 10

    struct = %ExMatchTest.Dummy{a: 1, b: {1, 2, 3, 4}, c: 10}

    ExMatch.match(%Dummy{a: ten - 9, b: {1, 2, 3, 4}, c: ten - 0}, struct)
    ExMatch.match(%Dummy{..., a: 1, b: b}, struct)
    assert b == {1, 2, 3, 4}

    ExMatch.match(%Dummy{a: ten - 9, b: {_, 2, _, 4}, c: ten - 0}, struct)

    match_fails(
      ExMatch.match(%ExMatchTest.Dummy1{a: 1, b: ^b}, struct),
      """
      left:  %ExMatchTest.Dummy1{c: nil}
      right: %ExMatchTest.Dummy{c: 10}
      """
    )
  end

  @opts ExMatch.options(%{
          ExMatchTest.Dummy => %{b: {1, _, _, ExMatchTest.Dummy.id(3 + 1)}}
        })

  defp opts1(), do: @opts

  defp opts2(),
    do:
      ExMatch.options(%{
        ExMatchTest.Dummy1 => %{c: 4}
      })

  test "struct with options" do
    alias ExMatchTest.Dummy

    one = 1

    struct = %Dummy{a: 1, b: {1, 2, 3, 4}, c: 10}

    ExMatch.match(%Dummy{c: id(1) + 9, b: {_, 2, _, 4}}, struct, %{
      Dummy => %{a: ^one}
    })

    match_fails(
      ExMatch.match(
        %Dummy{
          c: %Dummy{..., b: 1},
          b: {_, 2, _, 4}
        },
        struct,
        %{
          Dummy => %{..., a: _}
        }
      ),
      """
      left:  %ExMatchTest.Dummy{c: %ExMatchTest.Dummy{a: _, b: 1}}
      right: %ExMatchTest.Dummy{c: 10}
      """
    )

    ExMatch.match(%ExMatchTest.Dummy{..., a: id(1)}, struct, @opts)

    ExMatch.match(%Dummy{a: 1, c: 10}, struct, opts1())

    ExMatch.match(%ExMatchTest.Dummy1{}, %ExMatchTest.Dummy1{c: 4}, opts2())

    match_fails(
      ExMatch.match(%Dummy{}, struct!(ExMatchTest.Dummy1, Map.from_struct(struct)), opts1()),
      """
      left:  %ExMatchTest.Dummy{}
      right: %ExMatchTest.Dummy1{a: 1, c: 10}
      """
    )
  end

  test "options errors" do
    assert_raise(RuntimeError, "options must be a map or an expression returning a map", fn ->
      quote do
        ExMatch.match(%Dummy{}, struct, [])
      end
      |> Code.eval_quoted([], __ENV__)
    end)
  end

  test "DateTime" do
    # Timex keeps offsets in the DateTime unlike DateTime.parse
    datetime = Timex.parse!("2022-02-19 14:55:08.387165+09:45", "{ISO:Extended}")
    ExMatch.match("2022-02-19 14:55:08.387165+09:45", datetime)
    ExMatch.match("2022-02-19 05:10:08.387165Z", datetime)
    ExMatch.match(~U[2022-02-19 05:10:08.387165Z], datetime)

    match_fails(
      ExMatch.match(^datetime, nil),
      """
      left:  ^datetime = #DateTime<2022-02-19 14:55:08.387165+09:45 +09:45 Etc/UTC+9:45>
      right: nil
      """
    )
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
      right: %Decimal{coef: 11, exp: 0, sign: 1}
      """
    )

    match_fails(
      ExMatch.match(%Decimal{coef: ^eleven, exp: 1 - 1, sign: 1}, Decimal.add(1, eleven)),
      """
      left:  %Decimal{coef: ^eleven = 11, exp: 1 - 1 = 0, sign: 1}
      right: %Decimal{coef: 12, exp: 0, sign: 1}
      """
    )

    match_fails(
      ExMatch.match(~m(1.1), nil),
      """
      left:  ~m(1.1) = #Decimal<1.1>
      right: nil
      """
    )
  end

  defp id(value), do: value
end
