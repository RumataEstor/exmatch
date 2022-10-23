alias ExMatch.ParseContext

defmodule ExMatch.Options do
  @moduledoc false

  @enforce_keys [:opts]
  defstruct @enforce_keys

  def parse({:%{}, _, items}, parse_ast) do
    parse(items, parse_ast)
  end

  def parse(items, parse_ast) when is_list(items) do
    parse_context = %ParseContext{parse_ast: parse_ast, opts: Macro.escape(%{})}

    fields =
      Enum.map(items, fn
        {:%, _, [struct, {:%{}, _, _} = opts]} ->
          parse_option(struct, opts, parse_context)

        {struct, opts} ->
          parse_option(struct, opts, parse_context)

        other ->
          raise "Option item must be a structs or `{struct_module :: atom(), struct_opts :: term()}`, got: #{Macro.to_string(other)}"
      end)

    opts = {:%{}, [], fields}

    quote location: :keep do
      %ExMatch.Options{opts: unquote(opts)}
    end
  end

  defp parse_option(struct, opts, parse_context) do
    case ParseContext.parse(opts, parse_context) do
      {[], map} ->
        {struct, map}

      {vars, _} ->
        raise "Options cannot export variables, found #{Macro.to_string(vars)} in struct #{Macro.to_string(struct)}"
    end
  end

  def parse(other, _parse_ast) do
    cond do
      Macro.quoted_literal?(other) ->
        raise "Options argument must be a map or a list, got: #{Macro.to_string(other)}"

      true ->
        other
    end
  end
end
