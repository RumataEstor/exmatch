defmodule ExMatch.ParseContext do
  @enforce_keys [:opts]
  defstruct @enforce_keys

  def parse(ast, parse_context) do
    ExMatch.Parser.parse_ast(ast, parse_context)
  end

  def opts(parse_context) do
    %__MODULE__{opts: opts} = parse_context
    opts
  end
end
