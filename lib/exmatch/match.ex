defprotocol ExMatch.Match do
  @moduledoc false

  @fallback_to_any true

  @spec diff(t, any, any) :: [any] | {any, any}
  def diff(left, right, opts)

  @spec escape(t) :: any
  def escape(self)

  @spec value(t) :: any
  def value(self)
end

defimpl ExMatch.Match, for: Any do
  @moduledoc false

  def diff(left, right, opts) do
    diff_values(left, right, opts)
  end

  def escape(self),
    do: self

  def value(self),
    do: self

  def diff_values(left, right, opts, on_diff \\ nil) do
    get_opts = fn atom ->
      try do
        opts
        |> Map.get(atom)
        |> ExMatch.Match.value()
      rescue
        ArgumentError ->
          nil
      end
    end

    try do
      left_value = ExMatch.Match.value(left)
      ExMatch.Value.diff(left_value, right, get_opts)
    catch
      kind, error ->
        left_ast = ExMatch.Match.escape(left)
        ex = ExMatch.Exception.new(kind, error, __STACKTRACE__)
        {{:=~, [], [left_ast, ex]}, right}
    else
      nil ->
        []

      {left_diff, right_diff} when on_diff == nil ->
        {Macro.escape(left_diff), right_diff}

      diff ->
        on_diff.(diff)
    end
  end
end
