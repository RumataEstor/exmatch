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
    ExMatch.Options.parse(item, &parse_ast/2)
  end

  def gen_match(left, right, opts_expr) do
    opts_var = Macro.var(:opts, __MODULE__)
    parse_context = %ParseContext{parse_ast: &parse_ast/2, opts: opts_var}
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

  defp parse_ast(left, _parse_context)
       when is_number(left) or is_bitstring(left) or is_atom(left) do
    self =
      quote location: :keep do
        unquote(left)
      end

    {[], self}
  end

  defp parse_ast({var, _, context} = left, _parse_context)
       when is_atom(var) and is_atom(context) do
    ExMatch.Var.parse(left)
  end

  defp parse_ast({:when, _, [_binding, _condition]} = left, _parse_context) do
    ExMatch.Var.parse(left)
  end

  defp parse_ast(left, parse_context) when is_list(left) do
    ExMatch.List.parse(left, parse_context)
  end

  defp parse_ast({_, _} = left, parse_context) do
    ExMatch.Tuple.parse(left, parse_context)
  end

  defp parse_ast({:{}, _, _} = left, parse_context) do
    ExMatch.Tuple.parse(left, parse_context)
  end

  defp parse_ast({:%{}, _, _} = left, parse_context) do
    ExMatch.Map.parse(left, parse_context)
  end

  defp parse_ast({:%, _, _} = left, parse_context) do
    ExMatch.Struct.parse(left, parse_context)
  end

  defp parse_ast(left, _parse_context) do
    ExMatch.Expr.parse(left)
  end
end
