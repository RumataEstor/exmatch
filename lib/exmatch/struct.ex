defmodule ExMatch.Struct do
  @moduledoc false

  alias ExMatch.ParseContext

  defmodule WithValue do
    @enforce_keys [:module, :fields, :value]
    defstruct @enforce_keys

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
    @enforce_keys [:module, :fields, :partial]
    defstruct @enforce_keys

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

  def parse({:%, _, [module, {:%{}, _, fields}]}, parse_context) when is_list(fields) do
    {partial, bindings, parsed} = ExMatch.Map.parse_fields(fields, parse_context)

    self =
      quote location: :keep do
        ExMatch.Struct.new(
          unquote(module),
          unquote(parsed),
          unquote(partial),
          unquote(ParseContext.opts(parse_context))
        )
      end

    {bindings, self}
  end

  def new(module, fields, partial, opts) do
    case Map.get(opts, module) do
      nil ->
        new(module, fields, partial)

      %ExMatch.Map{} = opts ->
        partial = opts.partial || partial
        fields = Keyword.merge(opts.fields, fields)
        new(module, fields, partial)
    end
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
        left_diff = quote(do: %{})
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
