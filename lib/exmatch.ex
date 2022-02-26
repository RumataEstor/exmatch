defmodule ExMatch do
  @moduledoc """
    Assertions for data equivalence.
  """

  alias ExMatch.BindingProtocol

  @doc """
  Raises if the values don't match and displays what exactly was different.

  iex> ExMatch.match([1, a, 3], [1, 2, 3])
  iex> 2 = a
  """
  defmacro match(left, right) do
    {bindings, left} = parse_ast(left)

    quote do
      unquote(bindings) =
        case BindingProtocol.diff(unquote(left), unquote(right), %{}) do
          {diff_left, diff_right} = diff ->
            raise ExUnit.AssertionError,
              left: diff_left,
              right: diff_right,
              message: "match failed",
              context: {:match, []}

          bindings when is_list(bindings) ->
            bindings
        end
    end
  end

  defp parse_ast(left) when is_number(left) or is_bitstring(left) or is_atom(left) do
    self =
      quote do
        unquote(left)
      end

    {[], self}
  end

  defp parse_ast({var, _, context} = binding) when is_atom(var) and is_atom(context) do
    ExMatch.Var.parse(binding)
  end

  defp parse_ast(left) when is_list(left) do
    ExMatch.List.parse(left, &parse_ast/1)
  end

  defp parse_ast({_, _} = left) do
    ExMatch.Tuple.parse(left, &parse_ast/1)
  end

  defp parse_ast({:{}, _, _} = left) do
    ExMatch.Tuple.parse(left, &parse_ast/1)
  end

  defp parse_ast({:%{}, _, _} = left) do
    ExMatch.Map.parse(left, &parse_ast/1)
  end

  defp parse_ast({:%, _, _} = left) do
    ExMatch.Struct.parse(left, &parse_ast/1)
  end

  defp parse_ast(left) do
    ExMatch.Expr.parse(left)
  end
end
