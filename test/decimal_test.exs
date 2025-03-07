defmodule ExMatchTest.Decimal do
  use ExMatchTest.TestCase

  require ExMatch

  test "match" do
    eleven = 11
    opts = ExMatch.options([{Decimal, [:match_integer, :match_string]}])
    ExMatch.match(1, ~m(1.0), [{Decimal, [:match_integer]}])
    ExMatch.match("1", ~m(1.0), [{Decimal, [:match_string]}])
    ExMatch.match(Decimal.mult("0.5", 2), 1, opts)
    ExMatch.match(%{a: 1}, %{a: ~m(1.0)}, opts)
    ExMatch.match(%{a: 1}, %{a: Decimal.add("0.8", "0.2")}, opts)
    ExMatch.match(%Decimal{coef: 11, exp: -1, sign: 1}, ~m(1.1))
    ExMatch.match(%Decimal{..., coef: id(eleven)}, ~m(1.1))
    ExMatch.match(%Decimal{coef: 11, exp: 1 - 1, sign: 1}, Decimal.add(1, 10))
  end

  test "Decimal options must be a list" do
    assert_raise(
      Protocol.UndefinedError,
      ~r"^protocol Enumerable not implemented for (type Atom\. This protocol is implemented for the following type\(s\): .*[ \n]*Got value:[ \n]*:match_integer|:match_integer of type Atom\.)",
      fn -> ExMatch.match(1, ~m(1.0), [{Decimal, :match_integer}]) end
    )
  end

  test "partial diff with a literal" do
    match_fails(
      ExMatch.match(%Decimal{coef: 11, exp: -1, sign: 1}, ~m(11)),
      """
      left:  %Decimal{exp: -1}
      right: %Decimal{exp: 0}
      """
    )
  end

  test "partial diff with a variable" do
    eleven = 11

    match_fails(
      ExMatch.match(%Decimal{coef: ^eleven, exp: 1 - 1, sign: 1}, Decimal.add(1, eleven)),
      """
      left:  %Decimal{coef: ^eleven = 11}
      right: %Decimal{coef: 12}
      """
    )
  end

  test "whole value diff" do
    match_fails(
      ExMatch.match(~m(1.1), nil),
      """
      left:  ~m(1.1) = #{inspect_decimal(1.1)}
      right: nil
      """
    )
  end

  defp inspect_decimal(value), do: inspect(Decimal.new(to_string(value)))
end
