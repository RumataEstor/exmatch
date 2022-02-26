defprotocol ExMatch.BindingProtocol do
  @moduledoc false

  @fallback_to_any true

  @spec diff(t, any, any) :: [any] | {any, any}
  def diff(left, right, opts)

  @spec escape(t) :: any
  def escape(self)

  @spec value(t) :: any
  def value(self)
end

defimpl ExMatch.BindingProtocol, for: Any do
  @moduledoc false

  def diff(left, right, opts) do
    case ExMatch.Protocol.diff(left, right, opts) do
      nil ->
        []

      {left_diff, right_diff} ->
        {Macro.escape(left_diff), right_diff}
    end
  end

  # def diff(value, value, _), do: []

  # def diff(left = %struct{}, right = %struct{}, opts) do
  #   fields = Map.get(opts, struct, [])
  #   drop = Enum.filter(fields, &is_atom(&1))

  #   merge =
  #     Enum.reduce(fields, %{}, fn
  #       {key, value}, map -> Map.put(map, key, value)
  #       _, map -> map
  #     end)

  #   case ExMatch.Protocol.Map.diff(
  #          left |> Map.from_struct() |> Map.drop(drop) |> Map.merge(merge),
  #          right |> Map.from_struct() |> Map.drop(drop),
  #          opts
  #        ) do
  #     nil ->
  #       []

  #     {left_map, right_map} ->
  #       {
  #         Map.put(left_map, :__struct__, struct),
  #         Map.put(right_map, :__struct__, struct)
  #       }
  #   end
  # end

  # def diff(left, right = %_{}, opts) do
  #   case ExMatch.Protocol.diff(right, left, opts) do
  #     nil -> []
  #     {right_result, left_result} -> {left_result, right_result}
  #   end
  # end

  # def diff(left, right, _),
  #   do: {escape(left), right}

  def escape(self),
    do: Macro.escape(self)

  def value(self),
    do: self
end

defmodule ExMatch.Expr do
  @moduledoc false

  defstruct [:ast, :value]

  # pin variable
  def parse({:^, _, [{var_name, _, module} = var_item]} = ast)
      when is_atom(var_name) and is_atom(module),
      do: parse(ast, var_item)

  # remote function/macro call
  def parse({{:., _, [{:__aliases__, _, [module_alias | _]}, fn_name]}, _, args} = ast)
      when is_atom(module_alias) and is_atom(fn_name) and is_list(args),
      do: parse(ast, ast)

  # local/imported function/macro call
  def parse({fn_name, _, args} = ast) when is_atom(fn_name) and is_list(args) do
    if Macro.special_form?(fn_name, length(args)) do
      raise "Special form #{fn_name}/#{length(args)} is not yet supported in ExMatch"
    end

    parse(ast, ast)
  end

  defp parse(ast, value) do
    self =
      quote do
        %ExMatch.Expr{
          ast: unquote(Macro.escape(ast)),
          value: unquote(value)
        }
      end

    {[], self}
  end

  defimpl ExMatch.BindingProtocol do
    @moduledoc false

    def diff(left, right, opts) do
      %ExMatch.Expr{ast: ast, value: value} = left

      case ExMatch.Protocol.diff(value, right, opts) do
        {^value, right_diff} ->
          {escape(left), right_diff}

        {left_diff, right_diff} ->
          left_diff = {:=~, [], [ast, Macro.escape(left_diff)]}
          {left_diff, right_diff}

        nil ->
          []
      end
    end

    def escape(%ExMatch.Expr{ast: ast, value: value}) do
      code =
        ast
        |> Code.quoted_to_algebra()
        |> Inspect.Algebra.format(:infinity)
        |> IO.iodata_to_binary()

      if code == inspect(value) do
        ast
      else
        {:=, [], [ast, Macro.escape(value)]}
      end
    end

    def value(%ExMatch.Expr{value: value}),
      do: value
  end
end

defmodule ExMatch.Var do
  @moduledoc false

  defstruct [:ast]

  def parse({var, _, nil} = ast) when is_atom(var) do
    self =
      quote do
        %ExMatch.Var{ast: unquote(Macro.escape(ast))}
      end

    {[ast], self}
  end

  defimpl ExMatch.BindingProtocol do
    @moduledoc false

    def diff(_left, right, _opts) do
      [right]
    end

    def escape(%ExMatch.Var{ast: ast}),
      do: ast

    def value(_self),
      do: raise(ArgumentError, "Bindings don't represent values")
  end
end

