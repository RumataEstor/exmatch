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
    do: Macro.escape(self)

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
      ExMatch.Diff.diff(left_value, right, get_opts)
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

  defimpl ExMatch.Match do
    @moduledoc false

    def diff(left, right, opts) do
      %ExMatch.Expr{ast: ast, value: value} = left

      ExMatch.Match.Any.diff_values(value, right, opts, fn
        {^value, right_diff} ->
          {escape(left), right_diff}

        {left_diff, right_diff} ->
          left_diff = {:=~, [], [ast, Macro.escape(left_diff)]}
          {left_diff, right_diff}
      end)
    end

    def escape(%ExMatch.Expr{ast: ast, value: value}) do
      code = Macro.to_string(ast)

      if code == inspect(value) do
        ast
      else
        {:=, [], [ast, value]}
      end
    end

    def value(%ExMatch.Expr{value: value}),
      do: value
  end
end

defmodule ExMatch.Var do
  @moduledoc false

  defstruct [:binding, :expr, :expr_fun]

  def parse({var, _, context} = binding) when is_atom(var) and is_atom(context) do
    self =
      quote do
        %ExMatch.Var{
          binding: unquote(Macro.escape(binding))
        }
      end

    case var do
      :_ -> {[], self}
      _ -> {[binding], self}
    end
  end

  def parse({:when, _, [{var, meta, context} = binding, expr]})
      when is_atom(var) and is_atom(context) do
    self =
      quote do
        %ExMatch.Var{
          binding: unquote(Macro.escape(binding)),
          expr: unquote(Macro.escape(expr)),
          expr_fun: fn unquote(binding) -> unquote(expr) end
        }
      end

    {[{var, [generated: true] ++ meta, context}], self}
  end

  defimpl ExMatch.Match do
    @moduledoc false

    def diff(%ExMatch.Var{binding: binding, expr: nil, expr_fun: nil}, right, _opts) do
      case binding do
        {:_, _, nil} -> []
        _ -> [right]
      end
    end

    def diff(%ExMatch.Var{binding: binding, expr: expr, expr_fun: expr_fun}, right, _opts) do
      expr_fun.(right)
    catch
      class, error ->
        ast =
          quote do
            unquote(binding) = unquote(Macro.escape(right))
            when unquote(expr) = unquote(class)(unquote(error))
          end

        {ast, right}
    else
      falsy when falsy in [nil, false] ->
        ast =
          quote do
            unquote(binding) = unquote(Macro.escape(right))
            when unquote(expr) = unquote(Macro.escape(falsy))
          end

        {ast, right}

      _truthy ->
        [right]
    end

    def escape(%ExMatch.Var{binding: binding, expr: nil}),
      do: binding

    def escape(%ExMatch.Var{binding: binding, expr: expr}) do
      quote do
        unquote(binding) when unquote(expr)
      end
    end

    def value(_self),
      do: raise(ArgumentError, "Bindings don't represent values")
  end
end

defmodule ExMatch.List do
  @moduledoc false

  defstruct [:items]

  def parse(list, parse_ast, opts) do
    {bindings, parsed} = parse_items(list, [], [], parse_ast, opts)

    self =
      quote do
        %ExMatch.List{items: unquote(parsed)}
      end

    {bindings, self}
  end

  def parse_items([item | list], bindings, parsed, parse_ast, opts) do
    {item_bindings, item_parsed} = parse_ast.(item, opts)
    bindings = item_bindings ++ bindings
    parsed = [item_parsed | parsed]
    parse_items(list, bindings, parsed, parse_ast, opts)
  end

  def parse_items([], bindings, parsed, _parse_ast, _opts) do
    {bindings, Enum.reverse(parsed)}
  end

  def diff(items, right, opts) do
    diff(items, 0, [], [], [], right, opts)
  end

  defp diff([item | items], skipped, bindings, left_diffs, right_diffs, right, opts) do
    case right do
      [right_item | right] ->
        case ExMatch.Match.diff(item, right_item, opts) do
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
    Enum.map(items, &ExMatch.Match.escape/1)
  end

  def value(items) do
    Enum.map(items, &ExMatch.Match.value/1)
  end

  defimpl ExMatch.Match do
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

