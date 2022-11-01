defmodule ExMatch do
  @external_resource "README.md"

  @moduledoc """
  Assertions for data equivalence.

  #{"README.md" |> File.read!() |> String.split("<!-- EXAMPLES -->") |> Enum.at(1)}
  """

  @assertion_error (if Mix.env() in [:test] do
                      ExMatchTest.AssertionError
                    else
                      ExUnit.AssertionError
                    end)

  alias ExMatch.ParseContext

  @doc """
  Raises if the values don't match and displays what exactly was different.

  iex> ExMatch.match([1, a, 3], [1, 2, 3])
  iex> 2 = a
  """
  defmacro match(left, right) do
    gen_match(left, right, parse_options([]))
  end

  defmacro match(left, right, opts) do
    gen_match(left, right, parse_options(opts))
  end

  defmacro options(item) do
    parse_options(item)
  end

  defp parse_options(item) do
    ExMatch.Options.parse(item)
  end

  def gen_match(left, right, opts_expr) do
    opts_var = Macro.var(:opts, __MODULE__)
    parse_context = %ParseContext{opts: opts_var}
    {bindings, left} = ParseContext.parse(left, parse_context)

    quote location: :keep do
      unquote(opts_var) =
        case unquote(opts_expr) do
          %ExMatch.Options{opts: opts} ->
            opts

          other ->
            raise "The options provided as #{unquote(Macro.to_string(opts_expr))} must be built using ExMatch.options/1, got #{inspect(other)}"
        end

      unquote(bindings) =
        case ExMatch.Match.diff(unquote(left), unquote(right), unquote(opts_var)) do
          {diff_left, diff_right} = diff ->
            raise unquote(@assertion_error),
              left: diff_left,
              right: diff_right,
              context: {:match, []}

          bindings when is_list(bindings) ->
            bindings
        end

      :ok
    end
  end
end
