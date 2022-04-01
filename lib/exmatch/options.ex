defmodule ExMatch.Options do
  defstruct [:opts]

  def parse({:%{}, _, items}, parse_ast) do
    parse(items, parse_ast)
  end

  def parse(items, parse_ast) when is_list(items) do
    empty_opts = Macro.escape(%{})

    fields =
      Enum.map(items, fn
        {:%, _, [struct, {:%{}, _, _} = opts]} ->
          parse_option(struct, opts, parse_ast, empty_opts)

        {struct, opts} ->
          parse_option(struct, opts, parse_ast, empty_opts)

        other ->
          raise "Option item must be a structs or `{struct_module :: atom(), struct_opts :: term()}`, got: #{Macro.to_string(other)}"
      end)

    opts = {:%{}, [], fields}

    quote do
      %ExMatch.Options{opts: unquote(opts)}
    end
  end

  defp parse_option(struct, opts, parse_ast, empty_opts) do
    case parse_ast.(opts, empty_opts) do
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
