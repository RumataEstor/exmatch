defmodule ExMatch.Expr do
  @moduledoc false
  alias ExMatch.ParseContext

  @enforce_keys [:ast, :value]
  defstruct @enforce_keys

  # pin variable
  def parse({:^, _, [{var_name, _, module} = var_item]} = ast, _parse_context)
      when is_atom(var_name) and is_atom(module),
      do: parsed(ast, var_item)

  # plain variable
  def parse({var_name, _, module} = ast, _parse_context)
      when is_atom(var_name) and is_atom(module),
      do: parsed(ast, ast)

  # remote function/macro call or dot syntax
  def parse({{:., _, [_, _]}, _, args} = ast, parse_context) when is_list(args),
    do: parsed(ast, ast, expand(ast, parse_context))

  # binary strings with interpolation
  def parse({:<<>>, _, args} = ast, _parse_context) when is_list(args),
    do: parsed(ast, ast)

  # alias
  def parse({:__aliases__, _, _} = ast, _parse_context),
    do: parsed(ast, ast)

  # local/imported function/macro call
  def parse({fn_name, _, args} = ast, parse_context) when is_atom(fn_name) and is_list(args) do
    if Macro.special_form?(fn_name, length(args)) do
      raise "Special form #{fn_name}/#{length(args)} is not yet supported in ExMatch\n" <>
              "Please submit a report to handle #{inspect(ast)}"
    end

    parsed(ast, ast, expand(ast, parse_context))
  end

  defp expand(ast, parse_context) do
    expanded = ParseContext.expand(ast, parse_context)

    case ast != expanded and ParseContext.parse(expanded, parse_context) do
      false -> {[], ast}
      {vars, value} -> {vars, value}
    end
  end

  defp parsed(ast, value, parsed \\ nil) do
    {vars, value} =
      case parsed do
        nil -> {[], value}
        {vars, value} -> {vars, value}
      end

    self =
      quote do
        %ExMatch.Expr{
          ast: unquote(Macro.escape(ast)),
          value: unquote(value)
        }
      end

    {vars, self}
  end

  defimpl ExMatch.Pattern do
    @moduledoc false

    defp diff_expanded(%ExMatch.Expr{value: value} = left, right, opts) do
      case ExMatch.Pattern.diff(value, right, opts) do
        {left_diff, right_diff} ->
          {escape(left, left_diff, left_diff == value), right_diff}

        bindings ->
          bindings
      end
    end

    def diff(%ExMatch.Expr{value: value} = left, right, opts) do
      try do
        ExMatch.Pattern.value(value)
      catch
        ExMatch.NoValue ->
          diff_expanded(left, right, opts)
      else
        left_value ->
          ExMatch.Pattern.Any.diff_values(left_value, right, opts, fn
            {left_diff, right_diff} ->
              {escape(left, left_diff, left_diff == left_value), right_diff}
          end)
      end
    end

    def escape(%ExMatch.Expr{value: value} = self),
      do: escape(self, value, true)

    defp escape(%ExMatch.Expr{ast: ast}, value, exact?) do
      value_str = ExMatch.View.Any.inspect_value(value)
      ast_str = Macro.to_string(ast)

      if ast_str == value_str do
        ExMatch.View.Rendered.new(ast_str)
      else
        op = if exact?, do: " = ", else: " =~ "
        ExMatch.View.Rendered.new([ast_str, op, value_str])
      end
    end

    def value(%ExMatch.Expr{value: value}),
      do: ExMatch.Pattern.value(value)
  end
end
