defmodule ExMatch do
  @moduledoc """
    Assertions for data equivalence.
  """

  alias ExMatch.Protocol

  @doc """
  Raises if the values don't match and displays what exactly was different.

  ```elixir
  ExMatch.assert([1, 2, 3], [1, 2, 3])
  ```
  """
  defmacro match(left, right) do
    {bindings, left} = parse_ast(left)

    quote do
      unquote(bindings) =
        case Protocol.diff(unquote(left), unquote(right), []) do
          bindings when is_list(bindings) ->
            bindings

          {diff_left, diff_right} = diff ->
            raise ExUnit.AssertionError,
              left: diff_left,
              right: diff_right,
              message: "match failed"
        end
    end
  end

  defp parse_ast({var, _, nil} = binding) when is_atom(var) do
    ExMatch.Var.parse(binding)
  end

  defp parse_ast({:%{}, _, _} = left) do
    ExMatch.Map.parse(left, &parse_ast/1)
  end

  defp parse_ast(left) when is_list(left) do
    ExMatch.List.parse(left, &parse_ast/1)
  end

  defp parse_ast({_, _} = left) do
    ExMatch.Tuple.parse(left, &parse_ast/1)
  end

  defp parse_ast({:{}, _, _} = left) do
    ExMatch.Tuple.parse(left, &parse_ast/1)
  end

  defp parse_ast(left) when is_number(left) or is_bitstring(left) or is_atom(left) do
    self =
      quote do
        unquote(left)
      end

    {[], self}
  end

  # pin variable
  defp parse_ast({:^, _, [{var_name, _, module} = var_item]}) when is_atom(var_name) and is_atom(module) do
    {[], var_item}
  end

  # local/imported function/macro call
  defp parse_ast({fn_name, _, args} = left) when is_atom(fn_name) and is_list(args) do
    self =
      quote do
        unquote(left)
      end

    {[], self}
  end

  # remote function/macro call
  defp parse_ast({{:., _, [{:__aliases__, _, [module_alias | _]}, fn_name]}, _, args} = left) when is_atom(module_alias) and is_atom(fn_name) and is_list(args) do
    self =
      quote do
        unquote(left)
      end

    {[], self}
  end
end

defprotocol ExMatch.Protocol do
  @fallback_to_any true
  def diff(left, right, opts)
end

defprotocol ExMatch.AsValue do
  @fallback_to_any true
  def as_value(self)
end

defmodule ExMatch.Var do
  defstruct []

  def parse({var, _, nil} = binding) when is_atom(var) do
    self =
      quote do
        %ExMatch.Var{}
      end

    {[binding], self}
  end

  defimpl ExMatch.Protocol do
    def diff(left, right, _opts) do
      %ExMatch.Var{} = left
      [right]
    end
  end
end

defmodule ExMatch.List do
  defstruct [:items]

  def parse(list, parse_ast) do
    {bindings, parsed} = parse_items(list, [], [], parse_ast)

    self =
      quote do
        %ExMatch.List{items: unquote(parsed)}
      end

    {bindings, self}
  end

  def parse_items([item | list], bindings, parsed, parse_ast) do
    {item_bindings, item_parsed} = parse_ast.(item)
    bindings = item_bindings ++ bindings
    parsed = [item_parsed | parsed]
    parse_items(list, bindings, parsed, parse_ast)
  end

  def parse_items([], bindings, parsed, _) do
    {bindings, Enum.reverse(parsed)}
  end

  defimpl ExMatch.Protocol do
    def diff(left, right, opts) when is_list(right) do
      %ExMatch.List{items: items} = left
      bindings = []
      diffs = {[], []}
      diff(items, bindings, diffs, right, opts)
    end

    def diff(left, right, _), do: {left, right}

    defp diff([item | items], bindings, diffs, right, opts) do
      case right do
        [right_item | right] ->
          case ExMatch.Protocol.diff(item, right_item, opts) do
            new_bindings when is_list(new_bindings) ->
              bindings = new_bindings ++ bindings
              diff(items, bindings, diffs, right, opts)

            {left_diff, right_diff} ->
              {left_diffs, right_diffs} = diffs
              diffs = {[left_diff | left_diffs], [right_diff | right_diffs]}
              diff(items, bindings, diffs, right, opts)
          end

        [] ->
          {left_diffs, right_diffs} = diffs
          {Enum.reverse(left_diffs, [item | items]), Enum.reverse(right_diffs)}
      end
    end

    defp diff([], bindings, diffs, right, _opts) do
      case diffs do
        {[], []} ->
          bindings

        {left_diffs, right_diffs} ->
          {Enum.reverse(left_diffs), Enum.reverse(right_diffs, right)}
      end
    end
  end
