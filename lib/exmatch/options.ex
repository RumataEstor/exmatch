defmodule ExMatch.Options do
  @moduledoc false

  alias ExMatch.ParseContext

  @enforce_keys [:opts]
  defstruct @enforce_keys

  def parse({:%{}, _, items}, env) do
    parse(items, env)
  end

  def parse(items, env) when is_list(items) do
    parse_context = %ParseContext{opts: Macro.escape(%{}), env: env}

    fields =
      Enum.map(items, fn
        {:%, _, [struct, {:%{}, _, _} = opts]} ->
          parse_option(struct, opts, parse_context)

        {struct, opts} ->
          parse_option(struct, opts, parse_context)

        other ->
          raise "An option item must be a struct or `{struct_module :: atom(), struct_opts :: term()}`, got: #{Macro.to_string(other)}"
      end)

    opts = {:%{}, [], fields}

    quote location: :keep do
      %ExMatch.Options{opts: unquote(opts)}
    end
  end

  def parse(opts_expr, _env) do
    if Macro.quoted_literal?(opts_expr) do
      raise "Options argument must be a map or a list, got: #{Macro.to_string(opts_expr)}"
    end

    quote location: :keep do
      case unquote(opts_expr) do
        %ExMatch.Options{} = opts ->
          opts

        other ->
          raise "The options provided as #{unquote(Macro.to_string(opts_expr))} must be built using ExMatch.options/1, got #{inspect(other)}"
      end
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
end
