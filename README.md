# Extended match

This library is meant to provide an ergonomic way to pattern match
and bind data in complex types such as maps and structs during testing.

[![Build status](https://github.com/RumataEstor/exmatch/actions/workflows/ci.yml/badge.svg)](https://github.com/RumataEstor/exmatch/actions)
[![Hex.pm version](https://img.shields.io/hexpm/v/exmatch.svg)](http://hex.pm/packages/exmatch)
[![Hex.pm downloads](https://img.shields.io/hexpm/dt/exmatch.svg)](https://hex.pm/packages/exmatch)

## Installation

The package can be installed by adding `exmatch` to your list of dependencies in `mix.exs`:

```elixir
defp deps do
  [
    {:exmatch, "~> 0.12.0", only: [:dev, :test]}
  ]
end
```

<!-- EXAMPLES -->

## Usage
The library depends on ExUnit.AssertionError and therefore is meant
to be used only in testing.

> #### Notice {: .neutral}
> The examples below display ExMatchTest.AssertionError as they are used as doctests.
> When used in your tests the ExUnit.AssertionError would be used instead.
> Using plain IEx environment will use basic struct formatter different
> from ExUnit.CLIFormatter.

```elixir
iex> ExMatch.match(%{a: 1, b: 2, c: 3}, %{c: 3, a: 2, b: {1, 0}})
** (ExMatchTest.AssertionError)
left:  %{a: 1, b: 2}
right: %{a: 2, b: {1, 0}}
```

```elixir
iex> opts = ExMatch.options([{Decimal, [:match_integer]}])
iex> ExMatch.match([10, eleven, _], [Decimal.new("10"), 11, 12], opts)
iex> eleven == 11
true
```

```elixir
iex> eleven = 11
iex> ExMatch.match(%Decimal{coef: ^eleven, exp: 1 - 1, sign: 1}, Decimal.add(1, eleven))
** (ExMatchTest.AssertionError)
left:  %Decimal{coef: ^eleven = 11}
right: %Decimal{coef: 12}
```

```elixir
iex> ExMatch.match(%ExMatchTest.Dummy{
...>    a: %ExMatchTest.Dummy1{a: 1},
...>    b: ~U[2022-02-19 05:10:08.387165Z]
...>  }, %ExMatchTest.Dummy{
...>    a: %ExMatchTest.Dummy{a: 1},
...>    b: Timex.parse!("2022-02-19 14:55:08.387165+09:45", "{ISO:Extended}")
...>  })
** (ExMatchTest.AssertionError)
left:  %ExMatchTest.Dummy{a: %ExMatchTest.Dummy1{}}
right: %ExMatchTest.Dummy{a: %ExMatchTest.Dummy{}}
```

```elixir
iex> url = URI.parse("https://elixir-lang.org/")
iex> ExMatch.match(%URI{url | path: path}, URI.parse("https://elixir-lang.org/cases.html"))
iex> path == "/cases.html"
true
```

```elixir
iex> url = URI.parse("https://elixir-lang.org/")
iex> ExMatch.match(%URI{url | scheme: "http"}, URI.parse("http://localhost:3000"))
** (ExMatchTest.AssertionError)
left:  url = %URI{authority: "elixir-lang.org", host: "elixir-lang.org", path: "/", port: 443}
right: %URI{authority: "localhost:3000", host: "localhost", path: nil, port: 3000}
```

<!-- EXAMPLES -->
