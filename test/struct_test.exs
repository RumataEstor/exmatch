defmodule ExMatchTest.Struct do
  use ExMatchTest.TestCase

  require ExMatch

  alias ExMatchTest.Dummy

  test "match" do
    ten = 10

    struct = %ExMatchTest.Dummy{a: 1, b: {1, 2, 3, 4}, c: 10}

    ExMatch.match(%Dummy{a: ten - 9, b: {1, 2, 3, 4}, c: ten - 0}, struct)
    ExMatch.match(%Dummy{..., a: 1, b: b}, struct)
    assert b == {1, 2, 3, 4}

    ExMatch.match(%Dummy{a: ten - 9, b: {_, 2, _, 4}, c: ten - 0}, struct)
  end

  test "diff in omitted field" do
    b = {1, 2, 3, 4}
    struct = %ExMatchTest.Dummy{a: 1, b: b, c: 10}

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

  test "dot syntax matches" do
    url = URI.parse("https://elixir-lang.org/")
    map = %{port: 8080}

    ExMatch.match(
      %URI{url | port: map.port, authority: "#{url.authority}:#{map.port}"},
      URI.parse("https://elixir-lang.org:8080/")
    )
  end

  test "diff with dot syntax" do
    url = URI.parse("https://elixir-lang.org/")
    map = %{port: 8080}

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

  test "struct with options matches" do
    one = 1
    struct = %Dummy{a: 1, b: {1, 2, 3, 4}, c: 10}

    ExMatch.match(%Dummy{c: id(1) + 9, b: {_, 2, _, 4}}, struct, %{
      Dummy => %{a: ^one}
    })

    ExMatch.match(%ExMatchTest.Dummy{..., a: id(1)}, struct, @opts)

    ExMatch.match(%Dummy{a: 1, c: 10}, struct, opts1())

    ExMatch.match(%ExMatchTest.Dummy1{}, %ExMatchTest.Dummy1{c: 4}, opts2())
  end

  test "diff in struct with inline options" do
    struct = %Dummy{a: 1, b: {1, 2, 3, 4}, c: 10}

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
  end

  test "diff in struct with options from fun" do
    struct = %Dummy{a: 1, b: {1, 2, 3, 4}, c: 10}

    match_fails(
      ExMatch.match(%Dummy{}, struct!(ExMatchTest.Dummy1, Map.from_struct(struct)), opts1()),
      """
      left:  %ExMatchTest.Dummy{}
      right: %ExMatchTest.Dummy1{a: 1, c: 10}
      """
    )
  end
end
