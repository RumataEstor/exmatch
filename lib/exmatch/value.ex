defprotocol ExMatch.Value do
  @fallback_to_any true

  @spec diff(t, any, (atom -> any)) :: nil | {left :: any, right :: any}
  def diff(left, right, get_opts)
end

defimpl ExMatch.Value, for: Any do
  def diff(value, value, _), do: nil

  def diff(left = %struct{}, right = %struct{}, get_opts) do
    case ExMatch.Value.Map.diff(
           left |> Map.from_struct(),
           right |> Map.from_struct(),
           get_opts
         ) do
      nil ->
        nil

      {left_map, right_map} ->
        {
          Map.put(left_map, :__struct__, struct),
          Map.put(right_map, :__struct__, struct)
        }
    end
  end

  def diff(left, right = %_{}, get_opts) do
    with impl = ExMatch.Value.impl_for(right),
         false <- impl == ExMatch.Value.Any,
         {right_result, left_result} <- ExMatch.Value.diff(right, left, get_opts) do
      {left_result, right_result}
    else
      nil -> nil
      true -> {left, right}
    end
  end

  def diff(left, right, _),
    do: {left, right}
end

defimpl ExMatch.Value, for: List do
  def diff([left_value | left], [right_value | right], get_opts) do
    this_diff = ExMatch.Value.diff(left_value, right_value, get_opts)
    rest_diff = diff(left, right, get_opts)

    case {this_diff, rest_diff} do
      {nil, nil} ->
        nil

      {nil, {left_results, right_results}} ->
        {[:eq | left_results], [:eq | right_results]}

      {{left_result, right_result}, nil} ->
        {[left_result], [right_result]}

      {{left_result, right_result}, {left_results, right_results}} ->
        {[left_result | left_results], [right_result | right_results]}
    end
  end

  def diff([], [], _), do: nil

  def diff(left, right, _) do
    {left, right}
  end
end

defimpl ExMatch.Value, for: Tuple do
  def diff(left, right, get_opts) when is_tuple(right) do
    left = Tuple.to_list(left)
    right = Tuple.to_list(right)

    case ExMatch.Value.List.diff(left, right, get_opts) do
      {left, right} ->
        {List.to_tuple(left), List.to_tuple(right)}

      nil ->
        nil
    end
  end

  def diff(left, right, _) do
    {left, right}
  end
end

defimpl ExMatch.Value, for: Map do
  def diff(left, right, get_opts) when is_map(right) do
    case diff_items(left, right, get_opts) do
      {left_diffs, right_diffs, right}
      when left_diffs == [] and right_diffs == %{} and right == %{} ->
        nil

      {left_diffs, right_diffs, right} ->
        {Map.new(left_diffs), Map.merge(right, right_diffs)}
    end
  end

  def diff(left, right, _opts) do
    {left, right}
  end

  def diff_items(left, right, get_opts) do
    Enum.reduce(left, {%{}, %{}, right}, &diff_item(&1, &2, get_opts))
  end

  defp diff_item({key, field}, {left_diffs, right_diffs, right}, get_opts) do
    case right do
      %{^key => right_value} ->
        right = Map.delete(right, key)

        case ExMatch.Value.diff(field, right_value, get_opts) do
          {left_diff, right_diff} ->
            left_diffs = Map.put(left_diffs, key, left_diff)
            right_diffs = Map.put(right_diffs, key, right_diff)
            {left_diffs, right_diffs, right}

          nil ->
            {left_diffs, right_diffs, right}
        end

      _ ->
        left_diffs = Map.put(left_diffs, key, field)
        {left_diffs, right_diffs, right}
    end
  end
end

defimpl ExMatch.Value, for: DateTime do
  def diff(left, right, get_opts) when is_binary(right) do
    opts = get_opts.(DateTime) || []

    case :match_string in opts and DateTime.from_iso8601(right) do
      {:ok, right_date, _} ->
        diff_dates(left, right, right_date)

      _ ->
        {left, right}
    end
  end

  def diff(left, right = %DateTime{}, _) do
    diff_dates(left, right, right)
  end

  def diff(left, right, _) do
    {left, right}
  end

  defp diff_dates(left, right, right_date) do
    case DateTime.compare(left, right_date) do
      :eq -> nil
      _ -> {left, right}
    end
  end
end

if Code.ensure_loaded?(Decimal) do
  defimpl ExMatch.Value, for: Decimal do
    require Decimal

    def diff(left, right, get_opts) do
      opts = get_opts.(Decimal) || []

      if is_float(right) or
           (is_binary(right) and :match_string not in opts) or
           (is_integer(right) and :match_integer not in opts) do
        {left, right}
      else
        parse_and_diff(left, right)
      end
    end

    defp parse_and_diff(left, right) do
      Decimal.new(right)
      :eq = Decimal.compare(left, right)
      nil
    catch
      _, _ ->
        {left, right}
    end
  end
end
