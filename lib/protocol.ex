defprotocol ExMatch.Protocol do
  @fallback_to_any true

  @spec diff(t, any, any) :: nil | {left :: any, right :: any}
  def diff(left, right, opts)
end

defimpl ExMatch.Protocol, for: Any do
  def diff(value, value, _), do: nil

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
      nil ->
        nil

      {left_map, right_map} ->
        {
          Map.put(left_map, :__struct__, struct),
          Map.put(right_map, :__struct__, struct)
        }
    end
  end

  def diff(left, right = %_{}, opts) do
    with impl = ExMatch.Protocol.impl_for(right),
         false <- impl == ExMatch.Protocol.Any,
         {right_result, left_result} <- ExMatch.Protocol.diff(right, left, opts) do
      {left_result, right_result}
    else
      nil -> nil
      true -> {left, right}
    end
  end

  def diff(left, right, _),
    do: {left, right}
end

defimpl ExMatch.Protocol, for: List do
  def diff([left_value | left], [right_value | right], opts) do
    this_diff = ExMatch.Protocol.diff(left_value, right_value, opts)
    rest_diff = diff(left, right, opts)

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

  def diff(left, right, _opts) do
    {left, right}
  end
end

defimpl ExMatch.Protocol, for: Tuple do
  def diff(left, right, opts) when is_tuple(right) do
    left = Tuple.to_list(left)
    right = Tuple.to_list(right)

    case ExMatch.Protocol.List.diff(left, right, opts) do
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

defimpl ExMatch.Protocol, for: Map do
  def diff(left, right, opts) when is_map(right) do
    case diff_items(left, right, opts) do
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

  def diff_items(left, right, opts) do
    {left_diffs, right_diffs, right, _opts} =
      Enum.reduce(left, {%{}, %{}, right, opts}, &diff_item/2)

    {left_diffs, right_diffs, right}
  end

  defp diff_item({key, field}, {left_diffs, right_diffs, right, opts}) do
    case right do
      %{^key => right_value} ->
        right = Map.delete(right, key)

        case ExMatch.Protocol.diff(field, right_value, opts) do
          {left_diff, right_diff} ->
            left_diffs = Map.put(left_diffs, key, left_diff)
            right_diffs = Map.put(right_diffs, key, right_diff)
            {left_diffs, right_diffs, right, opts}

          nil ->
            {left_diffs, right_diffs, right, opts}
        end

      _ ->
        left_diffs = Map.put(left_diffs, key, field)
        {left_diffs, right_diffs, right, opts}
    end
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
      :eq -> nil
      _ -> {left, right}
    end
  end
end

if Code.ensure_loaded?(Decimal) do
  defimpl ExMatch.Protocol, for: Decimal do
    require Decimal

    def diff(left, right, _) do
      # ignore floats
      Decimal.new(right)
      :eq = Decimal.compare(left, right)
      nil
    rescue
      _ ->
        {left, right}
    end
  end
end
