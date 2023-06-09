defmodule ExMatchTest do
  @external_resource "README.md"

  use ExMatchTest.TestCase
  require ExMatch

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

  test "options errors" do
    assert_raise(RuntimeError, "Options argument must be a map or a list, got: {}", fn ->
      quote do
        ExMatch.match(%Dummy{}, struct, {})
      end
      |> Code.eval_quoted([], __ENV__)
    end)

    assert_raise(
      RuntimeError,
      "An option item must be a struct or `{struct_module :: atom(), struct_opts :: term()}`, got: %{a: 1}",
      fn ->
        quote do
          ExMatch.match(%Dummy{}, struct, [%{a: 1}])
        end
        |> Code.eval_quoted([], __ENV__)
      end
    )

    assert_raise(RuntimeError, "Options cannot export variables, found [a] in struct Dummy", fn ->
      quote do
        ExMatch.match(%Dummy{}, struct, [%Dummy{a: a}])
      end
      |> Code.eval_quoted([], __ENV__)
    end)
  end

  test "deep nested options" do
    ExMatch.match(
      %ExMatchTest.Dummy1{
        b: %ExMatchTest.Dummy{
          a: 2
        }
      },
      %ExMatchTest.Dummy1{
        b: %ExMatchTest.Dummy{
          a: 2,
          c: [%ExMatchTest.Dummy1{a: 1}]
        },
        c: 3
      },
      %{
        ExMatchTest.Dummy => %{
          c: [
            %ExMatchTest.Dummy1{a: 1}
          ]
        },
        ExMatchTest.Dummy1 => %{
          c: 3
        }
      }
    )
  end

  test "aliases" do
    alias Test.Aliases.A1
    ExMatch.match(A1 == A1)
    ExMatch.match(A1 == Test.Aliases.A1)
    ExMatch.match(Test.Aliases.A1 == A1)
    ExMatch.match([A1] == [Test.Aliases.A1])

    match_fails(
      ExMatch.match(A1 == Test.Aliases.A2),
      """
      left:  A1 = Test.Aliases.A1
      right: Test.Aliases.A2
      """
    )

    match_fails(
      ExMatch.match([A1] == [Test.Aliases.A2]),
      """
      left:  [A1 = Test.Aliases.A1]
      right: [Test.Aliases.A2]
      """
    )

    match_fails(
      ExMatch.match(Test.Aliases.A2 == A1),
      """
      left:  Test.Aliases.A2
      right: Test.Aliases.A1
      """
    )
  end
end
