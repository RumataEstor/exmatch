defprotocol ExMatch.Pattern do
  @moduledoc false

  @fallback_to_any true

  @spec diff(t, any, any) :: [any] | {any, any}
  def diff(left, right, opts)

  @spec escape(t) :: any
  def escape(self)

  @spec value(t) :: any
  def value(self)
end

defimpl ExMatch.Pattern, for: Any do
  @moduledoc false

  def diff(left, right, opts) do
    diff_values(left, right, opts)
  end

  def escape(self),
    do: ExMatch.View.Rendered.new(inspect(self))

  def value(self),
    do: self

  def diff_values(left_value, right, opts, on_diff \\ nil) do
    get_opts = fn atom ->
      try do
        opts
        |> Map.get(atom)
        |> ExMatch.Pattern.value()
      rescue
        ArgumentError ->
          nil
      end
    end

    case ExMatch.Value.diff(left_value, right, get_opts) do
      nil ->
        []

      {left_diff, right_diff} when on_diff == nil ->
        {ExMatch.Pattern.escape(left_diff), right_diff}

      diff when is_function(on_diff, 1) ->
        on_diff.(diff)
    end
  end
end
