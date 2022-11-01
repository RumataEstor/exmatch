defmodule ExMatch.Parser do
  def parse_ast(left, _parse_context)
      when is_number(left) or is_bitstring(left) or is_atom(left) do
    self =
      quote location: :keep do
        unquote(left)
      end

    {[], self}
  end

  def parse_ast({var, _, context} = left, _parse_context)
      when is_atom(var) and is_atom(context) do
    ExMatch.Var.parse(left)
  end

  def parse_ast({:when, _, [_binding, _condition]} = left, _parse_context) do
    ExMatch.Var.parse(left)
  end

  def parse_ast(left, parse_context) when is_list(left) do
    ExMatch.List.parse(left, parse_context)
  end

  def parse_ast({_, _} = left, parse_context) do
    ExMatch.Tuple.parse(left, parse_context)
  end

  def parse_ast({:{}, _, _} = left, parse_context) do
    ExMatch.Tuple.parse(left, parse_context)
  end

  def parse_ast({:%{}, _, _} = left, parse_context) do
    ExMatch.Map.parse(left, parse_context)
  end

  def parse_ast({:%, _, _} = left, parse_context) do
    ExMatch.Struct.parse(left, parse_context)
  end

  def parse_ast(left, _parse_context) do
    ExMatch.Expr.parse(left)
  end
end