defmodule ExMatch.List do
  @moduledoc false

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

  def diff([item | items], bindings, left_diffs, right_diffs, right, opts) do
    case right do
      [right_item | right] ->
        case ExMatch.BindingProtocol.diff(item, right_item, opts) do
          new_bindings when is_list(new_bindings) ->
            bindings = new_bindings ++ bindings
            diff(items, bindings, left_diffs, right_diffs, right, opts)

          {left_diff, right_diff} ->
            left_diffs = [left_diff | left_diffs]
            right_diffs = [right_diff | right_diffs]
            diff(items, bindings, left_diffs, right_diffs, right, opts)
        end

      [] ->
        items = escape_items([item | items])
        {Enum.reverse(left_diffs, items), Enum.reverse(right_diffs)}
    end
  end

  def diff([], bindings, [], [], _right, _opts), do: bindings

  def diff([], _bindings, left_diffs, right_diffs, right, _opts) do
    {Enum.reverse(left_diffs), Enum.reverse(right_diffs, right)}
  end

  def escape_items(items) do
    Enum.map(items, &ExMatch.BindingProtocol.escape/1)
  end

  def value(items) do
    Enum.map(items, &ExMatch.BindingProtocol.value/1)
  end

  defimpl ExMatch.BindingProtocol do
    @moduledoc false

    def diff(left, right, opts) when is_list(right) do
      %ExMatch.List{items: items} = left
      ExMatch.List.diff(items, [], [], [], right, opts)
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

defmodule ExMatch.Tuple do
  @moduledoc false

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

  defimpl ExMatch.BindingProtocol do
    @moduledoc false

    def diff(left, right, opts) when is_tuple(right) do
      %ExMatch.Tuple{items: items} = left

      case ExMatch.List.diff(items, [], [], [], Tuple.to_list(right), opts) do
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
      do: {ExMatch.BindingProtocol.escape(i1), ExMatch.BindingProtocol.escape(i2)}

    def escape(%ExMatch.Tuple{items: items}),
      do: {:{}, [], ExMatch.List.escape_items(items)}

    def value(%ExMatch.Tuple{items: items}),
      do:
        items
        |> ExMatch.List.value()
        |> List.to_tuple()
  end
end

defmodule ExMatch.Map do
  @moduledoc false

  @enforce_keys [:partial, :fields]
  defstruct @enforce_keys

  def parse({:%{}, _, fields}, parse_ast) do
    {partial, bindings, parsed} = parse_fields(fields, parse_ast)

    self =
      quote do
        %ExMatch.Map{
          partial: unquote(partial),
          fields: unquote(parsed)
        }
      end

    {bindings, self}
  end

  def parse_fields(fields, parse_ast) do
    {partial, bindings, parsed, _parse_ast} =
      Enum.reduce(fields, {false, [], [], parse_ast}, &parse_field/2)

    {partial, bindings, Enum.reverse(parsed)}
  end

  defp parse_field({:..., _, nil}, {_partial, bindings, parsed, parse_ast}) do
    {true, bindings, parsed, parse_ast}
  end

  defp parse_field({key, value}, {partial, bindings, parsed, parse_ast}) do
    {value_bindings, value_parsed} = parse_ast.(value)
    parsed = [{key, value_parsed} | parsed]
    bindings = value_bindings ++ bindings
    {partial, bindings, parsed, parse_ast}
  end

  def diff_items(fields, right, opts) do
    {bindings, left_diffs, right_diffs, right, _opts} =
      Enum.reduce(fields, {[], [], %{}, right, opts}, &diff_item/2)

    {bindings, Enum.reverse(left_diffs), right_diffs, right}
  end

  defp diff_item({key, field}, {bindings, left_diffs, right_diffs, right, opts}) do
    case right do
      %{^key => right_value} ->
        right = Map.delete(right, key)

        case ExMatch.BindingProtocol.diff(field, right_value, opts) do
          {left_diff, right_diff} ->
            left_diffs = [{ExMatch.BindingProtocol.escape(key), left_diff} | left_diffs]
            right_diffs = Map.put(right_diffs, key, right_diff)
            {bindings, left_diffs, right_diffs, right, opts}

          new_bindings ->
            bindings = new_bindings ++ bindings
            {bindings, left_diffs, right_diffs, right, opts}
        end

      _ ->
        left_diff = {
          ExMatch.BindingProtocol.escape(key),
          ExMatch.BindingProtocol.escape(field)
        }

        left_diffs = [left_diff | left_diffs]

        {bindings, left_diffs, right_diffs, right, opts}
    end
  end

  def field_values(fields),
    do:
      Enum.map(fields, fn {key, value} ->
        {
          ExMatch.BindingProtocol.value(key),
          ExMatch.BindingProtocol.value(value)
        }
      end)

  defimpl ExMatch.BindingProtocol do
    @moduledoc false

    def diff(left, right, opts) when is_map(right) do
      %ExMatch.Map{partial: partial, fields: fields} = left

      case ExMatch.Map.diff_items(fields, right, opts) do
        {bindings, left_diffs, right_diffs, right}
        when left_diffs == [] and
               right_diffs == %{} and
               (partial or right == %{}) ->
          bindings

        {_bindings, left_diffs, right_diffs, right} ->
          right_diffs =
            if partial do
              right_diffs
            else
              Map.merge(right_diffs, right)
            end

          left_diffs = {:%{}, [], left_diffs}
          {left_diffs, right_diffs}
      end
    end

    def diff(left, right, _opts) do
      {escape(left), right}
    end

    def escape(%ExMatch.Map{fields: fields} = left) do
      fields =
        Enum.map(fields, fn {key, value} ->
          {
            ExMatch.BindingProtocol.escape(key),
            ExMatch.BindingProtocol.escape(value)
          }
        end)

      {:%{}, [], fields ++ and_partial_ast(left)}
    end

    defp and_partial_ast(%ExMatch.Map{partial: partial}) do
      if partial do
        [quote(do: ...)]
      else
        []
      end
    end

    def value(%ExMatch.Map{partial: true}),
      do: raise(ArgumentError, "partial map doesn't represent a value")

    def value(%ExMatch.Map{fields: fields}),
      do: fields |> ExMatch.Map.field_values() |> Map.new()
  end
