defmodule ExMatch.Options do
  defstruct [:opts]

  def parse({:%{}, meta, opts_fields}, parse_ast) do
    opts_fields =
      Enum.map(opts_fields, fn {struct, struct_opts} ->
        {[], map} = parse_ast.(struct_opts, Macro.escape(%{}))
        {struct, map}
      end)

    opts = {:%{}, meta, opts_fields}

    quote do
      %ExMatch.Options{opts: unquote(opts)}
    end
  end

  def parse(other, _parse_ast) do
    cond do
      Macro.quoted_literal?(other) ->
        raise "options must be a map or an expression returning a map"

      true ->
        other
    end
  end
end