end

defmodule ExMatch.Tuple do
  defstruct [:items]

  def parse({:{}, _, items}, parse_ast), do: parse_items(items, parse_ast)
  def parse({item1, item2}, parse_ast), do: parse_items([item1, item2], parse_ast)

  defp parse_items(items, parse_ast) do
    {bindings, parsed} = ExMatch.List.parse_items(items, [], [], parse_ast)

    self =
      quote do
        %ExMatch.Tuple{items: unquote(parsed)}
      end

    {bindings, self}
  end

  defimpl ExMatch.Protocol do
    def diff(left, right, opts) when is_tuple(right) do
      %ExMatch.Tuple{items: items} = left
      left = %ExMatch.List{items: items}
      right = Tuple.to_list(right)

      case ExMatch.Protocol.ExMatch.List.diff(left, right, opts) do
        {left_diff, right_diff} ->
          {List.to_tuple(left_diff), List.to_tuple(right_diff)}

        bindings ->
          bindings
      end
    end
  end
end

defmodule ExMatch.Map do
  @enforce_keys [:partial, :fields]
  defstruct @enforce_keys

  def parse({:%{}, _, fields}, parse_ast) do
    parse(fields, false, [], [], parse_ast)
  end

  defp parse([field | fields], partial, bindings, parsed, parse_ast) do
    case field do
      {:..., _, nil} ->
        parse(fields, true, bindings, parsed, parse_ast)

      {key, value} ->
        {value_bindings, value_parsed} = parse_ast.(value)
        parsed = [{key, value_parsed} | parsed]
        bindings = value_bindings ++ bindings
        parse(fields, partial, bindings, parsed, parse_ast)
    end
  end

  defp parse([], partial, bindings, parsed, _) do
    parsed = Enum.reverse(parsed)

    self =
      quote do
        %ExMatch.Map{partial: unquote(partial), fields: unquote(parsed)}
      end

    {bindings, self}
  end

  defimpl ExMatch.Protocol do
    def diff(left, right, opts) when is_map(right) do
      %ExMatch.Map{partial: partial, fields: fields} = left
      diff(fields, [], {%{}, %{}}, right, partial, opts)
    end

    defp diff([{key, field} | fields], bindings, diffs, right, partial, opts) do
      case right do
        %{^key => right_value} ->
          right = Map.delete(right, key)

          case ExMatch.Protocol.diff(field, right_value, opts) do
            new_bindings when is_list(new_bindings) ->
              bindings = new_bindings ++ bindings
              diff(fields, bindings, diffs, right, partial, opts)

            {left_diff, right_diff} ->
              {left_diffs, right_diffs} = diffs

              diffs = {
                Map.put(left_diffs, key, left_diff),
                Map.put(right_diffs, key, right_diff)
              }

              diff(fields, bindings, diffs, right, partial, opts)
          end

        _ ->
          {left_diffs, right_diffs} = diffs

          diffs = {
            Map.put(left_diffs, key, field),
            right_diffs
          }

          diff(fields, bindings, diffs, right, partial, opts)
      end
    end

    defp diff([], bindings, {left_diffs, right_diffs}, right, partial, _opts)
         when left_diffs == %{} and
                right_diffs == %{} and
                (partial or right == %{}) do
      bindings
    end

    defp diff([], _, {left_diffs, right_diffs}, right, partial, _opts) do
      right_diffs =
        if partial do
          right_diffs
        else
          Map.merge(right_diffs, right)
        end

      {left_diffs, right_diffs}
    end
  end
end