end

defmodule ExMatch.Struct do
  @moduledoc false

  defmodule WithValue do
    defstruct [:module, :fields, :value]

    defimpl ExMatch.BindingProtocol do
      @moduledoc false

      def escape(%WithValue{module: module, fields: fields}),
        do: ExMatch.Struct.escape(module, fields, false)

      def value(%WithValue{value: value}),
        do: value

      def diff(left, right, opts) do
        %WithValue{module: module, fields: fields, value: value} = left

        case ExMatch.Protocol.diff(value, right, opts) do
          nil -> []
          {_, _} -> ExMatch.Struct.diff(module, fields, false, right, opts)
        end
      end
    end
  end

  defmodule NoValue do
    defstruct [:module, :fields, :partial]

    defimpl ExMatch.BindingProtocol do
      @moduledoc false

      def escape(%NoValue{module: module, fields: fields, partial: partial}),
        do: ExMatch.Struct.escape(module, fields, partial)

      def value(%NoValue{}),
        do: raise("This struct doesn't have value")

      def diff(left, right, opts) do
        %NoValue{module: module, fields: fields, partial: partial} = left
        ExMatch.Struct.diff(module, fields, partial, right, opts)
      end
    end
  end

  def parse(
        {:%, _, [module, {:%{}, _, fields}]},
        parse_ast
      )
      when is_list(fields) do
    {partial, bindings, parsed} = ExMatch.Map.parse_fields(fields, parse_ast)

    self =
      quote do
        ExMatch.Struct.new(
          unquote(module),
          unquote(parsed),
          unquote(partial)
        )
      end

    {bindings, self}
  end

  def new(module, fields, partial) do
    if partial do
      raise ArgumentError
    end

    value = struct!(module, ExMatch.Map.field_values(fields))

    fields =
      value
      |> Map.from_struct()
      |> Enum.map(fn {key, value} ->
        {key, Macro.escape(value)}
      end)
      |> Keyword.merge(fields, fn _, _, field -> field end)

    %WithValue{
      module: module,
      fields: fields,
      value: value
    }
  rescue
    ArgumentError ->
      %NoValue{
        module: module,
        fields: fields,
        partial: partial
      }
  end

  def diff(module, fields, partial, %rstruct{} = right, opts) do
    map = %ExMatch.Map{fields: fields, partial: partial}
    right_map = Map.from_struct(right)

    case ExMatch.BindingProtocol.ExMatch.Map.diff(map, right_map, opts) do
      {left_diff, right_diff} ->
        right_diff = Map.put(right_diff, :__struct__, rstruct)

        try do
          _ = inspect(right_diff, safe: false)
          {{:%, [], [module, left_diff]}, right_diff}
        rescue
          _ ->
            {escape(module, fields, partial), right}
        end

      bindings ->
        bindings
    end
  end

  def diff(module, fields, partial, right, _opts) do
    {escape(module, fields, partial), right}
  end

  def escape(module, fields, partial) do
    map = %ExMatch.Map{
      partial: partial,
      fields: fields
    }

    map = ExMatch.BindingProtocol.ExMatch.Map.escape(map)

    {:%, [], [module, map]}
  end
end