defmodule ExMatch.Tuple do
  @moduledoc false

  defstruct [:items]

  def parse({:{}, _, items}, parse_ast, opts), do: parse_items(items, parse_ast, opts)
  def parse({item1, item2}, parse_ast, opts), do: parse_items([item1, item2], parse_ast, opts)

  defp parse_items(items, parse_ast, opts) do
    {bindings, parsed} = ExMatch.List.parse_items(items, [], [], parse_ast, opts)

    self =
      quote do
        %ExMatch.Tuple{items: unquote(parsed)}
      end

    {bindings, self}
  end

  defimpl ExMatch.Match do
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
      do: {ExMatch.Match.escape(i1), ExMatch.Match.escape(i2)}

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

  def parse({:%{}, _, fields}, parse_ast, opts) do
    {partial, bindings, parsed} = parse_fields(fields, parse_ast, opts)

    self =
      quote do
        %ExMatch.Map{
          partial: unquote(partial),
          fields: unquote(parsed)
        }
      end

    {bindings, self}
  end

  def parse_fields(fields, parse_ast, opts) do
    {partial, bindings, parsed} =
      Enum.reduce(fields, {false, [], []}, fn
        item, {partial, binding, parsed} ->
          parse_field(item, partial, binding, parsed, parse_ast, opts)
      end)

    {partial, bindings, Enum.reverse(parsed)}
  end

  defp parse_field({:..., _, nil}, _partial, bindings, parsed, _parse_ast, _opts) do
    {true, bindings, parsed}
  end

  defp parse_field({key, value}, partial, bindings, parsed, parse_ast, opts) do
    {value_bindings, value_parsed} = parse_ast.(value, opts)
    parsed = [{key, value_parsed} | parsed]
    bindings = value_bindings ++ bindings
    {partial, bindings, parsed}
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

        case ExMatch.Match.diff(field, right_value, opts) do
          {left_diff, right_diff} ->
            left_diffs = [{ExMatch.Match.escape(key), left_diff} | left_diffs]
            right_diffs = Map.put(right_diffs, key, right_diff)
            {bindings, left_diffs, right_diffs, right, opts}

          new_bindings ->
            bindings = new_bindings ++ bindings
            {bindings, left_diffs, right_diffs, right, opts}
        end

      _ ->
        left_diff = {
          ExMatch.Match.escape(key),
          ExMatch.Match.escape(field)
        }

        left_diffs = [left_diff | left_diffs]

        {bindings, left_diffs, right_diffs, right, opts}
    end
  end

  def field_values(fields),
    do:
      Enum.map(fields, fn {key, value} ->
        {
          ExMatch.Match.value(key),
          ExMatch.Match.value(value)
        }
      end)

  defimpl ExMatch.Match do
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

    def escape(%ExMatch.Map{fields: fields}) do
      fields =
        Enum.map(fields, fn {key, value} ->
          {
            ExMatch.Match.escape(key),
            ExMatch.Match.escape(value)
          }
        end)

      {:%{}, [], fields}
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

    defimpl ExMatch.Match do
      @moduledoc false

      def escape(%WithValue{module: module, fields: fields}),
        do: ExMatch.Struct.escape(module, fields, false)

      def value(%WithValue{value: value}),
        do: value

      def diff(left, right, opts) do
        %WithValue{module: module, fields: fields, value: value} = left

        ExMatch.Match.Any.diff_values(value, right, opts, fn _ ->
          ExMatch.Struct.diff(module, fields, false, right, opts)
        end)
      end
    end
  end

  defmodule NoValue do
    defstruct [:module, :fields, :partial]

    defimpl ExMatch.Match do
      @moduledoc false

      def escape(%NoValue{module: module, fields: fields, partial: partial}),
        do: ExMatch.Struct.escape(module, fields, partial)

      def value(%NoValue{}),
        do: raise(ArgumentError, "This struct doesn't have value")

      def diff(left, right, opts) do
        %NoValue{module: module, fields: fields, partial: partial} = left
        ExMatch.Struct.diff(module, fields, partial, right, opts)
      end
    end
  end

  def parse(
        {:%, _, [module, {:%{}, _, fields}]},
        parse_ast,
        opts
      )
      when is_list(fields) do
    {partial, bindings, parsed} = ExMatch.Map.parse_fields(fields, parse_ast, opts)

    self =
      quote do
        ExMatch.Struct.new(
          unquote(module),
          unquote(parsed),
          unquote(partial),
          unquote(opts)
        )
      end

    {bindings, self}
  end

  def new(module, fields, partial, opts) do
    {partial, fields} =
      case Map.get(opts, module) do
        nil ->
          {partial, fields}

        %ExMatch.Map{} = opts ->
          partial = opts.partial || partial
          fields = Keyword.merge(opts.fields, fields)
          {partial, fields}
      end

    new(module, fields, partial)
  end

  defp new(module, fields, partial) do
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

    case ExMatch.Match.ExMatch.Map.diff(map, right_map, opts) do
      {left_diff, right_diff} ->
        make_diff(module, fields, partial, right, left_diff, right_diff)

      _ when module != rstruct ->
        left_diff = []
        right_diff = %{}
        make_diff(module, fields, partial, right, left_diff, right_diff)

      bindings ->
        bindings
    end
  end

  def diff(module, fields, partial, right, _opts) do
    {escape(module, fields, partial), right}
  end

  defp make_diff(module, fields, partial, %rstruct{} = right, left_diff, right_diff) do
    right_diff = Map.put(right_diff, :__struct__, rstruct)

    try do
      _ = inspect(right_diff, safe: false)
      {{:%, [], [module, left_diff]}, right_diff}
    rescue
      _ ->
        {escape(module, fields, partial), right}
    end
  end

  def escape(module, fields, partial) do
    map = %ExMatch.Map{
      partial: partial,
      fields: fields
    }

    map = ExMatch.Match.ExMatch.Map.escape(map)

    {:%, [], [module, map]}
  end
end
