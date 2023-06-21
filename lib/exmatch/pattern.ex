defprotocol ExMatch.Pattern do
  @moduledoc false

  @fallback_to_any true

  @spec diff(t, any, any) :: [any] | {any, any}
  def diff(left, right, opts)

  @spec escape(t) :: any
  def escape(self)

  @spec value(t) :: any
  @doc """
  May throw ExMatch.NoValue
  """
  def value(self)
end

defmodule ExMatch.NoValue do
end

defimpl ExMatch.Pattern, for: Any do
  @moduledoc false

  def diff(left, right, opts) do
    diff_values(left, right, opts)
  end

  def escape(self),
    do: self

  def value(self),
    do: self

  def diff_values(left_value, right, opts, on_diff \\ nil) do
    get_opts = fn atom ->
      try do
        opts
        |> Map.get(atom)
        |> ExMatch.Pattern.value()
      catch
        ExMatch.NoValue ->
          nil
      end
    end

    case ExMatch.Value.diff(left_value, right, get_opts) do
      nil ->
        []

      {left_diff, right_diff} when on_diff == nil ->
        {Macro.escape(left_diff), right_diff}

      diff when is_function(on_diff, 1) ->
        on_diff.(diff)
    end
  end
end
