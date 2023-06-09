defmodule ExMatch.List do
  @moduledoc false

  alias ExMatch.ParseContext

  @enforce_keys [:items]
  defstruct @enforce_keys

  def parse(list, parse_context) do
    {bindings, parsed} = parse_items(list, [], [], parse_context)

    self =
      quote location: :keep do
        %ExMatch.List{items: unquote(parsed)}
      end

    {bindings, self}
  end

  def parse_items([item | list], bindings, parsed, parse_context) do
    {item_bindings, item_parsed} = ParseContext.parse(item, parse_context)
    bindings = item_bindings ++ bindings
    parsed = [item_parsed | parsed]
    parse_items(list, bindings, parsed, parse_context)
  end

  def parse_items([], bindings, parsed, _parse_context) do
    {bindings, Enum.reverse(parsed)}
  end

  def diff(items, right, opts) do
    diff(items, 0, [], [], [], right, opts)
  end

  defp diff([item | items], skipped, bindings, left_diffs, right_diffs, right, opts) do
    case right do
      [right_item | right] ->
        case ExMatch.Pattern.diff(item, right_item, opts) do
          new_bindings when is_list(new_bindings) ->
            bindings = new_bindings ++ bindings
            diff(items, skipped + 1, bindings, left_diffs, right_diffs, right, opts)

          {left_diff, right_diff} ->
            skipped = ExMatch.Skipped.list(skipped)
            left_diffs = [left_diff | skipped ++ left_diffs]
            right_diffs = [right_diff | skipped ++ right_diffs]
            diff(items, 0, bindings, left_diffs, right_diffs, right, opts)
        end

      [] ->
        items = escape_items([item | items])
        {Enum.reverse(left_diffs, items), Enum.reverse(right_diffs)}
    end
  end

  defp diff([], _skipped, bindings, [], [], [], _opts), do: bindings

  defp diff([], skipped, _bindings, left_diffs, right_diffs, right, _opts) do
    skipped = ExMatch.Skipped.list(skipped)
    left_diffs = skipped ++ left_diffs
    right_diffs = skipped ++ right_diffs
    {Enum.reverse(left_diffs), Enum.reverse(right_diffs, right)}
  end

  def escape_items(items) do
    Enum.map(items, &ExMatch.Pattern.escape/1)
  end

  def value(items) do
    Enum.map(items, &ExMatch.Pattern.value/1)
  end

  defimpl ExMatch.Pattern do
    @moduledoc false

    def diff(left, right, opts) when is_list(right) do
      %ExMatch.List{items: items} = left
      ExMatch.List.diff(items, right, opts)
    end

    def diff(left, right, _) do
      {escape(left), right}
    end

    def escape(%ExMatch.List{items: items}),
      do: ExMatch.List.escape_items(items)

    def value(%ExMatch.List{items: items}),
      do: ExMatch.List.value(items)
  end
end
