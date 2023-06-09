defmodule ExMatch.Tuple do
  @moduledoc false

  @enforce_keys [:items]
  defstruct @enforce_keys

  def parse({:{}, _, items}, parse_context), do: parse_items(items, parse_context)
  def parse({item1, item2}, parse_context), do: parse_items([item1, item2], parse_context)

  defp parse_items(items, parse_context) do
    {bindings, parsed} = ExMatch.List.parse_items(items, [], [], parse_context)

    self =
      quote location: :keep do
        %ExMatch.Tuple{items: unquote(parsed)}
      end

    {bindings, self}
  end

  defimpl ExMatch.Pattern do
    @moduledoc false

    def diff(left, right, opts) when is_tuple(right) do
      %ExMatch.Tuple{items: items} = left

      case ExMatch.List.diff(items, Tuple.to_list(right), opts) do
        {left_diffs, right_diffs} ->
          right_diffs = List.to_tuple(right_diffs)
          {{:{}, [], left_diffs}, right_diffs}

        bindings ->
          bindings
      end
    end

    def diff(left, right, _opts) do
      {escape(left), right}
    end

    def escape(%ExMatch.Tuple{items: [i1, i2]}),
      do: {ExMatch.Pattern.escape(i1), ExMatch.Pattern.escape(i2)}

    def escape(%ExMatch.Tuple{items: items}),
      do: {:{}, [], ExMatch.List.escape_items(items)}

    def value(%ExMatch.Tuple{items: items}),
      do:
        items
        |> ExMatch.List.value()
        |> List.to_tuple()
  end
end
