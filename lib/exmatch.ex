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
    do_match(left, right, quote(do: %{}))
  end

  defmacro match(left, right, opts) do
    do_match(left, right, opts)
  end

  defmacro options(item) do
    options_(item)
  end

  defp options_(item) do
    case item do
      {:@, _, [{name, _, context}]} when is_atom(name) and is_atom(context) ->
        item

      {:%{}, meta, opts_fields} ->
        opts_fields =
          Enum.map(opts_fields, fn {struct, struct_opts} ->
            {[], map} = parse_ast(struct_opts, %{})
            {struct, map}
          end)

        {:%{}, meta, opts_fields}
    end
  end

  defp do_match(left, right, opts) do
    opts_var = Macro.var(:opts, __MODULE__)
    {bindings, left} = parse_ast(left, opts_var)
    opts = options_(opts)

    quote do
      unquote(opts_var) = unquote(opts)

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

  defp parse_ast(left, _opts) when is_number(left) or is_bitstring(left) or is_atom(left) do
    self =
      quote do
        unquote(left)
      end

    {[], self}
  end

  defp parse_ast({var, _, context} = left, _opts) when is_atom(var) and is_atom(context) do
    ExMatch.Var.parse(left)
  end

  defp parse_ast({:when, _, [_binding, _condition]} = left, _opts) do
    ExMatch.Var.parse(left)
  end

  defp parse_ast(left, opts) when is_list(left) do
    ExMatch.List.parse(left, &parse_ast/2, opts)
  end

  defp parse_ast({_, _} = left, opts) do
    ExMatch.Tuple.parse(left, &parse_ast/2, opts)
  end

  defp parse_ast({:{}, _, _} = left, opts) do
    ExMatch.Tuple.parse(left, &parse_ast/2, opts)
  end

  defp parse_ast({:%{}, _, _} = left, opts) do
    ExMatch.Map.parse(left, &parse_ast/2, opts)
  end

  defp parse_ast({:%, _, _} = left, opts) do
    ExMatch.Struct.parse(left, &parse_ast/2, opts)
  end

  defp parse_ast(left, _opts) do
    ExMatch.Expr.parse(left)
  end
end
