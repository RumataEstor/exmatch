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
    {:exmatch, "~> 0.6.0", only: [:dev, :test]}
  ]
end
```

<!-- EXAMPLES -->

## Usage
The library depends on ExUnit.AssertionError and therefore is meant
to be used only in testing.

> #### Notice {: .neutral}
> The examples below display the output you would see when testing using ExUnit.
> Using plain IEx environment will use basic struct formatter different
> from ExUnit.CLIFormatter.

```elixir
iex> ExMatch.match(%{a: 1, b: 2, c: 3}, %{c: 3, a: 2, b: {1, 0}})
** (ExUnit.AssertionError)
left:  %{a: 1, b: 2}
right: %{a: 2, b: {1, 0}}

iex> ExMatch.match([10, eleven, _], [Decimal.new("10"), 11, 12])
iex> eleven == 11
true
iex> ExMatch.match(%Decimal{coef: ^eleven, exp: 1 - 1, sign: 1}, Decimal.add(1, eleven))
** (ExUnit.AssertionError)
left:  %Decimal{coef: ^eleven = 11, exp: 1 - 1 = 0, sign: 1}
right: %Decimal{coef: 12, exp: 0, sign: 1}

iex> alias ExMatchTest.{Dummy, Dummy1}
iex> ExMatch.match(%Dummy{
...>    a: %Dummy1{a: 1},
...>    b: ~U[2022-02-19 05:10:08.387165Z]
...>  }, %Dummy{
...>    a: %Dummy{a: 1},
...>    b: Timex.parse!("2022-02-19 14:55:08.387165+09:45", "{ISO:Extended}")
...>  })
** (ExUnit.AssertionError)
left:  %ExMatchTest.Dummy{a: %(ExMatchTest.Dummy1, [])}
right: %ExMatchTest.Dummy{a: %{__struct__: ExMatchTest.Dummy}}
```

<!-- EXAMPLES -->