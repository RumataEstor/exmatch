defmodule ExMatch.Var do
  @moduledoc false

  @enforce_keys [:binding, :expr, :expr_fun]
  defstruct @enforce_keys

  def parse({var, _, context} = binding) when is_atom(var) and is_atom(context) do
    self =
      quote location: :keep do
        %ExMatch.Var{
          binding: unquote(Macro.escape(binding)),
          expr: nil,
          expr_fun: nil
        }
      end

    case var do
      :_ -> {[], self}
      _ -> {[binding], self}
    end
  end

  def parse({:when, _, [{var, meta, context} = binding, expr]})
      when is_atom(var) and is_atom(context) do
    self =
      quote location: :keep do
        %ExMatch.Var{
          binding: unquote(Macro.escape(binding)),
          expr: unquote(Macro.escape(expr)),
          expr_fun: fn unquote(binding) -> unquote(expr) end
        }
      end

    {[{var, [generated: true] ++ meta, context}], self}
  end

  defimpl ExMatch.Pattern do
    @moduledoc false

    def diff(%ExMatch.Var{binding: binding, expr: nil, expr_fun: nil}, right, _opts) do
      case binding do
        {:_, _, nil} -> []
        _ -> [right]
      end
    end

    def diff(%ExMatch.Var{binding: binding, expr: expr, expr_fun: expr_fun}, right, _opts) do
      expr_fun.(right)
    catch
      class, error ->
        ast =
          quote location: :keep do
            unquote(binding) = unquote(Macro.escape(right))
            when unquote(expr) = unquote(class)(unquote(error))
          end

        {ast, right}
    else
      falsy when falsy in [nil, false] ->
        ast =
          quote location: :keep do
            unquote(binding) = unquote(Macro.escape(right))
            when unquote(expr) = unquote(Macro.escape(falsy))
          end

        {ast, right}

      _truthy ->
        [right]
    end

    def escape(%ExMatch.Var{binding: binding, expr: nil}),
      do: binding

    def escape(%ExMatch.Var{binding: binding, expr: expr}) do
      quote location: :keep do
        unquote(binding) when unquote(expr)
      end
    end

    def value(_self),
      do: throw(ExMatch.NoValue)
  end
end
