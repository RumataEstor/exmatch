defmodule ExMatch.Struct do
  @moduledoc false

  alias ExMatch.ParseContext

  defmodule WithValue do
    @enforce_keys [:module, :base, :fields, :value]
    defstruct @enforce_keys

    defimpl ExMatch.Pattern do
      @moduledoc false

      def escape(%WithValue{module: module, base: base, fields: fields}),
        do: ExMatch.Struct.escape(module, base, fields, false)

      def value(%WithValue{value: value}),
        do: value

      def diff(left, right, opts) do
        %WithValue{module: module, base: base, fields: fields, value: value} = left

        case ExMatch.Pattern.diff(value, right, opts) do
          [] -> []
          _ -> ExMatch.Struct.diff(module, base, fields, false, right, opts)
        end
      end
    end
  end

  defmodule NoValue do
    @enforce_keys [:module, :base, :fields, :partial]
    defstruct @enforce_keys

    defimpl ExMatch.Pattern do
      @moduledoc false

      def escape(%NoValue{module: module, base: base, fields: fields, partial: partial}),
        do: ExMatch.Struct.escape(module, base, fields, partial)

      def value(%NoValue{}),
        do: throw(ExMatch.NoValue)

      def diff(left, right, opts) do
        %NoValue{module: module, base: base, fields: fields, partial: partial} = left
        ExMatch.Struct.diff(module, base, fields, partial, right, opts)
      end
    end
  end

  def parse({:%, _, [module, {:%{}, _, fields}]}, parse_context) when is_list(fields) do
    {base_parsed, fields} =
      case fields do
        [{:|, _, [base, fields]}] ->
          {[], base_parsed} = ExMatch.Expr.parse(base, parse_context)
          {base_parsed, fields}

        _ ->
          {nil, fields}
      end

    {partial, bindings, parsed} = ExMatch.Map.parse_fields(fields, parse_context)

    self =
      quote location: :keep do
        ExMatch.Struct.new(
          unquote(module),
          unquote(base_parsed),
          unquote(parsed),
          unquote(partial),
          unquote(ParseContext.opts(parse_context))
        )
      end

    {bindings, self}
  end

  def new(module, base, fields, partial, opts) do
    case Map.get(opts, module) do
      opts when base != nil or opts == nil ->
        new(module, base, fields, partial)

      %ExMatch.Map{} = opts ->
        partial = if(base, do: false, else: opts.partial || partial)
        fields = fields ++ Keyword.drop(opts.fields, Keyword.keys(fields))
        new(module, base, fields, partial)
    end
  end

  defp new(module, base, fields, partial) do
    if partial do
      # caught below
      throw(ExMatch.NoValue)
    end

    {value, fields} =
      case ExMatch.Pattern.value(base) do
        nil ->
          value = struct!(module, ExMatch.Map.field_values(fields))

          fields =
            value
            |> Map.from_struct()
            |> Enum.to_list()
            |> Keyword.merge(fields, fn _, _, field -> field end)

          {value, fields}

        %base_struct{} = base_value when base_struct == module ->
          value = struct!(base_value, ExMatch.Map.field_values(fields))
          {value, fields}

        value ->
          struct = %NoValue{
            module: module,
            base: base,
            fields: fields,
            partial: partial
          }

          raise "The #{ExMatch.Pattern.escape(struct)} struct update syntax was called with #{inspect(value)} as a base"
      end

    %WithValue{
      module: module,
      base: base,
      fields: fields,
      value: value
    }
  catch
    ExMatch.NoValue ->
      %NoValue{
        module: module,
        base: base,
        fields: fields,
        partial: partial
      }
  end

  defp base_fields(nil, _fields), do: []

  defp base_fields(base, fields) do
    base
    |> ExMatch.Pattern.value()
    |> Map.from_struct()
    |> Map.drop(Keyword.keys(fields))
    |> Enum.sort()
  end

  def diff(module, base, fields, partial, %rstruct{} = right, opts) do
    all_fields = fields ++ base_fields(base, fields)

    right_map = Map.from_struct(right)

    case ExMatch.Map.diff_items(all_fields, right_map, partial, opts) do
      {left_diff, right_diff} ->
        make_diff(module, base, fields, partial, right, left_diff, right_diff)

      _ when module != rstruct ->
        left_diff = []
        right_diff = []
        make_diff(module, base, fields, partial, right, left_diff, right_diff)

      bindings ->
        bindings
    end
  end

  def diff(module, base, fields, partial, right, _opts) do
    {escape(module, base, fields, partial, nil), right}
  end

  defp make_diff(module, base, fields, _partial, %rstruct{}, left_diff, right_diff) do
    {escape(module, base, fields, true, left_diff), escape(rstruct, nil, right_diff, true, nil)}
  end

  def escape(module, base, fields, _partial, diff \\ nil) do
    base_info =
      case base do
        %ExMatch.Expr{ast: base_expr} ->
          base_fields =
            base
            |> base_fields(fields)
            |> fields_in_diff(diff)

          {base_expr, base_fields}

        nil ->
          nil
      end

    fields =
      fields
      |> fields_in_diff(diff)
      |> ExMatch.Map.escape_fields()

    module = Macro.to_string(module)

    rendered =
      case base_info do
        nil ->
          ["%", module, "{" | ExMatch.Map.render_fields(fields, "}")]

        {base_expr, base_fields} when fields == [] ->
          [
            ExMatch.View.inspect(base_expr),
            " = %",
            module,
            "{"
            | ExMatch.Map.render_fields(base_fields, "}")
          ]

        {base_expr, base_fields} ->
          [
            "%",
            module,
            "{(",
            ExMatch.View.inspect(base_expr),
            " = %",
            module,
            "{"
            | ExMatch.Map.render_fields(base_fields, [
                "}) | " | ExMatch.Map.render_fields(fields, "}")
              ])
          ]
      end

    ExMatch.View.Rendered.new(rendered)
  end

  defp fields_in_diff(fields, nil), do: fields

  defp fields_in_diff(fields, diff),
    do: Keyword.take(diff, Keyword.keys(fields))
end