defimpl ExMatch.Protocol, for: Any do
  def diff(value, value, _), do: []

  def diff(left = %struct{}, right = %struct{}, opts) do
    fields = Map.get(opts, struct, [])
    drop = Enum.filter(fields, &is_atom(&1))

    merge =
      Enum.reduce(fields, %{}, fn
        {key, value}, map -> Map.put(map, key, value)
        _, map -> map
      end)

    case ExMatch.Protocol.Map.diff(
           left |> Map.from_struct() |> Map.drop(drop) |> Map.merge(merge),
           right |> Map.from_struct() |> Map.drop(drop),
           opts
         ) do
      [] ->
        []

      {left_map, right_map} ->
        {
          Map.put(left_map, :__struct__, struct),
          Map.put(right_map, :__struct__, struct)
        }
    end
  end

  def diff(left, right = %_{}, opts) do
    case ExMatch.Protocol.diff(right, left, opts) do
      [] -> []
      {right_result, left_result} -> {left_result, right_result}
    end
  end

  def diff(left, right, _), do: {left, right}
end

defimpl ExMatch.Protocol, for: Map do
  def normalize(map) do
    map
  end

  def diff(left, right, opts) when is_map(right) do
    left_keys = Map.keys(left)
    right_keys = Map.keys(right)

    all_keys = Enum.uniq(left_keys ++ right_keys)

    case Enum.reduce(all_keys, {%{}, %{}}, &compare_values(&1, &2, left, right, opts)) do
      {left_result, right_result} when left_result == %{} and right_result == %{} ->
        []

      {_, _} = results ->
        results
    end
  end

  defp compare_values(key, results, left, right, opts) do
    {left_results, right_results} = results

    case {left, right} do
      {%{^key => left_value}, %{^key => right_value}} ->
        case ExMatch.Protocol.diff(left_value, right_value, opts) do
          [] ->
            results

          {left_result, right_result} ->
            {
              Map.put(left_results, key, left_result),
              Map.put(right_results, key, right_result)
            }
        end

      {%{^key => left_value}, _} ->
        {
          Map.put(left_results, key, left_value),
          right_results
        }

      {_, %{^key => right_value}} ->
        {
          left_results,
          Map.put(right_results, key, right_value)
        }
    end
  end
end

defimpl ExMatch.Protocol, for: List do
  def normalize(list) do
    list
  end

  def diff([left_value | left], [right_value | right], opts) do
    this_diff = ExMatch.Protocol.diff(left_value, right_value, opts)
    rest_diff = diff(left, right, opts)

    case {this_diff, rest_diff} do
      {nil, nil} ->
        []

      {nil, {left_results, right_results}} ->
        {[:eq | left_results], [:eq | right_results]}

      {{left_result, right_result}, nil} ->
        {[left_result], [right_result]}

      {{left_result, right_result}, {left_results, right_results}} ->
        {[left_result | left_results], [right_result | right_results]}
    end
  end

  def diff([], [], _), do: []

  def diff(left, right, _opts) do
    {left, right}
  end
end

defimpl ExMatch.Protocol, for: DateTime do
  def diff(left, right = %DateTime{}, _) do
    diff_dates(left, right, right)
  end

  def diff(left, right, _) when is_binary(right) do
    case DateTime.from_iso8601(right) do
      {:ok, right_date, _} ->
        diff_dates(left, right, right_date)
      _ ->
        {left, right}
    end
  end

  def diff_dates(left, right, right_date) do
    case DateTime.compare(left, right_date) do
      :eq -> []
      _ -> {left, right}
    end
  end
end

defimpl ExMatch.Protocol, for: Tuple do
  def diff(left, right, opts) when is_tuple(right) do
    left = Tuple.to_list(left)
    right = Tuple.to_list(right)

    case ExMatch.Protocol.List.diff(left, right, opts) do
      {left, right} ->
        {List.to_tuple(left), List.to_tuple(right)}

      [] ->
        []
    end
  end

  def diff(left, right, _) do
    {left, right}
  end
end

if Code.ensure_loaded?(Decimal) do
  defimpl ExMatch.Protocol, for: Decimal do
    require Decimal

    def diff(left, right, _) do
      # ignore floats
      Decimal.new(right)
      :eq = Decimal.compare(left, right)
      []
    rescue
      _ ->
        {left, right}
    end
  end
end

Protocol
