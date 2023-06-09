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

  test "struct updates 1" do
    url = URI.parse("https://elixir-lang.org/")

    match_fails(
      ExMatch.match(%URI{url | scheme: "http"}, "http://localhost:3000"),
      """
      left:  %URI{(url = %URI{authority: "elixir-lang.org", fragment: nil, host: "elixir-lang.org", path: "/", port: 443, query: nil, userinfo: nil}) | scheme: "http"}
      right: "http://localhost:3000"
      """
    )
  end

  test "struct updates 2" do
    url = URI.parse("https://elixir-lang.org/")

    match_fails(
      ExMatch.match(%URI{url | scheme: "http"}, URI.parse("http://localhost:3000")),
      """
      left:  url = %URI{authority: "elixir-lang.org", host: "elixir-lang.org", path: "/", port: 443}
      right: %URI{authority: "localhost:3000", host: "localhost", path: nil, port: 3000}
      """
    )
  end

  test "dot syntax" do
    url = URI.parse("https://elixir-lang.org/")
    map = %{port: 8080}

    ExMatch.match(
      %URI{url | port: map.port, authority: "#{url.authority}:#{map.port}"},
      URI.parse("https://elixir-lang.org:8080/")
    )

    match_fails(
      ExMatch.match(
        %URI{url | scheme: "http", port: map.port, authority: "#{url.authority}:#{map.port}"},
        "http://localhost:3000"
      ),
      """
      left:  %URI{(url = %URI{fragment: nil, host: "elixir-lang.org", path: "/", query: nil, userinfo: nil}) | scheme: "http", port: map.port = 8080, authority: \"\#{url.authority}:\#{map.port}\" = "elixir-lang.org:8080"}
      right: "http://localhost:3000"
      """
    )
  end

  @opts ExMatch.options(%{
          ExMatchTest.Dummy => %{b: {1, _, _, ExMatchTest.Dummy.id(3 + 1)}}
        })

  defp opts1(), do: @opts

  defp opts2(),
    do:
      ExMatch.options([
        %ExMatchTest.Dummy1{c: 4}
      ])

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
