defmodule ExMatchTest.TestCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      require ExMatch
      import ExMatchTest.TestCase
    end
  end

  defmacro sigil_m({:<<>>, _, [string]}, []) do
    decimal =
      string
      |> String.replace("_", "")
      |> Decimal.new()
      |> Macro.escape()

    quote do
      unquote(decimal)
    end
  end

  defmacro match_fails(expr, expected_message) do
    quote do
      result =
        try do
          unquote(expr)
          :ok
        rescue
          error in ExUnit.AssertionError ->
            error
        end

      if result == :ok do
        raise ExUnit.AssertionError, "expected to raise but returned successfully"
      end

      result_message =
        result
        |> Exception.message()
        |> String.replace_leading("\n\nmatch failed\n", "")

      assert unquote(expected_message) == result_message
    end
  end
end
