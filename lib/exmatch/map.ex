defmodule ExMatch.Map do
  @moduledoc false

  alias ExMatch.ParseContext

  @enforce_keys [:partial, :fields]
  defstruct @enforce_keys

  def parse({:%{}, _, fields}, parse_context) do
    {partial, bindings, parsed} = parse_fields(fields, parse_context)

    self =
      quote location: :keep do
        %ExMatch.Map{
          partial: unquote(partial),
          fields: unquote(parsed)
        }
      end

    {bindings, self}
  end

  def parse_fields(fields, parse_context) do
    {partial, bindings, parsed} =
      Enum.reduce(fields, {false, [], []}, fn
        item, {partial, binding, parsed} ->
          parse_field(item, partial, binding, parsed, parse_context)
      end)

    {partial, bindings, Enum.reverse(parsed)}
  end

  defp parse_field({:..., _, nil}, _partial, bindings, parsed, _parse_context) do
    {true, bindings, parsed}
  end

  defp parse_field({key, value}, partial, bindings, parsed, parse_context) do
    {value_bindings, value_parsed} = ParseContext.parse(value, parse_context)
    parsed = [{key, value_parsed} | parsed]
    bindings = value_bindings ++ bindings
    {partial, bindings, parsed}
  end

  def diff_items(fields, right, partial, opts) do
    case Enum.reduce(fields, {[], [], %{}, right, opts}, &diff_item/2) do
      {bindings, [], right_diffs, right, _opts}
      when right_diffs == %{} and (partial or right == %{}) ->
        bindings

      {_bindings, left_diffs, right_diffs, right, _opts} ->
        left_diffs = Enum.reverse(left_diffs)

        right_diffs =
          if partial do
            right_diffs
          else
            Map.merge(right_diffs, right)
          end

        {left_diffs, right_diffs}
    end
  end

  defp diff_item({key, field}, {bindings, left_diffs, right_diffs, right, opts}) do
    case right do
      %{^key => right_value} ->
        right = Map.delete(right, key)

        case ExMatch.Pattern.diff(field, right_value, opts) do
          {left_diff, right_diff} ->
            left_diffs = [{key, left_diff} | left_diffs]
            right_diffs = Map.put(right_diffs, key, right_diff)
            {bindings, left_diffs, right_diffs, right, opts}

          new_bindings ->
            bindings = new_bindings ++ bindings
            {bindings, left_diffs, right_diffs, right, opts}
        end

      _ ->
        left_diff = {key, ExMatch.Pattern.escape(field)        }

        left_diffs = [left_diff | left_diffs]

        {bindings, left_diffs, right_diffs, right, opts}
    end
  end

  def field_values(fields) do
    Enum.map(fields, fn {key, value} ->
      {
        ExMatch.Pattern.value(key),
        ExMatch.Pattern.value(value)
      }
    end)
  end

  def escape_fields(fields) do
    Enum.map(fields, fn {key, value} ->
      {
        ExMatch.Pattern.escape(key),
        ExMatch.Pattern.escape(value)
      }
    end)
  end

  defimpl ExMatch.Pattern do
    @moduledoc false

    def diff(left, right, opts) when is_map(right) do
      %ExMatch.Map{partial: partial, fields: fields} = left

      case ExMatch.Map.diff_items(fields, right, partial, opts) do
        {left_diffs, right_diffs} ->
          left_diffs = {:%{}, [], left_diffs}
          {left_diffs, right_diffs}

        bindings ->
          bindings
      end
    end

    def diff(left, right, _opts) do
      {escape(left), right}
    end

    def escape(%ExMatch.Map{fields: fields}) do
      fields = ExMatch.Map.escape_fields(fields)
      {:%{}, [], fields}
    end

    def value(%ExMatch.Map{partial: true}),
      do: raise(ArgumentError, "partial map doesn't represent a value")

    def value(%ExMatch.Map{fields: fields}),
      do: fields |> ExMatch.Map.field_values() |> Map.new()
  end
end
