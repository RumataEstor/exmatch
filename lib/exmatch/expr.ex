defmodule ExMatch.Expr do
  @moduledoc false

  @enforce_keys [:ast, :value]
  defstruct @enforce_keys

  # pin variable
  def parse({:^, _, [{var_name, _, module} = var_item]} = ast)
      when is_atom(var_name) and is_atom(module),
      do: parse(ast, var_item)

  # plain variable
  def parse({var_name, _, module} = ast)
      when is_atom(var_name) and is_atom(module),
      do: parse(ast, ast)

  # remote function/macro call or dot syntax
  def parse({{:., _, [_, _]}, _, args} = ast) when is_list(args),
    do: parse(ast, ast)

  # binary strings with interpolation
  def parse({:<<>>, _, args} = ast) when is_list(args),
    do: parse(ast, ast)

  # alias
  def parse({:__aliases__, _, _} = ast),
    do: parse(ast, ast)

  # local/imported function/macro call
  def parse({fn_name, _, args} = ast) when is_atom(fn_name) and is_list(args) do
    if Macro.special_form?(fn_name, length(args)) do
      raise "Special form #{fn_name}/#{length(args)} is not yet supported in ExMatch\n" <>
              "Please submit a report to handle #{inspect(ast)}"
    end

    parse(ast, ast)
  end

  defp parse(ast, value) do
    self =
      quote location: :keep do
        %ExMatch.Expr{
          ast: unquote(Macro.escape(ast)),
          value: unquote(value)
        }
      end

    {[], self}
  end

  defimpl ExMatch.Pattern do
    @moduledoc false

    def diff(left, right, opts) do
      %ExMatch.Expr{value: value} = left

      ExMatch.Pattern.Any.diff_values(value, right, opts, fn
        {^value, right_diff} ->
          {escape(left, value, true), right_diff}

        {left_diff, right_diff} ->
          {escape(left, left_diff, false), right_diff}
      end)
    end

    def escape(%ExMatch.Expr{value: value} = self),
      do: escape(self, value, true)

    defp escape(%ExMatch.Expr{ast: ast}, value, exact?) do
      value_str = inspect(value)

      if Macro.to_string(ast) == value_str do
        ast
      else
        op = if(exact?, do: :=, else: :=~)
        {op, [], [ast, ExMatch.View.Rendered.new(value_str)]}
      end
    end

    def value(%ExMatch.Expr{value: value}),
      do: value
  end
end
