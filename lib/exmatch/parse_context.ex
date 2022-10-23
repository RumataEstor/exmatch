defmodule ExMatch.ParseContext do
  @enforce_keys [:parse_ast, :opts]
  defstruct @enforce_keys

  def parse(ast, parse_context) do
    %__MODULE__{parse_ast: parse_ast} = parse_context
    parse_ast.(ast, parse_context)
  end

  def opts(parse_context) do
    %__MODULE__{opts: opts} = parse_context
    opts
  end
end
